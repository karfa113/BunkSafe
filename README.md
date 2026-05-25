<div align="center">

<img src="bunksafe_logo.svg" alt="BunkSafe logo" width="120" />

# BunkSafe

**Know exactly when you can skip — and when you can't.**

A student attendance tracker built with Flutter. Set up your weekly routine once, mark each class in one tap, and let the app tell you how many classes you can safely bunk before your percentage dips below the threshold.

</div>

---

## Screenshots

<p align="center">
  <img src="screenshots/today_screen.jpg"     alt="Today screen"  width="200" />
  <img src="screenshots/routine_screen.jpg" alt="All screens"   width="200" />
  <img src="screenshots/calender_screen.jpg" alt="All screens"   width="200" />
  <img src="screenshots/stats_screen.jpg" alt="All screens"   width="200" />
  <img src="screenshots/settings_screen.jpg" alt="All screens"   width="200" />
</p>

## Features

### Core
- **Weekly routine** — define your timetable once; the app generates today's class list automatically
- **One-tap marking** — Present / Absent / Off for every class, with swipe-to-mark on the Today screen
- **Live percentages** — per-subject and overall attendance, updated as you mark
- **"Safe to bunk" indicator** — see how many classes you can miss before falling below your target %
- **Calendar view** — see every marked day at a glance
- **Extra / makeup classes** — add ad-hoc sessions that fall outside the weekly routine
- **Class reminders** — timezone-aware local notifications
- **Fully offline** — no account, no server, your data stays on your device

### Routine & onboarding (new in 1.3)
- **Weekly tabular routine** — rows = days, columns = class positions, with transparent + leaf-green theming
- **Multi-select class entry** — pick subjects in order with numbered badges, add a full day's classes in one go
- **Mid-semester baseline** — when adding a subject, enter Classes held / Present / Absent and have stats pick up where you left off
- **Routine PDF export** — beautiful tabular PDF mirroring the in-app look, with teacher names

### Attendance maths (new in 1.3)
- **Per-subject attendance target** — lab needs 60%, theory 75%? Set per-subject thresholds and get per-subject "safe to skip" counts
- **Holiday calendar** — register semester breaks as date ranges; those days are skipped from stats so your % isn't dragged down
- **Bulk-mark on Calendar** — pick a date range, choose a status (Present/Absent/Off/Clear), and back-fill weeks you forgot to mark
- **PDF attendance report** — overall + per-subject breakdown, ready to share

### Android extras (new in 1.3)
- **Home-screen widget** — today's classes + safe-to-bunk count at a glance, status icons (✓ / ✗ / ☀ / ○) right next to each subject, tap to open the app

## Tech stack

- **Flutter** & **Dart**
- **Provider** for state management
- **SharedPreferences** for local persistence
- **flutter_local_notifications** + **timezone** for scheduled reminders
- **pdf** + **printing** for report & routine export
- **home_widget** for the Android home-screen widget
- **intl** for date/time formatting

## Platforms

Android · iOS · Web · Windows · macOS · Linux — single codebase.

## Getting started

Requires Flutter SDK `^3.11.4`.

```bash
git clone https://github.com/karfa113/BunkSafe.git
cd BunkSafe
flutter pub get
flutter run
```

To build a release APK:

```bash
flutter build apk --release
```

## Project structure

```
lib/
├── main.dart                 # app entry
├── app_state.dart            # Provider state, attendance math
├── models.dart               # ClassItem, Subject, ExtraClass, Holiday, AttendanceStatus
├── storage.dart              # SharedPreferences persistence
├── theme.dart                # app theming
├── screens/                  # today, calendar, routine, stats, settings, home, holidays
├── services/                 # notifications, routine PDF, home-widget sync
└── widgets/                  # reusable UI components
```

## License & branding

Code is released under the [MIT License](LICENSE) — you're welcome to read, learn from, and build on it.

The name **BunkSafe**, the logo, and the visual identity are **not** covered by the MIT license. Please rename and rebrand any fork before redistributing or publishing.

## Author

Built solo by **Monojit Karfa**.
