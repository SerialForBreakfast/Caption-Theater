//
//  tvOSPlaybackShellView.swift
//  CaptionTheater
//
//  Fullscreen-first playback shell with ultra-wide Caption Theater offer (CT-0501 / CT-0502).
//

import SwiftUI

/// Fullscreen playback surface: native presentation by default, optional ultra-wide Caption Theater layout.
///
/// Touches **playback** via ``tvOSCaptionTheaterPlayerContainer`` (``AVLayerVideoGravity/resizeAspect`` only—no aspect-fill),
/// **layout** via ``CaptionTheaterLayoutEngine``, and **engineering telemetry** via ``CaptionTheaterPlaybackLogger``
/// (Console category `PlaybackFlow`).
struct tvOSPlaybackShellView: View {

    @AppStorage(CaptionTheaterCaptionTextPreferences.textSizePresetStorageKey)
    private var captionTextSizeRaw = CaptionTheaterCaptionTextPreferences.defaultTextSizeRawValue

    @AppStorage("CaptionTheater.playbackDebugHUD")
    private var playbackDebugHUD = false

    @State private var model: CaptionTheaterPlaybackShellViewModel?

    /// After the encoded aspect ratio arrives, non-ultra-wide titles skip the offer permanently for this presentation.
    @State private var ultraWideOfferResolvedForSession = false

    @State private var showUltraWideCaptionTheaterOffer = false

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
            return "The Mux demo URL failed to resolve. Use the Debug tab to confirm the networked demo source."
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
                    let layout = model.layoutGeometry(containerSize: geo.size)
                    ZStack(alignment: .topLeading) {
                        tvOSCaptionTheaterPlayerContainer(
                            player: model.player,
                            videoDisplayRect: layout?.activePictureRect
                        )
                        .frame(width: geo.size.width, height: geo.size.height)

                        captionTheaterReadingBand(model: model, layout: layout)

                        debugHudOverlay(model: model)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .focusable(true)
        .onPlayPauseCommand {
            model.togglePlayPause()
        }
        .onChange(of: model.pictureAspectRatioWidthOverHeight) { _, newAspect in
            reactToPresentationAspectChange(model: model, newAspect: newAspect)
        }
        .alert("Ultra-wide picture", isPresented: $showUltraWideCaptionTheaterOffer) {
            Button("Caption Theater") {
                CaptionTheaterPlaybackLogger.playbackFlow("User accepted Caption Theater layout for ultra-wide session")
                model.captionTheaterOptInAccepted = true
                model.captionTheaterTopPinnedLayoutEnabled = true
                ultraWideOfferResolvedForSession = true
            }
            Button("Standard", role: .cancel) {
                CaptionTheaterPlaybackLogger.playbackFlow("User declined Caption Theater; using standard centered presentation")
                model.captionTheaterOptInAccepted = false
                model.captionTheaterTopPinnedLayoutEnabled = false
                ultraWideOfferResolvedForSession = true
            }
        } message: {
            Text(
                "This encode uses a wider-than-HDTV active picture. Caption Theater pins video to the top and reserves the lower area for captions."
            )
        }
    }

    private func reactToPresentationAspectChange(
        model: CaptionTheaterPlaybackShellViewModel,
        newAspect: Double?
    ) {
        guard let aspect = newAspect else {
            return
        }
        guard !ultraWideOfferResolvedForSession else {
            return
        }

        if aspect > Double(CaptionTheaterPlaybackUILayout.ultrawideAspectRatioThresholdWidthOverHeight) {
            CaptionTheaterPlaybackLogger.playbackFlow("Presentation aspect triggers ultra-wide offer alert aspect=\(aspect)")
            showUltraWideCaptionTheaterOffer = true
        } else {
            CaptionTheaterPlaybackLogger.playbackFlow("Presentation aspect is standard HDTV-shaped; skipping Caption Theater offer aspect=\(aspect)")
            model.captionTheaterOptInAccepted = false
            model.captionTheaterTopPinnedLayoutEnabled = false
            ultraWideOfferResolvedForSession = true
        }
    }

    @ViewBuilder
    private func captionTheaterReadingBand(
        model: CaptionTheaterPlaybackShellViewModel,
        layout: CaptionTheaterLayoutGeometry?
    ) -> some View {
        if model.captionTheaterOptInAccepted,
           model.captionTheaterTopPinnedLayoutEnabled,
           let layout,
           layout.captionReadingRect.height > 1
        {
            Text(
                "Caption Theater band — timed text renders here in Phase 4. Native WebVTT may still composite over video until then."
            )
            .font(captionTextSizePreset.captionOverlayFont)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.65)
            .lineLimit(8)
            .padding(.horizontal, 12)
            .frame(width: layout.captionReadingRect.width, height: layout.captionReadingRect.height)
            .background(Color(red: 0.06, green: 0.06, blue: 0.08))
            .position(x: layout.captionReadingRect.midX, y: layout.captionReadingRect.midY)
        }
    }

    @ViewBuilder
    private func debugHudOverlay(model: CaptionTheaterPlaybackShellViewModel) -> some View {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
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
