//
//  CaptionTheaterPlaybackScenarioResources.swift
//  CaptionTheater
//
//  Loads bundled playback fixtures that mirror CT-0502 acceptance paths.
//

import Foundation

/// Packaged inspector outputs for one bundled playback scenario.
nonisolated struct CaptionTheaterPlaybackScenarioPack: Equatable, Sendable {
    let manifest: HLSManifestInspection?
    let provider: ProviderMetadataInspection?
    let subtitle: SubtitleMetadataClassification?
}

/// Bundled playback scenarios that exercise real inspectors alongside fixture MP4 playback.
///
/// Resources live under `CaptionTheater/Media/PlaybackScenarios` in source control; Xcode may copy them
/// into the app bundle with that subdirectory preserved **or** flattened at the bundle root—loaders accept both.
nonisolated enum CaptionTheaterPlaybackScenarioKind: String, CaseIterable, Identifiable, Sendable {
    /// Trusted letterbox metadata + WebVTT dialogue + clear multivariant manifest.
    case eligibleUltraWideLetterbox
    /// Same metadata/subtitles with an encrypted multivariant manifest declaration.
    case eligibleUltraWideEncryptedManifest
    /// Full-frame manifest hint + WebVTT dialogue without provider metadata (inactive-region gate fails).
    case fullFrame16x9WebVTT
    /// Burned-in subtitle metadata blocks Caption Theater even when provider metadata is otherwise trusted.
    case burnedInSubtitlesWithTrustedProvider
    /// Provider warns variable aspect ratio; stays native even with eligible-looking rectangles.
    case variableAspectProviderWarning
    /// Previous demo toggles without inspector bundles (escape hatch).
    case manualLegacyToggles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eligibleUltraWideLetterbox:
            return "Eligible letterbox (trusted + WebVTT)"
        case .eligibleUltraWideEncryptedManifest:
            return "Eligible + encrypted manifest markers"
        case .fullFrame16x9WebVTT:
            return "Full-frame 16:9 manifest hint"
        case .burnedInSubtitlesWithTrustedProvider:
            return "Burned-in subtitles (native)"
        case .variableAspectProviderWarning:
            return "Variable aspect provider warning"
        case .manualLegacyToggles:
            return "Manual demo toggles"
        }
    }

    var summary: String {
        switch self {
        case .eligibleUltraWideLetterbox:
            return "Runs real inspectors on bundled manifest/subtitle/provider fixtures aligned with CT-0502."
        case .eligibleUltraWideEncryptedManifest:
            return "Manifest declares SAMPLE-AES markers while trusted provider metadata authorizes presentation."
        case .fullFrame16x9WebVTT:
            return "1920×1080 variant metadata implies full-frame presentation; Caption Theater should fail closed."
        case .burnedInSubtitlesWithTrustedProvider:
            return "Subtitle classifier rejects burned-in pixels before viewport gates."
        case .variableAspectProviderWarning:
            return "Provider QC warns variable aspect ratio; viewport classification stays native."
        case .manualLegacyToggles:
            return "Uses stub snapshot builder toggles from CT-0501 without bundled inspector JSON."
        }
    }

    /// Preferred bundle subdirectory mirroring the repo folder; omitted when Xcode flattens resources.
    static let playbackScenarioResourcesSubdirectory = "PlaybackScenarios"

    /// Loads inspector bundles from `Bundle.main`.
    func loadPack(bundle: Bundle = .main) throws -> CaptionTheaterPlaybackScenarioPack {
        switch self {
        case .manualLegacyToggles:
            return CaptionTheaterPlaybackScenarioPack(manifest: nil, provider: nil, subtitle: nil)

        case .eligibleUltraWideLetterbox:
            return try Self.load(
                bundle: bundle,
                manifestName: "playback-sidecar-webvtt-master",
                providerName: "playback-provider-trusted-eligible-letterbox",
                subtitleName: "playback-subtitle-dialogue-webvtt"
            )

        case .eligibleUltraWideEncryptedManifest:
            return try Self.load(
                bundle: bundle,
                manifestName: "playback-encrypted-session-key-master",
                providerName: "playback-provider-trusted-eligible-letterbox",
                subtitleName: "playback-subtitle-dialogue-webvtt"
            )

        case .fullFrame16x9WebVTT:
            return try Self.load(
                bundle: bundle,
                manifestName: "playback-full-frame-no-subtitles-master",
                providerName: nil,
                subtitleName: "playback-subtitle-dialogue-webvtt"
            )

        case .burnedInSubtitlesWithTrustedProvider:
            return try Self.load(
                bundle: bundle,
                manifestName: "playback-sidecar-webvtt-master",
                providerName: "playback-provider-trusted-eligible-letterbox",
                subtitleName: "playback-subtitle-burned-in"
            )

        case .variableAspectProviderWarning:
            return try Self.load(
                bundle: bundle,
                manifestName: "playback-sidecar-webvtt-master",
                providerName: "playback-provider-variable-aspect-warning",
                subtitleName: "playback-subtitle-dialogue-webvtt"
            )
        }
    }

    private static func load(
        bundle: Bundle,
        manifestName: String?,
        providerName: String?,
        subtitleName: String?
    ) throws -> CaptionTheaterPlaybackScenarioPack {
        let manifestInspector = HLSManifestInspector()
        let providerInspector = ProviderMetadataInspector()
        let subtitleClassifier = SubtitleMetadataClassifier()

        let manifest: HLSManifestInspection?
        if let manifestName {
            let text = try Self.loadUTF8Text(resource: manifestName, extension: "m3u8", bundle: bundle)
            manifest = manifestInspector.inspect(text)
        } else {
            manifest = nil
        }

        let provider: ProviderMetadataInspection?
        if let providerName {
            let data = try Self.loadData(resource: providerName, extension: "json", bundle: bundle)
            let document = try providerInspector.decode(data)
            provider = providerInspector.inspect(document)
        } else {
            provider = nil
        }

        let subtitle: SubtitleMetadataClassification?
        if let subtitleName {
            let data = try Self.loadData(resource: subtitleName, extension: "json", bundle: bundle)
            let document = try subtitleClassifier.decode(data)
            subtitle = subtitleClassifier.classify(document)
        } else {
            subtitle = nil
        }

        return CaptionTheaterPlaybackScenarioPack(
            manifest: manifest,
            provider: provider,
            subtitle: subtitle
        )
    }

    private static func loadData(resource name: String, extension ext: String, bundle: Bundle) throws -> Data {
        guard let url = bundle.urlForPlaybackScenarioResource(name: name, extension: ext) else {
            throw CaptionTheaterPlaybackScenarioResourceError.missingFile("\(name).\(ext)")
        }
        return try Data(contentsOf: url)
    }

    private static func loadUTF8Text(resource name: String, extension ext: String, bundle: Bundle) throws -> String {
        guard let url = bundle.urlForPlaybackScenarioResource(name: name, extension: ext) else {
            throw CaptionTheaterPlaybackScenarioResourceError.missingFile("\(name).\(ext)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

extension Bundle {

    /// Resolves playback demo fixtures whether Xcode copied them under ``PlaybackScenarios`` or flat into the bundle root.
    fileprivate func urlForPlaybackScenarioResource(name: String, extension ext: String) -> URL? {
        if let url = url(forResource: name, withExtension: ext, subdirectory: CaptionTheaterPlaybackScenarioKind.playbackScenarioResourcesSubdirectory) {
            return url
        }
        return url(forResource: name, withExtension: ext)
    }
}

/// Missing bundled playback fixture.
nonisolated enum CaptionTheaterPlaybackScenarioResourceError: Error, Equatable, Sendable {
    case missingFile(String)
}
