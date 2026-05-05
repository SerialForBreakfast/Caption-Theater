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
/// **layout** via ``CaptionTheaterLayoutEngine``, Play/Pause via the Siri Remote command, and **engineering telemetry** via ``CaptionTheaterPlaybackLogger``.
struct tvOSPlaybackShellView: View {

    @AppStorage(CaptionTheaterCaptionTextPreferences.textSizePresetStorageKey)
    private var captionTextSizeRaw = CaptionTheaterCaptionTextPreferences.defaultTextSizeRawValue

    @AppStorage("CaptionTheater.playbackDebugHUD")
    private var playbackDebugHUD = false

    @State private var model: CaptionTheaterPlaybackShellViewModel?

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
        switch demoSource {
        case .bundledSyntheticSample:
            return "Add \(CaptionTheaterPlaybackFixture.sampleVideoResourceName).\(CaptionTheaterPlaybackFixture.sampleVideoExtension) to the app target Media folder."
        case .muxTearsOfSteelHLS:
            return "The Mux demo URL failed to resolve. Change `CaptionTheater.playbackDemoSource` in User Defaults if needed."
        }
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
                    model = CaptionTheaterPlaybackShellViewModel(url: url)
                }
            }
        }
        .background(Color.black)
        .onDisappear {
            model?.detachPlaybackObservers()
        }
    }

    private func fullscreenPlayback(model: CaptionTheaterPlaybackShellViewModel) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let failure = model.playbackFailureDescription {
                ContentUnavailableView(
                    "Playback failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(failure)
                )
            } else {
                GeometryReader { geo in
                    playbackStage(model: model, containerSize: geo.size)
                }
                .ignoresSafeArea()
            }
        }
        .focusable(true)
        .onPlayPauseCommand {
            model.togglePlayPause()
        }
        .onChange(of: model.presentationAspectGeneration) { _, _ in
            considerCaptionTheaterOffer(model: model)
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
    private func playbackStage(model: CaptionTheaterPlaybackShellViewModel, containerSize: CGSize) -> some View {
        let layout = model.layoutGeometry(containerSize: containerSize)

        if model.captionTheaterOptInAccepted,
           model.captionTheaterTopPinnedLayoutEnabled,
           let layout,
           layout.captionReadingRect.height > 0.5
        {
            topPinnedVideoWithCaptionColumn(model: model, containerSize: containerSize, layout: layout)
        } else {
            ZStack(alignment: .topLeading) {
                tvOSCaptionTheaterPlayerContainer(
                    player: model.player,
                    videoDisplayRect: layout?.activePictureRect
                )
                .frame(width: containerSize.width, height: containerSize.height)

                debugHudOverlay(model: model, containerSize: containerSize)
            }
        }
    }

    /// Top-pinned letterbox math with a **physical** lower ``VStack`` column for caption rendering (debug stroked).
    private func topPinnedVideoWithCaptionColumn(
        model: CaptionTheaterPlaybackShellViewModel,
        containerSize: CGSize,
        layout: CaptionTheaterLayoutGeometry
    ) -> some View {
        let pictureHeight = layout.activePictureRect.height
        let captionHeight = max(0, layout.captionReadingRect.height)

        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                ZStack {
                    Color.black
                    tvOSCaptionTheaterPlayerContainer(
                        player: model.player,
                        videoDisplayRect: CGRect(
                            x: layout.activePictureRect.minX,
                            y: 0,
                            width: layout.activePictureRect.width,
                            height: layout.activePictureRect.height
                        )
                    )
                    .frame(width: containerSize.width, height: pictureHeight)
                }
                .frame(width: containerSize.width, height: pictureHeight)

                captionTheaterCaptionColumn(
                    model: model,
                    width: containerSize.width,
                    height: captionHeight
                )
            }
            .frame(width: containerSize.width, height: containerSize.height, alignment: .top)

            if playbackDebugHUD {
                debugHudOverlay(model: model, containerSize: containerSize)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .top)
    }

    /// Scrolling caption band: **newest cue at the top**, older cues below via ``CaptionTheaterPlaybackShellViewModel/captionScrollingCueEntries``.
    private func captionTheaterCaptionColumn(
        model: CaptionTheaterPlaybackShellViewModel,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .center, spacing: 12) {
                    if model.captionScrollingCueEntries.isEmpty {
                        Text(
                            "Waiting for captions…"
                        )
                        .font(captionTextSizePreset.captionOverlayFont)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.65)
                        .lineLimit(8)
                        .padding(.horizontal, 4)
                    } else {
                        ForEach(model.captionScrollingCueEntries) { entry in
                            Text(entry.text)
                                .font(captionTextSizePreset.captionOverlayFont)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.65)
                                .lineLimit(8)
                                .frame(maxWidth: .infinity)
                                .id(entry.id)
                        }
                    }
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: model.captionScrollingCueEntries.first?.id) { _, newId in
                guard let newId else {
                    return
                }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(newId, anchor: .top)
                }
            }
        }
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
