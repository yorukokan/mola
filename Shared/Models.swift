import Foundation
import ActivityKit

// MARK: - Program tanımı

enum ExerciseKind: String, Codable, CaseIterable {
    case main   // ağır bileşik hareket: ısınma + top 6-8 + back-off 8-10
    case iso    // izolasyon: top 10-12 + back-off 10-12
    case face   // arka omuz / yüksek tekrar: 12-15

    var title: String {
        switch self {
        case .main: return "Ana bileşik (ısınmalı)"
        case .iso: return "İzolasyon"
        case .face: return "Yüksek tekrar (12–15)"
        }
    }

    var repSummary: String {
        switch self {
        case .main: return "6–8 / 8–10 tekrar"
        case .iso: return "10–12 tekrar"
        case .face: return "12–15 tekrar"
        }
    }

    var topRange: ClosedRange<Int> {
        switch self {
        case .main: return 6...8
        case .iso: return 10...12
        case .face: return 12...15
        }
    }
    var backoffRange: ClosedRange<Int> {
        switch self {
        case .main: return 8...10
        case .iso: return 10...12
        case .face: return 12...15
        }
    }
    var hasWarmup: Bool { self == .main }
}

struct ExerciseDef: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var kind: ExerciseKind
    /// Saniye cinsinden dinlenme
    var rest: Int
    /// Kilo artış adımı
    var step: Double
    /// Aynı hareketin farklı günlerdeki kayıtlarını birleştirmek için (ör. leg curl)
    var liftKey: String
    var note: String? = nil
    /// Back-off set sayısı (varsayılan 1 → toplam 2 çalışma seti; 2 → toplam 3 çalışma seti)
    var backoffSets: Int = 1

    var workSetCount: Int { 1 + max(1, backoffSets) }

    init(id: String,
         name: String,
         kind: ExerciseKind,
         rest: Int,
         step: Double,
         liftKey: String,
         note: String? = nil,
         backoffSets: Int = 1) {
        self.id = id
        self.name = name
        self.kind = kind
        self.rest = rest
        self.step = step
        self.liftKey = liftKey
        self.note = note
        self.backoffSets = backoffSets
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(ExerciseKind.self, forKey: .kind)
        rest = try c.decode(Int.self, forKey: .rest)
        step = try c.decode(Double.self, forKey: .step)
        liftKey = try c.decode(String.self, forKey: .liftKey)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        backoffSets = try c.decodeIfPresent(Int.self, forKey: .backoffSets) ?? 1
    }
}

struct RoutineDef: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var dayLabel: String
    var plate: Plate
    var exercises: [ExerciseDef]
}

// MARK: - Kayıtlar

enum SetKind: String, Codable, CaseIterable {
    case warmup, top, backoff

    var title: String {
        switch self {
        case .warmup: return "Isınma"
        case .top: return "Top set"
        case .backoff: return "Back-off"
        }
    }
    var short: String {
        switch self {
        case .warmup: return "ısınma"
        case .top: return "top"
        case .backoff: return "back-off"
        }
    }
}

struct SetEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: SetKind
    var kg: Double
    var reps: Int
    var done: Bool = false
    var doneAt: Date? = nil
    var skipped: Bool? = nil

    /// Henüz yapılmamış ve atlanmamış
    var isOpen: Bool { !done && skipped != true }
}

struct ExerciseEntry: Codable, Identifiable, Hashable {
    var id: String          // ExerciseDef.id
    var name: String
    var liftKey: String
    var sets: [SetEntry]

    /// Isınma dışındaki bütün setler yapıldı ya da atlandı
    var isComplete: Bool { !sets.contains { $0.isOpen && $0.kind != .warmup } }
    var topSet: SetEntry? { sets.first { $0.kind == .top && $0.done } }
    var doneWorkSets: Int { sets.filter { $0.done && $0.kind != .warmup }.count }
    var workSets: Int { sets.filter { $0.kind != .warmup }.count }
}

enum CardioKind: String, Codable, CaseIterable, Hashable {
    case treadmill
    case bike

    var title: String {
        switch self {
        case .treadmill: return "Koşu bandı"
        case .bike: return "Bisiklet"
        }
    }

