<div align="center">

<!-- Header Banner -->
<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0C0E11,45:171A1F,78:3D6FE6,100:E5484D&height=210&section=header&text=MOLA&fontSize=64&fontColor=F2F4F7&fontAlignY=38&desc=iOS%20Strength%20Training%20%E2%80%A2%20Rest%20Timer%20%C2%B7%20Antrenman%20ve%20Dinlenme%20Sayac%C4%B1&descSize=16&descAlignY=62&animation=fadeIn" width="100%" alt="Mola Banner" />

<!-- Animated Feature Taglines -->
<p>
  <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=18&duration=2600&pause=900&color=E5484D&center=true&vCenter=true&width=780&lines=Native+SwiftUI+iOS+Workout+Tracker+%E2%80%94+Zero+Third-Party+Dependencies;Live+Activities+%C2%B7+Dynamic+Island+%C2%B7+Interactive+Lock+%26+Home+Widgets;Background+Rest+Timer+with+Non-Interrupting+Audio+%26+Haptics;Double+Progression+Engine+%C2%B7+4-Day+Upper+%2F+Lower+%C2%B7+Swift+Charts" alt="Mola Feature Typing Animation" />
</p>

<!-- Quick Action Pills -->
<p>
  <img src="https://img.shields.io/badge/iOS%2026%2B-SwiftUI-000000?style=for-the-badge&logo=apple&logoColor=white&labelColor=0B0F19" alt="iOS 26+ SwiftUI" />
  <img src="https://img.shields.io/badge/WidgetKit-Live%20Activities-E5484D?style=for-the-badge&logo=swift&logoColor=white&labelColor=0B0F19" alt="WidgetKit & Live Activities" />
  <a href="https://github.com/yorukokan">
    <img src="https://img.shields.io/badge/GitHub-yorukokan-181717?style=for-the-badge&logo=github&logoColor=white&labelColor=0B0F19" alt="GitHub" />
  </a>
  <a href="https://linkedin.com/in/okanyoruk">
    <img src="https://img.shields.io/badge/LinkedIn-okanyoruk-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white&labelColor=0B0F19" alt="LinkedIn" />
  </a>
  <a href="mailto:okanyoruk.tr@gmail.com">
    <img src="https://img.shields.io/badge/Email-Contact-2E9E6A?style=for-the-badge&logo=gmail&logoColor=white&labelColor=0B0F19" alt="Email" />
  </a>
</p>

</div>

---

## 🎯 Overview · Proje Özeti

<table>
<tr>
<td width="50%" valign="top">

<h3>🇬🇧 English</h3>

**Mola** (`v2.0`) is a native, offline-first **iOS 26+ strength training & rest timer** built purely with **SwiftUI** and Apple system frameworks — **zero third-party dependencies**.

Designed around a focused, one-thing-at-a-time gym workflow, Mola guides every set from warm-up to top set, back-off sets, rest countdown, and post-lift cardio. Olympic bumper plate colors (`Red 25 kg`, `Blue 20 kg`, `Yellow 15 kg`, `Green 10 kg`) visually anchor the built-in **4-day Upper / Lower** split.

Thanks to **ActivityKit**, **WidgetKit**, **App Intents**, and a **mix-with-others AVAudioSession**, you can complete sets, adjust rest (`-15s` / `Skip` / `+15s`), and receive lock-screen wake alerts & chimes **without pausing your music** or unlocking your iPhone.

</td>
<td width="50%" valign="top">

<h3>🇹🇷 Türkçe</h3>

**Mola** (`v2.0`), **sıfır harici bağımlılık** ile yalnızca **SwiftUI** ve yerleşik Apple framework'leri kullanılarak geliştirilmiş, çevrimdışı çalışan yerel bir **iOS 26+ ağırlık antrenmanı ve dinlenme sayacı** uygulamasıdır.

Salonda tek bir şeye odaklanan sade bir akışla tasarlanan Mola; ısınma, top set, back-off setleri, dinlenme geri sayımı ve antrenman sonu kardiyoyu adım adım yönetir. Olimpik bumper plaka renkleri (`Kırmızı 25 kg`, `Mavi 20 kg`, `Sarı 15 kg`, `Yeşil 10 kg`), yerleşik **4 günlük Upper / Lower** programına görsel kimlik kazandırır.

