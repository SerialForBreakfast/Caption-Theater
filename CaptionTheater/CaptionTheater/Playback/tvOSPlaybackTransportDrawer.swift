//
//  tvOSPlaybackTransportDrawer.swift
//  CaptionTheater
//
//  Slide-out playback controls + caption mode toggle for the tvOS shell (CT-0504).
//

import AVFoundation
import SwiftUI
import UIKit

// MARK: - Timeline scrub control (tvOS)

/// Horizontal scrub bar for tvOS playback. `UISlider` and SwiftUI `Slider` are unavailable here, so this `UIControl`
/// uses `UIControl` **touch tracking** (Siri Remote touch surface + Simulator click-drag). `UIPanGestureRecognizer` alone
/// is a poor match for Simulator and some indirect inputs; accessibility adjustable nudges still apply.
/// Emits ``UIControl.Event/valueChanged`` while the user adjusts the playhead.
///
/// **Concurrency:** All API is main-thread only; used only from `UIViewRepresentable` on the main actor.
private final class TVPlaybackTimelineScrubControl: UIControl {

    private let trackBackground = UIView()
    private let trackFill = UIView()
    private let thumbView = UIView()
    private let focusChrome = UIView()

    private let trackHeight: CGFloat = 8
    private let thumbDiameter: CGFloat = 32

    /// Normalized 0...1; updated by playback sync and user scrubbing.
    private(set) var scrubNormalizedValue: CGFloat = 0

    /// While true, ignore playback snapshots from ``tvOSPlaybackTimelineScrubber`` so the thumb does not jump during a scrub.
    private(set) var isTrackingScrub: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isAccessibilityElement = true
        accessibilityTraits.formUnion(.adjustable)
        accessibilityLabel = "Playback position"

        trackBackground.isUserInteractionEnabled = false
        trackBackground.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.28)
        trackBackground.layer.cornerRadius = trackHeight / 2
        trackBackground.clipsToBounds = true

        trackFill.isUserInteractionEnabled = false
        trackFill.backgroundColor = UIColor.tintColor
        trackFill.layer.cornerRadius = trackHeight / 2
        trackFill.clipsToBounds = true

        thumbView.isUserInteractionEnabled = false
        thumbView.backgroundColor = UIColor.label
        thumbView.layer.cornerRadius = thumbDiameter / 2
        thumbView.layer.shadowColor = UIColor.black.cgColor
        thumbView.layer.shadowOpacity = 0.35
        thumbView.layer.shadowRadius = 4
        thumbView.layer.shadowOffset = .zero

        focusChrome.isUserInteractionEnabled = false
        focusChrome.layer.cornerRadius = 12
        focusChrome.layer.cornerCurve = .continuous
        focusChrome.layer.borderWidth = 0

        addSubview(trackBackground)
        addSubview(trackFill)
        addSubview(thumbView)
        insertSubview(focusChrome, belowSubview: thumbView)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 52)
    }

    /// Applies read-only playhead updates from ``CaptionTheaterPlaybackShellViewModel`` without emitting `valueChanged`.
    func applyPlaybackProgress(_ normalized: CGFloat) {
        guard !isTrackingScrub else { return }
        let clamped = min(1, max(0, normalized))
        guard abs(clamped - scrubNormalizedValue) > 0.001 else { return }
        scrubNormalizedValue = clamped
        setNeedsLayout()
        layoutIfNeeded()
        updateAccessibilityValue()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let midY = bounds.midY
        let usableWidth = max(0, bounds.width - thumbDiameter)
        let trackY = midY - trackHeight / 2
        let trackX = thumbDiameter / 2

        trackBackground.frame = CGRect(x: trackX, y: trackY, width: usableWidth, height: trackHeight)

        let fillWidth = usableWidth * scrubNormalizedValue
        trackFill.frame = CGRect(x: trackX, y: trackY, width: max(0, fillWidth), height: trackHeight)

        let thumbCenterX = trackX + usableWidth * scrubNormalizedValue
        thumbView.frame = CGRect(
            x: thumbCenterX - thumbDiameter / 2,
            y: midY - thumbDiameter / 2,
            width: thumbDiameter,
            height: thumbDiameter
        )

        let chromeOutset: CGFloat = 8
        focusChrome.frame = bounds.insetBy(dx: -chromeOutset, dy: -chromeOutset)
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard isUserInteractionEnabled else { return false }
        isTrackingScrub = true
        let value = normalizedValue(atHorizontalLocation: touch.location(in: self).x)
        setScrubNormalizedValueFromUser(value)
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let value = normalizedValue(atHorizontalLocation: touch.location(in: self).x)
        setScrubNormalizedValueFromUser(value)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        isTrackingScrub = false
        if let touch {
            let value = normalizedValue(atHorizontalLocation: touch.location(in: self).x)
            setScrubNormalizedValueFromUser(value)
        }
        super.endTracking(touch, with: event)
    }

    override func cancelTracking(with event: UIEvent?) {
        isTrackingScrub = false
        super.cancelTracking(with: event)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        let nextType = context.nextFocusedView.map { String(describing: type(of: $0)) } ?? "nil"
        let prevType = context.previouslyFocusedView.map { String(describing: type(of: $0)) } ?? "nil"
        CaptionTheaterPlaybackLogger.playbackFocus(
            "TVPlaybackTimelineScrubControl didUpdateFocus isFocused=\(isFocused) nextType=\(nextType) prevType=\(prevType)"
        )
        focusChrome.layer.borderColor = UIColor.white.cgColor
        focusChrome.layer.borderWidth = isFocused ? 4 : 0
        coordinator.addCoordinatedAnimations {
            let scale: CGFloat = self.isFocused ? 1.12 : 1
            self.thumbView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }

    override func accessibilityIncrement() {
        let next = min(1, scrubNormalizedValue + 0.05)
        setScrubNormalizedValueFromUser(next)
    }

    override func accessibilityDecrement() {
        let next = max(0, scrubNormalizedValue - 0.05)
        setScrubNormalizedValueFromUser(next)
    }

    private func normalizedValue(atHorizontalLocation x: CGFloat) -> CGFloat {
        let usableWidth = max(1, bounds.width - thumbDiameter)
        let trackStart = thumbDiameter / 2
        let clampedX = min(max(x, trackStart), trackStart + usableWidth)
        return min(1, max(0, (clampedX - trackStart) / usableWidth))
    }

    private func setScrubNormalizedValueFromUser(_ value: CGFloat) {
        let clamped = min(1, max(0, value))
        scrubNormalizedValue = clamped
        setNeedsLayout()
        layoutIfNeeded()
        updateAccessibilityValue()
        sendActions(for: .valueChanged)
    }

    private func updateAccessibilityValue() {
        let percent = Int((scrubNormalizedValue * 100).rounded())
        accessibilityValue = "\(percent) percent"
    }
}

