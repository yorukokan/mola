import Foundation

// MARK: - 4 günlük Upper / Lower programı

enum Program {
    static let routines: [RoutineDef] = [
        RoutineDef(id: "ustA", name: "Üst A", dayLabel: "Pzt", plate: .red, exercises: [
            ExerciseDef(id: "chest", name: "Chest Press", kind: .main, rest: 150, step: 2.5, liftKey: "chest"),
            ExerciseDef(id: "lat", name: "Lat Pulldown", kind: .main, rest: 150, step: 2.5, liftKey: "lat"),
            ExerciseDef(id: "mrow", name: "Machine Row (dar tutuş)", kind: .main, rest: 150, step: 2.5, liftKey: "mrow", note: "Dar tutuş · kanat"),
            ExerciseDef(id: "pec", name: "Pec Deck Fly", kind: .iso, rest: 90, step: 2.5, liftKey: "pec"),
            ExerciseDef(id: "latraise-a", name: "Lateral Raise", kind: .iso, rest: 90, step: 2.5, liftKey: "latraise"),
            ExerciseDef(id: "pushdown-a", name: "Triceps Pushdown", kind: .iso, rest: 90, step: 2.5, liftKey: "pushdown"),
            ExerciseDef(id: "overhead", name: "Overhead Extension", kind: .iso, rest: 90, step: 2.5, liftKey: "overhead"),
            ExerciseDef(id: "inclinecurl", name: "Incline Dambıl Curl", kind: .iso, rest: 90, step: 1, liftKey: "inclinecurl", note: "Tek kol kilosu"),
        ]),
        RoutineDef(id: "altA", name: "Alt A", dayLabel: "Sal", plate: .blue, exercises: [
            ExerciseDef(id: "legpress", name: "Leg Press", kind: .main, rest: 180, step: 5, liftKey: "legpress", note: "Dizleri kilitleme"),
            ExerciseDef(id: "rdl", name: "Dambıl RDL", kind: .main, rest: 150, step: 2.5, liftKey: "rdl", note: "Her elde. Bel düz, kalça geride"),
            ExerciseDef(id: "legcurl-a", name: "Leg Curl", kind: .iso, rest: 90, step: 5, liftKey: "legcurl"),
            ExerciseDef(id: "legext-a", name: "Leg Extension", kind: .iso, rest: 90, step: 5, liftKey: "legext"),
            ExerciseDef(id: "calf-a", name: "Calf Raise (oturarak)", kind: .iso, rest: 90, step: 5, liftKey: "calf-seated"),
            ExerciseDef(id: "crunch-a", name: "Abdominal Crunch", kind: .iso, rest: 90, step: 2.5, liftKey: "crunch"),
        ]),
        RoutineDef(id: "ustB", name: "Üst B", dayLabel: "Per", plate: .yellow, exercises: [
            ExerciseDef(id: "incline", name: "Incline Chest Press", kind: .main, rest: 150, step: 2.5, liftKey: "incline"),
            ExerciseDef(id: "mrow-wide", name: "Machine Row (geniş tutuş)", kind: .main, rest: 150, step: 2.5, liftKey: "mrow-wide", note: "Geniş tutuş · üst sırt"),
            ExerciseDef(id: "shoulder", name: "Shoulder Press", kind: .main, rest: 150, step: 2.5, liftKey: "shoulder"),
            ExerciseDef(id: "latnarrow", name: "Lat Pulldown (dar)", kind: .main, rest: 120, step: 5, liftKey: "latnarrow"),
            ExerciseDef(id: "singletriceps", name: "Tek Kol Kablo Triceps", kind: .iso, rest: 90, step: 2.5, liftKey: "singletriceps", note: "Tek kol kilosu"),
            ExerciseDef(id: "inclinecurl-b", name: "Incline Dambıl Curl", kind: .iso, rest: 90, step: 1, liftKey: "inclinecurl", note: "Tek kol kilosu"),
            ExerciseDef(id: "hammer", name: "Hammer Curl", kind: .iso, rest: 90, step: 1, liftKey: "hammer", note: "Süre uzarsa atla"),
        ]),
        RoutineDef(id: "altB", name: "Alt B", dayLabel: "Cum", plate: .green, exercises: [
            ExerciseDef(id: "smith", name: "Smith Squat", kind: .main, rest: 150, step: 2.5, liftKey: "smith", note: "Kilo = taraf başı plaka"),
            ExerciseDef(id: "legcurl-b", name: "Leg Curl", kind: .iso, rest: 90, step: 5, liftKey: "legcurl"),
            ExerciseDef(id: "legext-b", name: "Leg Extension", kind: .iso, rest: 90, step: 5, liftKey: "legext"),
            ExerciseDef(id: "calf-b", name: "Calf Raise (leg press)", kind: .iso, rest: 90, step: 5, liftKey: "calf-press"),
            ExerciseDef(id: "crunch-b", name: "Abdominal Crunch", kind: .iso, rest: 90, step: 2.5, liftKey: "crunch"),
            ExerciseDef(id: "latraise-b", name: "Lateral Raise", kind: .iso, rest: 90, step: 2.5, liftKey: "latraise"),
            ExerciseDef(id: "revpec", name: "Reverse Pec Deck Fly", kind: .face, rest: 90, step: 2.5, liftKey: "revpec", note: "Arka omuz · kontrollü açış", backoffSets: 2),
        ]),
    ]

