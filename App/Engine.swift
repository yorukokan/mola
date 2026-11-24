import SwiftUI
import ActivityKit
import WidgetKit
import UIKit

/// Uygulamanın tek beyni. Ekranlar, kilit ekranı butonları ve widget'lar hep bunu kullanır.
/// Bütün çağrılar ana iş parçacığından yapılır.
final class WorkoutEngine: ObservableObject {
    static let shared = WorkoutEngine()

    @Published var data: AppData {
        didSet {
            Feedback.settings = data.settings
            scheduleSave()
        }
    }
    @Published var showWorkout = false
    @Published var lastFinished: Workout?
    /// "Geri al" için en son tamamlanan set
    @Published private(set) var lastCompleted: SetRef?
    /// Ayarlar'daki 10 saniyelik deneme
    @Published private(set) var testRest: TestRest?
    /// Dinlenme az önce bitti (ekranda kısa bir parlama için)
    @Published private(set) var restEndedAt: Date?

    struct TestRest: Equatable {
        var start: Date
        var end: Date
    }

    struct RestInfo {
        var start: Date
        var end: Date
        var cardio: Bool
        var test: Bool
        var total: TimeInterval { max(1, end.timeIntervalSince(start)) }
    }

    private var ticker: Timer?
    private var lastCountdown = -1
    private var fallbackCancelled = false
    private var saveWork: DispatchWorkItem?

    private init() {
        var loaded = SharedStore.load()
        if !loaded.seeded {
            loaded.history = Program.seedHistory + loaded.history
            loaded.seeded = true
        }
        data = loaded
        Feedback.settings = loaded.settings
        SharedStore.save(loaded)
        resumeAfterLaunch()
    }

    // MARK: - Kayıt

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            SharedStore.save(self.data)
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        SharedStore.save(data)
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Okumalar

    var active: Workout? { data.active }
    var routines: [RoutineDef] { data.routines }
    var hasCustomRoutines: Bool { data.customRoutines != nil }
    var finishedHistory: [Workout] { Planner.finished(data.history) }
    var nextRoutine: RoutineDef { Planner.nextRoutine(history: data.history, routines: routines) }
    var isForeground: Bool { UIApplication.shared.applicationState == .active }

    func routine(_ id: String) -> RoutineDef? {
        routines.first { $0.id == id }
    }

    func exerciseDef(in w: Workout, at ei: Int) -> ExerciseDef? {
        Planner.def(w, ei, routines: routines)
    }

    var rest: RestInfo? {
        if let w = data.active, let s = w.restStart, let e = w.restEnd {
            return RestInfo(start: s, end: e, cardio: w.restIsCardio == true, test: false)
        }
        if let t = testRest {
            return RestInfo(start: t.start, end: t.end, cardio: false, test: true)
        }
        return nil
    }

    var cursor: SetRef? {
        guard let w = data.active else { return nil }
        return Planner.cursor(in: w)
    }

    func suggestion(for def: ExerciseDef) -> Suggestion {
        Planner.suggestion(for: def, history: data.history)
    }

    func lastTop(_ liftKey: String, before date: Date = .distantFuture) -> (set: SetEntry, date: Date)? {
        Planner.lastTop(liftKey, in: data.history, before: date)
    }

    // MARK: - Antrenmanı başlat

    func start(_ routine: RoutineDef) {
        if data.active != nil {
            showWorkout = true
            return
        }
        endTest()
        let w = Planner.makeWorkout(routine, history: data.history, cardioDefaults: data.settings.cardioDefaults)
        data.active = w
        lastCompleted = nil
        restEndedAt = nil
        saveNow()
        Notifier.requestAuthorization()
        if data.settings.backgroundTimer { AudioEngine.shared.startKeepAlive() }
        LiveActivityManager.shared.start(attributes: attributes(for: w), state: liveState())
        applyIdleTimer()
        showWorkout = true
        reloadWidgets()
    }

    private func attributes(for w: Workout) -> MolaActivityAttributes {
        MolaActivityAttributes(routineName: w.routineName, plateRaw: w.plate.rawValue, startedAt: w.startedAt)
    }

