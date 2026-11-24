import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

@main
struct MolaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MolaWidget()
        MolaLiveActivity()
    }
}

// MARK: - Zaman çizelgesi

struct TargetRow: Hashable {
    var name: String
    var target: String
    var up: Bool
}

struct MolaEntry: TimelineEntry {
    let date: Date
    /// Antrenman yokken sıradaki rutin
    let routine: RoutineDef
    let minutes: Int
    let targets: [TargetRow]
    /// Antrenman sürüyorsa anlık durum
    let live: MolaActivityAttributes.ContentState?
    let liveRoutine: String
    let livePlate: Plate
    let startedAt: Date?

    var plate: Plate { live != nil ? livePlate : routine.plate }
}

struct MolaProvider: TimelineProvider {
    func placeholder(in context: Context) -> MolaEntry {
        makeEntry(data: AppData(), now: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (MolaEntry) -> Void) {
        completion(makeEntry(data: SharedStore.load(), now: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MolaEntry>) -> Void) {
        let now = Date()
        let data = SharedStore.load()
        var entries = [makeEntry(data: data, now: now)]
        var refresh = now.addingTimeInterval(3600)
        if let end = data.active?.restEnd, end > now {
            // Dinlenme bitince widget kendiliğinden "hazır" görünümüne geçsin
            entries.append(makeEntry(data: data, now: end.addingTimeInterval(0.5)))
            refresh = end.addingTimeInterval(1800)
        }
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func makeEntry(data: AppData, now: Date) -> MolaEntry {
        let history = data.seeded ? data.history : Program.seedHistory + data.history
        let routine = Planner.nextRoutine(history: history)
        let rows = Planner.targets(for: routine, history: history).map {
            TargetRow(name: $0.name, target: $0.target, up: $0.up)
        }
        let live = data.active.map { Planner.liveState($0, history: history, now: now) }
        return MolaEntry(date: now,
                         routine: routine,
                         minutes: Planner.estimatedMinutes(routine, history: history),
                         targets: rows,
                         live: live,
                         liveRoutine: data.active?.routineName ?? "",
                         livePlate: data.active?.plate ?? routine.plate,
                         startedAt: data.active?.startedAt)
    }
}

struct MolaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MolaToday", provider: MolaProvider()) { entry in
            MolaWidgetView(entry: entry)
                .containerBackground(for: .widget) { Ink.surface }
        }
        .configurationDisplayName("Mola")
        .description("Sıradaki antrenman; antrenmandayken dinlenme sayacı ve set butonu.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

// MARK: - Widget görünümleri

struct MolaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MolaEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            AccessoryRect(entry: entry)
        case .accessoryCircular:
            AccessoryCircle(entry: entry)
        case .accessoryInline:
            AccessoryInline(entry: entry)
        case .systemMedium:
            MediumWidget(entry: entry)
        default:
            SmallWidget(entry: entry)
        }
    }
}

