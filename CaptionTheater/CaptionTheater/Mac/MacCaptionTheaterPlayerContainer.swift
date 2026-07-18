//
//  MacCaptionTheaterPlayerContainer.swift
//  CaptionTheater
//
//  Native AppKit AVPlayerLayer host for the macOS target.
//

#if os(macOS)
import AVFoundation
import SwiftUI
import AppKit

final class MacCaptionTheaterPlayerLayerHostingView: NSView {

    override var wantsUpdateLayer: Bool { true }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        nil
    }

    func attach(player: AVPlayer?) {
        playerLayer.player = player
    }
}

final class MacCaptionTheaterPlayerContainerView: NSView {

    private let hosting = MacCaptionTheaterPlayerLayerHostingView()

    var player: AVPlayer? {
        didSet { hosting.attach(player: player) }
    }

    var videoDisplayRect: CGRect?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        addSubview(hosting)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        hosting.frame = videoDisplayRect ?? bounds
    }
}

struct MacCaptionTheaterPlayerContainer: NSViewRepresentable {

    let player: AVPlayer
    let videoDisplayRect: CGRect?

    func makeNSView(context: Context) -> MacCaptionTheaterPlayerContainerView {
        let view = MacCaptionTheaterPlayerContainerView()
        view.player = player
        view.videoDisplayRect = videoDisplayRect
        return view
    }

    func updateNSView(_ nsView: MacCaptionTheaterPlayerContainerView, context: Context) {
        nsView.player = player
        nsView.videoDisplayRect = videoDisplayRect
        nsView.needsLayout = true
    }
}
#endif

