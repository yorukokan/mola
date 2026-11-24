import Foundation

/// Bir antrenmandaki set adresi
struct SetRef: Hashable {
    var ex: Int
    var set: Int
}

struct Suggestion {
    var kg: Double
    var reps: Int
    var increased: Bool
    var last: SetEntry?
    var lastDate: Date?
}

func roundTo(_ value: Double, step: Double) -> Double {
    guard step > 0 else { return value }
    return (value / step).rounded() * step
}

/// Uygulama ve widget'ın ortak kullandığı hesaplar
enum Planner {

    static func finished(_ history: [Workout]) -> [Workout] {
        history
            .filter { $0.finishedAt != nil }
            .sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
    }

    /// Bir hareketin en son yapılan top seti
    static func lastTop(_ liftKey: String, in history: [Workout], before date: Date = .distantFuture) -> (set: SetEntry, date: Date)? {
        for w in finished(history) where (w.finishedAt ?? .distantPast) < date {
            if let ex = w.exercises.first(where: { $0.liftKey == liftKey }),
               let top = ex.sets.first(where: { $0.kind == .top && $0.done && $0.kg > 0 }) {
                return (set: top, date: w.finishedAt ?? w.startedAt)
            }
        }
        return nil
    }

    /// Çift progresyon: geçen sefer aralığın üstüne çıktıysan kiloyu bir adım artır
    static func suggestion(for def: ExerciseDef, history: [Workout]) -> Suggestion {
        guard let found = lastTop(def.liftKey, in: history) else {
            return Suggestion(kg: 0, reps: def.kind.topRange.lowerBound, increased: false, last: nil, lastDate: nil)
        }
        let last = found.set
        if last.reps >= def.kind.topRange.upperBound {
            return Suggestion(kg: last.kg + def.step, reps: def.kind.topRange.lowerBound,
                              increased: true, last: last, lastDate: found.date)
        }
        return Suggestion(kg: last.kg, reps: min(last.reps + 1, def.kind.topRange.upperBound),
                          increased: false, last: last, lastDate: found.date)
    }

    /// Sırayla: Üst A → Alt A → Üst B → Alt B
    static func nextRoutine(history: [Workout], routines: [RoutineDef] = Program.routines) -> RoutineDef {
        let all = routines.isEmpty ? Program.routines : routines
        guard let last = finished(history).first,
              let idx = all.firstIndex(where: { $0.id == last.routineId }) else { return all[0] }
        return all[(idx + 1) % all.count]
    }

    static func estimatedMinutes(_ r: RoutineDef, history: [Workout]) -> Int {
        let same = Array(finished(history).filter { $0.routineId == r.id }.prefix(3))
        guard !same.isEmpty else { return r.exercises.count * 10 + 15 }
        let total = same.reduce(0) { $0 + $1.minutes }
        return total / same.count
    }

    static func makeWorkout(_ routine: RoutineDef,
                            history: [Workout],
                            cardioDefaults: CardioDefaults = CardioDefaults()) -> Workout {
        let exercises: [ExerciseEntry] = routine.exercises.map { def in
            let s = suggestion(for: def, history: history)
            let top = s.kg
            var sets: [SetEntry] = []
            if def.kind.hasWarmup {
                sets.append(SetEntry(kind: .warmup, kg: roundTo(top * 0.5, step: def.step), reps: 10))
            }
            sets.append(SetEntry(kind: .top, kg: top, reps: s.reps))
            for _ in 0..<max(1, def.backoffSets) {
                sets.append(SetEntry(kind: .backoff, kg: roundTo(top * 0.9, step: def.step), reps: def.kind.backoffRange.lowerBound))
            }
            return ExerciseEntry(id: def.id, name: def.name, liftKey: def.liftKey, sets: sets)
        }
        let cardio = CardioEntry(
            kind: cardioDefaults.kind,
            minutes: cardioDefaults.kind == .treadmill ? cardioDefaults.treadmillMinutes : cardioDefaults.bikeMinutes,
            incline: cardioDefaults.incline,
            speed: cardioDefaults.speed,
            resistance: cardioDefaults.resistance,
            done: false
        )
        return Workout(routineId: routine.id, routineName: routine.name, plate: routine.plate,
                       startedAt: Date(), exercises: exercises, cardio: cardio)
    }