struct WidgetEyebrow: View {
    var text: String
    var color: Color
    var body: some View {
        Text(text.uppercased(with: Fmt.tr))
            .font(.system(size: 11, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Widget içindeki dolu buton
struct WidgetButtonLabel: View {
    var title: String
    var systemImage: String?
    var color: Color
    var foreground: Color
    var height: CGFloat = 36

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 13, weight: .heavy))
            }
            Text(title).font(.system(size: 14, weight: .heavy))
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, minHeight: height)
        .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SmallWidget: View {
    let entry: MolaEntry

    var body: some View {
        if let s = entry.live {
            switch s.phase {
            case .resting, .cardio:
                restView(s)
            case .working:
                workView(s)
            case .done:
                doneView(s)
            }
        } else {
            idleView
        }
    }

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                MolaMark(size: 16)
                WidgetEyebrow(text: "Sıradaki", color: entry.routine.plate.color)
            }
            Text(entry.routine.name)
                .font(.system(size: 30, weight: .heavy))
                .fontWidth(.expanded)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(Ink.primary)
            Text("\(entry.routine.exercises.count) hareket · ~\(entry.minutes) dk")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.secondary)
            Spacer(minLength: 0)
            if let first = entry.targets.first {
                Text(first.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
                Text(first.target)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Ink.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "mola://home"))
    }

    private func workView(_ s: MolaActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            WidgetEyebrow(text: "\(s.exerciseIndex + 1)/\(s.exerciseCount) · \(entry.liveRoutine)", color: entry.plate.color)
            Text(s.exercise)
                .font(.system(size: 15, weight: .heavy))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Ink.primary)
            Text(s.target)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(Ink.primary)
            Spacer(minLength: 0)
            Button(intent: CompleteSetIntent()) {
                WidgetButtonLabel(title: "Seti bitir", systemImage: "checkmark",
                                  color: entry.plate.color, foreground: entry.plate.onColor)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "mola://workout"))
    }

    @ViewBuilder
    private func restView(_ s: MolaActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            WidgetEyebrow(text: s.phase == .cardio ? "Kardiyo" : "Dinlenme", color: entry.plate.color)
            if let r = s.restRange {
                Text(timerInterval: r, countsDown: true)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Ink.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(s.phase == .cardio ? s.target : "Sıradaki: \(s.target)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Button(intent: SkipRestIntent()) {
                    WidgetButtonLabel(title: s.phase == .cardio ? "Bitir" : "Atla", systemImage: nil,
                                      color: Ink.surface2, foreground: Ink.primary)
                }
                .buttonStyle(.plain)
                if s.phase == .resting {
                    Button(intent: AdjustRestIntent(seconds: 15)) {
                        WidgetButtonLabel(title: "+15", systemImage: nil, color: Ink.surface2, foreground: Ink.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "mola://workout"))
    }

    private func doneView(_ s: MolaActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetEyebrow(text: entry.liveRoutine, color: entry.plate.color)
            Text(s.exercise)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Ink.primary)
            Text(s.setTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.secondary)
            Spacer(minLength: 0)
            Text("\(s.doneSets)/\(s.totalSets) set")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Ink.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "mola://workout"))
    }
}

struct MediumWidget: View {
    let entry: MolaEntry

