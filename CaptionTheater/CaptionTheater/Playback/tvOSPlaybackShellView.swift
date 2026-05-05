//
//  tvOSPlaybackShellView.swift
//  CaptionTheater
//
//  Fixture-driven playback surface with Caption Theater toggles (CT-0501).
//

import AVKit
import SwiftUI

/// Shell that hosts bundled fixture playback plus Caption Theater controls ahead of layout integration.
///
/// Touches **playback geometry** (video presentation only), **eligibility toggles**, and a compact
/// **debug overlay**. Does not replace AVKit transport entirely; it layers stakeholder toggles required
/// by Phase 5 tasks.
struct tvOSPlaybackShellView: View {

    @State private var model: CaptionTheaterPlaybackShellViewModel?
    @State private var captionTheaterEnablePromptShown = false

    private let fixtureURL: URL?

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
        ZStack(alignment: .topLeading) {
            VideoPlayer(player: model.player)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if model.showDebugOverlay {
                debugOverlay(model: model, inspection: inspection)
            }

            presentationBadge(inspection: inspection, optIn: model.captionTheaterOptInAccepted)
        }
    }

    private func presentationBadge(
        inspection: CaptionTheaterDebugDecisionInspection,
        optIn: Bool
    ) -> some View {
        let text: String
        let color: Color
        if !optIn {
            text = "Native presentation"
            color = .secondary
        } else if inspection.outcomeHeadline == "Caption Theater eligible" {
            text = "Caption Theater presentation (layout pending CT-0303)"
            color = .green
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
                "Demo toggles stand in for manifest/subtitle/viewport adapters so you can rehearse eligible outcomes; turn them off to see conservative failures."
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
