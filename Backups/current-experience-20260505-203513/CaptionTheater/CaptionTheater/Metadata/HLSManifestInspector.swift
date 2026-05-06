import Foundation

/// Extracts safe, non-secret facts from a sanitized HLS manifest string.
///
/// `HLSManifestInspector` is stateless, synchronous, and nonisolated so manifest parsing can run away
/// from UI ownership. Callers should provide already-fetched, sanitized manifest text; this type does
/// not perform network access, key loading, media loading, or DRM interaction.
nonisolated struct HLSManifestInspector: Sendable {
    /// Creates an inspector with no retained state.
    init() {}

    /// Parses known HLS tags into a compact inspection model.
    ///
    /// Manifest inspection provides evidence only. It must not be treated as proof that inactive video
    /// regions are visually safe for Caption Theater.
    func inspect(_ manifestText: String) -> HLSManifestInspection {
        let lines = manifestText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var variants: [HLSVariantStream] = []
        var mediaRenditions: [HLSMediaRendition] = []
        var dateRanges: [HLSTagAttributes] = []
        var encryptionMethods: [String] = []
        var hasDiscontinuity = false
        var pendingStreamAttributes: [String: String]?

        for line in lines {
            if line.hasPrefix("#EXT-X-STREAM-INF:") {
                pendingStreamAttributes = parseAttributes(afterTagPrefix: "#EXT-X-STREAM-INF:", in: line)
                continue
            }

            if let attributes = pendingStreamAttributes, !line.hasPrefix("#") {
                variants.append(HLSVariantStream(attributes: attributes, uri: line))
                pendingStreamAttributes = nil
                continue
            }

            if line.hasPrefix("#EXT-X-MEDIA:") {
                let attributes = parseAttributes(afterTagPrefix: "#EXT-X-MEDIA:", in: line)
                mediaRenditions.append(HLSMediaRendition(attributes: attributes))
                continue
            }

            if line == "#EXT-X-DISCONTINUITY" {
                hasDiscontinuity = true
                continue
            }

            if line.hasPrefix("#EXT-X-DATERANGE:") {
                dateRanges.append(parseAttributes(afterTagPrefix: "#EXT-X-DATERANGE:", in: line))
                continue
            }

            if line.hasPrefix("#EXT-X-KEY:") {
                let attributes = parseAttributes(afterTagPrefix: "#EXT-X-KEY:", in: line)
                appendEncryptionMethod(from: attributes, to: &encryptionMethods)
                continue
            }

            if line.hasPrefix("#EXT-X-SESSION-KEY:") {
                let attributes = parseAttributes(afterTagPrefix: "#EXT-X-SESSION-KEY:", in: line)
                appendEncryptionMethod(from: attributes, to: &encryptionMethods)
                continue
            }
        }

        return HLSManifestInspection(
            isExtendedM3U: lines.first == "#EXTM3U",
            variants: variants,
            mediaRenditions: mediaRenditions,
            hasDiscontinuity: hasDiscontinuity,
            dateRanges: dateRanges,
            encryptionMethods: encryptionMethods
        )
    }

    private func appendEncryptionMethod(
        from attributes: [String: String],
        to encryptionMethods: inout [String]
    ) {
        guard let method = attributes["METHOD"], method != "NONE" else {
            return
        }

        encryptionMethods.append(method)
    }

    private func parseAttributes(afterTagPrefix prefix: String, in line: String) -> [String: String] {
        let attributeText = line.dropFirst(prefix.count)
        let pairs = splitAttributePairs(attributeText)

        return pairs.reduce(into: [:]) { attributes, pair in
            guard let equalsIndex = pair.firstIndex(of: "=") else {
                return
            }

            let key = pair[..<equalsIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = pair[pair.index(after: equalsIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            attributes[key] = rawValue.removingSurroundingQuotes()
        }
    }

    private func splitAttributePairs(_ attributeText: Substring) -> [String] {
        var pairs: [String] = []
        var currentPair = ""
        var isInsideQuotedValue = false

        for character in attributeText {
            if character == "\"" {
                isInsideQuotedValue.toggle()
                currentPair.append(character)
                continue
            }

            if character == "," && !isInsideQuotedValue {
                pairs.append(currentPair)
                currentPair.removeAll(keepingCapacity: true)
                continue
            }

            currentPair.append(character)
        }

        if !currentPair.isEmpty {
            pairs.append(currentPair)
        }

        return pairs
    }
}

/// Parsed HLS facts that can become metadata evidence for Caption Theater decisions.
///
/// This model deliberately avoids storing raw segments, keys, cookies, tokens, or fetched media.
nonisolated struct HLSManifestInspection: Equatable, Sendable {
    let isExtendedM3U: Bool
    let variants: [HLSVariantStream]
    let mediaRenditions: [HLSMediaRendition]
    let hasDiscontinuity: Bool
    let dateRanges: [HLSTagAttributes]
    let encryptionMethods: [String]

    /// Subtitle transports declared by `EXT-X-MEDIA` and variant stream attributes.
    var declaredSubtitleTransports: Set<HLSSubtitleTransport> {
        var transports = Set<HLSSubtitleTransport>()

        if mediaRenditions.contains(where: { $0.type == .subtitles && $0.uri != nil }) {
            transports.insert(.sidecarTextSubtitles)
        }

        let hasClosedCaptionMedia = mediaRenditions.contains { $0.type == .closedCaptions }
        let hasClosedCaptionVariantGroup = variants.contains {
            guard let groupID = $0.closedCaptionGroupID else {
                return false
            }

            return groupID != "NONE"
        }

        if hasClosedCaptionMedia || hasClosedCaptionVariantGroup {
            transports.insert(.embeddedClosedCaptions)
        }

        return transports
    }

    /// Indicates whether the manifest contains any non-`NONE` encryption marker.
    var hasEncryptionSignal: Bool {
        !encryptionMethods.isEmpty
    }

    /// Indicates whether the manifest carries date-range metadata often used for timed events.
    var hasDateRangeMetadata: Bool {
        !dateRanges.isEmpty
    }
}

/// A parsed `EXT-X-STREAM-INF` entry.
nonisolated struct HLSVariantStream: Equatable, Sendable {
    let uri: String
    let bandwidth: Int?
    let averageBandwidth: Int?
    let resolution: HLSResolution?
    let frameRate: Double?
    let codecs: [String]
    let audioGroupID: String?
    let subtitleGroupID: String?
    let closedCaptionGroupID: String?

    /// Creates a variant stream from parsed HLS attributes and its following URI line.
    init(attributes: [String: String], uri: String) {
        self.uri = uri
        self.bandwidth = attributes["BANDWIDTH"].flatMap(Int.init)
        self.averageBandwidth = attributes["AVERAGE-BANDWIDTH"].flatMap(Int.init)
        self.resolution = attributes["RESOLUTION"].flatMap(HLSResolution.init(rawValue:))
        self.frameRate = attributes["FRAME-RATE"].flatMap(Double.init)
        self.codecs = attributes["CODECS"]?.components(separatedBy: ",") ?? []
        self.audioGroupID = attributes["AUDIO"]
        self.subtitleGroupID = attributes["SUBTITLES"]
        self.closedCaptionGroupID = attributes["CLOSED-CAPTIONS"]
    }
}

/// Pixel dimensions declared by a variant stream's `RESOLUTION` attribute.
nonisolated struct HLSResolution: Equatable, Sendable {
    let width: Int
    let height: Int

    /// Creates an explicit HLS resolution value for tests and parsed manifests.
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// Parses HLS resolution values such as `1920x1080`.
    init?(rawValue: String) {
        let components = rawValue.lowercased().split(separator: "x")
        guard
            components.count == 2,
            let width = Int(components[0]),
            let height = Int(components[1])
        else {
            return nil
        }

        self.width = width
        self.height = height
    }
}

/// A parsed `EXT-X-MEDIA` rendition entry.
nonisolated struct HLSMediaRendition: Equatable, Sendable {
    let type: HLSMediaRenditionType
    let groupID: String?
    let name: String?
    let language: String?
    let uri: String?
    let isDefault: Bool
    let isForced: Bool
    let characteristics: [String]

    /// Creates a media rendition from parsed HLS attributes.
    init(attributes: [String: String]) {
        self.type = HLSMediaRenditionType(tagValue: attributes["TYPE"])
        self.groupID = attributes["GROUP-ID"]
        self.name = attributes["NAME"]
        self.language = attributes["LANGUAGE"]
        self.uri = attributes["URI"]
        self.isDefault = attributes["DEFAULT"] == "YES"
        self.isForced = attributes["FORCED"] == "YES"
        self.characteristics = attributes["CHARACTERISTICS"]?.components(separatedBy: ",") ?? []
    }
}

/// Supported `EXT-X-MEDIA` rendition kinds for the first manifest inspector.
nonisolated enum HLSMediaRenditionType: Equatable, Sendable {
    case audio
    case video
    case subtitles
    case closedCaptions
    case unknown

    /// Maps raw HLS `TYPE` attribute values into stable cases.
    init(tagValue: String?) {
        switch tagValue {
        case "AUDIO":
            self = .audio
        case "VIDEO":
            self = .video
        case "SUBTITLES":
            self = .subtitles
        case "CLOSED-CAPTIONS":
            self = .closedCaptions
        default:
            self = .unknown
        }
    }
}

/// Subtitle and caption transports declared by an HLS manifest.
nonisolated enum HLSSubtitleTransport: Hashable, Sendable {
    case sidecarTextSubtitles
    case embeddedClosedCaptions
}

/// Parsed attributes for HLS tags where the exact schema is intentionally deferred.
typealias HLSTagAttributes = [String: String]

nonisolated private extension String {
    func removingSurroundingQuotes() -> String {
        guard first == "\"", last == "\"", count >= 2 else {
            return self
        }

        return String(dropFirst().dropLast())
    }
}
