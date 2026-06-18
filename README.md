<div align="center">

<img src="lib/assets/app_icon_1.png" alt="ctrl. app icon" width="120" />

<<<<<<< HEAD
# ctrl.
=======
## Getting Started
i made this project with flutter / dart
>>>>>>> 3f660677793baababfc39d3977fee443c7a71b48

### Take back control of your screen time.

A native-feeling Android digital well-being app that actually **enforces** app time limits — not just reports them.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Kotlin](https://img.shields.io/badge/Kotlin-Android-7F52FF?logo=kotlin&logoColor=white)](https://kotlinlang.org)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://www.android.com)
[![License](https://img.shields.io/badge/License-Private-lightgrey)](#license)

</div>

---

## What is `ctrl.`?

We all install "screen time" apps that nicely *tell us* we've spent three hours on YouTube. `ctrl.` doesn't tell — it **acts**.

Pick any app on your phone, give it a daily time budget, and the moment that budget runs out, `ctrl.` kicks it to the home screen and locks it behind a cooldown timer — automatically, in the background, with zero taps required from you.

## ✨ Features

| | |
|---|---|
| ⏱️ **Real-time usage tracking** | Foreground-app detection that keeps tracking accurately even during long, uninterrupted sessions — not just the first few seconds of app use. |
| 🚫 **Automatic enforcement** | When the limit hits zero, an Android Accessibility Service instantly sends the offending app home — no "are you sure?" dialog, no way to ignore it. |
| 🔔 **Live countdown notification** | The instant a tracked app opens, a persistent status-bar notification appears with a real countdown to your limit. Leave the app and it vanishes; come back and it picks up exactly where it left off. |
| ❄️ **Cooldown periods** | Hit your limit and the app is locked for a configurable cooldown window (default 4h) before usage resets — no more "just one more minute" loopholes. |
| 📱 **Any app, including YouTube** | Full package-visibility support for Android 11+ — every launchable app on the device shows up in the picker, system apps included. |
| 🌗 **Light & dark mode** | A clean, modern UI with a fully theme-aware design system (`CtrlColors`) and persisted user preference. |
| 🔋 **Boots with your phone** | A `BOOT_COMPLETED` receiver keeps protection active across restarts. |
| 🛡️ **Local-only, private** | No accounts, no servers, no analytics. Every byte of usage data lives in `SharedPreferences` on your device. |

## 🖼️ How it works

```
┌────────────────────────┐        writes used/limit/cooldown        ┌──────────────────────────┐
│  UsageTrackingService   │ ────────────────────────────────────▶  │     SharedPreferences      │
│  (foreground service)   │                                         │       "app_limits"         │
└────────────────────────┘                                         └──────────────────────────┘
        ▲                                                                       │
        │ polls UsageStatsManager                                              │ reads
        │ every 1s for the                                                     ▼
        │ foreground package                                    ┌──────────────────────────────┐
        │                                                       │  BlockAccessibilityService     │
        └───────────────────────────────────────────────────────│  • tracks foreground app       │
                                                                  │  • shows live countdown notif  │
                                                                  │  • sends app home on limit hit │
                                                                  └──────────────────────────────┘
```

1. **`UsageTrackingService`** runs as a foreground service, polling Android's `UsageStatsManager` every second to determine the app currently on screen, and increments its used-time counter in `SharedPreferences`.
2. **`BlockAccessibilityService`** independently tracks the foreground app via `TYPE_WINDOW_STATE_CHANGED` accessibility events, drives the live status-bar countdown, and — the moment a tracked app is over its limit or mid-cooldown — fires `GLOBAL_ACTION_HOME` to boot the user straight out.
3. The two services never block on each other; SharedPreferences is the single source of truth they both read/write, so tracking and enforcement stay in sync even if one process restarts.

## 🛠️ Tech stack

- **Flutter / Dart** — UI, state management (`provider`), theming
- **Kotlin** — native Android services (`UsageTrackingService`, `BlockAccessibilityService`, `BootReceiver`)
- **Android `UsageStatsManager`** — foreground-app + usage-event detection
- **Android `AccessibilityService`** — app enforcement & global navigation actions
- **`shared_preferences`** — lightweight on-device persistence, shared between Dart and native layers
- **`google_fonts`** — Inter typeface throughout the UI

## 📋 Required permissions

| Permission | Why it's needed |
|---|---|
| **Usage Access** | Lets `ctrl.` see which app is currently in the foreground. |
| **Accessibility Service** | Lets `ctrl.` close an app and navigate home when your limit is reached. |
| **Notifications** | Powers the background tracking service and the live countdown timer. |

The app walks you through granting all three on first launch and surfaces a warning banner until everything is enabled.

## 🚀 Getting started

```bash
git clone <repo-url>
cd eighth_flutter_app
flutter pub get
flutter run
```

### Generating the app icon

The launcher icon is generated from [`lib/assets/app_icon_1.png`](lib/assets/app_icon_1.png) via `flutter_launcher_icons`:

```bash
dart run flutter_launcher_icons
```

## 📂 Project structure

```
lib/
├── main.dart                     # App entry, theming, providers
├── models/app_limit.dart         # AppLimit data model
├── services/
│   ├── timer_manager.dart        # Dart-side orchestration & polling
│   ├── usage_tracker.dart        # MethodChannel bridge to native code
│   └── theme_notifier.dart       # Light/dark mode persistence
├── screens/
│   ├── home_screen.dart          # Shield status + tracked app list
│   ├── app_selector_screen.dart  # Pick apps & configure limits
│   └── settings_screen.dart      # Permissions, theme, dev tools
└── utils/constants.dart          # CtrlColors design system

android/app/src/main/kotlin/.../
├── MainActivity.kt                # MethodChannel handler, native queries
├── UsageTrackingService.kt        # Foreground service: usage polling
├── BlockAccessibilityService.kt   # Enforcement + live notification
└── BootReceiver.kt                # Re-arm protection after reboot
```

## 🗺️ Roadmap ideas

- [ ] Weekly usage insights & charts
- [ ] Per-app custom cooldown curves
- [ ] iOS support (Screen Time API)
- [ ] Widget for quick limit adjustments

## License

Private project — not currently licensed for redistribution.

---

<div align="center">
<sub>Built with Flutter + native Android, for people who actually want their limits enforced.</sub>
</div>
