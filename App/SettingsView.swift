import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var engine: WorkoutEngine
    @Environment(\.openURL) private var openURL
    @State private var copiedAll = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var panelEnabled = true
    @State private var panelError: String?

    var body: some View {
        NavigationStack {
            Form {
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
                    Button(copiedAll ? "Kopyalandı" : "Tüm geçmişi kopyala") {
                        UIPasteboard.general.string = engine.exportAll()
                        copiedAll = true
                    }
                } header: {
                    Text("Kayıtlar")
                } footer: {
                    Text("Kayıtlar sadece bu telefonda saklanır. Claude'a göndermek için kopyalayıp sohbete yapıştır.")
                }

                Section("Hakkında") {
                    LabeledContent("Program", value: "4 gün Upper / Lower")
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