/// Bridges the custom scrub control into SwiftUI. `Slider` / `UISlider` are unavailable on tvOS.
private struct tvOSPlaybackTimelineScrubber: UIViewRepresentable {

    /// Normalized playhead 0...1; writes propagate to the host via ``CaptionTheaterPlaybackShellViewModel/seekToNormalizedProgress``.
    @Binding var normalizedProgress: Double

    /// Mirrors SwiftUI `.disabled`; scrub gestures are inactive when duration is unknown.
    var isUserInteractionEnabled: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(binding: $normalizedProgress)
    }

    func makeUIView(context: Context) -> TVPlaybackTimelineScrubControl {
        let control = TVPlaybackTimelineScrubControl()
        control.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return control
    }

    func updateUIView(_ uiView: TVPlaybackTimelineScrubControl, context: Context) {
        uiView.isUserInteractionEnabled = isUserInteractionEnabled
        uiView.applyPlaybackProgress(CGFloat(normalizedProgress))
    }

    final class Coordinator: NSObject {
        var binding: Binding<Double>

        init(binding: Binding<Double>) {
            self.binding = binding
        }

        @objc func valueChanged(_ sender: TVPlaybackTimelineScrubControl) {
            binding.wrappedValue = Double(sender.scrubNormalizedValue)
        }
    }
}

/// Collapsed trailing affordance that expands into play/pause, skip, scrubber, and scrolling-caption toggle.
///
/// **Focus:** Uses white 4 pt focus chrome on controls. **Menu / Back** (`onExitCommand`) collapses the expanded panel;
/// **Close** is an explicit ``Label`` for Select.
struct tvOSPlaybackTransportDrawer: View {

    /// Persists “retain scrolling caption history” vs “latest line only” across launches.
    static let captionScrollingHistoryStorageKey = "CaptionTheater.captionScrollingHistoryEnabled"

    @Bindable var model: CaptionTheaterPlaybackShellViewModel
    @Binding var isExpanded: Bool

    @AppStorage(Self.captionScrollingHistoryStorageKey)
    private var captionScrollingHistoryEnabled: Bool = true

    @AppStorage(CaptionTheaterCaptionTextPreferences.textSizePresetStorageKey)
    private var captionTextSizePresetRaw = CaptionTheaterCaptionTextPreferences.defaultTextSizeRawValue

    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion

    private var collapseAnimation: Animation {
        accessibilityReduceMotion ? .default : .easeInOut(duration: 0.22)
    }