    var body: some View {
        if let s = entry.live {
            HStack(spacing: 14) {
                SmallWidget(entry: entry)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    WidgetEyebrow(text: "İlerleme", color: Ink.secondary)
                    Text("\(s.doneSets)/\(s.totalSets) set")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Ink.primary)
                    progressBar(done: s.doneSets, total: s.totalSets)
                    if s.phase == .resting {
                        Text(s.exercise)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Ink.primary)
                            .lineLimit(1)
                        Text(s.setTitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Ink.secondary)
                            .lineLimit(1)
                    } else if let p = s.previous {
                        Text(s.setTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Ink.secondary)
                            .lineLimit(1)
                        Text(p)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Ink.secondary)
                    }
                    Spacer(minLength: 0)
                    if let start = entry.startedAt {
                        HStack(spacing: 4) {
                            Image(systemName: "stopwatch").font(.system(size: 11, weight: .bold))
                            Text(start, style: .timer)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        .foregroundStyle(Ink.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HStack(alignment: .top, spacing: 14) {
                SmallWidget(entry: entry)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(entry.targets.prefix(5).enumerated()), id: \.offset) { _, t in
                        HStack(spacing: 4) {
                            Text(t.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Ink.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            if t.up {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(Ink.positive)
                            }
                            Text(t.target)
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(Ink.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .widgetURL(URL(string: "mola://home"))
        }
    }

    private func progressBar(done: Int, total: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.line)
                Capsule().fill(entry.plate.color)
                    .frame(width: geo.size.width * CGFloat(done) / CGFloat(max(1, total)))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Kilit ekranı widget'ları

struct AccessoryRect: View {
    let entry: MolaEntry

    var body: some View {
        if let s = entry.live {
            VStack(alignment: .leading, spacing: 1) {
                if s.isResting, let r = s.restRange {
                    HStack(spacing: 6) {
                        Text(s.phase == .cardio ? "Kardiyo" : "Dinlenme")
                            .font(.system(size: 13, weight: .heavy))
                        Text(timerInterval: r, countsDown: true)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .widgetAccentable()
                    }
                    Text(s.phase == .cardio ? s.target : "Sıradaki: \(s.exercise)")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(s.phase == .cardio ? s.setTitle : s.target)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                } else {
                    Text(s.exercise)
                        .font(.system(size: 14, weight: .heavy))
                        .lineLimit(1)
                        .widgetAccentable()
                    Text(s.target.isEmpty ? s.setTitle : s.target)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("\(s.doneSets)/\(s.totalSets) set · \(entry.liveRoutine)")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "mola://workout"))
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text("Sıradaki: \(entry.routine.name)")
                    .font(.system(size: 14, weight: .heavy))
                    .widgetAccentable()
                Text("\(entry.routine.exercises.count) hareket · ~\(entry.minutes) dk")
                    .font(.system(size: 12, weight: .semibold))
                if let first = entry.targets.first {
                    Text("\(first.name) \(first.target)")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "mola://home"))
        }
    }
}

struct AccessoryCircle: View {
    let entry: MolaEntry

    var body: some View {
        if let s = entry.live, s.isResting, let r = s.restRange {
            ProgressView(timerInterval: r, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                Text(timerInterval: r, countsDown: true)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
            }
            .progressViewStyle(.circular)
            .widgetURL(URL(string: "mola://workout"))
        } else if let s = entry.live {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(s.doneSets)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                    Text("/\(s.totalSets)")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .widgetURL(URL(string: "mola://workout"))
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    MolaMark(size: 18, mono: true)
                    Text(entry.routine.name)
                        .font(.system(size: 11, weight: .heavy))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .padding(4)
            }
            .widgetURL(URL(string: "mola://home"))
        }
    }
}

struct AccessoryInline: View {
    let entry: MolaEntry

    var body: some View {
        if let s = entry.live, s.isResting, let r = s.restRange {
            Text("Dinlenme \(Text(timerInterval: r, countsDown: true))")
        } else if let s = entry.live {
            Text("\(s.exercise) · \(s.target)")
        } else {
            Text("Sıradaki: \(entry.routine.name)")
        }
    }
}

// MARK: - Kilit ekranı paneli (Live Activity) ve Dynamic Island

struct MolaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MolaActivityAttributes.self) { context in
            LockScreenPanel(context: context)
                .activityBackgroundTint(Color.dynamic(light: 0xFFFFFF, dark: 0x15181D))
                .activitySystemActionForegroundColor(Ink.primary)
                .widgetURL(URL(string: "mola://workout"))
        } dynamicIsland: { context in
            let s = context.state.effective(stale: context.isStale)
            let plate = context.attributes.plate
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        MolaMark(size: 18)
                        Text(context.attributes.routineName)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(plate.color)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if s.isResting, let r = s.restRange {
                        Text(timerInterval: r, countsDown: true)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72, alignment: .trailing)
                    } else {
                        Text("\(s.doneSets)/\(s.totalSets) set")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    IslandBottom(state: s, plate: plate)
                }
            } compactLeading: {
                MolaMark(size: 18)
            } compactTrailing: {
                if s.isResting, let r = s.restRange {
                    Text(timerInterval: r, countsDown: true)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 42)
                        .foregroundStyle(plate.color)
                } else {
                    Text("\(s.doneSets)/\(s.totalSets)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(plate.color)
                }
            } minimal: {
                if s.isResting, let r = s.restRange {
                    Text(timerInterval: r, countsDown: true)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 32)
                        .foregroundStyle(plate.color)
                } else {
                    MolaMark(size: 16)
                }
            }
            .keylineTint(plate.color)
        }
    }
}

