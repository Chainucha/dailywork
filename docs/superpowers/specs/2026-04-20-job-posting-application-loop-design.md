# Job Posting & Application Loop — Design Spec

- **Date:** 2026-04-20
- **Status:** Approved (brainstormed with user 2026-04-20)
- **Implementation:** Three sequential plans (A → B → C)
- **Author:** brainstorming session, Claude Code

---

## 1. Overview

Build the full marketplace transaction loop on top of the existing skeleton:

> Employer posts → workers apply → employer accepts → work happens → both parties confirm completion → reviews exchanged.

The skeleton (auth, profiles, browse, base routers, role-based navigation) already exists. This spec covers feature areas (1) **Job posting & editing** and (2) **Application flow**, designed as one cohesive loop and split into three thin implementation plans for risk and reviewability.

**Vibe anchor:** delivery-app feel. Active job front-and-center, big single-purpose buttons, status as a visible progress strip, push-driven flow, immediate review prompt after both confirm.

---

## 2. Locked decisions

| Area | Decision |
|---|---|
| Scope | One spec, three thin plans (A: post / B: apply+accept / C: active+complete+review) |
| Lifecycle | 2-party completion confirmation; worker cap = 2 concurrent commitments (count of applications with status `accepted` — covers both pre-start and started-but-not-completed); employer no cap; 7-day auto-close grace after `end_date` |
| Posting | 3-step wizard: What/Where → When/Count → Pay/Confirm |
| Location entry | Hybrid — GPS default + map-picker / address-search overrides (overrides lazy-loaded) |
| Schema additions (`jobs`) | `start_time`, `end_time`, `is_urgent`, `address_text`, `cancellation_reason` |
| Schema additions (`applications`) | `worker_completed_at`, `employer_completed_at`, `withdrawn_reason`; status enum extended with `completed` |
| Navigation | Per-role, 3 tabs (HOME / MY JOBS / PROFILE). Employer adds an orange FAB on Home/My Jobs to open the post wizard as a full-screen modal route |
| Apply | One-tap on card AND detail; 5-sec Undo toast; cap blocks apply with toast (no API call) |
| Applicant management | Separate route `/employer/jobs/:id/applicants` |
| Active job | "Mark complete" button inline on My Jobs card with confirmation modal + tappable card → full detail screen |
| 2-party complete | Either side taps → other side prompted (push + UI banner); 7-day grace auto-close; Undo available while waiting |
| Review prompt | Auto-fires after both confirm; 1-5 stars required, optional comment, skip-for-now leaves persistent banner on My Jobs |
| Cancellation/withdrawal | Optional reason text + preset chips ("Found another worker", "Plans changed", "Other") |
| Notifications | Backend dispatches async (existing pattern); frontend toasts only this spec; dedicated Alerts notification screen punted |

### Out of scope (explicitly)

- Dedicated Alerts notification screen
- Search/filter on the feed
- Employer dashboard analytics (a richer "today" digest can come later — v1 is minimal)
- In-app chat, payment/escrow, multilingual i18n content (English-only for the new strings; intl scaffolding still used so Kannada can land later)
- Tag/shift labels (e.g., "Night Shift Available") — punted

---

## 3. Backend changes

### 3.1 Schema migration (single file)

`jobs` table additions:

```sql
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS start_time TIME NULL;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS end_time TIME NULL;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS is_urgent BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS address_text TEXT NULL;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS cancellation_reason TEXT NULL;
```

`applications` table additions:

```sql
ALTER TABLE applications ADD COLUMN IF NOT EXISTS worker_completed_at TIMESTAMPTZ NULL;
ALTER TABLE applications ADD COLUMN IF NOT EXISTS employer_completed_at TIMESTAMPTZ NULL;
ALTER TABLE applications ADD COLUMN IF NOT EXISTS withdrawn_reason TEXT NULL;
-- Status enum: extend allowed values to include 'completed'
ALTER TABLE applications DROP CONSTRAINT IF EXISTS applications_status_check;
ALTER TABLE applications ADD CONSTRAINT applications_status_check
  CHECK (status IN ('pending','accepted','rejected','withdrawn','completed'));
```

