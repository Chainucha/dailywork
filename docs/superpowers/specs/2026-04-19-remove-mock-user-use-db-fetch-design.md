# Remove Mock User, Use Data From Database Fetch — Design

**Date:** 2026-04-19
**Status:** Draft — pending user approval
**Scope:** Full-stack refactor (Supabase migration + FastAPI + Flutter)

## Problem

`dailywork/lib/repositories/mock_users.dart` is the last piece of mock data in the user/profile surface. Most of the profile screens already read from the DB via `ApiUserRepository.getMe()` + `AuthNotifier`, but a few places are still stubbed:

1. `WorkerProfileScreen` renders `MockUsers.mockWorkerReviews` in its Reviews section.
2. `UserModel.fromJson` hardcodes `reliabilityPercent`, `jobsCompleted`, `experienceYears` to `0` because no backend fields exist.
3. `UserModel.displayName` reuses `phone_number` — there is no real display-name column.
4. `EmployerProfileScreen` shows a hardcoded `"12 jobs posted"` string.
5. The `MockUsers.workerUser` / `employerUser` objects are dead code (not imported anywhere) but still occupy the file.

The goal is to delete `mock_users.dart` entirely and make every field on both profile screens come from a real DB fetch.

## Non-Goals

- No ML-ranked recommendations or AI matching (V2).
- No worker-verification / ID upload flow.
- No employer posted-jobs *list* (the "Coming soon" placeholder stays). We only show the *count*.
- No public/private profile toggle — any authenticated user can read any user's reviews for now.
- No chat, payments, analytics.
- No backfill of `display_name` for existing users; they see their phone as a fallback until they edit.

## Key Design Decisions

| Decision | Choice | Reason |
|---|---|---|
| Aggregate stats source | Mixed — compute rollups on-the-fly, store user-supplied fields | Avoids adding counter columns + triggers at current scale; only adds a column for data that can't be computed. |
| `display_name` location | `users.display_name` (nullable), with employer override to `business_name` in Flutter `UserModel` | Single column for both roles; employer business name already covers the displayed name. |
| Onboarding capture | Required name prompt for new workers only; employers unchanged | Matches "low-friction for low-literacy" constraint — one extra screen, not a full form. Employers get their name from `business_name`. |
| Name entry UX | Required, 1–60 chars, non-whitespace | Cannot proceed to home without a name in onboarding; cannot save empty name in edit mode. |
| Existing users without `display_name` | Fall back to phone number in UI; no forced prompt on login | Returning users are not blocked from working. Edit button is discoverable. |
| `reliability_percent` | Dropped | No agreed formula; YAGNI. |
| `experience_years` | Dropped as a field; the Experience stat is replaced by **Reviews** count (total reviews received) | Reviews are the proxy for proven experience. |
| Reviews API shape | `GET /reviews/user/{user_id}?limit=20&offset=0`, any authenticated caller | Paginated from day one; consistent with the 20-item paginate-everything convention. |
| Phasing | Single bundled PR (backend-first, then Flutter) | Small, contained refactor. Splitting adds overhead without value at this size. |

## Architecture

Three layers, delivered together:

1. **DB migration** — one nullable column on `users`.
2. **Backend endpoints** — extend 3 existing endpoints + 1 new endpoint.
3. **Flutter** — delete `mock_users.dart`, update `UserModel`, add a repository + provider for reviews, add a `NameEntryScreen`, wire it into onboarding + both profile screens.

## Database Migration

File: `supabase/migrations/YYYYMMDD_add_users_display_name.sql`

```sql
ALTER TABLE users ADD COLUMN display_name TEXT;
-- Nullable. No backfill. Existing users remain NULL until they edit.
```

RLS: existing policies on `users` already allow self-read and self-update via JWT `sub`. Adding a nullable column requires no policy change.

## Backend Endpoints

All routes under `/api/v1`. Auth: `Authorization: Bearer <jwt>`.

### `GET /users/me` — extended response

```json
{
  "id": "...",
  "phone_number": "...",
  "user_type": "worker",
  "display_name": "Basavaraj"          // NEW, nullable
}
```

### `PATCH /users/me` — extended `UserUpdate` schema

New accepted field: `display_name: str | None`.

Validation:
- Trim whitespace on input.
- Reject empty string after trim → 422.
- Reject length > 60 → 422.
- To clear, client sends `null` (not `""`). The spec does not expose a "clear name" UI, but the API permits it.

