//
//  tvOSPlaybackShellView.swift
//  CaptionTheater
//
//  Fullscreen-first playback shell with Caption Theater offer and stacked caption band (CT-0501 / CT-0502).
//

import SwiftUI

/// Fullscreen playback surface: Caption Theater offer when cues qualify, then optional top-stacked caption column.
///
/// Touches **playback** via ``tvOSCaptionTheaterPlayerContainer`` (``AVPlayerLayer`` + ``AVLayerVideoGravity/resizeAspect``—no aspect-fill),
/// **layout** via ``CaptionTheaterLayoutEngine``, Play/Pause via the Siri Remote command, **transport** via ``tvOSPlaybackTransportDrawer`` (CT-0504),
/// and **engineering telemetry** via ``CaptionTheaterPlaybackLogger``.
struct tvOSPlaybackShellView: View {

    /// `Namespace` id for ``View/focusScope(_:)`` so **playback** keeps tvOS default focus while directional moves can still reach the **transport drawer** (separate ``View/focusSection()``).
    @Namespace private var transportFocusNamespace

    @AppStorage(CaptionTheaterCaptionTextPreferences.textSizePresetStorageKey)
    private var captionTextSizeRaw = CaptionTheaterCaptionTextPreferences.defaultTextSizeRawValue

    @AppStorage("CaptionTheater.playbackDebugHUD")
    private var playbackDebugHUD = false

    @AppStorage(tvOSPlaybackTransportDrawer.captionScrollingHistoryStorageKey)
    private var captionScrollingHistoryEnabled = true

    @State private var model: CaptionTheaterPlaybackShellViewModel?

    @State private var transportDrawerExpanded = false

    /// After the user chooses an option—or bundled non-scope content skips the offer—prompt logic stops for this shell instance.
    @State private var captionTheaterOfferResolvedForSession = false

    @State private var showCaptionTheaterOfferAlert = false

    private let demoSource: CaptionTheaterPlaybackDemoSource
    private let playbackURL: URL?

    private var captionTextSizePreset: CaptionTheaterCaptionTextSizePreset {
        CaptionTheaterCaptionTextSizePreset.resolved(fromStoredRaw: captionTextSizeRaw)
    }

    init(demoSource: CaptionTheaterPlaybackDemoSource, playbackURL: URL?) {
        self.demoSource = demoSource
        self.playbackURL = playbackURL
    }

