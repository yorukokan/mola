import SwiftUI
import Charts
import UIKit

struct HistoryView: View {
    @EnvironmentObject var engine: WorkoutEngine

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
        }
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject var engine: WorkoutEngine
    var workout: Workout
    @State private var copied = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    PlateDot(plate: workout.plate, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Fmt.full.string(from: workout.finishedAt ?? workout.startedAt))
                            .font(.system(size: 15, weight: .semibold))
                        Text("\(workout.minutes) dk · \(workout.doneSetCount) set")
                            .font(.system(size: 13))
                            .foregroundStyle(Ink.secondary)
                    }
                }
            }
            ForEach(workout.exercises) { ex in
                Section(ex.name) {
                    ForEach(ex.sets.filter(\.done)) { s in
                        HStack {
                            Text(s.kind.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(s.kind == .warmup ? Ink.secondary : Ink.primary)
                            Spacer()
                            Text("\(Fmt.kg(s.kg)) kg × \(s.reps)")
                                .font(PFont.number(16))
                        }
                    }
                }
            }
            Section("Kardiyo") {
                Text(workout.cardio.done ? workout.cardio.summaryText : "Kaydedilmedi")
                    .foregroundStyle(workout.cardio.done ? Ink.primary : Ink.secondary)
            }
            Section {
                Button {
                    UIPasteboard.general.string = engine.exportText(workout)
                    copied = true
                } label: {
                    Label(copied ? "Kopyalandı" : "Claude için özeti kopyala", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Ink.canvas.ignoresSafeArea())
        .navigationTitle(workout.routineName)
        .navigationBarTitleDisplayMode(.inline)
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
        for r in Program.routines {
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
