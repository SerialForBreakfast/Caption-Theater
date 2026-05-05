//
//  tvOSPlaybackShellView.swift
//  CaptionTheater
//
//  Fixture-driven playback surface with inspector-backed eligibility (CT-0501 / CT-0502).
//

import SwiftUI

/// Shell that hosts bundled fixture playback plus inspector-backed eligibility and MVP layout (CT-0501 / CT-0502 / CT-0303 slice).
///
/// Touches **playback** via ``tvOSCaptionTheaterPlayerContainer`` (``AVLayerVideoGravity/resizeAspect`` only—no aspect-fill),
/// **captions/eligibility** via bundled manifests/metadata classifiers, **caption typography** via persisted ``CaptionTheaterCaptionTextSizePreset``, and **layout** via ``CaptionTheaterLayoutEngine``.
struct tvOSPlaybackShellView: View {

    @State private var model: CaptionTheaterPlaybackShellViewModel?
    @State private var captionTheaterEnablePromptShown = false

    @AppStorage(CaptionTheaterCaptionTextPreferences.textSizePresetStorageKey)
    private var captionTextSizeRaw = CaptionTheaterCaptionTextPreferences.defaultTextSizeRawValue

    private let fixtureURL: URL?

    private var captionTextSizePreset: CaptionTheaterCaptionTextSizePreset {
        CaptionTheaterCaptionTextSizePreset.resolved(fromStoredRaw: captionTextSizeRaw)
    }

    init(fixtureURL: URL?) {
        self.fixtureURL = fixtureURL
    }

    var body: some View {
        Group {
            if let fixtureURL {
                playbackBody(url: fixtureURL)
            } else {
                missingFixturePlaceholder
            }
        }
        .navigationTitle("Playback")
    }

    private var missingFixturePlaceholder: some View {
        ContentUnavailableView(
            "Sample video missing",
            systemImage: "film.stack",
            description: Text(
                "Add \(CaptionTheaterPlaybackFixture.sampleVideoResourceName).\(CaptionTheaterPlaybackFixture.sampleVideoExtension) to the app target Media folder."
            )
        )
    }

    private func playbackBody(url: URL) -> some View {
        Group {
            if let model {
                playbackContent(model: model)
            } else {
                ProgressView("Loading player…")
                    .task {
                        model = CaptionTheaterPlaybackShellViewModel(url: url)
                    }
            }
        }
        .onDisappear {
            model?.detachPlaybackObservers()
        }
    }

