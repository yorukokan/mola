import SwiftUI

/// Antrenman ekranı: her an tek bir şey gösterir.
/// Sıradaki set → "Seti bitir" → dinlenme → sıradaki set ... → kardiyo → bitir.
struct WorkoutView: View {
    @EnvironmentObject var engine: WorkoutEngine
    @State private var showList = false
    @State private var confirmFinish = false

    var body: some View {
        ZStack {
            Ink.canvas.ignoresSafeArea()
            if let w = engine.data.active {
                VStack(spacing: 0) {
                    topBar(w)
                    ExerciseStrip(workout: w, current: engine.cursor?.ex) { showList = true }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    content(w)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showList) {
            ExerciseListSheet()
                .environmentObject(engine)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Antrenman", isPresented: $confirmFinish, titleVisibility: .hidden) {
            if (engine.data.active?.doneSetCount ?? 0) > 0 {
                Button("Kaydet ve bitir") { engine.finish() }
            }
            Button("Antrenmanı sil", role: .destructive) { engine.discardActive() }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text((engine.data.active?.doneSetCount ?? 0) > 0
                 ? "Yaptığın setler kaydedilecek."
                 : "Henüz set yapmadın, kaydedilecek bir şey yok.")
        }
    }

    @ViewBuilder
    private func content(_ w: Workout) -> some View {
        if let r = engine.rest, !r.test {
            if r.cardio {
                CardioRunningScreen(rest: r, workout: w)
            } else {
                RestScreen(rest: r, workout: w)
            }
        } else if let c = engine.cursor {
            SetScreen(workout: w, ref: c)
                .id("\(c.ex)-\(c.set)")
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .opacity))
        } else {
            CardioScreen(workout: w) { confirmFinish = true }
        }
    }

