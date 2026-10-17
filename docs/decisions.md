# Decision Records & Failure Logs

Living log of design/engineering decisions for MediCare (SE5070). Add an
entry whenever a non-obvious choice is made, something is tried and
abandoned, or an AI-assisted step produced an error worth recording.

## Project area

Index number MS26926162 → digit sum 34 → 34 mod 5 = 4 → **HealthTech**.

## OCR scope: printed labels only, English only, medicine name only

- **Decision:** scan pharmacy-printed labels / pill packets, not
  handwritten doctor prescriptions.
- **Why:** standard OCR (Google ML Kit text recognition) is trained on
  printed text; handwriting recognition accuracy would be too unreliable
  for a safety-relevant field within an 8-week solo build.
- **Follow-on decision:** OCR is further scoped to English only, since
  Sri Lankan pharmacy labels are printed in English in practice. Sinhala
  script recognition was considered and rejected for the same
  risk/timeline reason — see `ui-ux.md` section on language support.
- **Scope reduction to medicine name only:** OCR scope reduced to the medicine name only; dosage, frequency and instructions are entered manually, because name recognition on printed text is reliable while dosage parsing risks unsafe errors. Name candidates are matched against a known-drug list, with user-selectable fallbacks.
- **Input sources (Camera & Gallery):** Users can either take a photo with the rear camera or upload an existing photo/screenshot from the device gallery. This accommodates users who have pre-saved prescription/packet images and allows easy testing on emulators without a physical camera.
- **Mitigation:** every scanned field is shown on an editable confirmation
  screen before it is saved, so a misread value can always be corrected.

## Offline-first, not offline-tolerant

- **Decision:** every write (add medicine, log a dose) goes to local
  SQLite (`sqflite`) first. `SyncService` pushes unsynced rows to
  Firestore only when connectivity returns.
- **Why:** reminders and logging must keep working with zero signal —
  core requirement for the target users (elderly patients, sometimes in
  low-connectivity areas).
- **Conflict handling:** local data wins for that device; server merges
  by timestamp.

## Backend: Firebase

- **Decision:** Firebase (Auth + Firestore + Cloud Messaging) over a
  custom backend.
- **Why:** built-in auth, realtime sync, and push notifications cover the
  caregiver-alert requirement without building a separate server for an
  individual 8-week assignment.

## Account linking (patient ↔ caregiver)

- **Decision:** many-to-many link via invite code or phone number lookup,
  not a single fixed pairing.
- **Why:** a patient may have more than one adult child/caregiver; a
  caregiver may be watching more than one relative.

## Custom component

- `lib/widgets/pill_calendar.dart` — month-grid adherence calendar,
  color-coded green/amber/red, built from scratch (no calendar package)
  because no off-the-shelf component visualizes per-day adherence status
  this way. Properties and events are documented in the file header.

## Caregiver permissions: Read-only access

- **Decision:** Caregivers are read-only. They can view a patient's medicines, calendar and alerts but cannot add, edit, delete or log doses, so adherence data stays patient-reported and schedules cannot be changed remotely by mistake. Enforced in UI, service layer and Firestore rules.
- **Why:** Patient adherence reports must reflect direct patient action, and medication schedules should not be altered remotely by third parties to avoid accidental changes to doctor-prescribed regimens.
- **Enforcement Layers:**
  1. **UI Layer:** `MedicineCard(readOnly: true)` hides Taken/Skipped buttons and presents status chips; caregiver navigation omits Add tabs and medicine editing/deletion. Patient detail view (`PatientDetailScreen`) is strictly read-only.
  2. **Service Guard Layer:** `LocalDbService` validates the caller's role and data ownership in a shared helper (`enforcePatientWritePermission`), throwing `PermissionDeniedException` if a caregiver attempts to add, modify, or delete medicines or write dose logs.
  3. **Firestore Security Rules:** Server-side rules (`firestore.rules`) enforce that caregivers can only read patient medicines and dose logs if linked in `linkedCaregiverIds`, and reject all write attempts.

## Notification Timings: 5-minute Patient Reminder & 20-minute Caregiver Escalation

- **Decision:**
  - **Patient Reminder (Pre-Dose):** Exactly 5 minutes before scheduled dose time (e.g., 8:55 AM for a 9:00 AM medicine), the patient receives a notification: `"💊 Medicine Reminder: <MedicineName> - Upcoming dose in 5 minutes (<Time>). Please get your <Dosage> ready!"`.
  - **Caregiver Alert (Post-Dose Escalation):** If 20 minutes elapse after the scheduled time (e.g., 9:20 AM for a 9:00 AM medicine) and the dose has NOT been marked as taken, a high-priority alert is triggered for the caregiver: `"⚠️ Caregiver Alert: Missed Medicine - <PatientName> has not taken <MedicineName> (<Dosage>) scheduled for <Time> (20 minutes past due)."`.
- **Why:**
  - 5 minutes ahead gives elderly patients sufficient preparation time to fetch water, retrieve pill boxes, and safely take their medication on time.
  - 20 minutes grace period prevents false-positive alerts while ensuring caregivers are notified rapidly enough to intervene before adherence lapses or double-dosing risks occur.
- **Offline & Reliability Guarantees:**
  - Managed via `NotificationService` singleton using `flutter_local_notifications` with Android notification channels (`dose_reminders` and `caregiver_alerts`).
  - Evaluated on dashboard load, app resume, and background periodic timer.
  - In-memory and local tracking guarantees deduplication so the patient and caregiver are never spammed.
  - Automatically records overdue status locally in SQLite (`DoseStatus.missed`) and syncs to Firestore `caregiver_alerts` collection.

## Failure log

Record AI-assisted steps here as they happen during implementation,
including the prompt used and what broke, e.g.:

- _(template)_ **Prompt:** "…" → **Result:** error / wrong output →
  **Fix:** what was changed and why.

