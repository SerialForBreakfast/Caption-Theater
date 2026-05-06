//
//  CaptionTheaterLegibleCaptionSink.swift
//  CaptionTheater
//
//  Push delegate for ``AVPlayerItemLegibleOutput`` (tvOS playback shell).
//

import AVFoundation
import Foundation

/// Receives ``AVPlayerItemLegibleOutput`` callbacks on a caller-provided dispatch queue (expected: main).
///
/// **Concurrency:** Instantiate once per playback shell; set ``setDelegate(_:queue:)`` on the legible output to
/// the main queue when updating ``@MainActor`` SwiftUI models from ``onAttributedStrings``.
final class CaptionTheaterLegibleCaptionSink: NSObject, AVPlayerItemLegibleOutputPushDelegate {

    /// Invoked when new timed legible samples arrive (may be empty between cues). Includes presentation item time for diagnostics.
    var onAttributedStrings: (([NSAttributedString], CMTime) -> Void)?

    /// Invoked after seeks or playback-direction changes; discard held cue text when this fires.
    var onOutputSequenceFlushed: (() -> Void)?

    func resetLegibleDeliveryTelemetry() {
        // Hook kept so ``CaptionTheaterPlaybackShellViewModel`` can reset counters if instrumentation returns later.
    }

    func legibleOutput(
        _ output: AVPlayerItemLegibleOutput,
        didOutputAttributedStrings strings: [NSAttributedString],
        nativeSampleBuffers nativeSamples: [Any],
        forItemTime itemTime: CMTime
    ) {
        _ = output
        _ = nativeSamples
        onAttributedStrings?(strings, itemTime)
    }

    func outputSequenceWasFlushed(_ output: AVPlayerItemOutput) {
        _ = output
        onOutputSequenceFlushed?()
    }
}