struct IslandBottom: View {
    let state: MolaActivityAttributes.ContentState
    let plate: Plate

    var body: some View {
        let s = state
        VStack(alignment: .leading, spacing: 8) {
            if s.phase == .resting {
                Text("Sıradaki: \(s.exercise) · \(s.target)")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                RestButtons(dark: true)
            } else if s.phase == .cardio {
                Text("\(s.setTitle) · \(s.target)")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            } else if s.phase == .working {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.exercise)
                            .font(.system(size: 15, weight: .heavy))
                            .lineLimit(1)
                        Text("\(s.setTitle) · \(s.target)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Button(intent: CompleteSetIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy))
                            Text("Bitti").font(.system(size: 14, weight: .heavy))
                        }
                        .foregroundStyle(plate.onColor)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(plate.color, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(s.exercise)
                    .font(.system(size: 15, weight: .heavy))
            }
        }
        .padding(.horizontal, 4)
    }
}

/// −15 · Atla · +15
struct RestButtons: View {
    var dark: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: AdjustRestIntent(seconds: -15)) { label("−15") }
                .buttonStyle(.plain)
            Button(intent: SkipRestIntent()) { label("Atla") }
                .buttonStyle(.plain)
            Button(intent: AdjustRestIntent(seconds: 15)) { label("+15") }
                .buttonStyle(.plain)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(dark ? Color.white.opacity(0.14) : Color.primary.opacity(0.08), in: Capsule())
    }
}

struct LockScreenPanel: View {
    let context: ActivityViewContext<MolaActivityAttributes>

    var body: some View {
        let s = context.state.effective(stale: context.isStale)
        let plate = context.attributes.plate
        VStack(alignment: .leading, spacing: 8) {
            header(s, plate)
            switch s.phase {
            case .resting, .cardio:
                restBody(s, plate)
            case .working:
                workBody(s, plate)
            case .done:
                doneBody(s)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func header(_ s: MolaActivityAttributes.ContentState, _ plate: Plate) -> some View {
        HStack(spacing: 6) {
            MolaMark(size: 16)
            Text(context.attributes.routineName.uppercased(with: Fmt.tr))
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(plate.color)
            Text("· \(min(s.exerciseIndex + 1, max(1, s.exerciseCount)))/\(s.exerciseCount) hareket · \(s.doneSets)/\(s.totalSets) set")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(context.attributes.startedAt, style: .timer)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(width: 58, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func restBody(_ s: MolaActivityAttributes.ContentState, _ plate: Plate) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(s.phase == .cardio ? "KARDİYO" : "DİNLENME")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(plate.color)
                if let r = s.restRange {
                    Text(timerInterval: r, countsDown: true)
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 112, alignment: .leading)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 1) {
                Text(s.phase == .cardio ? s.setTitle : "Sıradaki")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(s.phase == .cardio ? "Eğimli yürüyüş" : s.exercise)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text(s.target)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
        }
        if let r = s.restRange {
            ProgressView(timerInterval: r, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(plate.color)
        }
        if s.phase == .resting {
            RestButtons()
        }
    }

    private func workBody(_ s: MolaActivityAttributes.ContentState, _ plate: Plate) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.exercise)
                    .font(.system(size: 17, weight: .heavy))
                    .lineLimit(1)
                Text(s.setTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(s.target)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let p = s.previous {
                    Text(p)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Button(intent: CompleteSetIntent()) {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .heavy))
                    Text("Bitti")
                        .font(.system(size: 13, weight: .heavy))
                }
                .foregroundStyle(plate.onColor)
                .frame(width: 78, height: 78)
                .background(plate.color, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func doneBody(_ s: MolaActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.exercise)
                .font(.system(size: 20, weight: .heavy))
            Text(s.setTitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