    static func routine(_ id: String) -> RoutineDef? { routines.first { $0.id == id } }

    // MARK: Önceki kayıtlar (Claude'daki sayaçtan aktarıldı)

    private typealias S = (SetKind, Double, Int)

    private static func w(_ routineId: String, _ start: Double, _ end: Double, _ items: [(String, [S])]) -> Workout {
        let r = routine(routineId)!
        let exs: [ExerciseEntry] = items.compactMap { pair in
            guard let def = r.exercises.first(where: { $0.id == pair.0 }) else { return nil }
            let sets = pair.1.map { SetEntry(kind: $0.0, kg: $0.1, reps: $0.2, done: true, doneAt: Date(timeIntervalSince1970: end)) }
            return ExerciseEntry(id: def.id, name: def.name, liftKey: def.liftKey, sets: sets)
        }
        return Workout(routineId: r.id, routineName: r.name, plate: r.plate,
                       startedAt: Date(timeIntervalSince1970: start),
                       finishedAt: Date(timeIntervalSince1970: end),
                       exercises: exs, cardio: CardioEntry(minutes: 0, done: false))
    }

    static var seedHistory: [Workout] {
        [
            w("ustA", 1793631800, 1793635924, [
                ("chest", [(.warmup, 20, 12), (.top, 40, 12), (.backoff, 50, 10)]),
                ("lat", [(.warmup, 25, 12), (.top, 60, 10), (.backoff, 65, 6)]),
                ("mrow", [(.warmup, 30, 10), (.top, 55, 8), (.backoff, 50, 10)]),
                ("pec", [(.top, 45, 11), (.backoff, 36, 8)]),
                ("latraise-a", [(.top, 20, 12), (.backoff, 20, 9)]),
                ("pushdown-a", [(.top, 39, 12), (.backoff, 44, 7)]),
                ("overhead", [(.top, 19, 7), (.backoff, 14, 8)]),
                ("inclinecurl", [(.top, 10, 8), (.backoff, 7.5, 9)]),
            ]),
            w("altA", 1793805713, 1793809435, [
                ("legpress", [(.warmup, 50, 15), (.top, 140, 9), (.backoff, 140, 9)]),
                ("rdl", [(.top, 25, 10), (.backoff, 25, 9)]),
                ("legcurl-a", [(.top, 85, 9), (.backoff, 85, 8)]),
                ("legext-a", [(.top, 60, 8), (.backoff, 60, 8)]),
                ("calf-a", [(.top, 104, 12), (.backoff, 113, 12)]),
                ("crunch-a", [(.top, 56, 8), (.backoff, 56, 8)]),
            ]),
            w("ustB", 1793891741, 1793895964, [
                ("incline", [(.warmup, 15, 10), (.top, 25, 9), (.backoff, 25, 8)]),
                ("shoulder", [(.warmup, 10, 10), (.top, 20, 8), (.backoff, 20, 8)]),
                ("latnarrow", [(.warmup, 30, 10), (.top, 60, 8), (.backoff, 60, 8)]),
                ("hammer", [(.top, 10, 10), (.backoff, 8, 8)]),
            ]),
            w("altB", 1793978245, 1793981210, [
                ("smith", [(.warmup, 5, 8), (.top, 10, 9), (.backoff, 10, 9)]),
                ("legcurl-b", [(.top, 85, 8), (.backoff, 85, 9)]),
                ("legext-b", [(.top, 60, 8), (.backoff, 60, 8)]),
                ("calf-b", [(.top, 113, 12), (.backoff, 113, 12)]),
                ("crunch-b", [(.top, 56, 9), (.backoff, 56, 9)]),
                ("latraise-b", [(.top, 20, 12), (.backoff, 20, 11)]),
            ]),
            w("ustA", 1794237065, 1794241222, [
                ("chest", [(.warmup, 20, 8), (.top, 60, 7), (.backoff, 60, 7)]),
                ("lat", [(.warmup, 30, 12), (.top, 60, 8), (.backoff, 65, 9)]),
                ("mrow", [(.top, 60, 7), (.backoff, 60, 7)]),
                ("pec", [(.top, 45, 8), (.backoff, 36, 9)]),
                ("latraise-a", [(.top, 20, 12), (.backoff, 20, 11)]),
                ("pushdown-a", [(.top, 46, 7), (.backoff, 41, 7)]),
                ("overhead", [(.top, 23, 8), (.backoff, 18, 8)]),
                ("inclinecurl", [(.top, 10, 9), (.backoff, 10, 7)]),
            ]),
        ]
    }
}
