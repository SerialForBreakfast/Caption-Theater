//
//  CaptionTheaterPlaybackFixture.swift
//  CaptionTheater
//
//  Bundled offline sample media for the tvOS playback shell (CT-0501).
//

import Foundation

/// Resolves packaged playback samples shipped inside the Caption Theater app bundle.
///
/// The sample file is a tiny synthetic clip (letterboxed inside 1080p) generated offline for demos.
/// It contains no audio and no third-party content.
enum CaptionTheaterPlaybackFixture {

    /// Resource name for ``sampleVideoURL()`` (without extension).
    static let sampleVideoResourceName = "CaptionTheaterSamplePlayback"

    /// File extension for ``sampleVideoURL()``.
    static let sampleVideoExtension = "mp4"

    /// URL of the packaged MP4 used by ``tvOSPlaybackShellView``, when present in the bundle.
    static func sampleVideoURL() -> URL? {
        Bundle.main.url(forResource: sampleVideoResourceName, withExtension: sampleVideoExtension)
    }
}
