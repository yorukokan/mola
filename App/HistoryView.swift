import SwiftUI
import Charts
import UIKit

struct HistoryView: View {
    @EnvironmentObject var engine: WorkoutEngine
    @State private var copiedLabel: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        LiftProgressView()
                    } label: {
                        Label("Kilo ilerlemesi", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                Section("Antrenmanlar") {
                    if engine.finishedHistory.isEmpty {
                        Text("Henüz kayıt yok. İlk antrenmanını bitirince burada görünecek.")
                            .font(.system(size: 14))
                            .foregroundStyle(Ink.secondary)
                    }
                    ForEach(engine.finishedHistory) { w in
                        NavigationLink {
                            WorkoutDetailView(workout: w)
                        } label: {
                            HStack(spacing: 12) {
                                PlateDot(plate: w.plate, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(w.routineName)
                                        .font(.system(size: 16, weight: .bold))
                                    Text("\(Fmt.dayMonth.string(from: w.finishedAt ?? w.startedAt)) · \(w.minutes) dk · \(w.doneSetCount) set")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Ink.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { offsets in
                        let items = offsets.map { engine.finishedHistory[$0] }
                        items.forEach { engine.delete($0) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Ink.canvas.ignoresSafeArea())
            .navigationTitle("Geçmiş")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(WorkoutEngine.ExportRange.allCases, id: \.self) { range in
                            let count = engine.workouts(in: range).count
                            Button {
                                UIPasteboard.general.string = engine.exportText(range: range)
                                Feedback.tap()
                                copiedLabel = range.title
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if copiedLabel == range.title { copiedLabel = nil }
                                }
                            } label: {
                                Label("\(range.title) (\(count))", systemImage: "doc.on.doc")
                            }
                        }
                    } label: {
                        Label(copiedLabel == nil ? "Kopyala" : "Kopyalandı",
                              systemImage: copiedLabel == nil ? "doc.on.doc" : "checkmark")
                    }
                }
            }
        }
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject var engine: WorkoutEngine
    var workout: Workout
    @State private var copied = false
    @State private var editingTarget: EditableSet?

    private struct EditableSet: Identifiable {
        var id: UUID { entry.id }
        var exerciseId: String
        var exerciseName: String
        var entry: SetEntry
    }

    private var currentWorkout: Workout {
        engine.data.history.first(where: { $0.id == workout.id }) ?? workout
    }

    private var completedExercises: [ExerciseEntry] {
        currentWorkout.exercises.filter { !$0.sets.filter(\.done).isEmpty }
    }

    var body: some View {
        let w = currentWorkout
        List {
            Section {
                HStack(spacing: 16) {
                    PlateDot(plate: w.plate, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Fmt.full.string(from: w.finishedAt ?? w.startedAt))
                            .font(.system(size: 15, weight: .semibold))
                        Text("\(w.minutes) dk · \(w.doneSetCount) set")
                            .font(.system(size: 13))
                            .foregroundStyle(Ink.secondary)
                    }
                }
            }
            ForEach(completedExercises) { ex in
                Section(ex.name) {
                    ForEach(ex.sets.filter(\.done)) { s in
                        Button {
                            editingTarget = EditableSet(exerciseId: ex.id, exerciseName: ex.name, entry: s)
                        } label: {
                            HStack {
                                Text(s.kind.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(s.kind == .warmup ? Ink.secondary : Ink.primary)
                                Spacer()
                                Text("\(Fmt.kg(s.kg)) kg × \(s.reps)")
                                    .font(PFont.number(16))
                                    .foregroundStyle(Ink.primary)
                            }
                        }
                    }
                }
            }
            Section("Kardiyo") {
                Text(w.cardio.done ? w.cardio.summaryText : "Kaydedilmedi")
                    .foregroundStyle(w.cardio.done ? Ink.primary : Ink.secondary)
            }
            Section {
                Button {
                    UIPasteboard.general.string = engine.exportText(w)
                    copied = true
                } label: {
                    Label(copied ? "Kopyalandı" : "AI için özeti kopyala", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
            } footer: {
                Text("Yanlış girilmiş bir seti düzeltmek için satıra dokun.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Ink.canvas.ignoresSafeArea())
        .navigationTitle(w.routineName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTarget) { item in
            HistorySetEditSheet(exerciseName: item.exerciseName, set: item.entry) { kg, reps in
                engine.updateHistorySet(workoutId: w.id, exerciseId: item.exerciseId, setId: item.entry.id, kg: kg, reps: reps)
            }
            .presentationDetents([.medium])
        }
    }
}

private struct HistorySetEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String
    let set: SetEntry
    let onSave: (Double, Int) -> Void

    @State private var kgText = ""
    @State private var reps = 8

    var body: some View {
        NavigationStack {
            Form {
                Section("\(exerciseName) · \(set.kind.title)") {
                    HStack {
                        Text("Kilo (kg)")
                        Spacer()
                        TextField("0", text: $kgText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(PFont.number(18, weight: .bold))
                            .frame(width: 100)
                    }
                    Stepper("Tekrar: \(reps)", value: $reps, in: 0...50)
                }
            }
            .navigationTitle("Seti düzelt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        let kg = parseNumber(kgText) ?? set.kg
                        onSave(kg, reps)
                        dismiss()
                    }
                }
            }
            .onAppear {
                kgText = Fmt.kg(set.kg)
                reps = set.reps
            }
        }
    }
}

// MARK: - Kilo ilerleme grafiği

struct LiftProgressView: View {
    @EnvironmentObject var engine: WorkoutEngine
    @State private var selected: String = "chest"

    private struct Lift: Hashable {
        var key: String
        var name: String
    }

    private var lifts: [Lift] {
        var seen = Set<String>()
        var out: [Lift] = []
        for r in engine.routines {
            for e in r.exercises where seen.insert(e.liftKey).inserted {
                out.append(Lift(key: e.liftKey, name: e.name))
            }
        }
        return out
    }

    private struct Point: Identifiable {
        var id = UUID()
        var date: Date
        var kg: Double
        var reps: Int
    }

    private var points: [Point] {
        engine.finishedHistory.reversed().compactMap { w -> Point? in
            guard let ex = w.exercises.first(where: { $0.liftKey == selected }),
                  let top = ex.topSet else { return nil }
            return Point(date: w.finishedAt ?? w.startedAt, kg: top.kg, reps: top.reps)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Hareket", selection: $selected) {
                    ForEach(lifts, id: \.key) { l in
                        Text(l.name).tag(l.key)
                    }
                }
                .pickerStyle(.menu)
                .tint(Ink.primary)

                let pts = points
                if pts.count < 2 {
                    Text(pts.isEmpty ? "Bu hareket için henüz kayıt yok."
                                     : "Grafik için en az iki kayıt gerekiyor. Son: \(Fmt.kg(pts[0].kg)) kg × \(pts[0].reps)")
                        .font(.system(size: 14))
                        .foregroundStyle(Ink.secondary)
                        .card()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Top set kilosu")
                        Chart(pts) { p in
                            LineMark(x: .value("Tarih", p.date), y: .value("Kilo", p.kg))
                                .interpolationMethod(.monotone)
                                .foregroundStyle(Plate.red.color)
                            PointMark(x: .value("Tarih", p.date), y: .value("Kilo", p.kg))
                                .foregroundStyle(Plate.red.color)
                                .annotation(position: .top) {
                                    Text("\(Fmt.kg(p.kg))×\(p.reps)")
                                        .font(PFont.number(10, weight: .semibold))
                                        .foregroundStyle(Ink.secondary)
                                }
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 220)
                    }
                    .card()
                }
            }
            .padding(20)
        }
        .background(Ink.canvas.ignoresSafeArea())
        .navigationTitle("Kilo ilerlemesi")
        .navigationBarTitleDisplayMode(.inline)
    }
}
