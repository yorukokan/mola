import SwiftUI
import UIKit

struct SummaryView: View {
    @EnvironmentObject var engine: WorkoutEngine
    @Environment(\.dismiss) private var dismiss
    var workout: Workout
    @State private var copied = false

    var body: some View {
        let records = engine.records(in: workout)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    PlateDot(plate: workout.plate, size: 40)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Eline sağlık")
                        .font(.system(size: 40, weight: .heavy))
                        .fontWidth(.expanded)
                    Text("\(workout.routineName) · \(Fmt.full.string(from: workout.finishedAt ?? workout.startedAt))")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Ink.secondary)
                }

                HStack(spacing: 10) {
                    stat("Süre", "\(workout.minutes) dk")
                    stat("Set", "\(workout.doneSetCount)")
                    stat("Hacim", "\(Int(workout.volume)) kg")
                }

                if !records.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "Kilo artışı", color: Ink.positive)
                        ForEach(Array(records.enumerated()), id: \.offset) { _, r in
                            HStack {
                                Text(r.name).font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Text("\(Fmt.kg(r.from)) → \(Fmt.kg(r.to)) kg")
                                    .font(PFont.number(16, weight: .bold))
                                    .foregroundStyle(Ink.positive)
                            }
                        }
                    }
                    .card()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "Kardiyo")
                    Text(workout.cardio.done ? workout.cardio.summaryText : "Yapılmadı")
                        .font(.system(size: 16, weight: .semibold))
                }
                .card()

                Button {
                    UIPasteboard.general.string = engine.exportText(workout)
                    copied = true
                    Feedback.setDone()
                } label: {
                    Label(copied ? "Kopyalandı, Claude'a yapıştır" : "Claude için özeti kopyala",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(BigButtonStyle(color: Ink.primary, foreground: Ink.surface))
            }
            .padding(20)
        }
        .background(Ink.canvas.ignoresSafeArea())
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased(with: Fmt.tr))
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Ink.secondary)
            Text(value)
                .font(PFont.number(22, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .card(padding: 14)
    }
}