    func liveState() -> MolaActivityAttributes.ContentState {
        if let t = testRest {
            return MolaActivityAttributes.ContentState(
                phase: .resting, exercise: "Deneme dinlenmesi", setTitle: "Telefonu kilitle ve bekle",
                target: "10 sn", previous: nil, restStart: t.start, restEnd: t.end,
                exerciseIndex: 0, exerciseCount: 1, doneSets: 0, totalSets: 1)
        }
        guard let w = data.active else {
            return MolaActivityAttributes.ContentState(
                phase: .done, exercise: "Antrenman yok", setTitle: "", target: "", previous: nil,
                restStart: nil, restEnd: nil, exerciseIndex: 0, exerciseCount: 0, doneSets: 0, totalSets: 0)
        }
        return Planner.liveState(w, history: data.history)
    }

    func pushLive() {
        LiveActivityManager.shared.update(liveState())
    }

    // MARK: - Set düzenleme

    func setValue(_ ref: SetRef, kg: Double? = nil, reps: Int? = nil) {
        guard var w = data.active,
              w.exercises.indices.contains(ref.ex),
              w.exercises[ref.ex].sets.indices.contains(ref.set) else { return }
        if let kg { w.exercises[ref.ex].sets[ref.set].kg = max(0, kg) }
        if let reps { w.exercises[ref.ex].sets[ref.set].reps = max(0, min(50, reps)) }

        // Top set kilosu değişince, henüz yapılmamış tüm back-off setlerini %90'a çek
        if kg != nil,
           w.exercises[ref.ex].sets[ref.set].kind == .top,
           let def = exerciseDef(in: w, at: ref.ex) {
            let top = w.exercises[ref.ex].sets[ref.set].kg
            let backoffKg = roundTo(top * 0.9, step: def.step)
            for bi in w.exercises[ref.ex].sets.indices
                where w.exercises[ref.ex].sets[bi].kind == .backoff && w.exercises[ref.ex].sets[bi].isOpen {
                w.exercises[ref.ex].sets[bi].kg = backoffKg
            }
        }
        data.active = w
        pushLive()
    }

    func step(for ref: SetRef) -> Double {
        guard let w = data.active else { return 2.5 }
        return exerciseDef(in: w, at: ref.ex)?.step ?? 2.5
    }

    /// Aktif antrenmandaki tamamlanmış veya açık herhangi bir seti düzenler
    func updateSet(_ ref: SetRef, kg: Double, reps: Int) {
        setValue(ref, kg: kg, reps: reps)
        saveNow()
        reloadWidgets()
    }

    /// Tamamlanmış ya da atlanmış bir seti tekrar açık hale getirir
    func reopenSet(_ ref: SetRef) {
        guard var w = data.active,
              w.exercises.indices.contains(ref.ex),
              w.exercises[ref.ex].sets.indices.contains(ref.set) else { return }
        w.exercises[ref.ex].sets[ref.set].done = false
        w.exercises[ref.ex].sets[ref.set].doneAt = nil
        w.exercises[ref.ex].sets[ref.set].skipped = nil
        w.focus = ref.ex
        data.active = w
        saveNow()
        pushLive()
        reloadWidgets()
    }

    /// Aktif harekete ekstra bir çalışma (back-off) seti ekler
    func addExtraSet(toExercise ei: Int) {
        guard var w = data.active, w.exercises.indices.contains(ei) else { return }
        let ex = w.exercises[ei]
        let def = exerciseDef(in: w, at: ei)
        let refSet = ex.sets.last(where: { $0.kind != .warmup }) ?? ex.sets.last
        let kg = refSet?.kg ?? 0
        let reps = refSet?.reps ?? (def?.kind.backoffRange.lowerBound ?? 10)
        w.exercises[ei].sets.append(SetEntry(kind: .backoff, kg: kg, reps: reps))
        w.focus = ei
        data.active = w
        Feedback.tap()
        saveNow()
        pushLive()
        reloadWidgets()
    }

    /// Ekstra eklenen bir seti siler (en az 1 çalışma seti kalmasını garanti eder)
    func removeSet(_ ref: SetRef) {
        guard var w = data.active,
              w.exercises.indices.contains(ref.ex),
              w.exercises[ref.ex].sets.indices.contains(ref.set) else { return }
        let target = w.exercises[ref.ex].sets[ref.set]
        if target.kind != .warmup && w.exercises[ref.ex].workSets <= 1 { return }
        w.exercises[ref.ex].sets.remove(at: ref.set)
        data.active = w
        saveNow()
        pushLive()
        reloadWidgets()
    }