### `GET /workers/me/profile` — one new computed field

Response adds `jobs_completed: int`.

Query (expressed as SQL for clarity):
```sql
SELECT COUNT(*)
FROM applications a
JOIN jobs j ON j.id = a.job_id
WHERE a.worker_id = :me
  AND a.status = 'accepted'
  AND j.status = 'completed';
```

Implementation note: existing routers use the supabase-py fluent client (`db.table(...).select(...).eq(...).execute()`). A two-table filtered count is easiest to express either with PostgREST's embedded resource filter (`.table('applications').select('id, jobs!inner(status)', count='exact').eq('worker_id', me).eq('status', 'accepted').eq('jobs.status', 'completed').execute()`) or by creating a small Postgres view / RPC function. Implementer chooses at plan time — both are fine.

### `GET /employers/me/profile` — one new computed field

Response adds `jobs_posted: int`.

Query:
```sql
SELECT COUNT(*) FROM jobs WHERE employer_id = :me;
```

Counts all statuses (open/assigned/in_progress/completed/cancelled) — the UI label "Jobs posted" has no status qualifier.

### `POST /auth/setup-profile` — extended body

```json
{
  "user_type": "worker",
  "display_name": "Basavaraj"   // optional; present in worker flow, absent in employer flow
}
```

Behaviour: sets `users.user_type` and (if provided) `users.display_name` in one DB update. Omitted → leaves `display_name` NULL.

### `GET /reviews/user/{user_id}` — NEW endpoint

Location: `backend/app/routers/reviews.py`.
Query params: `limit` (default 20, max 50), `offset` (default 0, min 0).
Auth: any authenticated user.
Rate limit: `60/minute` (consistent with other read endpoints).

Query:
```sql
SELECT r.id, r.rating, r.comment, r.created_at,
       COALESCE(u.display_name, u.phone_number) AS reviewer_display_name
FROM reviews r
JOIN users u ON u.id = r.reviewer_id
WHERE r.reviewee_id = :user_id
ORDER BY r.created_at DESC
LIMIT :limit OFFSET :offset;
```

Response:
```json
{
  "items": [
    {
      "id": "...",
      "rating": 5,
      "comment": "Excellent work ethic.",
      "created_at": "2026-03-15T10:00:00Z",
      "reviewer_display_name": "Prestige Builders"
    }
  ],
  "total": 45,
  "limit": 20,
  "offset": 0
}
```

`total` is computed with a separate `SELECT COUNT(*) FROM reviews WHERE reviewee_id = :user_id`. Two queries per request is acceptable at current scale.

## Flutter Changes

### Deleted

- `dailywork/lib/repositories/mock_users.dart` — whole file.

### `lib/models/user_model.dart`

`WorkerProfile`:
- **Remove:** `reliabilityPercent`, `experienceYears`.
- **Keep:** `skills`, `availabilityStatus`, `dailyWageExpectation`, `ratingAvg`, `totalReviews`.
- **Promote to real field:** `jobsCompleted` (was hardcoded 0) → now `json['jobs_completed'] as int? ?? 0`.

`EmployerProfile`:
- **Add:** `jobsPosted` from `json['jobs_posted'] as int? ?? 0`.

`UserModel.fromJson` — resolve `displayName` with precedence:
```dart
final displayName = (json['business_name'] as String?)      // employer override
    ?? (json['display_name'] as String?)                    // users.display_name
    ?? (json['phone_number'] as String);                    // fallback
```

### `lib/repositories/api/api_user_repository.dart` — new method

```dart
Future<UserModel> updateDisplayName(String name) async {
  await _dio.patch('/users/me', data: {'display_name': name});
  return getMe();
}
```

### `lib/repositories/api/api_auth_repository.dart` — widen signature

```dart
Future<void> setupProfile(String userType, {String? displayName}) async {
  await _dio.post('/auth/setup-profile', data: {
    'user_type': userType,
    if (displayName != null) 'display_name': displayName,
  });
}
```

Matching widening on `AuthNotifier.setupProfile`.

### `lib/repositories/api/api_review_repository.dart` — new file