All additions nullable for backwards compatibility with existing rows. New posts populate the new fields via Pydantic validation.

### 3.2 Pydantic schema updates

- `schemas/jobs.py` — extend `JobCreate`, `JobUpdate`, `JobResponse` with new fields. New schemas: `JobCancelRequest { reason: str | None }`.
- `schemas/applications.py` — extend `ApplicationResponse` with `worker_completed_at`, `employer_completed_at`. New schemas: `ApplicationCompleteRequest` (empty body, role inferred), `ApplicationWithdrawRequest { reason: str | None }`.

### 3.3 New / modified endpoints

| Method | Path | Purpose | Notes |
|---|---|---|---|
| `POST` | `/jobs/{id}/apply` | (existing) extend to enforce per-worker active cap | rejects with 409 if `accepted+in_progress` count ≥ 2 |
| `POST` | `/applications/{id}/complete` | NEW — caller stamps their side's `completed_at` | infers role from JWT; when both stamped → status flips to `completed`, fires review-prompt notification |
| `POST` | `/jobs/{id}/cancel` | NEW — employer cancels job with optional reason | only valid when status `open` or `assigned`; cascades to all `pending`/`accepted` apps |
| `PATCH` | `/applications/{id}` | (existing) extend `withdrawn` to accept optional `reason` body | |
| `GET` | `/workers/me/jobs` | NEW — combined active + applications + history for worker's MY JOBS | sorted: active pinned, then pending, then history |
| `GET` | `/employers/me/jobs` | NEW — employer's posted jobs grouped by status | for employer MY JOBS |

### 3.4 Service-layer logic

- `application_service.enforce_active_cap(worker_id)` — counts `accepted` + `in_progress` apps for the worker; raises 409 if at cap
- `application_service.mark_complete(app_id, role)` — stamps the right column based on role; if both stamped, sets `status='completed'` and fires review notification
- `job_service.recompute_status(job_id)` — called on accept (workers_assigned bump may flip `open → assigned`) and on completion (all apps complete may flip job-level → `completed`); also handles the reverse on withdrawal of an accepted app
- `job_service.cancel_job(job_id, reason)` — atomic transaction: sets job to `cancelled`, sets all `pending`/`accepted` apps to `withdrawn` with `withdrawn_reason='Job cancelled by employer'`, fires `job_cancelled` push to all affected workers
- `job_service.auto_close_overdue()` — celery beat task daily at 02:00; idempotent; scans apps where one-sided `completed_at` set AND `end_date + 7d < now` → stamps the missing side, fires `auto_completed` notification
- `job_service.advance_in_progress()` — celery beat task hourly; flips `assigned → in_progress` once `start_date <= today`

### 3.5 Notifications wired (extending existing `notification_service`)

| Event | Recipient | When |
|---|---|---|
| `application_received` | employer | worker applies |
| `application_accepted` | worker | (existing) |
| `application_rejected` | worker | (existing) |
| `completion_requested` | other party | one side marks complete |
| `completion_confirmed` | both sides | both stamped (or grace fires) |
| `review_prompt` | both sides | bundled with `completion_confirmed`; auto-opens review sheet |
| `job_cancelled` | all `pending`/`accepted` workers | employer cancels job |
| `auto_completed` | both sides | grace auto-close fires |

All dispatched best-effort via existing async pattern (`try/except` wrapping). UI must work without push arriving.

---

## 4. Frontend architecture

### 4.1 Layered pattern (unchanged)

Presentation (screens/widgets) → State (Riverpod providers) → Repository (Dio-backed API repos) → Data (Hive cache for offline). New code slots into existing folders.

### 4.2 New routes

| Route | Owner | Purpose |
|---|---|---|
| `/worker/my-jobs` | Worker shell | New tab — active job pinned + applications grouped (pending / history) |
| `/employer/my-jobs` | Employer shell | New tab — posted jobs grouped by status |
| `/employer/jobs/new` | Top-level (full-screen modal) | Post-job wizard, escapes shell |
| `/employer/jobs/:id/edit` | Top-level (full-screen modal) | Edit job (re-uses wizard skeleton, pre-filled) |
| `/employer/jobs/:id/applicants` | Top-level | Dedicated applicant management screen |