    var body: some View {
        Group {
            if let playbackURL {
                playbackBody(url: playbackURL)
            } else {
                missingPlaybackPlaceholder
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var missingPlaybackPlaceholder: some View {
        ContentUnavailableView(
            "Playback unavailable",
            systemImage: "film.stack",
            description: Text(missingPlaybackGuidance)
        )
    }

    private var missingPlaybackGuidance: String {
        demoSource.missingPlaybackGuidance
    }

    private func playbackBody(url: URL) -> some View {
        Group {
            if let model {
                fullscreenPlayback(model: model)
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView("Opening stream…")
                        .foregroundStyle(.secondary)
                }
                .task(id: url.absoluteString) {
                    CaptionTheaterPlaybackLogger.playbackFlow("tvOSPlaybackShellView creating ViewModel for playbackBody")
                    model?.detachPlaybackObservers()
                    model = CaptionTheaterPlaybackShellViewModel(url: url, demoSource: demoSource)
                }
            }
        }
        .background(Color.black)
        .onDisappear {
            model?.detachPlaybackObservers()
        }
    }

    private func fullscreenPlayback(model: CaptionTheaterPlaybackShellViewModel) -> some View {
        ZStack(alignment: .bottomTrailing) {
            // Keep `.focusable` / Play-Pause **only** on the stage. Wrapping the whole `ZStack` (including the
            // transport drawer) makes tvOS deliver the Siri Remote **Select** action to the wrong focus
            // environment, so drawer `Button`s highlight but never run their actions (CT-0504).
            ZStack {
                Color.black.ignoresSafeArea()

                if let failure = model.playbackFailureDescription {
                    ContentUnavailableView(
                        "Playback failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(failure)
                    )
                    .focusable(true) { focused in
                        CaptionTheaterPlaybackLogger.playbackFocus(
                            "playbackFailureView.focusable focused=\(focused) drawerExpanded=\(transportDrawerExpanded)"
                        )
                    }
                    .prefersDefaultFocus(true, in: transportFocusNamespace)
                } else {
                    GeometryReader { geo in
                        let contentInsets = CaptionTheaterLayoutContentInsets(
                            top: Double(geo.safeAreaInsets.top),
                            left: Double(geo.safeAreaInsets.leading),
                            bottom: Double(geo.safeAreaInsets.bottom),
                            right: Double(geo.safeAreaInsets.trailing)
                        )
                        playbackStage(model: model, containerSize: geo.size, contentInsets: contentInsets)
                    }
                    .ignoresSafeArea()
                }
            }
            .focusSection()

            if model.playbackFailureDescription == nil {
                tvOSPlaybackTransportDrawer(model: model, isExpanded: $transportDrawerExpanded)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .prefersDefaultFocus(false, in: transportFocusNamespace)
                    .focusSection()
            }
        }
        .focusScope(transportFocusNamespace)
        .onMoveCommand { direction in
            CaptionTheaterPlaybackLogger.playbackFocus(
                "fullscreenPlayback.onMoveCommand direction=\(direction) drawerExpanded=\(transportDrawerExpanded)"
            )
        }
        .onChange(of: transportDrawerExpanded) { _, expanded in
            CaptionTheaterPlaybackLogger.playbackFocus("transportDrawerExpanded changed -> \(expanded)")
        }
        .onPlayPauseCommand {
            model.togglePlayPause()
        }
        .onChange(of: model.presentationAspectGeneration) { _, _ in
            considerCaptionTheaterOffer(model: model)
        }
        .onChange(of: showCaptionTheaterOfferAlert) { _, presented in
            CaptionTheaterPlaybackLogger.playbackFocus("Caption Theater offer alert presented=\(presented)")
        }
        .alert("Caption Theater", isPresented: $showCaptionTheaterOfferAlert) {
            Button("Use Caption Theater") {
                CaptionTheaterPlaybackLogger.playbackFlow("User chose Caption Theater (stacked captions)")
                model.captionTheaterOptInAccepted = true
                model.captionTheaterTopPinnedLayoutEnabled = true
                captionTheaterOfferResolvedForSession = true
                model.logCaptionTheaterLayoutPipeline(reason: "After CT alert confirm")
                model.refreshCaptionTheaterLegiblePipeline(reason: "After CT alert confirm")
            }
            Button("Standard playback", role: .cancel) {
                CaptionTheaterPlaybackLogger.playbackFlow("User chose standard centered playback")
                model.captionTheaterOptInAccepted = false
                model.captionTheaterTopPinnedLayoutEnabled = false
                captionTheaterOfferResolvedForSession = true
                model.logCaptionTheaterLayoutPipeline(reason: "After CT alert standard")
                model.refreshCaptionTheaterLegiblePipeline(reason: "After CT alert standard")
            }
        } message: {
            Text(
                "This title looks scope-friendly or streams over HTTP(S). Pin video to the top and show captions in the dedicated band below?"
            )
        }
        .onChange(of: model.captionTheaterOptInAccepted) { _, _ in
            model.refreshCaptionTheaterLegiblePipeline(reason: "captionTheaterOptInAccepted changed")
        }
        .onChange(of: model.captionTheaterTopPinnedLayoutEnabled) { _, _ in
            model.refreshCaptionTheaterLegiblePipeline(reason: "captionTheaterTopPinnedLayoutEnabled changed")
        }
    }

    @ViewBuilder
    private func playbackStage(
        model: CaptionTheaterPlaybackShellViewModel,
        containerSize: CGSize,
        contentInsets: CaptionTheaterLayoutContentInsets
    ) -> some View {
        let layout = model.layoutGeometry(containerSize: containerSize, contentInsets: contentInsets)
        let layoutAnimationIdentity = Self.layoutAnimationIdentity(layout)

        if model.captionTheaterOptInAccepted,
           model.captionTheaterTopPinnedLayoutEnabled,
           let layout,
           layout.captionReadingRect.height > 0.5
        {
            topPinnedVideoWithCaptionColumn(model: model, containerSize: containerSize, layout: layout)
                .animation(.easeInOut(duration: 0.2), value: layoutAnimationIdentity)
        } else {
            ZStack(alignment: .topLeading) {
                tvOSCaptionTheaterPlayerContainer(
                    player: model.player,
                    videoDisplayRect: layout?.activePictureRect
                )
                .frame(width: containerSize.width, height: containerSize.height)
                .focusable(true) { videoFocused in
                    CaptionTheaterPlaybackLogger.playbackFocus(
                        "centeredLayout.player.focusable focused=\(videoFocused) drawerExpanded=\(transportDrawerExpanded)"
                    )
                }
                .prefersDefaultFocus(true, in: transportFocusNamespace)
                .overlay {
                    Rectangle()
                        .strokeBorder(Color.green, lineWidth: 4)
                }

                debugHudOverlay(model: model, containerSize: containerSize)
            }
            .animation(.easeInOut(duration: 0.2), value: layoutAnimationIdentity)
        }
    }

    /// Stable string for SwiftUI layout transitions when picture/caption rects change size or origin.
    private static func layoutAnimationIdentity(_ layout: CaptionTheaterLayoutGeometry?) -> String {
        guard let layout else {
            return "nil"
        }
        let p = layout.activePictureRect
        let c = layout.captionReadingRect
        return "\(p.origin.x),\(p.origin.y),\(p.size.width),\(p.size.height)|\(c.origin.y),\(c.size.height)"
    }

    /// Top-pinned letterbox math with a **physical** lower ``VStack`` column for caption rendering (debug stroked).
    private func topPinnedVideoWithCaptionColumn(
        model: CaptionTheaterPlaybackShellViewModel,
        containerSize: CGSize,
        layout: CaptionTheaterLayoutGeometry
    ) -> some View {
        let pictureHeight = layout.activePictureRect.height
        let captionHeight = max(0, layout.captionReadingRect.height)
        let columnLeading = layout.captionReadingRect.minX
        let columnWidth = layout.captionReadingRect.width
        let columnTrailingGutter = max(0, containerSize.width - layout.captionReadingRect.maxX)

        return ZStack(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: 0) {
                Color.clear.frame(width: columnLeading)
                VStack(spacing: 0) {
                    ZStack {
                        Color.black
                        tvOSCaptionTheaterPlayerContainer(
                            player: model.player,
                            videoDisplayRect: CGRect(
                                x: layout.activePictureRect.minX - columnLeading,
                                y: 0,
                                width: layout.activePictureRect.width,
                                height: layout.activePictureRect.height
                            )
                        )
                        .frame(width: columnWidth, height: pictureHeight)
                        .focusable(true) { videoFocused in
                            CaptionTheaterPlaybackLogger.playbackFocus(
                                "topPinned.player.focusable focused=\(videoFocused) drawerExpanded=\(transportDrawerExpanded)"
                            )
                        }
                        .prefersDefaultFocus(true, in: transportFocusNamespace)
                        .overlay {
                            Rectangle()
                                .strokeBorder(Color.green, lineWidth: 4)
                        }
                    }
                    .frame(width: columnWidth, height: pictureHeight)

                    captionTheaterCaptionColumn(
                        model: model,
                        width: columnWidth,
                        height: captionHeight,
                        captionScrollingHistoryEnabled: captionScrollingHistoryEnabled
                    )
                }
                Color.clear.frame(width: columnTrailingGutter)
            }
            .frame(width: containerSize.width, height: containerSize.height, alignment: .top)

            if playbackDebugHUD {
                debugHudOverlay(model: model, containerSize: containerSize)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .top)
    }

    /// Caption band: either a scrolling history (**newest-first**) or a single latest line (traditional-style).
    ///
    /// Builds the ``CaptionTheaterCaptionRenderPlan`` here (cue rows + pause state + text-size preset) and hands it
    /// to ``CaptionTheaterCaptionRendererView`` (CT-0404), which owns no geometry of its own — this call site is
    /// responsible for sizing the band from ``CaptionTheaterLayoutGeometry/captionReadingRect``.
    private func captionTheaterCaptionColumn(
        model: CaptionTheaterPlaybackShellViewModel,
        width: CGFloat,
        height: CGFloat,
        captionScrollingHistoryEnabled: Bool
    ) -> some View {
        let plan = CaptionTheaterCaptionRendererPolicy.plan(
            rows: model.visibleCaptionRows,
            textSizePreset: captionTextSizePreset,
            isPlaybackPaused: model.isPlaybackPaused
        )

        return CaptionTheaterCaptionRendererView(
            plan: plan,
            textSizePreset: captionTextSizePreset,
            isScrollingHistoryEnabled: captionScrollingHistoryEnabled
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .focusable(false)
        .frame(width: width, height: height, alignment: .top)
        .background(Color(red: 0.06, green: 0.06, blue: 0.08))
        .overlay {
            Rectangle()
                .strokeBorder(Color.blue, lineWidth: 4)
        }
    }

    private func considerCaptionTheaterOffer(model: CaptionTheaterPlaybackShellViewModel) {
        guard model.presentationProbeFinished else {
            return
        }
        guard !captionTheaterOfferResolvedForSession else {
            return
        }

        guard model.qualifiesForCaptionTheaterOffer else {
            CaptionTheaterPlaybackLogger.playbackFlow(
                "Caption Theater offer suppressed (local clip / non-offer heuristic) remote=\(model.playbackUsesRemoteURL) ar=\(model.pictureAspectRatioWidthOverHeight ?? -1)"
            )
            model.captionTheaterOptInAccepted = false
            model.captionTheaterTopPinnedLayoutEnabled = false
            captionTheaterOfferResolvedForSession = true
            return
        }

        CaptionTheaterPlaybackLogger.playbackFlow(
            "Presenting Caption Theater offer remote=\(model.playbackUsesRemoteURL) aspectUltraWide=\(model.isUltraWideEncodedPicture) ar=\(model.pictureAspectRatioWidthOverHeight ?? -1)"
        )
        showCaptionTheaterOfferAlert = true
    }

    @ViewBuilder
    private func debugHudOverlay(model: CaptionTheaterPlaybackShellViewModel, containerSize: CGSize) -> some View {
        if playbackDebugHUD {
            let inspection = model.eligibilityInspection()
            VStack(alignment: .leading, spacing: 4) {
                Text(model.presentationAspectSummary)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.85))
                Text(formatClock(model.currentSeconds))
                    .monospacedDigit()
                Text("Duration \(formatClock(model.durationSeconds))")
                    .monospacedDigit()
                Text(inspection.outcomeHeadline)
                    .font(.caption2.weight(.semibold))
                Text(inspection.outcomeDetail)
                    .font(.caption2)
            }
            .padding(10)
            .background(Color.black.opacity(0.55))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(width: containerSize.width, height: containerSize.height, alignment: .topTrailing)
            .padding(16)
        }
    }

    private func formatClock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    NavigationStack {
        tvOSPlaybackShellView(
            demoSource: .bundledSyntheticSample,
            playbackURL: CaptionTheaterPlaybackFixture.sampleVideoURL()
        )
    }
}
