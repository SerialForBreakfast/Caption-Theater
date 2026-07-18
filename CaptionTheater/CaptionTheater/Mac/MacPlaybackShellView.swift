//
//  MacPlaybackShellView.swift
//  CaptionTheater
//
//  Native macOS playback shell with top-pinned Caption Theater layout.
//

#if os(macOS)
import AVFoundation
import SwiftUI

struct MacPlaybackShellView: View {

    @AppStorage(CaptionTheaterCaptionTextPreferences.textSizePresetStorageKey)
    private var captionTextSizeRaw = CaptionTheaterCaptionTextPreferences.defaultTextSizeRawValue

    @AppStorage(CaptionTheaterLaunchConfiguration.playbackDebugHUDStorageKey)
    private var playbackDebugHUD = false

    @AppStorage(CaptionTheaterLaunchConfiguration.playbackLayoutBorderStorageKey)
    private var playbackLayoutBorder = true

    @State private var model: MacPlaybackShellViewModel?

    let demoSource: CaptionTheaterPlaybackDemoSource
    let playbackURL: URL?

    private var captionTextSizePreset: CaptionTheaterCaptionTextSizePreset {
        CaptionTheaterCaptionTextSizePreset.resolved(fromStoredRaw: captionTextSizeRaw)
    }

    var body: some View {
        Group {
            if let playbackURL {
                playbackBody(url: playbackURL)
            } else {
                ContentUnavailableView(
                    "Playback unavailable",
                    systemImage: "film.stack",
                    description: Text(demoSource.missingPlaybackGuidance)
                )
            }
        }
        .background(Color.black)
        .onDisappear {
            if MacPlaybackStateStore.shared.activePlaybackModel === model {
                MacPlaybackStateStore.shared.activePlaybackModel = nil
            }
            model?.detachPlaybackObservers()
        }
    }

    private func playbackBody(url: URL) -> some View {
        Group {
            if let model {
                playbackStage(model: model)
            } else {
                ZStack {
                    Color.black
                    ProgressView("Opening stream...")
                        .foregroundStyle(.secondary)
                }
                .task(id: url.absoluteString) {
                    model?.detachPlaybackObservers()
                    model = MacPlaybackShellViewModel(url: url)
                    MacPlaybackStateStore.shared.activePlaybackModel = model
                }
            }
        }
    }

    private func playbackStage(model: MacPlaybackShellViewModel) -> some View {
        GeometryReader { geometry in
            let layout = model.layoutGeometry(containerSize: geometry.size)

            ZStack(alignment: .topLeading) {
                if let failure = model.playbackFailureDescription {
                    ContentUnavailableView(
                        "Playback failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(failure)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.captionTheaterTopPinnedLayoutEnabled,
                          let layout,
                          layout.captionReadingRect.height > 0.5
                {
                    topPinnedLayout(model: model, containerSize: geometry.size, layout: layout)
                } else {
                    MacCaptionTheaterPlayerContainer(player: model.player, videoDisplayRect: layout?.activePictureRect)
                        .overlay { playerBorder }
                }

                if playbackDebugHUD {
                    debugHud(model: model)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func topPinnedLayout(
        model: MacPlaybackShellViewModel,
        containerSize: CGSize,
        layout: CaptionTheaterLayoutGeometry
    ) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                MacCaptionTheaterPlayerContainer(
                    player: model.player,
                    videoDisplayRect: CGRect(
                        x: layout.activePictureRect.minX - layout.captionReadingRect.minX,
                        y: 0,
                        width: layout.activePictureRect.width,
                        height: layout.activePictureRect.height
                    )
                )
                .frame(width: layout.captionReadingRect.width, height: layout.activePictureRect.height)
                .overlay { playerBorder }
            }
            .frame(width: layout.captionReadingRect.width, height: layout.activePictureRect.height)

            captionBand(model: model, width: layout.captionReadingRect.width, height: layout.captionReadingRect.height)
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .top)
    }

    private func captionBand(model: MacPlaybackShellViewModel, width: CGFloat, height: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .center, spacing: 12) {
                if model.captionScrollingCueEntries.isEmpty {
                    Text("Waiting for captions...")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.captionScrollingCueEntries) { entry in
                        Text(entry.text)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(8)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .font(captionTextSizePreset.captionOverlayFont)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .frame(width: width, height: height, alignment: .top)
        .background(Color(red: 0.06, green: 0.06, blue: 0.08))
        .overlay {
            if playbackLayoutBorder {
                Rectangle()
                    .strokeBorder(Color.blue, lineWidth: 4)
            }
        }
    }

    @ViewBuilder
    private var playerBorder: some View {
        if playbackLayoutBorder {
            Rectangle()
                .strokeBorder(Color.green, lineWidth: 4)
        }
    }

    private func debugHud(model: MacPlaybackShellViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.presentationAspectSummary)
            Text(formatClock(model.currentSeconds))
                .monospacedDigit()
            Text("Duration \(formatClock(model.durationSeconds))")
                .monospacedDigit()
            Text(model.timeControlStatus == .playing ? "Playing" : "Paused")
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(10)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 6))
        .padding(16)
    }

    private func formatClock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else {
            return "00:00"
        }
        let total = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
#endif
