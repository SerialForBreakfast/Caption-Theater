//
//  MacPlaybackStateStore.swift
//  CaptionTheater
//
//  Small main-actor state bridge for macOS menu commands.
//

#if os(macOS)
import CoreGraphics

@MainActor
final class MacPlaybackStateStore {

    static let shared = MacPlaybackStateStore()

    weak var activePlaybackModel: MacPlaybackShellViewModel?
    var sourceAspectForWindowPreset: CGFloat?

    private init() {}
}
#endif
