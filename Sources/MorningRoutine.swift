import AppKit
import AVFoundation
import ScreenSaver

@objc(SnoopyScreenSaverView)
final class SnoopyScreenSaverView: ScreenSaverView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var videoLayer: AVPlayerLayer?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        animationTimeInterval = 1.0
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        animationTimeInterval = 1.0
    }
    override func startAnimation() {
        super.startAnimation()
        if player == nil, let url = Bundle(for: Self.self).url(forResource: "Morning Routine", withExtension: "mp4") {
            let queue = AVQueuePlayer()
            queue.isMuted = true
            let item = AVPlayerItem(url: url)
            looper = AVPlayerLooper(player: queue, templateItem: item)
            let video = AVPlayerLayer(player: queue)
            video.videoGravity = .resizeAspectFill
            video.frame = bounds
            layer?.addSublayer(video)
            videoLayer = video
            player = queue
        }
        player?.play()
    }
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer?.frame = bounds
        CATransaction.commit()
    }
    override func stopAnimation() {
        player?.pause()
        looper?.disableLooping()
        player?.removeAllItems()
        videoLayer?.removeFromSuperlayer()
        videoLayer = nil
        looper = nil
        player = nil
        super.stopAnimation()
    }
    override func animateOneFrame() {}
}