    /// Geçmiş bir antrenmandaki setin kilo/tekrar değerini düzeltir
    func updateHistorySet(workoutId: UUID, exerciseId: String, setId: UUID, kg: Double, reps: Int) {
        guard let wi = data.history.firstIndex(where: { $0.id == workoutId }),
              let ei = data.history[wi].exercises.firstIndex(where: { $0.id == exerciseId }),
              let si = data.history[wi].exercises[ei].sets.firstIndex(where: { $0.id == setId }) else { return }
        data.history[wi].exercises[ei].sets[si].kg = max(0, kg)
        data.history[wi].exercises[ei].sets[si].reps = max(0, min(50, reps))
        saveNow()
        reloadWidgets()
    }

    // MARK: - Program düzenleme

    func saveRoutines(_ updated: [RoutineDef]) {
        data.customRoutines = updated
        saveNow()
        reloadWidgets()
    }

    func resetRoutinesToDefault() {
        data.customRoutines = nil
        saveNow()
        reloadWidgets()
    }

    // MARK: - Ana akış: seti bitir → dinlen → sıradaki set

    func completeCurrentSet() {
        guard var w = data.active, let c = Planner.cursor(in: w) else { return }
        let kind = w.exercises[c.ex].sets[c.set].kind
        w.exercises[c.ex].sets[c.set].done = true
        w.exercises[c.ex].sets[c.set].doneAt = Date()
        w.focus = c.ex
        w.restStart = nil
        w.restEnd = nil
        w.restIsCardio = nil
        data.active = w
        lastCompleted = c
        restEndedAt = nil
        Feedback.setDone()

        if Planner.cursor(in: w) != nil {
            let seconds = kind == .warmup ? 60 : (exerciseDef(in: w, at: c.ex)?.rest ?? 90)
            startRest(seconds: seconds, cardio: false)
        } else {
            // Bütün setler bitti: sırada kardiyo
            stopTicker()
            Notifier.cancelRest()
            saveNow()
            pushLive()
            reloadWidgets()
        }
    }

    func skipCurrentSet() {
        guard var w = data.active, let c = Planner.cursor(in: w) else { return }
        w.exercises[c.ex].sets[c.set].skipped = true
        w.focus = c.ex
        data.active = w
        saveNow()
        pushLive()
        reloadWidgets()
    }

    func undoLast() {
        guard var w = data.active, let c = lastCompleted,
              w.exercises.indices.contains(c.ex),
              w.exercises[c.ex].sets.indices.contains(c.set) else { return }
        w.exercises[c.ex].sets[c.set].done = false
        w.exercises[c.ex].sets[c.set].doneAt = nil
        w.exercises[c.ex].sets[c.set].skipped = nil
        w.focus = c.ex
        w.restStart = nil
        w.restEnd = nil
        w.restIsCardio = nil
        data.active = w
        lastCompleted = nil
        stopTicker()
        Notifier.cancelRest()
        saveNow()
        pushLive()
        reloadWidgets()
    }

    func focus(_ ei: Int) {
        guard var w = data.active, w.exercises.indices.contains(ei) else { return }
        w.focus = ei
        data.active = w
        saveNow()
        pushLive()
        reloadWidgets()
    }

    // MARK: - Dinlenme

