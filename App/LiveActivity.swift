import Foundation
import ActivityKit

/// Kilit ekranı ve Dynamic Island paneli
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    /// Ayarlar ekranında göstermek için son hata
    private(set) var lastError: String?

    var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    private var running: [Activity<MolaActivityAttributes>] {
        Activity<MolaActivityAttributes>.activities.filter { $0.activityState == .active }
    }

    var isRunning: Bool { !running.isEmpty }

    func start(attributes: MolaActivityAttributes, state: MolaActivityAttributes.ContentState) {
        for a in Activity<MolaActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
        guard enabled else {
            lastError = "Canlı Etkinlikler kapalı. iPhone Ayarlar → Mola → Canlı Etkinlikler'i aç."
            return
        }
        do {
            _ = try Activity.request(attributes: attributes,
                                     content: ActivityContent(state: state, staleDate: state.restEnd),
                                     pushType: nil)
            lastError = nil
        } catch {
            lastError = "Panel açılamadı: \(error.localizedDescription)"
        }
    }

    /// alert verilirse ekran uyanır, zil çalar ve Dynamic Island açılır
    func update(_ state: MolaActivityAttributes.ContentState, alert: (title: String, body: String)? = nil) {
        let content = ActivityContent(state: state, staleDate: state.restEnd)
        let config: AlertConfiguration? = alert.map {
            AlertConfiguration(title: LocalizedStringResource(stringLiteral: $0.title),
                               body: LocalizedStringResource(stringLiteral: $0.body),
                               sound: .named("mola-chime.wav"))
        }
        for a in running {
            Task { await a.update(content, alertConfiguration: config) }
        }
    }

    func endAll() {
        for a in Activity<MolaActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