**ActivityKit**, **WidgetKit**, **App Intents** ve müziği kesmeyen **AVAudioSession** mimarisi sayesinde; **müziğin durmadan** ve telefonun kilidini açmadan set bitirebilir, dinlenmeyi ayarlayabilir (`-15` / `Atla` / `+15`) ve süre dolduğunda ekran uyanması, zil ve titreşim uyarısı alabilirsin.

</td>
</tr>
</table>

---

## ✨ Key Features · Öne Çıkan Özellikler

<table>
<tr>
<td width="50%" valign="top">

<h4>📈 Double Progression Engine · Çift Progresyon Motoru</h4>
<b>EN:</b> Automatically tracks your previous top set per <code>liftKey</code> across routines, suggests a weight bump when you hit the upper rep range (or +1 rep otherwise), and scales warm-up (50%) and back-off (90%) loads to the exercise's rounding step.<br/><br/>
<b>TR:</b> Her hareketin son top setini <code>liftKey</code> üzerinden takip eder; tekrar aralığının üst sınırına ulaştığında kiloyu bir adım artırır (aksi hâlde +1 tekrar önerir), ısınma (%50) ve back-off (%90) ağırlıklarını otomatik yuvarlar.<br/><br/>
<code>Planner.swift</code> <code>Models.swift</code> <code>Program.swift</code>

</td>
<td width="50%" valign="top">

<h4>🏝️ Live Activities & Interactive Widgets · Canlı Etkinlikler</h4>
<b>EN:</b> Full Lock Screen panel, Dynamic Island (expanded, compact, minimal), and 5 widget families (Small, Medium, Lock Screen Rectangular, Circular, Inline). Interactive <code>LiveActivityIntent</code> buttons let you finish sets or tweak rest right from the widget.<br/><br/>
<b>TR:</b> Kilit Ekranı paneli, Dynamic Island (geniş, kompakt, minimal) ve 5 farklı widget boyutu sunar. Etkileşimli <code>LiveActivityIntent</code> butonlarıyla uygulamayı açmadan set bitirip dinlenme süresini (<code>-15</code> / <code>Atla</code> / <code>+15</code>) yönetebilirsin.<br/><br/>
<code>MolaWidgets.swift</code> <code>LiveActivity.swift</code> <code>Intents.swift</code>

</td>
</tr>
<tr>
<td width="50%" valign="top">

<h4>🔔 Non-Interrupting Background Audio · Kesintisiz Sayaç & Ses</h4>
<b>EN:</b> Uses <code>AVAudioSession</code> with <code>.playback</code> + <code>.mixWithOthers</code> and a silent keep-alive loop so your music (YouTube Music, Spotify, etc.) never pauses. Synthesizes PCM WAV countdown ticks (last 3s), plays <code>mola-chime.wav</code>, triggers dual haptics/vibration, and arms a fallback local notification.<br/><br/>
<b>TR:</b> <code>.mixWithOthers</code> ses oturumu ve sessiz arka plan döngüsüyle müziği durdurmadan kilit ekranında bile tam zamanında çalışır. Son 3 saniye tıklarını programatik WAV olarak üretir, <code>mola-chime.wav</code> zili + çift titreşim verir ve yedek yerel bildirim kurar.<br/><br/>
<code>Audio.swift</code> <code>Engine.swift</code>

</td>
<td width="50%" valign="top">

<h4>🏋️ Focused Gym Flow & Cardio · Odaklı Antrenman & Kardiyo</h4>
<b>EN:</b> Full-screen distraction-free workout flow with custom value dials, repeat-press steppers, undo last set, add/remove extra sets, exercise jumping, and built-in Treadmill (incline/speed) & Bike (resistance) cardio timer that remembers your last settings.<br/><br/>
<b>TR:</b> Dikkat dağıtmayan tam ekran akış; büyük rakam kadranları, son seti geri alma, ekstra set ekleme/silme, hareketler arası geçiş ve son ayarlarını hatırlayan Koşu Bandı (eğim/hız) ile Bisiklet (seviye) kardiyo sayacı.<br/><br/>
<code>WorkoutView.swift</code> <code>Components.swift</code> <code>SummaryView.swift</code>

