import AVFoundation
import CoreVideo
import Combine
import UIKit

/// カメラのCMOSセンサーを簡易的な放射線検出器として使う。
///
/// 原理: レンズを完全に遮光すると、センサーには本来ほぼ真っ黒な映像だけが届く。
/// そこへガンマ線が当たると電子が弾き飛ばされ、一瞬だけ明るい輝点（ホットピクセル）が現れる。
/// この輝点を1フレームごとに数えて「イベント」としてカウントし、cpm（毎分カウント）へ換算する。
///
/// ★これは本物のガイガー＝ミュラー管ではない。感度は低く、拾えるのはガンマ線の一部だけ。
///  参考・実験・エンタメ用途であり、正確な線量計ではない。
final class RadiationDetector: NSObject, ObservableObject {

    // MARK: - 公開状態（UIが監視）
    @Published private(set) var isRunning = false
    @Published private(set) var cpm: Double = 0            // 直近60秒のイベント数
    @Published private(set) var microSievertPerHour: Double = 0
    @Published private(set) var totalCounts: Int = 0        // セッション積算カウント
    @Published private(set) var lastEventAt: Date? = nil
    @Published private(set) var noiseFloor: Double = 0      // キャリブレーションで得た背景（events/秒）
    @Published private(set) var isCalibrating = false
    @Published private(set) var permissionDenied = false
    @Published private(set) var frameBrightness: Double = 0 // 遮光チェック用（明るいと未遮光の警告）

    /// cpm → μSv/h の換算係数（参考値）。実測できないためユーザーが調整可能。
    /// 一般的なガイガー管の目安（SBM-20 ≒ 0.0057）に近い既定値。カメラ方式では厳密でない。
    var conversionFactor: Double = 0.0057

    /// 輝点とみなす明るさのしきい値（0–255の輝度）。キャリブレーションで自動調整。
    private(set) var lumaThreshold: UInt8 = 245