    private func topBar(_ w: Workout) -> some View {
        HStack(spacing: 10) {
            Button {
                engine.showWorkout = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    PlateDot(plate: w.plate, size: 10)
                    Text(w.routineName).font(.system(size: 16, weight: .heavy))
                }
                Text(w.startedAt, style: .timer)
                    .font(PFont.number(13, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
            }
            Spacer()
            Button {
                showList = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            Button {
                confirmFinish = true
            } label: {
                Text("Bitir")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.horizontal, 8)
                    .frame(height: 44)
            }
            .buttonStyle(.glass)
        }
        .foregroundStyle(Ink.primary)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

// MARK: - Hareket şeridi (ilerleme)

struct ExerciseStrip: View {
    var workout: Workout
    var current: Int?
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                ForEach(Array(workout.exercises.enumerated()), id: \.offset) { i, ex in
                    Capsule()
                        .fill(segmentColor(ex, i))
                        .frame(height: i == current ? 8 : 6)
                }
            }
            .frame(height: 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hareket listesi")
    }

    private func segmentColor(_ ex: ExerciseEntry, _ i: Int) -> Color {
        if ex.isComplete { return workout.plate.color }
        if i == current { return workout.plate.color.opacity(0.45) }
        return Ink.line
    }
}

// MARK: - Sıradaki set

struct SetScreen: View {
    @EnvironmentObject var engine: WorkoutEngine
    var workout: Workout
    var ref: SetRef

    private enum Field {
        case kg, reps
    }
    @State private var editing: Field?
    @State private var entryText = ""
    @State private var editingSetIndex: Int?

    private var exercise: ExerciseEntry { workout.exercises[ref.ex] }
    private var entry: SetEntry { exercise.sets[ref.set] }
    private var def: ExerciseDef? { engine.exerciseDef(in: workout, at: ref.ex) }
    private var step: Double { def?.step ?? 2.5 }
    private var plate: Plate { workout.plate }
    private var range: ClosedRange<Int>? {
        switch entry.kind {
        case .top: return def?.kind.topRange
        case .backoff: return def?.kind.backoffRange
        case .warmup: return nil
        }
    }
    private var last: (set: SetEntry, date: Date)? {
        engine.lastTop(exercise.liftKey, before: workout.startedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 18)
            SetPills(exercise: exercise,
                     current: ref.set,
                     plate: plate,
                     onSelect: { idx in
                         guard idx != ref.set else { return }
                         Feedback.tap()
                         editingSetIndex = idx
                     },
                     onAddSet: {
                         withAnimation(.snappy) {
                             engine.addExtraSet(toExercise: ref.ex)
                         }
                     })
                .padding(.top, 14)
            Spacer(minLength: 12)
            target
            Spacer(minLength: 12)
            actions
        }
        .padding(.horizontal, 20)
        .alert(alertTitle, isPresented: editingBinding) {
            TextField(alertTitle, text: $entryText)
                .keyboardType(editing == .kg ? .decimalPad : .numberPad)
            Button("Tamam") { applyEntry() }
            Button("Vazgeç", role: .cancel) {}
        }
        .sheet(isPresented: editSetSheetBinding) {
            if let si = editingSetIndex, exercise.sets.indices.contains(si) {
                ActiveSetEditSheet(
                    exerciseName: exercise.name,
                    set: exercise.sets[si],
                    step: step,
                    canDelete: exercise.sets[si].kind == .backoff && exercise.workSets > 1,
                    onSave: { kg, reps in
                        engine.updateSet(SetRef(ex: ref.ex, set: si), kg: kg, reps: reps)
                    },
                    onReopen: {
                        engine.reopenSet(SetRef(ex: ref.ex, set: si))
                    },
                    onDelete: {
                        engine.removeSet(SetRef(ex: ref.ex, set: si))
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    private var editSetSheetBinding: Binding<Bool> {
        Binding(get: { editingSetIndex != nil }, set: { if !$0 { editingSetIndex = nil } })
    }

    private var alertTitle: String {
        editing == .kg ? "Kilo (kg)" : "Tekrar"
    }

    private var editingBinding: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Hareket \(ref.ex + 1)/\(workout.exercises.count)")
            Text(exercise.name)
                .font(.system(size: 34, weight: .heavy))
                .fontWidth(.expanded)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            if let note = def?.note {
                Text(note)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Ink.secondary)
            }
        }
    }

    private var targetTitle: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.kind.title.uppercased(with: Fmt.tr))
                .font(.system(size: 15, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(plate.color)
            if let r = range {
                Text("· \(r.lowerBound)–\(r.upperBound) tekrar")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
            }
            Spacer()
            if let l = last {
                Text("Geçen: \(Fmt.kg(l.set.kg))×\(l.set.reps)")
                    .font(PFont.number(14, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
            }
        }
    }

    private var increased: Bool {
        guard entry.kind == .top, let r = range, let l = last else { return false }
        return l.set.reps >= r.upperBound
    }

    private var target: some View {
        let kg = entry.kg
        let reps = entry.reps
        return VStack(alignment: .leading, spacing: 12) {
            targetTitle
            HStack(spacing: 10) {
                ValueDial(title: "KG", value: Fmt.kg(kg),
                          onMinus: { engine.setValue(ref, kg: max(0, kg - step)) },
                          onPlus: { engine.setValue(ref, kg: kg + step) },
                          onTap: { entryText = Fmt.kg(kg); editing = .kg })
                ValueDial(title: "TEKRAR", value: "\(reps)",
                          onMinus: { engine.setValue(ref, reps: max(0, reps - 1)) },
                          onPlus: { engine.setValue(ref, reps: reps + 1) },
                          onTap: { entryText = "\(reps)"; editing = .reps })
            }
            if increased {
                Label("Geçen sefer üst sınıra ulaştın, kilo artırıldı.", systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Ink.positive)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) { engine.completeCurrentSet() }
            } label: {
                Label("Seti bitir", systemImage: "checkmark")
            }
            .buttonStyle(BigButtonStyle(color: plate.color, foreground: plate.onColor, height: 70))

            HStack {
                Button("Bu seti atla") {
                    withAnimation(.snappy) { engine.skipCurrentSet() }
                }
                Spacer()
                if engine.lastCompleted != nil {
                    Button("Son seti geri al") {
                        withAnimation(.snappy) { engine.undoLast() }
                    }
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Ink.secondary)
            .padding(.top, 14)
            .padding(.bottom, 8)
        }
    }

    private func applyEntry() {
        guard let field = editing, let v = parseNumber(entryText) else { return }
        switch field {
        case .kg: engine.setValue(ref, kg: v)
        case .reps: engine.setValue(ref, reps: Int(v.rounded()))
        }
    }
}

/// Bu hareketin setleri: yapılanlar dolu (dokununca düzenlenir), sıradaki çerçeveli, sonda + Set
struct SetPills: View {
    var exercise: ExerciseEntry
    var current: Int
    var plate: Plate
    var onSelect: (Int) -> Void
    var onAddSet: () -> Void

    private var hasMultipleBackoffs: Bool {
        exercise.sets.filter { $0.kind == .backoff }.count > 1
    }

    private func label(for index: Int, _ s: SetEntry) -> String {
        if s.done { return "\(Fmt.kg(s.kg))×\(s.reps)" }
        if s.skipped == true { return "atlandı" }
        if s.kind == .backoff && hasMultipleBackoffs {
            let n = exercise.sets[0...index].filter { $0.kind == .backoff }.count
            return "Back-off \(n)"
        }
        return s.kind.title
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { i, s in
                    Button {
                        onSelect(i)
                    } label: {
                        pill(s, title: label(for: i, s), isCurrent: i == current)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onAddSet) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .heavy))
                        Text("Set").font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .foregroundStyle(Ink.secondary)
                    .background(Ink.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Ink.line, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ekstra set ekle")
            }
        }
    }

    @ViewBuilder
    private func pill(_ s: SetEntry, title: String, isCurrent: Bool) -> some View {
        HStack(spacing: 4) {
            if s.done { Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)) }
            Text(title).font(.system(size: 13, weight: .bold)).lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .foregroundStyle(s.done ? plate.onColor : (isCurrent ? plate.color : Ink.secondary))
        .background(s.done ? plate.color : Ink.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(isCurrent ? plate.color : Ink.line, lineWidth: isCurrent ? 2 : 0.5))
        .opacity(s.skipped == true ? 0.5 : 1)
    }
}

struct ActiveSetEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String
    let set: SetEntry
    let step: Double
    let canDelete: Bool
    let onSave: (Double, Int) -> Void
    let onReopen: () -> Void
    let onDelete: () -> Void