</td>
</tr>
<tr>
<td width="50%" valign="top">

<h4>🧩 Custom Program Editor · Özelleştirilebilir Program</h4>
<b>EN:</b> Ships with a 4-day Upper/Lower split (<code>Üst A</code>, <code>Alt A</code>, <code>Üst B</code>, <code>Alt B</code>), and lets you add, edit, reorder, or delete exercises (kind, rest seconds, weight step, back-off set count, notes) or reset to defaults without touching past history.<br/><br/>
<b>TR:</b> Yerleşik 4 günlük Upper/Lower (<code>Üst A</code>, <code>Alt A</code>, <code>Üst B</code>, <code>Alt B</code>) programıyla gelir; hareket ekleme, düzenleme, sürükleyerek sıralama, silme ve geçmişi bozmadan varsayılana sıfırlama desteği sunar.<br/><br/>
<code>ProgramEditorView.swift</code> <code>Program.swift</code>

</td>
<td width="50%" valign="top">

<h4>📊 Swift Charts, AI Export & JSON Backup · Grafik & Yedekleme</h4>
<b>EN:</b> Visualizes per-lift top-set weight progression with <code>Swift Charts</code>, allows post-workout set editing, copies clean 7-day / 30-day / all-time summaries for AI coaching, and supports full atomic JSON backup & restore via Files / iCloud Drive.<br/><br/>
<b>TR:</b> <code>Swift Charts</code> ile hareket bazlı kilo ilerlemesini çizer, geçmiş setleri sonradan düzeltmeye izin verir; yapay zekâ takibi için son 7 gün / 30 gün / tüm geçmiş metin çıktısı ve Dosyalar / iCloud Drive üzerinden tam JSON yedekleme/geri yükleme sağlar.<br/><br/>
<code>HistoryView.swift</code> <code>SettingsView.swift</code> <code>SharedStore.swift</code>

</td>
</tr>
</table>

---

