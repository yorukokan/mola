import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

struct MolaBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsView: View {
    @EnvironmentObject var engine: WorkoutEngine
    @Environment(\.openURL) private var openURL
    @State private var copiedRange: WorkoutEngine.ExportRange?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var panelEnabled = true
    @State private var panelError: String?

    @State private var showExporter = false
    @State private var exportDoc = MolaBackupDocument(data: Data())
    @State private var showImporter = false
    @State private var pendingRestoreData: Data?
    @State private var pendingRestoreCount = 0
    @State private var confirmRestore = false
    @State private var backupMessage: String?

    private var backupFilename: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "mola-yedek-\(f.string(from: Date()))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Program") {
                    NavigationLink {
                        ProgramEditorView()
                    } label: {
                        Label("Programı düzenle", systemImage: "list.bullet.rectangle")
                    }
                }

                Section {
                    Toggle("Zil sesi", isOn: $engine.data.settings.sound)
                    Toggle("Son 3 saniye tıkları", isOn: $engine.data.settings.countdownTicks)
                        .disabled(!engine.data.settings.sound)
                    Toggle("Titreşim", isOn: $engine.data.settings.haptics)
                    Toggle("Kilitliyken de sayaç çalışsın", isOn: $engine.data.settings.backgroundTimer)
                } header: {
                    Text("Dinlenme uyarısı")
                } footer: {
                    Text("Zil müziğin üstüne çalar, YouTube Music durmaz. Son seçenek açıkken uygulama antrenman boyunca arkada sessizce çalışır; böylece telefon cebindeyken de zil, titreşim ve kilit ekranı sayacı tam zamanında gelir.")
                }

                Section {
                    statusRow("Bildirim izni", ok: notificationStatus == .authorized || notificationStatus == .provisional,
                              okText: "Açık",
                              badText: notificationStatus == .notDetermined ? "Sorulmadı" : "Kapalı")
                    statusRow("Kilit ekranı paneli", ok: panelEnabled, okText: "Açık", badText: "Kapalı")
                    if let panelError {
                        Text(panelError)
                            .font(.system(size: 13))
                            .foregroundStyle(Plate.red.color)
                    }
                    if notificationStatus == .notDetermined {
                        Button("Bildirim izni ver") {
                            Notifier.requestAuthorization()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { refresh() }
                        }
                    } else if notificationStatus == .denied || !panelEnabled {
                        Button("iPhone Ayarları'nı aç") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                    Button {
                        engine.startTestRest()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { refresh() }
                    } label: {
                        Label(engine.testRest != nil ? "Deneme sürüyor: telefonu kilitle" : "10 saniyelik deneme dinlenmesi",
                              systemImage: "timer")
                    }
                    .disabled(engine.data.active != nil || engine.testRest != nil)
                } header: {
                    Text("Kontrol")
                } footer: {
                    Text("Denemeyi başlat, telefonu kilitle. 10 saniye sonra ekran yanmalı, zil çalmalı ve titremeli. Kilit ekranında geri sayım görünmeli.")
                }

                Section("Görünüm") {
                    Picker("Tema", selection: $engine.data.settings.appearance) {
                        ForEach(Appearance.allCases, id: \.self) { a in
                            Text(a.title).tag(a)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Antrenmanda ekran açık kalsın", isOn: $engine.data.settings.keepAwake)
                }

                Section {
                    ForEach(WorkoutEngine.ExportRange.allCases, id: \.self) { range in
                        let count = engine.workouts(in: range).count
                        Button {
                            UIPasteboard.general.string = engine.exportText(range: range)
                            Feedback.tap()
                            copiedRange = range
                        } label: {
                            HStack {
                                Label(copiedRange == range ? "Kopyalandı" : "\(range.title) özetini kopyala",
                                      systemImage: copiedRange == range ? "checkmark" : "doc.on.doc")
                                Spacer()
                                Text("\(count)")
                                    .font(PFont.number(14, weight: .semibold))
                                    .foregroundStyle(Ink.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Yapay zeka için özet")
                } footer: {
                    Text("Haftalık, aylık ya da tüm antrenman özetini kopyalayıp yapay zekaya yapıştırabilirsin.")
                }

                Section {
                    Button {
                        if let raw = engine.backupData() {
                            exportDoc = MolaBackupDocument(data: raw)
                            showExporter = true
                        }
                    } label: {
                        Label("JSON yedeğini kaydet", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showImporter = true
                    } label: {
                        Label("Yedekten geri yükle", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Yedekleme")
                } footer: {
                    Text("Kayıtlar sadece bu telefonda saklanır. Dosyalar veya iCloud Drive'a yedekleyip istediğin zaman geri yükleyebilirsin.")
                }

                Section("Hakkında") {
                    LabeledContent("Program", value: engine.hasCustomRoutines ? "Özel 4 gün Upper / Lower" : "4 gün Upper / Lower")
                    LabeledContent("Sürüm", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Ink.canvas.ignoresSafeArea())
            .navigationTitle("Ayarlar")
            .onAppear { refresh() }
            .onChange(of: engine.data.settings.backgroundTimer) { _, _ in
                engine.applyBackgroundSetting()
            }
            .onChange(of: engine.data.settings.keepAwake) { _, _ in
                engine.applyIdleTimer()
            }
            .fileExporter(isPresented: $showExporter,
                          document: exportDoc,
                          contentType: .json,
                          defaultFilename: backupFilename) { result in
                switch result {
                case .success:
                    backupMessage = "Yedek dosyası kaydedildi."
                case .failure(let err):
                    backupMessage = "Yedek kaydedilemedi: \(err.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard let raw = try? Data(contentsOf: url),
                          let decoded = try? SharedStore.decoder.decode(AppData.self, from: raw) else {
                        backupMessage = "Seçilen dosya geçerli bir Mola yedeği değil."
                        return
                    }
                    pendingRestoreData = raw
                    pendingRestoreCount = Planner.finished(decoded.history).count
                    confirmRestore = true
                case .failure(let err):
                    backupMessage = "Dosya açılamadı: \(err.localizedDescription)"
                }
            }
            .confirmationDialog("Yedekten geri yüklensin mi?", isPresented: $confirmRestore, titleVisibility: .visible) {
                Button("Geri yükle (\(pendingRestoreCount) antrenman)", role: .destructive) {
                    guard let raw = pendingRestoreData else { return }
                    do {
                        let count = try engine.restoreBackup(from: raw)
                        backupMessage = "\(count) antrenman kaydı geri yüklendi."
                    } catch {
                        backupMessage = error.localizedDescription
                    }
                    pendingRestoreData = nil
                }
                Button("Vazgeç", role: .cancel) {
                    pendingRestoreData = nil
                }
            } message: {
                Text("Mevcut kayıtların yerine yedekteki \(pendingRestoreCount) antrenman ve program ayarları yüklenecek.")
            }
            .alert("Yedekleme", isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(backupMessage ?? "")
            }
        }
    }

    private func refresh() {
        Notifier.status { notificationStatus = $0 }
        panelEnabled = LiveActivityManager.shared.enabled
        panelError = LiveActivityManager.shared.lastError
    }

    private func statusRow(_ title: String, ok: Bool, okText: String, badText: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Label(ok ? okText : badText, systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ok ? Ink.positive : Plate.red.color)
        }
    }
}