    static func def(_ w: Workout, _ ei: Int, routines: [RoutineDef] = Program.routines) -> ExerciseDef? {
        guard w.exercises.indices.contains(ei) else { return nil }
        let id = w.exercises[ei].id
        if let found = routines.first(where: { $0.id == w.routineId })?.exercises.first(where: { $0.id == id }) {
            return found
        }
        return Program.routine(w.routineId)?.exercises.first { $0.id == id }
    }

    /// Sıradaki set: odaktaki hareketten başlayıp ileriye doğru ilk açık set
    static func cursor(in w: Workout) -> SetRef? {
        let n = w.exercises.count
        guard n > 0 else { return nil }
        let start = min(max(w.focus ?? 0, 0), n - 1)
        for k in 0..<n {
            let ei = (start + k) % n
            let ex = w.exercises[ei]
            if ex.isComplete { continue }
            if let si = ex.sets.firstIndex(where: { $0.isOpen }) {
                return SetRef(ex: ei, set: si)
            }
        }
        return nil
    }

    static func setTitle(_ ex: ExerciseEntry, _ si: Int) -> String {
        guard ex.sets.indices.contains(si) else { return "" }
        return "\(ex.sets[si].kind.title) · \(si + 1)/\(ex.sets.count)"
    }

    /// Kilit ekranı paneli ve widget için anlık durum
    static func liveState(_ w: Workout, history: [Workout], now: Date = Date()) -> MolaActivityAttributes.ContentState {
        var s = MolaActivityAttributes.ContentState(
            phase: .working, exercise: "", setTitle: "", target: "", previous: nil,
            restStart: nil, restEnd: nil,
            exerciseIndex: 0, exerciseCount: w.exercises.count,
            doneSets: w.doneSetCount, totalSets: w.totalSetCount)

        let resting = (w.restEnd ?? .distantPast) > now
        if resting {
            s.restStart = w.restStart
            s.restEnd = w.restEnd
        }

        if resting && w.restIsCardio == true {
            s.phase = .cardio
            s.exercise = w.cardio.kind.shortActivity
            s.setTitle = "\(w.cardio.kind.title) · \(w.cardio.minutes) dk"
            s.target = w.cardio.detailText
            s.exerciseIndex = max(0, w.exercises.count - 1)
            return s
        }

        if let c = cursor(in: w) {
            let ex = w.exercises[c.ex]
            let set = ex.sets[c.set]
            s.phase = resting ? .resting : .working
            s.exercise = ex.name
            s.setTitle = setTitle(ex, c.set)
            s.target = Fmt.target(set.kg, set.reps)
            s.exerciseIndex = c.ex
            if let found = lastTop(ex.liftKey, in: history, before: w.startedAt) {
                s.previous = "Geçen: \(Fmt.kg(found.set.kg))×\(found.set.reps)"
            }
        } else {
            s.phase = .done
            s.exercise = w.cardio.done ? "Antrenman tamam" : "Setler bitti"
            s.setTitle = w.cardio.done ? "Kaydetmek için uygulamayı aç" : "Sırada kardiyo"
            s.target = ""
            s.exerciseIndex = max(0, w.exercises.count - 1)
            s.restStart = nil
            s.restEnd = nil
        }
        return s
    }

    /// Ana ekran widget'ı için sıradaki antrenmanın hedefleri
    static func targets(for r: RoutineDef, history: [Workout]) -> [(name: String, target: String, up: Bool)] {
        r.exercises.map { def -> (name: String, target: String, up: Bool) in
            let s = suggestion(for: def, history: history)
            let text = s.kg > 0 ? "\(Fmt.kg(s.kg))×\(s.reps)" : "—"
            return (name: def.name, target: text, up: s.increased)
        }
    }
}