    func startRest(seconds: Int, cardio: Bool) {
        guard var w = data.active else { return }
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(max(1, seconds)))
        w.restStart = now
        w.restEnd = end
        w.restIsCardio = cardio
        data.active = w
        restEndedAt = nil
        arm(end: end)
        saveNow()
        pushLive()
        reloadWidgets()
    }

    func adjustRest(_ delta: Int) {
        guard testRest == nil, var w = data.active, let e = w.restEnd else { return }
        let newEnd = e.addingTimeInterval(TimeInterval(delta))
        if newEnd.timeIntervalSinceNow < 1 {
            skipRest()
            return
        }
        w.restEnd = newEnd
        data.active = w
        arm(end: newEnd)
        saveNow()
        pushLive()
        reloadWidgets()
    }

    func skipRest() {
        if testRest != nil {
            endTest()
            return
        }
        guard var w = data.active, w.restEnd != nil else { return }
        if w.restIsCardio == true {
            let elapsed = Date().timeIntervalSince(w.restStart ?? Date())
            w.cardio.minutes = max(1, Int((elapsed / 60).rounded()))
            w.cardio.done = true
        }
        w.restStart = nil
        w.restEnd = nil
        w.restIsCardio = nil
        data.active = w
        stopTicker()
        Notifier.cancelRest()
        saveNow()
        pushLive()
        reloadWidgets()
    }

    private func arm(end: Date) {
        lastCountdown = -1
        fallbackCancelled = false
        let (title, body) = alertText()
        // Uygulama tamamen kapanırsa yine de uyarı gelsin diye yedek bildirim
        Notifier.scheduleRest(at: end, title: title, body: body)
        startTicker()
    }

    private func alertText() -> (String, String) {
        if testRest != nil { return ("Deneme bitti", "Ses, titreşim ve kilit ekranı çalışıyor.") }
        guard let w = data.active else { return ("Dinlenme bitti", "Sıradaki sete geç.") }
        if w.restIsCardio == true { return ("Kardiyo bitti", "Eline sağlık. Antrenmanı kaydetmeyi unutma.") }
        // Dinlenme bittiğinde gösterilecek sıradaki set
        var copy = w
        copy.restStart = nil
        copy.restEnd = nil
        let s = Planner.liveState(copy, history: data.history)
        if s.target.isEmpty { return ("Dinlenme bitti", "Sıradaki sete geç.") }
        return ("Dinlenme bitti", "\(s.exercise) · \(s.target)")
    }

    private func startTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 0.25, repeats: true) { _ in
            WorkoutEngine.shared.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let r = rest else {
            stopTicker()
            return
        }
        let left = r.end.timeIntervalSinceNow
        // Uygulama ayaktaysa yedek bildirimi iptal et, uyarıyı kendimiz verelim
        if left <= 0.7 && left > -3 && !fallbackCancelled {
            fallbackCancelled = true
            Notifier.cancelRest()
        }
        if left <= 0 {
            restFinished(late: left < -3)
            return
        }
        let whole = Int(ceil(left))
        if whole <= 3, whole >= 1, whole != lastCountdown, r.total > 8, !r.cardio {
            lastCountdown = whole
            Feedback.countdown(foreground: isForeground)
        }
    }

    private func restFinished(late: Bool) {
        stopTicker()
        let foreground = isForeground
        let (title, body) = alertText()

        if testRest != nil {
            testRest = nil
            let done = MolaActivityAttributes.ContentState(
                phase: .working, exercise: "Deneme tamam", setTitle: "Her şey çalışıyor",
                target: "", previous: nil, restStart: nil, restEnd: nil,
                exerciseIndex: 0, exerciseCount: 1, doneSets: 1, totalSets: 1)
            if !late { alert(foreground: foreground, state: done, title: title, body: body) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                guard self.data.active == nil, self.testRest == nil else { return }
                LiveActivityManager.shared.endAll()
                AudioEngine.shared.stopKeepAlive()
            }
            return
        }

        guard var w = data.active else { return }
        if w.restIsCardio == true { w.cardio.done = true }
        w.restStart = nil
        w.restEnd = nil
        w.restIsCardio = nil
        data.active = w
        restEndedAt = Date()
        saveNow()
        if late {
            Notifier.cancelRest()
            pushLive()
        } else {
            alert(foreground: foreground, state: liveState(), title: title, body: body)
        }
        reloadWidgets()
    }

    private func alert(foreground: Bool, state: MolaActivityAttributes.ContentState, title: String, body: String) {
        let panel = LiveActivityManager.shared.isRunning
        // Ön plandaysa zili biz çalarız; arka planda kilit ekranı paneli çalar ve ekranı uyandırır
        Feedback.restDone(foreground: foreground, playSound: foreground || !panel)
        if foreground || !panel {
            LiveActivityManager.shared.update(state)
        } else {
            LiveActivityManager.shared.update(state, alert: (title, body))
        }
    }

    // MARK: - Kardiyo ve bitiş

    func startCardio(kind: CardioKind, minutes: Int, incline: Double, speed: Double, resistance: Int) {
        guard var w = data.active else { return }
        w.cardio.kind = kind
        w.cardio.minutes = minutes
        w.cardio.incline = incline
        w.cardio.speed = speed
        w.cardio.resistance = resistance
        w.cardio.done = false
        data.active = w
        // Bir sonraki antrenman için en son kardiyo ayarını hatırla
        data.settings.cardioDefaults.kind = kind
        switch kind {
        case .treadmill:
            data.settings.cardioDefaults.treadmillMinutes = minutes
            data.settings.cardioDefaults.incline = incline
            data.settings.cardioDefaults.speed = speed
        case .bike:
            data.settings.cardioDefaults.bikeMinutes = minutes
            data.settings.cardioDefaults.resistance = resistance
        }
        startRest(seconds: minutes * 60, cardio: true)
    }

    func setCardioDone(_ done: Bool) {
        guard var w = data.active else { return }
        w.cardio.done = done
        data.active = w
        saveNow()
        pushLive()
    }

    /// Antrenmanı kaydeder. Hiç set yapılmadıysa kaydetmez.
    @discardableResult
    func finish() -> Workout? {
        guard var w = data.active else { return nil }
        stopTicker()
        Notifier.cancelRest()
        LiveActivityManager.shared.endAll()
        AudioEngine.shared.stopKeepAlive()
        w.restStart = nil
        w.restEnd = nil
        w.restIsCardio = nil
        w.focus = nil
        showWorkout = false
        lastCompleted = nil
        restEndedAt = nil

        guard w.doneSetCount > 0 else {
            data.active = nil
            saveNow()
            applyIdleTimer()
            reloadWidgets()
            return nil
        }
        w.finishedAt = Date()
        data.history.append(w)
        data.active = nil
        saveNow()
        applyIdleTimer()
        reloadWidgets()
        // Tam ekran kapanırken özet açılmasın diye kısa bekle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.lastFinished = w
        }
        return w
    }

    func discardActive() {
        stopTicker()
        Notifier.cancelRest()
        LiveActivityManager.shared.endAll()
        AudioEngine.shared.stopKeepAlive()
        showWorkout = false
        lastCompleted = nil
        data.active = nil
        saveNow()
        applyIdleTimer()
        reloadWidgets()
    }

    func delete(_ workout: Workout) {
        data.history.removeAll { $0.id == workout.id }
        saveNow()
        reloadWidgets()
    }

    // MARK: - Deneme

    func startTestRest() {
        guard data.active == nil else { return }
        Notifier.requestAuthorization()
        let now = Date()
        let t = TestRest(start: now, end: now.addingTimeInterval(10))
        testRest = t
        if data.settings.backgroundTimer { AudioEngine.shared.startKeepAlive() }
        LiveActivityManager.shared.start(
            attributes: MolaActivityAttributes(routineName: "Deneme", plateRaw: Plate.red.rawValue, startedAt: now),
            state: liveState())
        arm(end: t.end)
    }

    private func endTest() {
        guard testRest != nil else { return }
        testRest = nil
        stopTicker()
        Notifier.cancelRest()
        LiveActivityManager.shared.endAll()
        if data.active == nil { AudioEngine.shared.stopKeepAlive() }
    }

    // MARK: - Uygulama yaşam döngüsü

    private func resumeAfterLaunch() {
        guard data.active != nil else { return }
        if let e = data.active?.restEnd, e <= Date() {
            var w = data.active!
            if w.restIsCardio == true { w.cardio.done = true }
            w.restStart = nil
            w.restEnd = nil
            w.restIsCardio = nil
            data.active = w
        }
        if rest != nil { startTicker() }
        if data.settings.backgroundTimer { AudioEngine.shared.startKeepAlive() }
    }

    func didBecomeActive() {
        if rest != nil {
            tick()
            if rest != nil { startTicker() }
        }
        if let w = data.active {
            if LiveActivityManager.shared.isRunning {
                pushLive()
            } else {
                LiveActivityManager.shared.start(attributes: attributes(for: w), state: liveState())
            }
            if data.settings.backgroundTimer { AudioEngine.shared.startKeepAlive() }
        } else if testRest == nil {
            LiveActivityManager.shared.endAll()
        }
        applyIdleTimer()
        reloadWidgets()
    }

    func didEnterBackground() {
        saveNow()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func applyBackgroundSetting() {
        if data.settings.backgroundTimer && (data.active != nil || testRest != nil) {
            AudioEngine.shared.startKeepAlive()
        } else if !data.settings.backgroundTimer {
            AudioEngine.shared.stopKeepAlive()
        }
    }

    func applyIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = data.settings.keepAwake && data.active != nil && isForeground
    }

    func handle(_ url: URL) {
        guard url.scheme == "mola" else { return }
        if url.host == "workout", data.active != nil {
            showWorkout = true
        }
    }

    // MARK: - Özet metni (Claude'a göndermek için)

    func exportText(_ w: Workout) -> String {
        var lines: [String] = []
        let date = Fmt.full.string(from: w.finishedAt ?? w.startedAt)
        lines.append("MOLA · \(w.routineName) · \(date) · \(w.minutes) dk · \(w.doneSetCount) set")
        for ex in w.exercises {
            let done = ex.sets.filter(\.done)
            guard !done.isEmpty else { continue }
            let parts = done.map { "\($0.kind.short) \(Fmt.kg($0.kg))×\($0.reps)" }
            lines.append("\(ex.name): " + parts.joined(separator: " | "))
        }
        if w.cardio.done {
            lines.append("Kardiyo: \(w.cardio.summaryText)")
        } else {
            lines.append("Kardiyo: yapılmadı")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Özet metni (Yapay zeka takibi için) ve JSON Yedek

    enum ExportRange: CaseIterable {
        case week
        case month
        case all

        var title: String {
            switch self {
            case .week: return "Son 7 gün"
            case .month: return "Son 30 gün"
            case .all: return "Tüm geçmiş"
            }
        }
    }

    func workouts(in range: ExportRange, now: Date = Date()) -> [Workout] {
        let all = finishedHistory
        switch range {
        case .all:
            return all
        case .week:
            let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            return all.filter { ($0.finishedAt ?? $0.startedAt) >= cutoff }
        case .month:
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
            return all.filter { ($0.finishedAt ?? $0.startedAt) >= cutoff }
        }
    }

    func exportText(range: ExportRange) -> String {
        let list = workouts(in: range).reversed()
        guard !list.isEmpty else {
            return "MOLA · \(range.title) · Kayıt yok"
        }
        let header = "MOLA · \(range.title) (\(list.count) antrenman)"
        let body = list.map(exportText).joined(separator: "\n\n")
        return "\(header)\n\n\(body)"
    }

    func exportAll() -> String {
        exportText(range: .all)
    }

    func backupData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(data)
    }

    enum BackupError: LocalizedError {
        case invalidFormat
        var errorDescription: String? {
            "Seçilen dosya geçerli bir Mola yedeği değil."
        }
    }

    /// JSON yedeğini doğrular ve mevcut verilerin yerine geri yükler
    func restoreBackup(from raw: Data) throws -> Int {
        guard var decoded = try? SharedStore.decoder.decode(AppData.self, from: raw) else {
            throw BackupError.invalidFormat
        }
        decoded.seeded = true
        stopTicker()
        Notifier.cancelRest()
        LiveActivityManager.shared.endAll()
        AudioEngine.shared.stopKeepAlive()
        showWorkout = false
        lastCompleted = nil
        restEndedAt = nil
        data = decoded
        saveNow()
        applyIdleTimer()
        reloadWidgets()
        return Planner.finished(decoded.history).count
    }

    /// Bu antrenmanda geçen sefere göre artan top setler
    func records(in w: Workout) -> [(name: String, from: Double, to: Double)] {
        w.exercises.compactMap { ex -> (name: String, from: Double, to: Double)? in
            guard let top = ex.topSet,
                  let found = Planner.lastTop(ex.liftKey, in: data.history, before: w.startedAt),
                  top.kg > found.set.kg else { return nil }
            return (name: ex.name, from: found.set.kg, to: top.kg)
        }
    }
}
