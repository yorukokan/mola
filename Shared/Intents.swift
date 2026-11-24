import AppIntents
import Foundation

// Kilit ekranı panelindeki ve widget'taki butonlar.
// LiveActivityIntent olduğu için sistem bunları uygulamanın kendi içinde çalıştırır;
// widget eklentisi sadece butonu çizer.

struct CompleteSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Seti bitir"
    static var description = IntentDescription("Sıradaki seti tamamlar ve dinlenmeyi başlatır.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        WorkoutEngine.shared.completeCurrentSet()
        #endif
        return .result()
    }
}

struct AdjustRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Dinlenmeyi değiştir"

    @Parameter(title: "Saniye")
    var seconds: Int

    init() {}

    init(seconds: Int) {
        self.seconds = seconds
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        WorkoutEngine.shared.adjustRest(seconds)
        #endif
        return .result()
    }
}

struct SkipRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Dinlenmeyi atla"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        WorkoutEngine.shared.skipRest()
        #endif
        return .result()
    }
}