    @State private var kgText: String = ""
    @State private var reps: Int = 8

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

                if set.done || set.skipped == true {
                    Section {
                        Button("Seti tekrar aç") {
                            onReopen()
                            dismiss()
                        }
                    }
                }

                if canDelete {
                    Section {
                        Button("Bu seti sil", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Seti düzenle")
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

// MARK: - Dinlenme

struct RestScreen: View {
    @EnvironmentObject var engine: WorkoutEngine
    var rest: WorkoutEngine.RestInfo
    var workout: Workout

    var body: some View {
        let plate = workout.plate
        VStack(spacing: 0) {
            Spacer(minLength: 10)
            Eyebrow(text: "Dinlenme", color: plate.color)
            TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                let left = max(0, rest.end.timeIntervalSince(ctx.date))
                ZStack {
                    RingView(progress: left / rest.total, color: plate.color, lineWidth: 18)
                    VStack(spacing: 2) {
                        Text(Fmt.clock(Int(left.rounded(.up))))
                            .font(PFont.number(76, weight: .heavy))
                            .foregroundStyle(Ink.primary)
                            .contentTransition(.numericText(countsDown: true))
                        Text("toplam \(Fmt.clock(Int(rest.total.rounded())))")
                            .font(PFont.number(14, weight: .semibold))
                            .foregroundStyle(Ink.secondary)
                    }
                }
                .frame(width: 270, height: 270)
            }
            .padding(.top, 14)

            HStack(spacing: 10) {
                Button("−15") { Feedback.tap(); engine.adjustRest(-15) }
                    .buttonStyle(SoftButtonStyle())
                Button("Atla") { Feedback.tap(); withAnimation(.snappy) { engine.skipRest() } }
                    .buttonStyle(SoftButtonStyle())
                Button("+15") { Feedback.tap(); engine.adjustRest(15) }
                    .buttonStyle(SoftButtonStyle())
            }
            .font(PFont.number(17, weight: .bold))
            .padding(.top, 24)

            Spacer(minLength: 16)

            if let c = engine.cursor {
                NextSetCard(workout: workout, ref: c)
            }

            if engine.lastCompleted != nil {
                Button("Son seti geri al") {
                    withAnimation(.snappy) { engine.undoLast() }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Ink.secondary)
                .padding(.top, 12)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 20)
    }
}

/// Dinlenirken sıradaki seti gör ve gerekirse kiloyu/tekrarı değiştir
struct NextSetCard: View {
    @EnvironmentObject var engine: WorkoutEngine
    var workout: Workout
    var ref: SetRef

    var body: some View {
        let ex = workout.exercises[ref.ex]
        let entry = ex.sets[ref.set]
        let step = engine.exerciseDef(in: workout, at: ref.ex)?.step ?? 2.5
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Sıradaki")
            HStack(alignment: .firstTextBaseline) {
                Text(ex.name).font(.system(size: 19, weight: .heavy)).lineLimit(1)
                Spacer()
                Text(entry.kind.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(workout.plate.color)
            }
            HStack(spacing: 10) {
                MiniStepper(value: Fmt.kg(entry.kg), unit: "kg",
                            onMinus: { engine.setValue(ref, kg: max(0, entry.kg - step)) },
                            onPlus: { engine.setValue(ref, kg: entry.kg + step) })
                MiniStepper(value: "\(entry.reps)", unit: "tekrar",
                            onMinus: { engine.setValue(ref, reps: max(0, entry.reps - 1)) },
                            onPlus: { engine.setValue(ref, reps: entry.reps + 1) })
            }
        }
        .card(padding: 16)
    }
}

// MARK: - Kardiyo

struct CardioScreen: View {
    @EnvironmentObject var engine: WorkoutEngine
    var workout: Workout
    var onFinish: () -> Void

    @State private var kind: CardioKind = .treadmill
    @State private var treadmillMinutes = 15
    @State private var incline = 12.0
    @State private var speed = 4.2
    @State private var bikeMinutes = 15
    @State private var resistance = 8
    @State private var loaded = false

    private var activeMinutes: Int {
        kind == .treadmill ? treadmillMinutes : bikeMinutes
    }

    private var subtitle: String {
        if workout.cardio.done {
            return "\(workout.doneSetCount) set ve \(workout.cardio.summaryText). Kaydedip bitirebilirsin."
        }
        switch kind {
        case .treadmill:
            return "Koşu bandında eğimli yürüyüş. Tutunma, tempoyu koru."
        case .bike:
            return "Kondisyon bisikleti. Sabit tempoyla sür."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: workout.cardio.done ? "Antrenman tamam" : "Setler bitti", color: workout.plate.color)
                Text(workout.cardio.done ? "Eline sağlık" : "Kardiyo")
                    .font(.system(size: 40, weight: .heavy))
                    .fontWidth(.expanded)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Ink.secondary)
            }
            .padding(.top, 20)

            Spacer(minLength: 16)

            if !workout.cardio.done {
                VStack(spacing: 14) {
                    cardioKindPicker
                    VStack(spacing: 12) {
                        cardioRow("Süre", value: "\(activeMinutes) dk",
                                  minus: {
                                      if kind == .treadmill {
                                          treadmillMinutes = max(5, treadmillMinutes - 1)
                                      } else {
                                          bikeMinutes = max(5, bikeMinutes - 1)
                                      }
                                  },
                                  plus: {
                                      if kind == .treadmill {
                                          treadmillMinutes = min(60, treadmillMinutes + 1)
                                      } else {
                                          bikeMinutes = min(60, bikeMinutes + 1)
                                      }
                                  })
                        if kind == .treadmill {
                            cardioRow("Eğim", value: "%\(Fmt.kg(incline))",
                                      minus: { incline = max(0, incline - 1) },
                                      plus: { incline = min(20, incline + 1) })
                            cardioRow("Hız", value: "\(Fmt.kg(speed)) km/s",
                                      minus: { speed = max(2, (speed * 10 - 1).rounded() / 10) },
                                      plus: { speed = min(12, (speed * 10 + 1).rounded() / 10) })
                        } else {
                            cardioRow("Seviye", value: "\(resistance)",
                                      minus: { resistance = max(1, resistance - 1) },
                                      plus: { resistance = min(25, resistance + 1) })
                        }
                    }
                    .card(padding: 16)
                }
            }

            Spacer(minLength: 16)

            if workout.cardio.done {
                Button {
                    engine.finish()
                } label: {
                    Label("Kaydet ve bitir", systemImage: "checkmark")
                }
                .buttonStyle(BigButtonStyle(color: workout.plate.color, foreground: workout.plate.onColor, height: 70))
            } else {
                Button {
                    engine.startCardio(kind: kind, minutes: activeMinutes, incline: incline, speed: speed, resistance: resistance)
                } label: {
                    Label("Kardiyoyu başlat", systemImage: kind.icon)
                }
                .buttonStyle(BigButtonStyle(color: workout.plate.color, foreground: workout.plate.onColor, height: 70))
                Button("Kardiyo yapmadan bitir", action: onFinish)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let defaults = engine.data.settings.cardioDefaults
            kind = defaults.kind
            treadmillMinutes = max(5, defaults.treadmillMinutes)
            incline = defaults.incline
            speed = defaults.speed
            bikeMinutes = max(5, defaults.bikeMinutes)
            resistance = defaults.resistance
        }
    }

    private var cardioKindPicker: some View {
        HStack(spacing: 8) {
            ForEach(CardioKind.allCases, id: \.self) { option in
                let selected = kind == option
                Button {
                    Feedback.tap()
                    withAnimation(.snappy(duration: 0.2)) { kind = option }
                } label: {
                    Label(option.title, systemImage: option.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(selected ? workout.plate.onColor : Ink.primary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(selected ? workout.plate.color : Ink.surface,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Ink.line, lineWidth: selected ? 0 : 0.5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cardioRow(_ title: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Ink.secondary)
            Spacer()
            Button { Feedback.tap(); minus() } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Ink.surface2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
            Text(value)
                .font(PFont.number(20, weight: .heavy))
                .frame(minWidth: 96)
                .multilineTextAlignment(.center)
            Button { Feedback.tap(); plus() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Ink.surface2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
        }
        .foregroundStyle(Ink.primary)
    }
}

struct CardioRunningScreen: View {
    @EnvironmentObject var engine: WorkoutEngine
    var rest: WorkoutEngine.RestInfo
    var workout: Workout

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 10)
            Eyebrow(text: workout.cardio.kind.title, color: workout.plate.color)
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                let left = max(0, rest.end.timeIntervalSince(ctx.date))
                ZStack {
                    RingView(progress: 1 - left / rest.total, color: workout.plate.color, lineWidth: 18)
                    VStack(spacing: 2) {
                        Text(Fmt.clock(Int(left.rounded(.up))))
                            .font(PFont.number(70, weight: .heavy))
                        Text(workout.cardio.detailText)
                            .font(PFont.number(15, weight: .semibold))
                            .foregroundStyle(Ink.secondary)
                    }
                }
                .frame(width: 270, height: 270)
            }
            .padding(.top, 14)
            Text("Telefonu kilitleyebilirsin. Süre bitince uyaracak.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Ink.secondary)
                .padding(.top, 20)
            Spacer()
            Button {
                engine.skipRest()
            } label: {
                Label("Kardiyoyu şimdi bitir", systemImage: "stop.fill")
            }
            .buttonStyle(SoftButtonStyle(height: 60))
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Hareket listesi (başka harekete geçmek için)

struct ExerciseListSheet: View {
    @EnvironmentObject var engine: WorkoutEngine
    @Environment(\.dismiss) private var dismiss

    private func summary(_ ex: ExerciseEntry) -> String {
        let done = ex.sets.filter(\.done).map { "\(Fmt.kg($0.kg))×\($0.reps)" }
        return done.isEmpty ? "\(ex.workSets) set" : done.joined(separator: "  ·  ")
    }

    var body: some View {
        NavigationStack {
            List {
                if let w = engine.data.active {
                    let current = engine.cursor?.ex
                    Section {
                        ForEach(Array(w.exercises.enumerated()), id: \.offset) { i, ex in
                            Button {
                                engine.focus(i)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(ex.isComplete ? w.plate.color : Ink.surface2)
                                        if ex.isComplete {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .heavy))
                                                .foregroundStyle(w.plate.onColor)
                                        } else {
                                            Text("\(i + 1)").font(PFont.number(13, weight: .bold))
                                        }
                                    }
                                    .frame(width: 30, height: 30)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.name).font(.system(size: 16, weight: .bold))
                                        Text(summary(ex))
                                            .font(PFont.number(13, weight: .medium))
                                            .foregroundStyle(Ink.secondary)
                                    }
                                    Spacer()
                                    if i == current {
                                        Text("Şimdi")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(w.plate.color)
                                    }
                                }
                                .foregroundStyle(Ink.primary)
                            }
                        }
                    } footer: {
                        Text("Makine doluysa başka bir harekete dokun, sıra oradan devam eder.")
                    }
                }
            }
            .navigationTitle("Hareketler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}