    // MARK: - 内部
    private let session = AVCaptureSession()
    private let videoQueue = DispatchQueue(label: "geigerlens.video", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private var device: AVCaptureDevice?

    /// 直近のイベント発生時刻（cpm算出用のスライディングウィンドウ）
    private var eventTimestamps: [CFTimeInterval] = []

    /// キャリブレーション用の一時集計
    private var calibrating = false
    private var calibrationStart: CFTimeInterval = 0
    private var calibrationEvents = 0
    private let calibrationSeconds: CFTimeInterval = 6

    /// イベント発生時に鳴らすクリック音のコールバック
    var onEvent: (() -> Void)?

    override init() {
        super.init()
    }

    // MARK: - 起動 / 停止
    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            if !granted {
                DispatchQueue.main.async { self.permissionDenied = true }
                return
            }
            self.videoQueue.async { self.configureAndRun() }
        }
    }

    func stop() {
        videoQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func configureAndRun() {
        if session.isRunning { return }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480   // 解析を軽くするため低解像度

        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: cam),
              session.canAddInput(input) else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.permissionDenied = true }
            return
        }
        session.addInput(input)
        device = cam

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) { session.addOutput(output) }

        session.commitConfiguration()

        configureForDarkCapture(cam)
        session.startRunning()
        DispatchQueue.main.async { self.isRunning = true }
    }

    /// 露出・フォーカスを固定し、暗所でホットピクセルを拾いやすい設定にする。
    private func configureForDarkCapture(_ cam: AVCaptureDevice) {
        do {
            try cam.lockForConfiguration()
            if cam.isFocusModeSupported(.locked) { cam.focusMode = .locked }
            // 露出を固定（自動増感でノイズが暴れるのを防ぐ）。中程度のISO・短めのシャッター。
            let minDur = cam.activeFormat.minExposureDuration
            let dur = CMTimeMakeWithSeconds(1.0/30.0, preferredTimescale: 1_000_000)
            let clampedDur = CMTimeCompare(dur, minDur) < 0 ? minDur : dur
            let iso = min(max(cam.activeFormat.minISO, 400), cam.activeFormat.maxISO)
            if cam.isExposureModeSupported(.custom) {
                cam.setExposureModeCustom(duration: clampedDur, iso: iso, completionHandler: nil)
            }
            if cam.isWhiteBalanceModeSupported(.locked) { cam.whiteBalanceMode = .locked }
            cam.unlockForConfiguration()
        } catch {
            // 設定できない機種でも既定のまま動作継続
        }
    }

    // MARK: - キャリブレーション（背景ノイズ測定）
    /// レンズを遮光した状態で数秒間サンプリングし、背景イベント率を記録する。
    func calibrate() {
        videoQueue.async {
            self.calibrationEvents = 0
            self.calibrationStart = CACurrentMediaTime()
            self.calibrating = true
            DispatchQueue.main.async { self.isCalibrating = true }
        }
    }

    func resetSession() {
        videoQueue.async {
            self.eventTimestamps.removeAll()
            DispatchQueue.main.async {
                self.totalCounts = 0
                self.cpm = 0
                self.microSievertPerHour = 0
                self.lastEventAt = nil
            }
        }
    }

    // MARK: - フレーム解析
    private func analyze(_ pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return }
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        let thr = lumaThreshold
        var events = 0
        var brightSum: UInt64 = 0
        let sampleStep = 4   // 明るさ推定は間引きでOK

        // 端は無視（センサー端のノイズ回避）
        let y0 = 2, y1 = height - 2, x0 = 2, x1 = width - 2
        var y = y0
        while y < y1 {
            let row = y * stride
            let rowUp = (y - 1) * stride
            var x = x0
            while x < x1 {
                let v = ptr[row + x]
                if (y % sampleStep == 0) && (x % sampleStep == 0) { brightSum &+= UInt64(v) }
                if v >= thr {
                    // 連結成分の重複カウント回避: 左と上が閾値未満のときだけ「新しい輝点」と数える
                    let left = ptr[row + x - 1]
                    let up = ptr[rowUp + x]
                    if left < thr && up < thr {
                        events += 1
                    }
                }
                x += 1
            }
            y += 1
        }

        let sampleCount = Double(((y1 - y0) / sampleStep + 1) * ((x1 - x0) / sampleStep + 1))
        let avgBright = sampleCount > 0 ? Double(brightSum) / sampleCount : 0

        handle(events: events, avgBrightness: avgBright)
    }

    private func handle(events: Int, avgBrightness: Double) {
        let now = CACurrentMediaTime()

        // キャリブレーション中は背景として集計
        if calibrating {
            calibrationEvents += events
            if now - calibrationStart >= calibrationSeconds {
                let rate = Double(calibrationEvents) / calibrationSeconds   // events/秒
                calibrating = false
                DispatchQueue.main.async {
                    self.noiseFloor = rate
                    self.isCalibrating = false
                }
                // 背景が多い＝しきい値が低すぎる。少し上げてノイズを抑える。
                if rate > 2.0 && lumaThreshold < 254 {
                    lumaThreshold = min(254, lumaThreshold + 3)
                } else if rate < 0.05 && lumaThreshold > 235 {
                    lumaThreshold = max(235, lumaThreshold - 2)
                }
            }
            DispatchQueue.main.async { self.frameBrightness = avgBrightness }
            return
        }

        // 背景率ぶんを確率的に差し引く（背景が高い機種で誤カウントを抑制）
        var realEvents = events
        if noiseFloor > 0 {
            // 1フレーム(≒1/30秒)あたりの期待背景数
            let perFrame = noiseFloor / 30.0
            realEvents = max(0, events - Int(perFrame.rounded()))
        }

        if realEvents > 0 {
            for _ in 0..<realEvents { eventTimestamps.append(now) }
            onEvent?()
        }

        // 60秒より古いイベントを捨てる
        let cutoff = now - 60
        if let idx = eventTimestamps.firstIndex(where: { $0 >= cutoff }) {
            if idx > 0 { eventTimestamps.removeFirst(idx) }
        } else {
            eventTimestamps.removeAll()
        }

        let currentCpm = Double(eventTimestamps.count)
        let usv = currentCpm * conversionFactor

        DispatchQueue.main.async {
            self.frameBrightness = avgBrightness
            if realEvents > 0 {
                self.totalCounts += realEvents
                self.lastEventAt = Date()
            }
            self.cpm = currentCpm
            self.microSievertPerHour = usv
        }
    }
}

extension RadiationDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        analyze(pb)
    }
}