```dart
class Review {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String reviewerDisplayName;
  // fromJson...
}

class ReviewPage {
  final List<Review> items;
  final int total;
  final int limit;
  final int offset;
  // fromJson...
}

class ApiReviewRepository {
  final Dio _dio;
  ApiReviewRepository(this._dio);
  Future<ReviewPage> getUserReviews(String userId,
      {int limit = 20, int offset = 0}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/reviews/user/$userId',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return ReviewPage.fromJson(res.data!);
  }
}
```

### Providers

- `apiReviewRepositoryProvider` — plain `Provider`, same pattern as `apiUserRepositoryProvider`.
- `userReviewsProvider(userId)` — `FutureProvider.family<ReviewPage, String>` that calls the repo for the first page. Invalidated from the Retry button.

### `AuthNotifier.refreshMe()` — new method

```dart
Future<void> refreshMe() async {
  final user = await _userRepo.getMe();
  state = state.copyWith(user: user);
}
```

Called after `updateDisplayName` so both profile screens re-render with the new name.

### `NameEntryScreen` — new file `lib/screens/auth/name_entry_screen.dart`

Single screen used in two modes:

- **Onboarding mode** (entered from role-select, worker only): Continue → `authNotifier.setupProfile('worker', displayName: name)` → home.
- **Edit mode** (entered from profile screens): pre-filled with current name; Continue → `userRepo.updateDisplayName(name)` → `authNotifier.refreshMe()` → pop.

UX:
- Heading: "What should I call you?" (onboarding) / "Edit name" (edit).
- Single large TextField (≥48dp tap target).
- Max length 60, validator rejects empty-after-trim.
- Continue button disabled until valid.
- No "Skip" link. Name is required in both modes.

Route: `/name-entry` with a typed argument (`NameEntryMode.onboardingWorker` or `NameEntryMode.edit`). Edit mode optionally takes the current name for pre-fill.

### `RoleSelectScreen` — worker branch navigates through name entry

- Current flow: tap Worker → `setupProfile('worker')` → home.
- New flow: tap Worker → push `/name-entry` (onboarding mode). That screen owns the `setupProfile` call on success.
- Employer branch unchanged — goes through its existing path.

### `WorkerProfileScreen`

- Import of `mock_users.dart` removed.
- Header: add an **edit icon** next to the display name → opens `/name-entry` in edit mode with current name pre-filled.
- Stats card:
  - Drop the Reliability row.
  - Swap Experience row for "Reviews" showing `user.workerProfile.totalReviews`.
  - Keep Jobs Done row — now shows real `jobsCompleted`.
- Reviews section: `ref.watch(userReviewsProvider(user.id))` with states:
  - `loading` → spinner
  - `error` → "Couldn't load reviews" + Retry button (invalidates the provider)
  - `data.items.isEmpty` → "No reviews yet" text
  - `data.items.isNotEmpty` → renders existing `_ReviewItem` widget wired to real fields (`rating`, `reviewerDisplayName`, `comment`). The `date` field is formatted from `createdAt`.

### `EmployerProfileScreen`

- **No edit-name icon.** Employers display `business_name`, which is owned by the employer profile, not `users.display_name`. Editing `display_name` would have no visible effect because the Flutter precedence rule always prefers `business_name` for employers. A future "Edit business info" screen will own `business_name` edits; out of scope here.
- Posted Jobs card: replace hardcoded `'12 jobs posted'` with `'${user.employerProfile?.jobsPosted ?? 0} jobs posted'`.
- "Coming soon" line stays — unrelated to this spec; refers to a future posted-jobs *list*.

## Data Flow

1. **New worker sign-up:** OTP → verify → `AuthStatus.needsProfile` → `RoleSelectScreen` → tap Worker → `/name-entry` (onboarding) → `authNotifier.setupProfile('worker', displayName: name)` → `getMe()` → `AuthStatus.authenticated` → home.
2. **Returning user with no display_name:** OTP → verify → `getMe()` returns `display_name: null` → `UserModel.displayName` resolves to `phone_number` → home, profile shows phone as name.
3. **Edit name:** profile screen → edit icon → `/name-entry` (edit) → Continue → PATCH `/users/me` → `refreshMe()` → pop back to profile, header re-renders with new name.
4. **Worker profile open:** `AuthNotifier` already has user → profile renders header/skills/stats from model → Reviews section fires `userReviewsProvider(user.id)` → paginated fetch → renders first 20 reviews.

## Error Handling

