import SwiftUI
import UserNotifications

@main
struct MolaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var engine = WorkoutEngine.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(engine)
                .preferredColorScheme(colorScheme)
                .tint(Ink.primary)
                .onOpenURL { url in engine.handle(url) }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                engine.didBecomeActive()
            case .background:
                engine.didEnterBackground()
            default:
                break
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch engine.data.settings.appearance {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        _ = WorkoutEngine.shared
        return true
    }

    // Uygulama açıkken dinlenme bildirimini gösterme: zili ve titreşimi uygulama kendisi veriyor.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.identifier == Notifier.restID {
            completionHandler([])
        } else {
            completionHandler([.banner, .sound])
        }
    }
}

struct RootView: View {
    @EnvironmentObject var engine: WorkoutEngine

    var body: some View {
        TabView {
            Tab("Bugün", systemImage: "figure.strengthtraining.traditional") {
                HomeView()
            }
            Tab("Geçmiş", systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }
            Tab("Ayarlar", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .fullScreenCover(isPresented: $engine.showWorkout) {
            WorkoutView()
                .environmentObject(engine)
        }
        .sheet(item: $engine.lastFinished) { w in
            SummaryView(workout: w)
                .environmentObject(engine)
        }
        .onAppear {
            // Uygulama devam eden bir antrenmanla açıldıysa doğrudan oraya git
            if engine.data.active != nil { engine.showWorkout = true }
        }
    }
}
