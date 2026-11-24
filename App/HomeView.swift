import SwiftUI

struct HomeView: View {
    @EnvironmentObject var engine: WorkoutEngine
    /// Kullanıcı başka bir rutin seçtiyse; yoksa sıradaki
    @State private var picked: String?

    private var routine: RoutineDef {
        if let id = picked, let r = Program.routine(id) { return r }
        return engine.nextRoutine
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let w = engine.data.active {
                        ResumeCard(workout: w)
                    } else {
                        routinePicker
                        NextWorkoutCard(routine: routine, isNext: routine.id == engine.nextRoutine.id)
                    }
                    if let last = engine.finishedHistory.first {
                        NavigationLink {
                            WorkoutDetailView(workout: last)
                        } label: {
                            LastWorkoutRow(workout: last)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Ink.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            MolaMark(size: 30)
            Text("Mola")
                .font(.system(size: 26, weight: .heavy))
                .fontWidth(.expanded)
                .foregroundStyle(Ink.primary)
            Spacer()
            Text(Fmt.longDay.string(from: Date()))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Ink.secondary)
        }
        .padding(.top, 6)
    }

    /// Dört rutin, tek satır. Seçili olan büyük kartta görünür.
    private var routinePicker: some View {
        HStack(spacing: 8) {
            ForEach(Program.routines) { r in
                let selected = r.id == routine.id
                Button {
                    Feedback.tap()
                    picked = r.id == engine.nextRoutine.id ? nil : r.id
                } label: {
                    HStack(spacing: 6) {
                        PlateDot(plate: r.plate, size: 10)
                        Text(r.name)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selected ? Ink.surface : Ink.primary)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(selected ? Ink.primary : Ink.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Ink.line, lineWidth: selected ? 0 : 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Sıradaki antrenman kartı

struct NextWorkoutCard: View {
    @EnvironmentObject var engine: WorkoutEngine
    var routine: RoutineDef
    var isNext: Bool

    var body: some View {
        let rows = Planner.targets(for: routine, history: engine.data.history)
        let minutes = Planner.estimatedMinutes(routine, history: engine.data.history)

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: isNext ? "Sıradaki antrenman" : "Seçilen antrenman", color: routine.plate.color)
                Text(routine.name)
                    .font(.system(size: 48, weight: .heavy))
                    .fontWidth(.expanded)
                    .foregroundStyle(Ink.primary)
                Text("\(routine.exercises.count) hareket · yaklaşık \(minutes) dk + kardiyo")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Ink.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(spacing: 10) {
                        Text("\(i + 1)")
                            .font(PFont.number(13, weight: .bold))
                            .foregroundStyle(Ink.tertiary)
                            .frame(width: 18, alignment: .leading)
                        Text(row.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Ink.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if row.up {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(Ink.positive)
                        }
                        Text(row.target)
                            .font(PFont.number(16, weight: .bold))
                            .foregroundStyle(Ink.primary)
                    }
                    .padding(.vertical, 10)
                    if i < rows.count - 1 {
                        Divider().overlay(Ink.line)
                    }
                }
            }

            Text("Sağdaki rakamlar bugünkü top set hedefin. Yeşil ok: geçen sefer üst sınıra ulaştın, kilo arttı.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Ink.tertiary)

            Button {
                engine.start(routine)
            } label: {
                Label("Başla", systemImage: "play.fill")
            }
            .buttonStyle(BigButtonStyle(color: routine.plate.color, foreground: routine.plate.onColor))
        }
        .card(padding: 20)
    }
}

// MARK: - Devam eden antrenman

struct ResumeCard: View {
    @EnvironmentObject var engine: WorkoutEngine
    var workout: Workout

    var body: some View {
        let s = Planner.liveState(workout, history: engine.data.history)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(text: "Devam ediyor", color: workout.plate.color)
                Spacer()
                Text(workout.startedAt, style: .timer)
                    .font(PFont.number(15, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
            }
            Text(workout.routineName)
                .font(.system(size: 44, weight: .heavy))
                .fontWidth(.expanded)
            VStack(alignment: .leading, spacing: 4) {
                Text(s.exercise).font(.system(size: 18, weight: .bold))
                Text(s.target.isEmpty ? s.setTitle : "\(s.setTitle) · \(s.target)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Ink.secondary)
            }
            Text("\(workout.doneSetCount)/\(workout.totalSetCount) set bitti")
                .font(PFont.number(14, weight: .semibold))
                .foregroundStyle(Ink.secondary)
            Button {
                engine.showWorkout = true
            } label: {
                Label("Devam et", systemImage: "arrow.right")
            }
            .buttonStyle(BigButtonStyle(color: workout.plate.color, foreground: workout.plate.onColor))
        }
        .card(padding: 20)
    }
}

struct LastWorkoutRow: View {
    var workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            PlateDot(plate: workout.plate, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Son antrenman · \(workout.routineName)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Ink.primary)
                Text("\(Fmt.dayMonth.string(from: workout.finishedAt ?? workout.startedAt)) · \(workout.minutes) dk · \(workout.doneSetCount) set")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Ink.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Ink.tertiary)
        }
        .card(padding: 16)
    }
}