## 🏗️ Architecture & Data Flow · Mimari ve Veri Akışı

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                         Mola App Target (iOS 26+)                            │
│                                                                              │
│  MolaApp (@main) ──► RootView (Bugün · Geçmiş · Ayarlar)                     │
│     │                  ├─ HomeView / WorkoutView / SummaryView               │
│     │                  ├─ HistoryView (Swift Charts) / ProgramEditorView     │
│     │                  └─ SettingsView (JSON Backup · Diagnostics · 10s Test)│
│     │                                                                        │
│     ▼ (mola:// deep links & scenePhase)                                      │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                    WorkoutEngine.shared (Engine.swift)                 │  │
│  │  • Single Source of Truth (@Published AppData, 0.25s rest ticker)      │  │
│  │  • Progression & live state computation via Planner.swift              │  │
│  └───┬───────────────────────┬──────────────────────────┬─────────────────┘  │
│      │                       │                          │                    │
│      ▼                       ▼                          ▼                    │
│  Audio.swift            LiveActivity.swift        SharedStore.swift          │
│  • AudioEngine          • ActivityKit manager     • Atomic JSON I/O          │
│    (.mixWithOthers)     • Lock Screen & Island    • plaka-data.json          │
│  • Feedback (Haptics)   • Wake Alert + Chime      • plaka-data.backup.json   │
│  • Notifier (Fallback)                                  │                    │
└─────────────────────────────────────────────────────────┼────────────────────┘
                                                          │
                              App Group Container         │
                          (group.com.okan.plaka.app)      │
                                                          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                     MolaWidgets Extension Target                             │
│                                                                              │
│  MolaWidgetsBundle                                                           │
│   ├─ MolaWidget (Small · Medium · Accessory Rect / Circular / Inline)        │
│   └─ MolaLiveActivity (Lock Screen Panel · Dynamic Island)                   │
│                                                                              │
│  Interactive Buttons (Intents.swift · LiveActivityIntent)                    │
│   └─ CompleteSetIntent · AdjustRestIntent · SkipRestIntent ──► WorkoutEngine │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack · Teknoloji Yığını

<div align="center">

<!-- Verified directly from source imports & Mola.xcodeproj (Zero third-party packages) -->
<p>
  <img src="https://img.shields.io/badge/Swift-5-F05138?style=for-the-badge&logo=swift&logoColor=white&labelColor=0D1117" alt="Swift 5" />
  <img src="https://img.shields.io/badge/SwiftUI-iOS%2026%2B-007AFF?style=for-the-badge&logo=apple&logoColor=white&labelColor=0D1117" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/WidgetKit-Home%20%26%20Lock%20Widgets-E5484D?style=for-the-badge&logo=apple&logoColor=white&labelColor=0D1117" alt="WidgetKit" />
  <img src="https://img.shields.io/badge/ActivityKit-Live%20Activities-3D6FE6?style=for-the-badge&logo=apple&logoColor=white&labelColor=0D1117" alt="ActivityKit" />
  <img src="https://img.shields.io/badge/App%20Intents-Interactive%20Actions-EFAE2B?style=for-the-badge&logo=apple&logoColor=white&labelColor=0D1117" alt="App Intents" />
</p>
<p>
  <img src="https://img.shields.io/badge/Swift%20Charts-Lift%20Progress-2E9E6A?style=for-the-badge&logo=apple&logoColor=white&labelColor=0D1117" alt="Swift Charts" />
  <img src="https://img.shields.io/badge/AVFoundation-Audio%20Session-8E44AD?style=for-the-badge&logo=apple&logoColor=white&labelColor=0D1117" alt="AVFoundation" />
  <img src="https://img.shields.io/badge/AudioToolbox-Vibration-5D6570?style=for-the-badge&logo=apple&logoColor=white&labelColor=0D1117" alt="AudioToolbox" />
  <img src="https://img.shields.io/badge/UserNotifications-Fallback%20Alerts-E5484D?style=for-the-badge&logo=apple&logoColor=white&labelColor=0D1117" alt="UserNotifications" />
  <img src="https://img.shields.io/badge/Zero%20Dependencies-100%25%20Native-2E9E6A?style=for-the-badge&labelColor=0D1117" alt="Zero Dependencies" />
</p>

</div>

---

## 📂 Project Structure · Proje Yapısı

```text
mola/
├── App/                              # Main iOS Application Target (Mola)
│   ├── MolaApp.swift                 # @main entry, AppDelegate, 3-tab RootView & mola:// URL handler
│   ├── Engine.swift                  # WorkoutEngine.shared: state, 0.25s rest ticker, cardio, export & JSON backup
│   ├── Audio.swift                   # WAV Tone synthesizer, mixWithOthers AudioEngine, Feedback haptics & Notifier
│   ├── LiveActivity.swift            # LiveActivityManager: ActivityKit lifecycle & wake AlertConfiguration
│   ├── HomeView.swift                # Routine picker, NextWorkoutCard, ResumeCard & last workout shortcut
│   ├── WorkoutView.swift             # Full-screen set screen, rest/cardio countdown & exercise list sheet
│   ├── HistoryView.swift             # Past workouts, editable set detail & Swift Charts LiftProgressView
│   ├── SummaryView.swift             # Post-workout stats, weight PR highlights & one-tap AI summary copy
│   ├── ProgramEditorView.swift       # Custom 4-day routine & exercise editor (add, edit, reorder, delete, reset)
│   ├── SettingsView.swift            # Audio/haptics/theme toggles, permission diagnostics, 10s test & JSON FileDocument
│   ├── Components.swift              # Reusable UI primitives (CardModifier, BigButtonStyle, ValueDial, StepButton)
│   ├── mola-chime.wav                # Custom rest-complete chime audio asset
│   ├── Info.plist                    # Live Activities, background audio mode, mola:// URL scheme, MolaAppGroup
│   ├── Mola.entitlements             # App Group entitlement ($(APP_GROUP))
│   └── Assets.xcassets/              # AppIcon & asset catalog
├── Shared/                           # Shared Code (Compiled into both Mola & MolaWidgets)
│   ├── Models.swift                  # Codable models (Workout, SetEntry, CardioEntry, AppData, MolaActivityAttributes)
│   ├── Program.swift                 # Built-in 4-day Upper/Lower routines & initial seedHistory
│   ├── Planner.swift                 # Double progression, warm-up/back-off builder, cursor & liveState calculations
│   ├── SharedStore.swift             # App Group JSON persistence (plaka-data.json + automatic backup fallback)
│   ├── Intents.swift                 # LiveActivityIntent actions (CompleteSet, AdjustRest, SkipRest)
│   ├── Palette.swift                 # Olympic Plate colors, dynamic light/dark Ink tokens & PFont typography
│   └── Brand.swift                   # MolaMark barbell-pause emblem & PlateDot routine indicator
├── Widgets/                          # WidgetKit & Live Activity Extension Target (MolaWidgets)
│   ├── MolaWidgets.swift             # MolaWidget (5 families) & MolaLiveActivity (Lock Screen + Dynamic Island)
│   ├── Info.plist                    # WidgetKit extension configuration & MolaAppGroup
│   └── MolaWidgets.entitlements      # App Group entitlement ($(APP_GROUP))
├── Mola.xcodeproj/                   # Xcode project (iOS 26.0 deployment target, Swift 5, v2.0)
└── BENIOKU.txt                       # Original Turkish quick-install checklist
```

---

## 🚀 Setup & Installation · Kurulum ve Çalıştırma

### Requirements · Gereksinimler
- **Xcode** supporting **iOS 26.0+ SDK** (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `SWIFT_VERSION = 5.0`)
- Physical **iPhone** recommended (Live Activities, Dynamic Island, Haptics, and Background Audio cannot be fully verified in the Simulator)
- An Apple Developer account (free Personal Team works)

### Step-by-Step · Adım Adım Kurulum

1. **Open the Project · Projeyi Aç**
   - Double-click `Mola.xcodeproj` in Xcode (`open Mola.xcodeproj`).

2. **Configure Signing & Capabilities · İmzalama Ayarları**
   - Select the blue **Mola** project → **TARGETS** → **Mola** → **Signing & Capabilities** → select your **Team**.
   - Repeat the same **Team** selection for the **MolaWidgets** target.

3. **Bundle ID & App Group Note · Bundle ID ve App Group Notu**
   - Default User-Defined Build Settings in `Mola.xcodeproj`:
     - `BUNDLE_ID` = `com.okan.plaka.app` (Widget target: `$(BUNDLE_ID).widgets`)
     - `APP_GROUP` = `group.com.okan.plaka.app`
   - **If Xcode reports a Bundle ID / Signing conflict:** Go to **Mola Project → Build Settings → User-Defined** and append the same unique suffix to both `BUNDLE_ID` and `APP_GROUP` (e.g., `com.okan.plaka.app2` and `group.com.okan.plaka.app2`) so the app and widget extension continue sharing the same App Group container. *(Note: Changing the App Group starts with the built-in seed history instead of previous records.)*

4. **Build & Run · Derle ve Çalıştır**
   - Connect your iPhone and press **▶ (Run)**.
   - When prompted on the device, tap **Allow** for **Notifications** and **Live Activities** *(Bildirim ve Canlı Etkinlik izinlerine "İzin Ver" de)*.

5. **Verify with the Built-in 10-Second Test · 10 Saniyelik Deneme Dinlenmesi**
   - Open **Ayarlar (Settings) → Kontrol (Diagnostics) → "10 saniyelik deneme dinlenmesi"**.
   - Immediately **lock your iPhone**.
   - After 10 seconds, verify that the **Lock Screen lights up**, **`mola-chime.wav` plays** (without pausing background music), and the **device vibrates**.

6. **Add Widgets · Widget Ekle**
   - Long-press your **Home Screen** or **Lock Screen** and add the **Mola** widget (available in Small, Medium, Lock Screen Rectangular, Circular, and Inline sizes).

---

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:E5484D,35:3D6FE6,75:171A1F,100:0C0E11&height=110&section=footer" width="100%" alt="Mola Footer" />

<sub>⚡ <b>Okan Yörük</b> · Built natively with SwiftUI, WidgetKit & ActivityKit · <a href="https://github.com/yorukokan">github.com/yorukokan</a></sub>

</div>
