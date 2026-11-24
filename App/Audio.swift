import Foundation
import AVFoundation
import AudioToolbox
import UIKit
import UserNotifications

// MARK: - Ses üretimi

enum Tone {
    /// Basit bir ton dizisi üretir: (frekans, süre, sönme hızı, ses yüksekliği)
    static func wav(_ notes: [(Double, Double, Double, Double)], rate: Double = 22050) -> Data {
        var samples: [Int16] = []
        for (freq, dur, decay, gain) in notes {
            let n = Int(dur * rate)
            for i in 0..<n {
                let t = Double(i) / rate
                var v = 0.0
                if freq > 0 {
                    let env = min(1, t / 0.006) * exp(-t * decay)
                    v = env * (sin(2 * .pi * freq * t) * 0.8 + sin(2 * .pi * freq * 2 * t) * 0.2)
                }
                let clamped = max(-1, min(1, v * gain))
                samples.append(Int16(clamped * 32767))
            }
        }
        var data = Data()
        func append<T>(_ value: T) {
            var v = value
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        let byteCount = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + byteCount).littleEndian)
        data.append(contentsOf: Array("WAVE".utf8)); data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16).littleEndian); append(UInt16(1).littleEndian); append(UInt16(1).littleEndian)
        append(UInt32(rate).littleEndian); append(UInt32(rate * 2).littleEndian)
        append(UInt16(2).littleEndian); append(UInt16(16).littleEndian)
        data.append(contentsOf: Array("data".utf8)); append(byteCount.littleEndian)
        for s in samples { append(s.littleEndian) }
        return data
    }

    static let tick: Data = wav([(1480, 0.09, 34, 0.55)])
    /// Yedek zil (paketteki dosya bulunamazsa)
    static let chimeFallback: Data = wav([(880, 0.18, 6, 0.9), (1175, 0.5, 5, 0.9)])
    /// Uygulamayı arka planda canlı tutan sessizlik
    static let silence: Data = wav([(0, 1.0, 0, 0)])
}

// MARK: - Ses oturumu

/// Bütün sesler başka uygulamaların sesiyle karışarak çalar: YouTube Music durmaz.
final class AudioEngine: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioEngine()

    private var keepAlive: AVAudioPlayer?
    private var oneShots: [AVAudioPlayer] = []
    private var interruptionObserver: NSObjectProtocol?

    var isKeepingAlive: Bool { keepAlive != nil }

    @discardableResult
    private func activate() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }

    private func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Antrenman boyunca sessiz bir ses çalarak uygulamanın arka planda durdurulmasını engeller.
    /// Böylece kilitliyken de sayaç, titreşim ve kilit ekranı güncellenir.
    func startKeepAlive() {
        if let p = keepAlive {
            if !p.isPlaying { activate(); p.play() }
            return
        }
        guard activate(), let p = try? AVAudioPlayer(data: Tone.silence) else { return }
        p.numberOfLoops = -1
        p.volume = 1
        p.prepareToPlay()
        p.play()
        keepAlive = p

        if interruptionObserver == nil {
            interruptionObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
            ) { [weak self] note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw),
                      type == .ended else { return }
                // Telefon görüşmesi vb. bittiğinde sessizliği yeniden başlat
                self?.resumeKeepAlive()
            }
        }
    }

    private func resumeKeepAlive() {
        guard let p = keepAlive else { return }
        activate()
        p.play()
    }

    func stopKeepAlive() {
        keepAlive?.stop()
        keepAlive = nil
        if oneShots.isEmpty { deactivate() }
    }

    func playChime() {
        if let url = Bundle.main.url(forResource: "mola-chime", withExtension: "wav"),
           let p = try? AVAudioPlayer(contentsOf: url) {
            play(p)
        } else if let p = try? AVAudioPlayer(data: Tone.chimeFallback) {
            play(p)
        }
    }

    func playTick() {
        guard let p = try? AVAudioPlayer(data: Tone.tick) else { return }
        play(p)
    }

    private func play(_ p: AVAudioPlayer) {
        activate()
        p.delegate = self
        p.volume = 1
        p.prepareToPlay()
        p.play()
        oneShots.append(p)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.oneShots.removeAll { $0 === player }
            guard self.oneShots.isEmpty, self.keepAlive == nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard self.oneShots.isEmpty, self.keepAlive == nil else { return }
                self.deactivate()
            }
        }
    }
}

// MARK: - Titreşim ve ses tetikleyicileri

enum Feedback {
    static var settings = AppSettings()

    static func tap() {
        guard settings.haptics else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func setDone() {
        guard settings.haptics else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Son 3 saniye
    static func countdown(foreground: Bool) {
        if settings.haptics {
            if foreground {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
        }
        if settings.sound && settings.countdownTicks { AudioEngine.shared.playTick() }
    }

    /// Dinlenme bitti. Arka planda zili kilit ekranı paneli çalar; panel yoksa biz çalarız.
    static func restDone(foreground: Bool, playSound: Bool) {
        if settings.haptics {
            if foreground { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            vibrate(times: 2)
        }
        if settings.sound && playSound { AudioEngine.shared.playChime() }
    }

    static func vibrate(times: Int) {
        for i in 0..<times {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 * Double(i)) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
}

// MARK: - Bildirim (uygulama tamamen kapanırsa yedek uyarı)

enum Notifier {
    static let restID = "mola.rest"

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func status(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let st = s.authorizationStatus
            DispatchQueue.main.async { completion(st) }
        }
    }

    static func scheduleRest(at date: Date, title: String, body: String) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: [restID])
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // Ses her zaman eklenir: sessiz bildirim titreşmez
        content.sound = UNNotificationSound(named: UNNotificationSoundName("mola-chime.wav"))
        content.interruptionLevel = .active
        let seconds = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        c.add(UNNotificationRequest(identifier: restID, content: content, trigger: trigger), withCompletionHandler: nil)
    }

    static func cancelRest() {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: [restID])
        c.removeDeliveredNotifications(withIdentifiers: [restID])
    }
}
