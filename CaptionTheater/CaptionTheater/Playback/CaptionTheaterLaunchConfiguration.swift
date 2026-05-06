//
//  CaptionTheaterLaunchConfiguration.swift
//  CaptionTheater
//
//  Launch-argument overrides for demo and engineering feature toggles.
//

import Foundation

/// Applies launch-argument overrides to the same persisted keys used by engineering configurations.
///
/// Supported forms:
/// - `-CaptionTheater.playbackDemoSource bundledOfflineHLSMock`
/// - `--caption-theater-playback-demo-source=bundledOfflineHLSMock`
/// - `--caption-theater-offline-hls`
enum CaptionTheaterLaunchConfiguration {

    static let playbackDemoSourceStorageKey = "CaptionTheater.playbackDemoSource"
    static let playbackDebugHUDStorageKey = "CaptionTheater.playbackDebugHUD"

    /// Applies recognized launch arguments to `defaults`.
    static func apply(arguments: [String] = ProcessInfo.processInfo.arguments, defaults: UserDefaults = .standard) {
        let overrides = resolvedOverrides(arguments: arguments)

        if let playbackDemoSource = overrides.playbackDemoSource {
            defaults.set(playbackDemoSource.rawValue, forKey: playbackDemoSourceStorageKey)
        }
        if let playbackDebugHUD = overrides.playbackDebugHUD {
            defaults.set(playbackDebugHUD, forKey: playbackDebugHUDStorageKey)
        }
    }

    /// Resolves typed overrides without mutating defaults; useful for tests.
    static func resolvedOverrides(arguments: [String]) -> CaptionTheaterLaunchOverrides {
        var overrides = CaptionTheaterLaunchOverrides()

        for index in arguments.indices {
            let argument = arguments[index]

            if argument == "--caption-theater-offline-hls" {
                overrides.playbackDemoSource = .bundledOfflineHLSMock
            } else if argument.hasPrefix("--caption-theater-playback-demo-source=") {
                let rawValue = value(afterEqualsIn: argument)
                overrides.playbackDemoSource = CaptionTheaterPlaybackDemoSource(rawValue: rawValue)
            } else if argument.hasPrefix("--caption-theater-playback-debug-hud=") {
                overrides.playbackDebugHUD = boolValue(from: value(afterEqualsIn: argument))
            } else if argument == "-CaptionTheater.playbackDemoSource" {
                overrides.playbackDemoSource = nextDemoSource(in: arguments, after: index)
            } else if argument == "-CaptionTheater.playbackDebugHUD" {
                overrides.playbackDebugHUD = nextBool(in: arguments, after: index)
            }
        }

        return overrides
    }

    private static func value(afterEqualsIn argument: String) -> String {
        guard let equalsIndex = argument.firstIndex(of: "=") else {
            return ""
        }
        return String(argument[argument.index(after: equalsIndex)...])
    }

    private static func nextDemoSource(in arguments: [String], after index: Int) -> CaptionTheaterPlaybackDemoSource? {
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }
        return CaptionTheaterPlaybackDemoSource(rawValue: arguments[valueIndex])
    }

    private static func nextBool(in arguments: [String], after index: Int) -> Bool? {
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }
        return boolValue(from: arguments[valueIndex])
    }

    private static func boolValue(from rawValue: String) -> Bool? {
        switch rawValue.lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return nil
        }
    }
}

/// Typed launch overrides parsed from process arguments.
struct CaptionTheaterLaunchOverrides: Equatable, Sendable {
    var playbackDemoSource: CaptionTheaterPlaybackDemoSource?
    var playbackDebugHUD: Bool?
}
