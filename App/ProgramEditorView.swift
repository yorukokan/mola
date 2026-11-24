import SwiftUI

struct ProgramEditorView: View {
    @EnvironmentObject var engine: WorkoutEngine
    @State private var confirmReset = false

    var body: some View {
        List {
            Section {
                ForEach(engine.routines) { routine in
                    NavigationLink {
                        RoutineEditorView(routineId: routine.id)
                    } label: {
                        HStack(spacing: 12) {
                            PlateDot(plate: routine.plate, size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(routine.name)
                                    .font(.system(size: 16, weight: .bold))
                                let totalSets = routine.exercises.reduce(0) { $0 + $1.workSetCount }
                                Text("\(routine.dayLabel) · \(routine.exercises.count) hareket · \(totalSets) çalışma seti")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Ink.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } footer: {
                Text("Yaptığın değişiklikler yeni antrenmanlara ve widget'lara hemen yansır. Eski antrenman kayıtların etkilenmez.")
            }

            if engine.hasCustomRoutines {
                Section {
                    Button("Varsayılan programa sıfırla", role: .destructive) {
                        confirmReset = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Ink.canvas.ignoresSafeArea())
        .navigationTitle("Programı düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Varsayılan programa dönülsün mü?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Sıfırla", role: .destructive) {
                engine.resetRoutinesToDefault()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Rutinlerde yaptığın özel değişiklikler kaldırılır, geçmiş kayıtların korunur.")
        }
    }
}

struct RoutineEditorView: View {
    @EnvironmentObject var engine: WorkoutEngine
    let routineId: String

    @State private var editingExercise: ExerciseDef?
    @State private var addingNew = false

    private var routineIndex: Int? {
        engine.routines.firstIndex { $0.id == routineId }
    }

    private var routine: RoutineDef? {
        guard let idx = routineIndex else { return nil }
        return engine.routines[idx]
    }

    var body: some View {
        List {
            if let r = routine {
                Section {
                    ForEach(r.exercises) { ex in
                        Button {
                            editingExercise = ex
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(ex.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Ink.primary)
                                    Text("\(ex.workSetCount) set · \(ex.kind.repSummary) · \(Fmt.clock(ex.rest)) dinlenme · +\(Fmt.kg(ex.step)) kg")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Ink.secondary)
                                    if let note = ex.note, !note.isEmpty {
                                        Text(note)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Ink.tertiary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Ink.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                } footer: {
                    Text("Sıralamayı değiştirmek için Düzenle'ye basıp sürükle, silmek için sola kaydır.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Ink.canvas.ignoresSafeArea())
        .navigationTitle(routine?.name ?? "Rutin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button {
                    addingNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingExercise) { ex in
            ExerciseFormSheet(existing: ex) { updated in
                saveExercise(updated)
            }
        }
        .sheet(isPresented: $addingNew) {
            ExerciseFormSheet(existing: nil) { created in
                addExercise(created)
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        guard let idx = routineIndex else { return }
        var all = engine.routines
        all[idx].exercises.move(fromOffsets: source, toOffset: destination)
        engine.saveRoutines(all)
    }

    private func delete(at offsets: IndexSet) {
        guard let idx = routineIndex else { return }
        var all = engine.routines
        all[idx].exercises.remove(atOffsets: offsets)
        engine.saveRoutines(all)
    }

    private func saveExercise(_ updated: ExerciseDef) {
        guard let idx = routineIndex else { return }
        var all = engine.routines
        if let ei = all[idx].exercises.firstIndex(where: { $0.id == updated.id }) {
            all[idx].exercises[ei] = updated
            engine.saveRoutines(all)
        }
    }

    private func addExercise(_ created: ExerciseDef) {
        guard let idx = routineIndex else { return }
        var all = engine.routines
        // Aynı isimde mevcut bir hareket varsa aynı liftKey'i paylaşsın
        var ex = created
        let normalized = ex.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let match = all.flatMap(\.exercises).first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }) {
            ex.liftKey = match.liftKey
        }
        all[idx].exercises.append(ex)
        engine.saveRoutines(all)
    }
}

private struct ExerciseFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let existing: ExerciseDef?
    let onSave: (ExerciseDef) -> Void

    @State private var name: String = ""
    @State private var kind: ExerciseKind = .iso
    @State private var workSets: Int = 2
    @State private var rest: Int = 90
    @State private var step: Double = 2.5
    @State private var note: String = ""

    private let stepOptions: [Double] = [0.5, 1, 2.5, 5]

    var body: some View {
        NavigationStack {
            Form {
                Section("Hareket") {
                    TextField("Hareket adı", text: $name)
                    Picker("Tür", selection: $kind) {
                        ForEach(ExerciseKind.allCases, id: \.self) { k in
                            Text(k.title).tag(k)
                        }
                    }
                    TextField("Not (opsiyonel)", text: $note)
                }

                Section("Set ve Dinlenme") {
                    Stepper("Çalışma seti: \(workSets)", value: $workSets, in: 2...5)
                    Stepper("Dinlenme: \(Fmt.clock(rest))", value: $rest, in: 30...240, step: 15)
                    Picker("Kilo artış adımı", selection: $step) {
                        ForEach(stepOptions, id: \.self) { s in
                            Text("\(Fmt.kg(s)) kg").tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(existing == nil ? "Yeni hareket" : "Hareketi düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        let id = existing?.id ?? "custom-\(UUID().uuidString.prefix(8))"
                        let liftKey = existing?.liftKey ?? "custom-\(UUID().uuidString.prefix(8))"
                        let def = ExerciseDef(
                            id: id,
                            name: trimmed,
                            kind: kind,
                            rest: rest,
                            step: step,
                            liftKey: liftKey,
                            note: cleanNote.isEmpty ? nil : cleanNote,
                            backoffSets: max(1, workSets - 1)
                        )
                        onSave(def)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let e = existing {
                    name = e.name
                    kind = e.kind
                    workSets = max(2, e.workSetCount)
                    rest = e.rest
                    step = stepOptions.contains(e.step) ? e.step : 2.5
                    note = e.note ?? ""
                }
            }
        }
    }
}