    var body: some View {
        Group {
            if isExpanded {
                expandedPanel
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                collapsedGlyph
                    .transition(.opacity)
            }
        }
        .animation(collapseAnimation, value: isExpanded)
        .onChange(of: isExpanded) { _, expanded in
            CaptionTheaterPlaybackLogger.playbackFocus("transportDrawer.root isExpanded=\(expanded)")
        }
    }

    private var collapsedGlyph: some View {
        Button {
            isExpanded = true
            CaptionTheaterPlaybackLogger.playbackFlow("Transport drawer expanded")
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(14)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.card)
        .tvOSHighContrastFocusCircleBorder()
        .logTVOSFocusTransitions("transportDrawer.collapsedGlyph")
        .accessibilityLabel("Playback and caption settings")
        .accessibilityHint("Opens transport, caption size, and scrolling options")
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Playback")
                    .font(.headline)
                Spacer(minLength: 8)
                Button {
                    collapseTransportDrawer(reason: "Transport drawer collapsed (Close)")
                } label: {
                    Label("Close", systemImage: "xmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.card)
                .tvOSHighContrastFocusBorder(cornerRadius: 14)
                .logTVOSFocusTransitions("transportDrawer.close")
                .accessibilityLabel("Close")
                .accessibilityHint("Closes playback and caption settings")
            }

            HStack(spacing: 20) {
                Button {
                    model.seek(by: -Self.skipSeconds)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                .buttonStyle(.card)
                .tvOSHighContrastFocusBorder(cornerRadius: 14)
                .logTVOSFocusTransitions("transportDrawer.rewind15")
                .accessibilityLabel("Rewind 15 seconds")

                Button {
                    model.togglePlayPause()
                } label: {
                    Image(systemName: playPauseSymbolName)
                        .font(.title)
                }
                .buttonStyle(.card)
                .tvOSHighContrastFocusBorder(cornerRadius: 14)
                .logTVOSFocusTransitions("transportDrawer.playPause")
                .accessibilityLabel(model.timeControlStatus == .playing ? "Pause" : "Play")

                Button {
                    model.seek(by: Self.skipSeconds)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
                .buttonStyle(.card)
                .tvOSHighContrastFocusBorder(cornerRadius: 14)
                .logTVOSFocusTransitions("transportDrawer.ffwd15")
                .accessibilityLabel("Fast forward 15 seconds")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(formatClock(model.currentSeconds))
                        .font(.caption2.monospacedDigit())
                    Spacer()
                    Text(formatClock(model.durationSeconds))
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(.secondary)

                tvOSPlaybackTimelineScrubber(
                    normalizedProgress: scrubberBinding,
                    isUserInteractionEnabled: model.durationSeconds > 0
                )
                    .frame(height: 52)
                    .opacity(model.durationSeconds <= 0 ? 0.35 : 1)
                    .logTVOSFocusTransitions("transportDrawer.scrubberHost")
            }

            Toggle(isOn: $captionScrollingHistoryEnabled) {
                Label("Scrolling captions", systemImage: "list.bullet.rectangle")
            }
            .tvOSHighContrastFocusBorder(cornerRadius: 10)
            .logTVOSFocusTransitions("transportDrawer.scrollingToggle")
            .accessibilityHint("When on, recent lines stay visible in a scrollable column")

            Picker("Caption text size", selection: $captionTextSizePresetRaw) {
                ForEach(CaptionTheaterCaptionTextSizePreset.allCases) { preset in
                    Text(preset.menuTitle).tag(preset.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tvOSHighContrastFocusBorder(cornerRadius: 10)
            .logTVOSFocusTransitions("transportDrawer.captionSizePicker")
            .accessibilityHint("Larger sizes use the caption band below the picture")
        }
        .onExitCommand {
            collapseTransportDrawer(reason: "Transport drawer collapsed (Menu / back)")
        }
        .padding(20)
        .frame(width: 420, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var playPauseSymbolName: String {
        switch model.timeControlStatus {
        case .playing:
            return "pause.fill"
        case .paused, .waitingToPlayAtSpecifiedRate:
            return "play.fill"
        @unknown default:
            return "play.fill"
        }
    }

    private var scrubberBinding: Binding<Double> {
        Binding(
            get: {
                guard model.durationSeconds > 0 else { return 0 }
                return min(1, max(0, model.currentSeconds / model.durationSeconds))
            },
            set: { model.seekToNormalizedProgress($0) }
        )
    }

    private static var skipSeconds: Double {
        CaptionTheaterPlaybackShellViewModel.playbackTransportSkipSeconds
    }

    private func collapseTransportDrawer(reason: String) {
        guard isExpanded else {
            return
        }
        isExpanded = false
        CaptionTheaterPlaybackLogger.playbackFlow(reason)
    }

    private func formatClock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