    private func playbackContent(model: CaptionTheaterPlaybackShellViewModel) -> some View {
        let inspection = model.eligibilityInspection()
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                videoStage(model: model, inspection: inspection)

                transportControls(model: model)

                scenarioPicker(model: model)

                captionTextSizeMenu

                captionTheaterControls(model: model)

                eligibilitySummary(model: model, inspection: inspection)
            }
            .padding()
        }
        .scrollIndicators(.visible)
        .confirmationDialog(
            "Enable Caption Theater for this session?",
            isPresented: $captionTheaterEnablePromptShown,
            titleVisibility: .visible
        ) {
            Button("Use Caption Theater") {
                model.captionTheaterOptInAccepted = true
            }
            Button("Stay native only", role: .cancel) {
                model.captionTheaterOptInAccepted = false
            }
        } message: {
            Text(
                "This demo reserves letterbox space for captions when eligibility allows. Ads and native subtitles keep normal fullscreen behavior."
            )
        }
    }

    private func videoStage(
        model: CaptionTheaterPlaybackShellViewModel,
        inspection: CaptionTheaterDebugDecisionInspection
    ) -> some View {
        GeometryReader { geo in
            let layout = model.layoutGeometry(containerSize: geo.size)
            ZStack(alignment: .topLeading) {
                tvOSCaptionTheaterPlayerContainer(
                    player: model.player,
                    videoDisplayRect: layout?.activePictureRect
                )
                .frame(width: geo.size.width, height: geo.size.height)

                captionPlaceholder(model: model, layout: layout, textSizePreset: captionTextSizePreset)

                if model.showDebugOverlay {
                    debugOverlay(model: model, inspection: inspection)
                }

                presentationBadge(model: model, inspection: inspection, optIn: model.captionTheaterOptInAccepted)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }

    /// Chooses caption typography for MVP overlays; persisted for upcoming Phase 4 renderer integration.
    private var captionTextSizeMenu: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Caption appearance")
                .font(.headline)
            Menu {
                ForEach(CaptionTheaterCaptionTextSizePreset.allCases) { preset in
                    Button {
                        captionTextSizeRaw = preset.rawValue
                    } label: {
                        HStack {
                            Text(preset.menuTitle)
                            if preset.rawValue == captionTextSizeRaw {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(captionTextSizePreset.menuTitle, systemImage: "textformat.size")
            }
            Text(
                "Extra letterbox space supports larger captions without covering picture; Phase 4 renderer will honor this preset."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func captionPlaceholder(
        model: CaptionTheaterPlaybackShellViewModel,
        layout: CaptionTheaterLayoutGeometry?,
        textSizePreset: CaptionTheaterCaptionTextSizePreset
    ) -> some View {
        if model.captionTheaterTopPinnedLayoutEnabled,
           let layout,
           layout.captionReadingRect.height > 8
        {
            Text("Caption Theater captions (MVP placeholder)")
                .font(textSizePreset.captionOverlayFont)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.65)
                .lineLimit(6)
                .frame(width: layout.captionReadingRect.width, height: layout.captionReadingRect.height)
                .background(Color.white.opacity(0.14))
                .position(x: layout.captionReadingRect.midX, y: layout.captionReadingRect.midY)
        }
    }

    private func presentationBadge(
        model: CaptionTheaterPlaybackShellViewModel,
        inspection: CaptionTheaterDebugDecisionInspection,
        optIn: Bool
    ) -> some View {
        let text: String
        let color: Color
        if !optIn {
            text = "Native presentation"
            color = .secondary
        } else if inspection.outcomeHeadline == "Caption Theater eligible" {
            if model.captionTheaterTopPinnedLayoutEnabled {
                text = "Caption Theater (top-pinned MVP, resizeAspect only)"
                color = .green
            } else {
                text = "Caption Theater eligible (centered aspect-fit)"
                color = .green
            }
        } else {
            text = "Native presentation (eligibility blocked)"
            color = .orange
        }

        return Text(text)
            .font(.caption.weight(.semibold))
            .padding(8)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(10)
            .foregroundStyle(color)
    }

    private func debugOverlay(
        model: CaptionTheaterPlaybackShellViewModel,
        inspection: CaptionTheaterDebugDecisionInspection
    ) -> some View {
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
        .padding(8)
        .background(Color.black.opacity(0.55))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(10)
    }

    private func transportControls(model: CaptionTheaterPlaybackShellViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transport")
                .font(.headline)
            HStack(spacing: 16) {
                Button("Back 15s") {
                    model.seek(by: -15)
                }
                Button("Play / Pause") {
                    model.togglePlayPause()
                }
                Button("Ahead 15s") {
                    model.seek(by: 15)
                }
            }
            // SwiftUI Slider is unavailable on tvOS; coarse jumps plus Siri remote scrubbing from VideoPlayer.
            HStack(spacing: 16) {
                Button("Start") {
                    model.seekToNormalizedProgress(0)
                }
                Button("Middle") {
                    model.seekToNormalizedProgress(0.5)
                }
                Button("Near end") {
                    model.seekToNormalizedProgress(0.92)
                }
            }
            .disabled(model.durationSeconds <= 0)
        }
    }

    private func scenarioPicker(model: CaptionTheaterPlaybackShellViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Evidence scenario")
                .font(.headline)
            Picker(
                "Scenario",
                selection: Binding(
                    get: { model.scenarioKind },
                    set: { newValue in
                        Task { await model.applyScenario(newValue) }
                    }
                )
            ) {
                ForEach(CaptionTheaterPlaybackScenarioKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }

            Text(model.scenarioKind.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let loadError = model.scenarioLoadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func captionTheaterControls(model: CaptionTheaterPlaybackShellViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Caption Theater")
                .font(.headline)

            Toggle(
                "Caption Theater session",
                isOn: Binding(
                    get: { model.captionTheaterOptInAccepted },
                    set: { newValue in
                        if newValue {
                            captionTheaterEnablePromptShown = true
                        } else {
                            model.captionTheaterOptInAccepted = false
                        }
                    }
                )
            )

            Toggle(
                "Debug overlay",
                isOn: Binding(
                    get: { model.showDebugOverlay },
                    set: { model.showDebugOverlay = $0 }
                )
            )

            Toggle(
                "Top-pin cinematic layout (MVP)",
                isOn: Binding(
                    get: { model.captionTheaterTopPinnedLayoutEnabled },
                    set: { model.captionTheaterTopPinnedLayoutEnabled = $0 }
                )
            )

            Text(
                "Player uses AVPlayerLayer resizeAspect only—aspect-fill/zoom is excluded from this milestone."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if model.scenarioKind == .manualLegacyToggles {
                manualLegacyDemoToggles(model: model)
            }
        }
    }

    private func manualLegacyDemoToggles(model: CaptionTheaterPlaybackShellViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual demo overrides")
                .font(.subheadline.weight(.semibold))

            Toggle(
                "Demo: assume WebVTT selected",
                isOn: Binding(
                    get: { model.demoAssumeWebVTTSelected },
                    set: { model.demoAssumeWebVTTSelected = $0 }
                )
            )
            Toggle(
                "Demo: assume safe letterbox viewport",
                isOn: Binding(
                    get: { model.demoAssumeSafeLetterboxViewport },
                    set: { model.demoAssumeSafeLetterboxViewport = $0 }
                )
            )

            Text(
                "Stub snapshot toggles from CT-0501; bundled scenarios above exercise real inspectors instead."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func eligibilitySummary(
        model: CaptionTheaterPlaybackShellViewModel,
        inspection: CaptionTheaterDebugDecisionInspection
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eligibility (same engine as tests)")
                .font(.headline)
            Text(inspection.outcomeHeadline)
                .font(.title3.weight(.semibold))
            Text(inspection.outcomeDetail)
                .foregroundStyle(.secondary)

            Text(inspection.lifecycleTransitionNote)
                .font(.caption)
                .foregroundStyle(.secondary)
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
        tvOSPlaybackShellView(fixtureURL: CaptionTheaterPlaybackFixture.sampleVideoURL())
    }
}
