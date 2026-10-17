# MediCare App

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?logo=firebase)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-blue)](#)
[![Tests](https://img.shields.io/badge/Tests-60%20passed-success)](#testing)
[![Area](https://img.shields.io/badge/Domain-HealthTech-0E7485)](#)

**MediCare** is an offline-first medication adherence tracker designed for elderly and chronic-condition patients, paired with real-time caregiver monitoring, label OCR scanning, automated dose reminders, escalation alerts, and direct phone contact.

---

## Key Features

### 1. Patient Experience & Medication Management
- **Today's Dashboard:** Clear daily schedule showing upcoming, taken, late, and missed doses with one-tap logging.
- **Printed-Label OCR Scanning:** Scans medicine packaging/labels using Google ML Kit Text Recognition with drug candidate matching, supporting both camera capture and photo uploads from the device gallery.
- **Flexible Scheduling:**
  - Multi-select times of day (Morning, Afternoon, Evening, Night) or custom combinations.
  - Custom time pickers per dose (e.g. Morning 09:00 AM, Evening 08:30 PM).
  - Manual creation, editing, and deletion of medication regimens.
- **Custom Adherence Calendar (`PillCalendar`):** Built-from-scratch monthly grid visualizing daily adherence status (Green = Taken, Amber = Late, Red = Missed) without third-party calendar dependencies.
- **Bilingual Localization:** Full English and Sinhala (`en` / `si`) interface switching on the fly.

### 2. Intelligent Notification & Caregiver Escalation Timings
- **Pre-Dose Patient Reminder (5 Mins Before):**
  - Triggers **5 minutes prior** to scheduled dose time (e.g., at 8:55 AM for a 9:00 AM dose):  
    `💊 Medicine Reminder: <MedicineName> - Upcoming dose in 5 minutes (<Time>). Please get your <Dosage> ready!`
- **Caregiver Escalation Alert (20 Mins Past Due):**
  - If a patient does not mark a scheduled dose as taken **within 20 minutes** (e.g., by 9:20 AM for a 9:00 AM dose):
    - Triggers high-priority caregiver alert:  
      `⚠️ Caregiver Alert: Missed Medicine - <PatientName> has not taken <MedicineName> (<Dosage>) scheduled for <Time> (20 minutes past due).`
    - Automatically marks dose log status as `missed` in SQLite and Firebase.
    - Records alert in Firestore `caregiver_alerts` collection.
    - Updates Caregiver Dashboard attention count and badge.

### 3. Caregiver View & Direct Phone Call Integration
- **Caregiver Dashboard:** Real-time visibility into all linked patients, 7-day adherence rates, active medication counts, and urgent care alerts.
- **Direct Phone Calling (`PhoneCallService`):**
  - Built-in native Android dialer launch (`Intent.ACTION_DIAL`) via custom `MethodChannel` (`com.example.medicare_app/phone_call`).
  - Pre-fills patient phone numbers directly in the dialer without requiring dangerous `CALL_PHONE` permissions.
  - Quick action buttons on patient cards, urgent care alerts, patient detail AppBar, and check-in bottom sheets.
  - Interactive fallback sheet with number copy on Web or environments without cellular dialers.
- **3-Layer Role Security Guard:** Caregivers have read-only access to patient medications and adherence logs to prevent accidental schedule tampering (enforced at UI, Local Service, and Firestore Security Rule layers).

### 4. Offline-First Architecture & Cloud Sync
- **SQLite (`sqflite`):** All medication creation, updates, and dose logs write to local storage first, enabling 100% functionality without network connectivity.
- **Background Sync (`SyncService`):** Unsynced transactions queue locally and sync to Firebase Firestore upon connection restoration.
- **Account Pairing:** Many-to-many pairing between patients and caregivers via 6-character alphanumeric invite codes with 24-hour expiration.
- **Auth & Password Reset:** Phone-number/email authentication with OTP password reset verification.

---

## Project Structure

```
medicare-app/
├── android/                   # Native Android host & Kotlin MainActivity MethodChannel
├── lib/
│   ├── l10n/                  # Localization files (app_en.arb, app_si.arb)
│   ├── models/                # Data models: Medicine, DoseLog, UserProfile
│   ├── screens/
│   │   ├── welcome_screen.dart           # Role selection entry screen
│   │   ├── sign_in_screen.dart           # Authentication & phone sign in
│   │   ├── patient_signup_screen.dart    # Patient onboarding
│   │   ├── caregiver_signup_screen.dart  # Caregiver onboarding
│   │   ├── forgot_password_screen.dart   # Phone OTP password reset
│   │   ├── today_dashboard_screen.dart   # Patient daily medication view
│   │   ├── caregiver_screen.dart         # Caregiver dashboard & alerts
│   │   ├── patient_detail_screen.dart    # Patient calendar & adherence inspection
│   │   ├── ocr_scan_screen.dart          # Camera & gallery OCR scanner
│   │   ├── ocr_confirmation_screen.dart  # OCR label confirmation & pre-fill
│   │   ├── add_manually_screen.dart      # Medication add/edit form with custom times
│   │   └── link_caregiver_screen.dart    # Invite code generation & linking
│   ├── services/
│   │   ├── auth_service.dart             # Firebase Auth & user profile management
│   │   ├── local_db_service.dart         # SQLite persistence & offline sync queue
│   │   ├── sync_service.dart             # Bi-directional Firestore synchronization
│   │   ├── notification_service.dart     # 5-min reminders & 20-min caregiver escalation
│   │   ├── phone_call_service.dart       # Native dialer MethodChannel & fallback
│   │   ├── ocr_service.dart              # Google ML Kit OCR text processing
│   │   └── log_service.dart              # Local diagnostic & error logging
│   ├── theme/                            # AppColors & Material 3 AppTheme
│   └── widgets/                          # MedicineCard, PillCalendar, MedicinesModal, etc.
├── test/                                 # 60 Unit & Widget Tests
└── docs/
    └── decisions.md                      # Architecture decision records & failure logs
```

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>= 3.3.0 < 4.0.0)
- Android Studio / Android SDK (API 30+ recommended)
- Java 17+
- (Optional) Connected Android emulator or physical device

### Installation & Run

1. **Clone the repository and install dependencies:**
   ```bash
   cd medicare-app
   flutter pub get
   ```

2. **Generate localization files:**
   ```bash
   flutter gen-l10n
   ```

3. **Run on an Android device or emulator:**
   ```bash
   flutter run -d android
   ```

4. **Run on Chrome (Web preview):**
   ```bash
   flutter run -d chrome
   ```

---

## Testing

The project maintains **60 automated tests** covering core business logic, offline sync, OCR drug matching, calendar rendering, notification timings, phone calling, and caregiver security guards.

Execute the test suite with:

```bash
flutter test
```

### Test Coverage Highlights
| Test Suite | Purpose |
| :--- | :--- |
| `notification_service_test.dart` | 5-min pre-dose patient reminder, 20-min overdue caregiver escalation, deduplication |
| `phone_call_service_test.dart` | Phone number formatting, validation, and native MethodChannel invocation |
| `caregiver_readonly_test.dart` | 3-layer role enforcement: UI button hiding, service exceptions, and read-only inspection |
| `caregiver_linking_test.dart` | UserProfile copyWith, invite code generation (6 chars), and 24-hour expiry |
| `ocr_candidate_selection_test.dart` | OCR drug candidate extraction, known medicine prioritization, noisy line filtering |
| `ocr_confirmation_screen_test.dart` | Pre-fill flow from camera/gallery scanning to editable medicine form |
| `edit_medicine_form_test.dart` | Multi-time-of-day selection, custom hour/minute preservation, form validation |
| `pill_calendar_test.dart` | Custom month grid rendering, day tap callbacks, month navigation, adherence dots |
| `offline_medicine_test.dart` | SQLite local database write, unsynced status flag, and sync status transition |
| `log_service_test.dart` | Diagnostic error logging to local file storage |

---

## Architecture & Design Decisions

Detailed architecture decision records (ADRs) and failure logs are documented in [docs/decisions.md](file:///c:/MSC/SE5070%20-%20Enterprise%20Mobility/medicare-app/docs/decisions.md):
- **HealthTech Scoping:** English-first printed pharmacy label recognition; name-only parsing with user-confirmed dosage.
- **Offline-First Storage:** Local writes to SQLite win for the device; server timestamp merges on connectivity.
- **Permission-Safe Calling:** Native `Intent.ACTION_DIAL` launch avoids sensitive Android permissions while enabling single-tap caregiver calling.
- **Timing Rationale:** 5-minute pre-dose notice gives elderly patients prep time; 20-minute post-due window balances false-alarm reduction with timely caregiver intervention.
