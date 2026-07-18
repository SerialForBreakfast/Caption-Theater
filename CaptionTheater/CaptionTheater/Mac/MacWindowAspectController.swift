//
//  MacWindowAspectController.swift
//  CaptionTheater
//
//  AppKit window resizing for native macOS demo presets.
//

#if os(macOS)
import AppKit
import CoreGraphics

@MainActor
enum MacWindowAspectController {

    static func apply(_ preset: MacWindowAspectPreset, sourceAspect: CGFloat?, window: NSWindow? = nil) {
        let window = window ?? NSApp.keyWindow
        guard let window else {
            return
        }

        if preset == .freeform {
            window.aspectRatio = .zero
            return
        }

        guard let ratio = preset.ratio(sourceAspect: sourceAspect), ratio > 0 else {
            return
        }

        let currentContentSize = window.contentLayoutRect.size
        let targetContentSize = preset.contentSize(fitting: currentContentSize, sourceAspect: sourceAspect)
        let oldFrame = window.frame
        let oldContentRect = window.contentRect(forFrameRect: oldFrame)
        let newContentOrigin = CGPoint(
            x: oldContentRect.midX - targetContentSize.width / 2,
            y: oldContentRect.midY - targetContentSize.height / 2
        )
        let newContentRect = CGRect(origin: newContentOrigin, size: targetContentSize)
        let newFrame = window.frameRect(forContentRect: newContentRect)

        window.aspectRatio = NSSize(width: ratio, height: 1)
        window.setFrame(newFrame, display: true, animate: true)
    }
}
#endif
