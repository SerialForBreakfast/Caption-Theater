//
//  tvOSCaptionTheaterPlayerContainer.swift
//  CaptionTheater
//
//  AVPlayerLayer hosting for demo-stable subtitle extraction via AVPlayerItemLegibleOutput (embedded AVKit players
//  fought legible delivery on tvOS in Caption Theater testing).
//

import AVFoundation
import SwiftUI
import UIKit

/// Embedded view that pins ``AVPlayerLayer`` to an explicit sub-rect so SwiftUI can match ``CaptionTheaterLayoutEngine`` math.
///
/// **MVP policy:** ``AVLayerVideoGravity/resizeAspect`` only. Aspect-fill/zoom modes are out of scope.
final class CaptionTheaterPlayerLayerHostingView: UIView {

    override static var layerClass: AnyClass { AVPlayerLayer.self }

    /// Layer backing this view; gravity is locked to aspect-fit for the milestone.
    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// Attaches or clears the active ``AVPlayer``.
    func attach(player: AVPlayer?) {
        playerLayer.player = player
    }
}

/// Positions the player layer inside a container; when ``videoDisplayRect`` is nil the layer fills bounds.
final class CaptionTheaterPlayerContainerView: UIView {

    private let hosting = CaptionTheaterPlayerLayerHostingView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        hosting.playerLayer.videoGravity = .resizeAspect
        addSubview(hosting)
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// Current player piped to the layer.
    var player: AVPlayer? {
        didSet { hosting.attach(player: player) }
    }

    /// Target frame for video in this view's coordinate space; `nil` uses ``bounds``.
    var videoDisplayRect: CGRect?

    override func layoutSubviews() {
        super.layoutSubviews()
        hosting.frame = videoDisplayRect ?? bounds
    }
}

/// SwiftUI bridge for the MVP player container (tvOS target).
struct tvOSCaptionTheaterPlayerContainer: UIViewRepresentable {

    let player: AVPlayer
    /// When non-nil, pins the layer to aspect-fit math from ``CaptionTheaterLayoutEngine``.
    let videoDisplayRect: CGRect?

    func makeUIView(context: Context) -> CaptionTheaterPlayerContainerView {
        let view = CaptionTheaterPlayerContainerView()
        view.player = player
        view.videoDisplayRect = videoDisplayRect
        return view
    }

    func updateUIView(_ uiView: CaptionTheaterPlayerContainerView, context: Context) {
        uiView.player = player
        uiView.videoDisplayRect = videoDisplayRect
    }
}
