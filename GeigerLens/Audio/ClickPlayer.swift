import Foundation
import AVFoundation
import UIKit

/// ガイガー音（クリック）を合成して鳴らす。音源ファイル不要。
/// イベント（放射線由来の輝点）検出ごとに1クリック。
final class ClickPlayer {

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?
    private var ready = false

    private let haptic = UIImpactFeedbackGenerator(style: .rigid)

    var soundEnabled = true
    var hapticEnabled = true

    init() {
        setup()
    }

    private func setup() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        // 5msの鋭いクリック（減衰する高周波）
        let frames = AVAudioFrameCount(44_100 * 0.005)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buf.frameLength = frames
        if let ch = buf.floatChannelData?[0] {
            for i in 0..<Int(frames) {
                let t = Double(i) / 44_100.0
                let decay = exp(-t * 1_100.0)
                let tone = sin(2 * .pi * 2_200 * t) >= 0 ? 1.0 : -1.0
                ch[i] = Float(tone * decay * 0.4)
            }
        }
        buffer = buf

        do {
            try engine.start()
            ready = true
        } catch {
            ready = false
        }
        haptic.prepare()
    }

    func click() {
        if hapticEnabled { haptic.impactOccurred(intensity: 0.7) }
        guard soundEnabled, ready, let buffer else { return }
        if !player.isPlaying { player.play() }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }
}