    var icon: String {
        switch self {
        case .treadmill: return "figure.walk"
        case .bike: return "bicycle"
        }
    }

    var shortActivity: String {
        switch self {
        case .treadmill: return "Eğimli yürüyüş"
        case .bike: return "Kondisyon bisikleti"
        }
    }
}

struct CardioEntry: Codable, Hashable {
    var kind: CardioKind = .treadmill
    var minutes: Int = 15
    var incline: Double = 12
    var speed: Double = 4.2
    var resistance: Int = 8
    var done: Bool = false

    init(kind: CardioKind = .treadmill,
         minutes: Int = 15,
         incline: Double = 12,
         speed: Double = 4.2,
         resistance: Int = 8,
         done: Bool = false) {
        self.kind = kind
        self.minutes = minutes
        self.incline = incline
        self.speed = speed
        self.resistance = resistance
        self.done = done
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(CardioKind.self, forKey: .kind) ?? .treadmill
        minutes = try c.decodeIfPresent(Int.self, forKey: .minutes) ?? 15
        incline = try c.decodeIfPresent(Double.self, forKey: .incline) ?? 12
        speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? 4.2
        resistance = try c.decodeIfPresent(Int.self, forKey: .resistance) ?? 8
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
    }

    var detailText: String {
        switch kind {
        case .treadmill:
            return "%\(Fmt.kg(incline)) · \(Fmt.kg(speed)) km/s"
        case .bike:
            return "Seviye \(resistance)"
        }
    }

    var summaryText: String {
        switch kind {
        case .treadmill:
            return "\(minutes) dk · %\(Fmt.kg(incline)) eğim · \(Fmt.kg(speed)) km/s"
        case .bike:
            return "Bisiklet · \(minutes) dk · Seviye \(resistance)"
        }
    }
}

struct Workout: Codable, Identifiable, Hashable {
    var id = UUID()
    var routineId: String
    var routineName: String
    var plate: Plate
    var startedAt: Date
    var finishedAt: Date? = nil
    var exercises: [ExerciseEntry]
    var cardio: CardioEntry = CardioEntry()

    // Devam eden antrenmanın anlık durumu (eski kayıtlarda yok, o yüzden opsiyonel)
    var focus: Int? = nil
    var restStart: Date? = nil
    var restEnd: Date? = nil
    var restIsCardio: Bool? = nil

    var doneSetCount: Int {
        exercises.reduce(0) { $0 + $1.doneWorkSets }
    }
    var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.workSets }
    }
    var minutes: Int {
        let end = finishedAt ?? Date()
        return max(1, Int(end.timeIntervalSince(startedAt) / 60))
    }
    /// Toplam hacim (kg × tekrar), ısınma hariç
    var volume: Double {
        exercises.reduce(0) { acc, ex in
            acc + ex.sets.filter { $0.done && $0.kind != .warmup }.reduce(0) { $0 + $1.kg * Double($1.reps) }
        }
    }
}

enum Appearance: String, Codable, CaseIterable {
    case light, dark, system
    var title: String {
        switch self {
        case .light: return "Açık"
        case .dark: return "Koyu"
        case .system: return "Telefona uy"
        }
    }
}

struct CardioDefaults: Codable, Hashable {
    var kind: CardioKind = .treadmill
    var treadmillMinutes: Int = 15
    var incline: Double = 12
    var speed: Double = 4.2
    var bikeMinutes: Int = 15
    var resistance: Int = 8

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(CardioKind.self, forKey: .kind) ?? .treadmill
        treadmillMinutes = try c.decodeIfPresent(Int.self, forKey: .treadmillMinutes) ?? 15
        incline = try c.decodeIfPresent(Double.self, forKey: .incline) ?? 12
        speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? 4.2
        bikeMinutes = try c.decodeIfPresent(Int.self, forKey: .bikeMinutes) ?? 15
        resistance = try c.decodeIfPresent(Int.self, forKey: .resistance) ?? 8
    }
}

struct AppSettings: Codable, Hashable {
    var sound = true
    var haptics = true
    var countdownTicks = true
    var keepAwake = true
    var appearance: Appearance = .light
    /// Antrenman boyunca uygulamayı arka planda canlı tutar (müzik durmaz)
    var backgroundTimer = true
    /// En son kullanılan koşu bandı ve bisiklet ayarları
    var cardioDefaults = CardioDefaults()

