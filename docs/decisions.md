# Decision Records & Failure Logs

Living log of design/engineering decisions for MediCare (SE5070). Add an
entry whenever a non-obvious choice is made, something is tried and
abandoned, or an AI-assisted step produced an error worth recording.

## Project area

Index number MS26926162 → digit sum 34 → 34 mod 5 = 4 → **HealthTech**.

## OCR scope: printed labels only, English only

- **Decision:** scan pharmacy-printed labels / pill packets, not
  handwritten doctor prescriptions.
- **Why:** standard OCR (Google ML Kit text recognition) is trained on
  printed text; handwriting recognition accuracy would be too unreliable
  for a safety-relevant field within an 8-week solo build.
- **Follow-on decision:** OCR is further scoped to English only, since
  Sri Lankan pharmacy labels are printed in English in practice. Sinhala
  script recognition was considered and rejected for the same
  risk/timeline reason — see `ui-ux.md` section on language support.
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

## Failure log

Record AI-assisted steps here as they happen during implementation,
including the prompt used and what broke, e.g.:

- _(template)_ **Prompt:** "…" → **Result:** error / wrong output →
  **Fix:** what was changed and why.