Existing routes adapted (not replaced): `/worker/jobs/:id` and `/employer/jobs/:id` become status-aware (show "Mark complete" / "Confirm completion" / "Cancel" buttons based on app+job state). `/employer/home` becomes a lightweight "today" digest (active jobs starting today + jobs needing your attention).

### 4.3 Navigation

- Worker shell: explicit 3 tabs (Home / My Jobs / Profile)
- Employer shell: explicit 3 tabs (Home / My Jobs / Profile) + centered orange FAB anchored to the Scaffold (visible on Home + My Jobs, hidden on Profile and inside detail screens). FAB opens `/employer/jobs/new`.

### 4.4 New repositories (in `repositories/api/`)

- `JobRepository` adds `createJob`, `updateJob`, `cancelJob`, `getMyPostedJobs`
- `ApplicationRepository` adds `applyForJob` (returns an undo handle), `markComplete`, `withdrawApplication`, `getMyApplications`
- Existing `ReviewRepository` already supports submission

### 4.5 New providers (in `providers/`)

- `myJobsProvider` (worker — combined active + applications + history)
- `myPostedJobsProvider` (employer — grouped by status)
- `applicantsProvider(jobId)` — paginated list per job
- `activeJobCountProvider` — derived from `myJobsProvider`; powers the apply-cap UI gate
- `postJobWizardProvider` — keeps wizard state across steps so user can back-nav without losing input

### 4.6 New widgets (in `widgets/`)

- `JobCardCompact` — re-used across feed and lists
- `ActiveJobCard` — pinned top-of-list with inline "Mark complete" button + tap-to-detail
- `WizardScaffold` — 3-step shell with progress dots and back/next buttons
- `LocationPickerSheet` — modal sheet with GPS default + "Adjust on map" / "Type address" overrides; map only loads if user picks the override (lazy)
- `ApplicantTile` — name, rating, accept/reject pills
- `CompletionStatusStrip` — 4-segment progress bar (Hired / Started / In progress / Done)
- `ReasonChipsField` — preset chips ("Found another worker", "Plans changed", "Other") + free text
- `UndoToast` — 5-sec snackbar with primary undo action
- `ReviewBottomSheet` — 1-5 star tap + optional 200-char comment + Submit/Skip

### 4.7 Caching strategy

- Hive caches the worker feed (existing) — extend to cache `myJobsProvider` so opening MY JOBS feels instant offline
- Active job is always re-fetched on app foreground (state changes are time-sensitive)

---

## 5. Key flows

### Flow 1 — Post-job wizard (employer)

