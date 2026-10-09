# MediCare

Medication adherence tracker for elderly and chronic-condition patients,
with caregiver linking, printed-label OCR scanning, offline-first sync,
and English/Sinhala support.

SE5070 Enterprise Mobility (MSc) — individual project, HealthTech area.

## Status

Project scaffold: data models, service interfaces, theme, and the two
main screens/components are in place. Business logic (Firebase wiring,
local DB queries, OCR parsing) is stubbed with `TODO`s — see each file
under `lib/services/`.

## Getting started

This repo only contains the Dart/Flutter source (`lib/`) — platform
folders are generated locally, not committed:

```bash
flutter create .        # generates android/, ios/, etc. in place
flutter pub get
flutter gen-l10n        # generates lib/l10n/app_localizations.dart
flutter run
```

You'll also need a Firebase project connected (`flutterfire configure`)
before `AuthService`, `SyncService`, or push notifications will work.

## Structure

```
lib/
  models/      Medicine, DoseLog, UserProfile
  services/    AuthService, LocalDbService, SyncService, NotificationService, OcrService
  screens/     TodayDashboardScreen, PillCalendarScreen
  widgets/     MedicineCard, PillCalendar (custom component)
  theme/       AppColors / AppTheme
  l10n/        app_en.arb, app_si.arb
docs/
  decisions.md Decision records & failure log
```

## Docs

- `docs/decisions.md` — architecture decisions and the AI-assisted
  implementation/failure log required by the assignment brief.