| Failure | Behaviour |
|---|---|
| Network error during `setupProfile` | Error dialog + Retry; `NameEntryScreen` preserves entered name. |
| Network error during `updateDisplayName` | Toast "Couldn't save name, try again"; stay on edit screen; state unchanged. |
| Network error on `getMe` (bootstrap or post-setup) | Existing behaviour — clear token, return to guest. |
| Network error on reviews fetch | Reviews section shows error card with Retry that calls `ref.invalidate(userReviewsProvider(userId))`. Rest of profile renders normally. |
| Empty reviews (`total == 0`) | "No reviews yet" placeholder. Not an error. |
| `display_name == null` | `UserModel.displayName` falls back to `phone_number` — never blank. |

## Testing

### Backend (pytest)

- `test_users_patch_display_name` — PATCH with valid name returns 200; GET reflects it; empty/whitespace/>60 chars → 422.
- `test_workers_profile_jobs_completed_count` — seed mixed application/job statuses; assert only `accepted` + `completed` pair is counted.
- `test_employers_profile_jobs_posted_count` — seed jobs across statuses; assert all are counted.
- `test_reviews_user_pagination` — seed 25 reviews; `limit=20&offset=0` → 20 items, `total=25`; `offset=20` → 5 items.
- `test_reviews_includes_reviewer_display_name` — `display_name` populated when set; falls back to `phone_number` when null.
- `test_setup_profile_with_display_name` — POST with both fields sets both columns in one DB update.

### Flutter (unit + widget)

- `UserModel.fromJson` — all three display-name cases (business_name wins, display_name wins, phone fallback).
- `NameEntryScreen` — Continue disabled when empty; submits trimmed value; onboarding mode calls `setupProfile` with name; edit mode calls `updateDisplayName`.
- `RoleSelectScreen` worker branch — navigates to `/name-entry` (not straight to home).
- `WorkerProfileScreen` smoke test — renders real `jobsCompleted`; no Reliability row present; Reviews section handles loading → data transitions.

### Manual smoke (once wired)

- New worker signup → forced to enter name → lands on home with name shown.
- Existing user (no `display_name`) logs in → sees phone as name → taps edit → sets name → header updates.
- Worker profile with 0 reviews → "No reviews yet". Worker profile with >20 reviews → first 20 render (pagination UI is future work).
- Employer profile shows real `jobsPosted` count from their seeded jobs.

## Files Touched

**Created:**
- `supabase/migrations/YYYYMMDD_add_users_display_name.sql`
- `dailywork/lib/repositories/api/api_review_repository.dart`
- `dailywork/lib/screens/auth/name_entry_screen.dart`
- `backend/tests/test_reviews_list.py` (and additions to existing test files)

**Modified:**
- `backend/app/routers/users.py` — extended GET/PATCH responses/schemas.
- `backend/app/routers/workers.py` — add `jobs_completed` to profile response.
- `backend/app/routers/employers.py` — add `jobs_posted` to profile response.
- `backend/app/routers/auth.py` — widen `setup-profile` body.
- `backend/app/routers/reviews.py` — add GET endpoint.
- `backend/app/schemas/users.py` — add `display_name` to Read/Update schemas.
- `backend/app/schemas/workers.py` — add `jobs_completed` to profile schema.
- `backend/app/schemas/employers.py` — add `jobs_posted` to profile schema.
- `backend/app/schemas/reviews.py` — add list response schema.
- `dailywork/lib/models/user_model.dart` — drop fields, add fields, fix displayName resolution.
- `dailywork/lib/repositories/api/api_user_repository.dart` — add `updateDisplayName`.
- `dailywork/lib/repositories/api/api_auth_repository.dart` — widen `setupProfile`.
- `dailywork/lib/providers/auth_provider.dart` — add `refreshMe`; widen `setupProfile`.
- `dailywork/lib/screens/auth/role_select_screen.dart` — worker branch → `/name-entry`.
- `dailywork/lib/screens/worker/worker_profile_screen.dart` — drop mock import; rewire stats + reviews.
- `dailywork/lib/screens/employer/employer_profile_screen.dart` — real `jobsPosted`.
- `dailywork/lib/core/router/app_router.dart` (or equivalent) — register `/name-entry` route.

**Deleted:**
- `dailywork/lib/repositories/mock_users.dart`

## Open Questions / Follow-ups

- Exact filename conventions for the Supabase migration (timestamp format) should follow whatever convention the existing migrations in `supabase/migrations/` use. (Dir wasn't inspected during brainstorming.)