1. Employer taps orange FAB on Home or My Jobs → router pushes `/employer/jobs/new` (full-screen modal).
2. **Step 1 (What/Where):** category dropdown, title, description (optional), location. Location button opens `LocationPickerSheet` → tries GPS first, returns `{lat, lng, address_text}` via Nominatim reverse-geocode. User can switch to map or address-search if GPS is wrong/missing.
3. **Step 2 (When/Count):** date pickers for start/end, time pickers for start/end, integer stepper for `workers_needed`.
4. **Step 3 (Pay/Confirm):** wage input (₹), `is_urgent` toggle, live preview card showing how the listing will appear, Post button.
5. **Submit:** `JobRepository.createJob` → `POST /jobs/`. On success, router pops back to employer home, snackbar "Job posted ✓", `myPostedJobsProvider` invalidated.
6. **Validation:** field-level inline errors per step (can't move Next until current step valid). Network errors on submit → snackbar with retry.
7. **Edit flow:** same wizard, hydrated from existing job. `PATCH /jobs/{id}` on submit.

### Flow 2 — Worker applies (with undo + cap)

1. Worker taps Apply on card or detail.
2. Frontend pre-checks `activeJobCountProvider`. If ≥ 2 active → toast "You're at your active-job limit. Finish a current job first." (no API call).
3. Otherwise call `ApplicationRepository.applyForJob(jobId)` → `POST /jobs/{id}/apply`. Optimistic UI: card flips to "Applied ✓".
4. 5-sec `UndoToast` appears. If tapped → `PATCH /applications/{id}` with `status=withdrawn`, card reverts.
5. After 5 sec the application is committed and `myJobsProvider` refreshes to show it under "Pending."

### Flow 3 — Employer accepts/rejects

1. From `/employer/jobs/:id/applicants`, employer taps Accept or ✕ on a tile.
2. Accept → `PATCH /applications/{id}` `status=accepted`. Backend bumps `workers_assigned`; if it equals `workers_needed`, job auto-flips `open → assigned`.
3. Worker receives push `application_accepted` and the app appears under "Active" in their My Jobs.
4. Reject → same endpoint with `status=rejected`. Worker gets `application_rejected` push.
5. If accept would exceed `workers_needed` → backend 400, snackbar "Job has reached worker capacity."

### Flow 4 — 2-party completion (the critical one)

1. Job's `start_date` arrives → daily celery beat task auto-flips job `assigned → in_progress`. `ActiveJobCard` surfaces "Mark complete" button on both sides' My Jobs once today is `>= start_date`.
2. Either party taps "Mark complete" → confirm modal ("Is the work fully complete?") → `POST /applications/{id}/complete`. Backend stamps `worker_completed_at` or `employer_completed_at` based on caller role.
3. The acting side's UI shows the *waiting* state: yellow banner "Waiting for [other party] to confirm" + Undo button (deletes their `completed_at` stamp via PATCH).
4. The other party gets push `completion_requested` → opens app → sees the same job with banner "Has [other party] confirmed work is done? [Yes, complete] [Not yet]". The "Not yet" path is a soft dismiss — the banner re-shows next session; no state change. The asking party can also Undo their own stamp from their waiting view. If neither party resolves, the auto-close grace eventually fires (Flow 5). Formal cancellation/withdrawal is a separate user action via Flow 6 if either side wants to terminate.
5. When both `completed_at` stamped → backend flips application `status='completed'`, fires `completion_confirmed` push to both. If all of the job's accepted applications are now completed, job-level status flips to `completed`.
6. Frontend receives push → opens `ReviewBottomSheet` automatically. Skip leaves a persistent banner on My Jobs ("Rate Ravi's Builders →") until rated.

### Flow 5 — Auto-close grace (background)

1. Daily celery beat task scans applications where one-sided `completed_at` is set AND `end_date + 7d < now`.
2. Stamps the missing side with `completed_at = now`, sets status `completed`, fires `auto_completed` push to both sides explaining the auto-close. Review prompt still fires.

### Flow 6 — Cancellation

1. Employer cancels job (only valid statuses: `open`, `assigned`) → `ReasonChipsField` modal → `POST /jobs/{id}/cancel` with optional reason.
2. Backend updates job to `cancelled`, cascades to all `pending` and `accepted` applications (mark them `withdrawn` with `withdrawn_reason='Job cancelled by employer'`), fires `job_cancelled` push to all affected workers.
3. Worker withdraws their own application → same `ReasonChipsField` → `PATCH /applications/{id}` `status=withdrawn` + reason. Backend decrements `workers_assigned` if was accepted; job's `status='assigned'` may revert to `open` if no longer at capacity.

---

## 6. Cross-cutting concerns

**Concurrent-active cap enforcement**
- Frontend pre-checks `activeJobCountProvider` to avoid wasted API calls and provide instant feedback
- Backend is authoritative: `enforce_active_cap()` runs inside the apply transaction; race conditions return 409 Conflict
- Cap counts: applications belonging to this worker with `status = 'accepted'`. (There is no application-level `in_progress` status; the application stays `accepted` from acceptance through to completion. The job-level `in_progress` status is independent and used only for surface UI like the `ActiveJobCard`.) Status `completed`, `withdrawn`, `rejected`, `pending` do not count.

**Auto-close grace race**
- Celery beat runs daily at 02:00 server time; idempotent (won't re-stamp already-stamped completions)
- Edge case: user undoes their completion at the same moment grace fires. Resolution: backend wraps stamp + status update in a single transaction; `auto_completed` push only fires after transaction commits — single source of truth

**Optimistic UI rollback**
- All mutations are optimistic with a snackbar undo where applicable
- On API error → revert local state, show error snackbar with Retry
- Apply has the explicit 5-sec undo window — visually prominent
- Mark-complete has Undo available the entire waiting state, not time-boxed (waiting can be hours/days)

**Cancellation cascade**
- Backend handles cascade in `job_service.cancel_job()` — atomic transaction
- Workers see status flip on next refresh + push notification
- Worker UI: cancelled jobs move to History section with "Cancelled by employer" tag

**Network/offline behavior**
- Read paths (feed, My Jobs, applicant list): Hive cache renders instantly; stale banner if older than 60s and offline
- Write paths (apply, accept, post, mark-complete, review): require network; offline → blocking snackbar "No connection — try again." No silent queueing

**Time zones & dates**
- Server stores all timestamps in UTC; date columns are date-only (no tz)
- Client renders in device local tz via `intl`
- Date/time pickers in wizard work in local tz, converted to UTC on submit
- `start_date` comparison for auto-progression uses server-local date (no per-user TZ confusion in v1)

**Permissions**
- Location permission requested on first wizard step opening `LocationPickerSheet` (deferred — not on app launch)
- Tap-to-call uses `url_launcher` `tel:` scheme (no Android permission required)
- Push notification permission requested at end of onboarding (existing pattern, no changes here)

**Notification fallback**
- Push is best-effort (current backend pattern wraps in try/except)
- UI must function without push arriving: pull-to-refresh on My Jobs always re-fetches and renders authoritative state. Banners and prompts are derived from server state, not push payloads.

**i18n placeholder**
- All new user-facing strings go through the existing intl scaffolding (or get added if not yet wired) so the KN/EN swap from the mockup can ship later without re-touching every screen. Strings live in `lib/l10n/`.

**Telemetry / logging**
- Per CLAUDE.md: only `user_id`, endpoint, status, latency. No PII (e.g., reason text not logged). Cancellation/withdraw reasons stored in DB but not in app logs.

---

## 7. Testing strategy

### Backend (`backend/tests/`, pytest hitting live dev DB per existing convention)

- `test_jobs_create.py` — wizard submissions with new fields (`start_time`/`end_time`/`is_urgent`/`address_text`); validation failures
- `test_jobs_cancel.py` — cancel from `open`/`assigned`, blocked from `in_progress`/`completed`; cascade to applications; reason persisted
- `test_applications_apply.py` — extend existing tests for cap enforcement (worker at cap → 409); double-apply blocked (existing); apply on closed job blocked (existing)
- `test_applications_complete.py` — single-side stamp persists; both-side stamp flips status; cross-role caller resolution (worker can't stamp employer's column); job-level status flips when last app completes
- `test_jobs_status_transitions.py` — `open → assigned` auto on capacity; revert on withdrawal; manual transitions blocked outside the matrix
- `test_celery_tasks.py` — `auto_close_overdue` idempotency, `advance_in_progress` daily flip; mock the time, not the DB
- `test_workers_me_jobs.py` / `test_employers_me_jobs.py` — new combined endpoints, ordering (active pinned, then pending, then history)

### Frontend (`dailywork/test/`)

- Widget tests for `WizardScaffold`, `LocationPickerSheet`, `ActiveJobCard`, `CompletionStatusStrip`, `ReviewBottomSheet`, `ReasonChipsField`, `UndoToast`
- Provider tests for `myJobsProvider`, `applicantsProvider`, `activeJobCountProvider` (mocked repository)
- Integration tests for the three end-to-end flows (post-job wizard, apply+undo, 2-party completion) using `flutter_test` + a fake repository
- `flutter analyze` must pass (existing convention)

### Deliberately not tested in this spec

- Push notification delivery itself (best-effort backend behavior, manual smoke)
- Map tile rendering (third-party `flutter_map`; we test our integration, not their renderer)
- Nominatim availability (we wrap with try/except + fallback to lat/lng-only display)

---

## 8. Implementation phasing

### Plan A — "Employer can post" (~3-5 days)

- Migration: jobs table additions (`start_time`, `end_time`, `is_urgent`, `address_text`, `cancellation_reason`)
- Pydantic schemas updated; `JobCreate` / `JobUpdate` accept new fields
- Backend `POST /jobs/{id}/cancel` endpoint + `GET /employers/me/jobs`
- Frontend: `WizardScaffold`, `LocationPickerSheet`, `/employer/jobs/new` route, `/employer/jobs/:id/edit` route, employer FAB integration, employer `MY JOBS` screen, employer `HOME` "today" digest, tap-to-call wiring on existing detail screen
- Repository extensions: `JobRepository.createJob/updateJob/cancelJob/getMyPostedJobs`
- Tests: `test_jobs_create.py`, `test_jobs_cancel.py`, `test_employers_me_jobs.py`, widget tests for wizard + location picker
- **Ships:** end-to-end "employer signs in → posts a job → it appears in feed" workflow

### Plan B — "Marketplace match-up" (~3-5 days)

- Migration: applications status enum extension; `withdrawn_reason` column
- Backend cap enforcement on `POST /jobs/{id}/apply`
- Backend `GET /workers/me/jobs` endpoint
- Frontend: worker `MY JOBS` screen (basic — no active-job pinning yet, just grouped lists), apply one-tap + `UndoToast`, applicant tile + accept/reject UI, `/employer/jobs/:id/applicants` route, `JobCardCompact` reusable widget
- Repository extensions: `ApplicationRepository.applyForJob/withdrawApplication/getMyApplications`
- Tests: extend `test_applications_apply.py` (cap), new `test_workers_me_jobs.py`, widget tests for apply undo + applicant tile
- **Ships:** worker can apply, employer can accept; status visibility on both sides

### Plan C — "Closing the loop" (~4-6 days)

- Migration: applications table additions (`worker_completed_at`, `employer_completed_at`)
- Backend `POST /applications/{id}/complete` endpoint; `enforce_active_cap` becomes meaningful (covers `in_progress`)
- Celery beat tasks: `advance_in_progress` (hourly), `auto_close_overdue` (daily)
- Frontend: `ActiveJobCard` (replaces basic worker MY JOBS top section), `CompletionStatusStrip`, `ReasonChipsField` (used by withdraw + dispute paths), `ReviewBottomSheet`, auto-fire review prompt wiring, push notification handlers for `completion_requested`/`completion_confirmed`
- Repository extensions: `ApplicationRepository.markComplete`
- Tests: `test_applications_complete.py`, `test_celery_tasks.py`, widget tests for active card + status strip + review sheet, integration test for full happy path
- **Ships:** the full transaction loop closes; ratings flow

### Sequencing notes

- Plan A is mergeable independently — nothing downstream depends on it functionally. Worth shipping first to validate the new schema in production.
- Plan B depends on A's schema and "My Jobs" navigation patterns landing.
- Plan C depends on B's apply/accept flow being live (otherwise no `in_progress` applications exist to close out).
- Each plan ends with a green CI build, working manual smoke test on a device, and the option to gate behind a feature flag for soft-launch.

---

## 9. Open follow-ups (not blocking this spec)

- **Dedicated Alerts notification screen** — separate spec; the slot is intentionally absent from the new 3-tab nav so adding a 4th tab later won't disrupt the layout (FAB + 3 tabs already eats screen-width budget; revisit on Alerts spec).
- **Tag/shift labels** ("Night Shift Available") — needs a controlled vocabulary; design later.
- **Multilingual content** (Kannada / Bengali / Tagalog / Swahili) — intl scaffolding is wired now so this is a content drop, not a re-architecture.
- **Worker concurrent-active cap value (currently 2)** — tunable via config; observe behavior in production and adjust if too restrictive or too lax.
- **Auto-close grace period (currently 7 days)** — same; tunable via config.