    init() {}

    // Eski sürümün kayıtlarında olmayan alanlar varsayılan değeri alsın
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? true
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        countdownTicks = try c.decodeIfPresent(Bool.self, forKey: .countdownTicks) ?? true
        keepAwake = try c.decodeIfPresent(Bool.self, forKey: .keepAwake) ?? true
        appearance = try c.decodeIfPresent(Appearance.self, forKey: .appearance) ?? .light
        backgroundTimer = try c.decodeIfPresent(Bool.self, forKey: .backgroundTimer) ?? true
        cardioDefaults = (try? c.decodeIfPresent(CardioDefaults.self, forKey: .cardioDefaults)) ?? CardioDefaults()
    }
}

struct AppData: Codable {
    var history: [Workout] = []
    var active: Workout? = nil
    var settings = AppSettings()
    var seeded = false
    /// Kullanıcı uygulama içinden programı özelleştirdiyse burada saklanır
    var customRoutines: [RoutineDef]? = nil

    var routines: [RoutineDef] { customRoutines ?? Program.routines }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        history = try c.decodeIfPresent([Workout].self, forKey: .history) ?? []
        active = try? c.decodeIfPresent(Workout.self, forKey: .active)
        settings = (try? c.decodeIfPresent(AppSettings.self, forKey: .settings)) ?? AppSettings()
        seeded = try c.decodeIfPresent(Bool.self, forKey: .seeded) ?? false
        customRoutines = try? c.decodeIfPresent([RoutineDef].self, forKey: .customRoutines)
    }
}

// MARK: - Kilit ekranı paneli (Live Activity) ve widget durumu

struct MolaActivityAttributes: ActivityAttributes {
    enum Phase: String, Codable, Hashable {
        case working   // sıradaki seti yapıyor
        case resting   // dinleniyor
        case cardio    // kardiyo sayacı çalışıyor
        case done      // setler bitti
    }

    struct ContentState: Codable, Hashable {
        var phase: Phase
        /// Sıradaki (ya da şu anki) hareket
        var exercise: String
        /// "Top set · 2/3" gibi
        var setTitle: String
        /// "130 kg × 8"
        var target: String
        /// "Geçen: 131×7"
        var previous: String?
        var restStart: Date?
        var restEnd: Date?
        var exerciseIndex: Int
        var exerciseCount: Int
        var doneSets: Int
        var totalSets: Int

        var isResting: Bool { phase == .resting || phase == .cardio }

        /// Süre dolduysa (uygulama güncelleyemeden) "hazır" görünümüne geç
        func effective(stale: Bool, now: Date = Date()) -> ContentState {
            guard isResting else { return self }
            let over = stale || (restEnd ?? .distantFuture) <= now
            guard over else { return self }
            var s = self
            s.phase = phase == .cardio ? .done : .working
            if phase == .cardio {
                s.exercise = "Kardiyo bitti"
                s.setTitle = "Kaydetmek için uygulamayı aç"
                s.target = ""
            }
            s.restStart = nil
            s.restEnd = nil
            return s
        }

        /// Geri sayım aralığı (geçerli değilse nil)
        var restRange: ClosedRange<Date>? {
            guard let s = restStart, let e = restEnd, s < e else { return nil }
            return s...e
        }
    }

    var routineName: String
    var plateRaw: Int
    var startedAt: Date

    var plate: Plate { Plate(rawValue: plateRaw) ?? .red }
}

// MARK: - Biçimlendirme

enum Fmt {
    static func kg(_ v: Double) -> String {
        if v.rounded() == v { return String(Int(v)) }
        let s = String(format: "%.1f", v)
        return s.replacingOccurrences(of: ".", with: ",")
    }

    static func target(_ kg: Double, _ reps: Int) -> String {
        kg > 0 ? "\(Fmt.kg(kg)) kg × \(reps)" : "\(reps) tekrar"
    }

    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMM"
        return f
    }()

    static let longDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM EEEE"
        return f
    }()

    static let full: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    static let tr = Locale(identifier: "tr_TR")
}
