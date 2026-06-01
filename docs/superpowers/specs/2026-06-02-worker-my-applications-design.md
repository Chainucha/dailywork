# Worker "My Applications" Tab — Design

**Date:** 2026-06-02
**Status:** Approved (design)

## Problem

The worker bottom-nav "Jobs" tab (`worker_shell.dart`, index 1) is dead: its
`onTap` navigates to `/worker/home`, identical to the Home tab. No
`/worker/jobs` list route exists, and the backend has no endpoint for a worker
to see their own applications. The tab should let a worker track the jobs they
applied to.

## Goal

Worker Jobs tab shows **My Applications** — every job the worker applied to,
grouped by application status, with the ability to withdraw and to open the job
detail.

## Non-Goals

- Saved/bookmarked jobs (no bookmarks table; out of scope).
- Any change to the employer applicant-management flow.
- Push notifications, realtime updates (V2 roadmap).

## Backend

### Endpoint

`GET /workers/me/applications` in `backend/app/routers/workers.py`, guarded by
`require_worker`. Mirrors the existing `GET /employers/me/jobs` pattern.

Logic:
1. Fetch `applications` rows where `worker_id = current_user["id"]`, ordered by
   `created_at` desc.
2. Collect their `job_id`s; fetch `jobs` with `*, categories(name)`.
3. Enrich job rows via the existing `job_service._enrich_rows_batch`.
4. For each application, attach `application_id` and `application_status` onto
   the matching enriched job dict.
5. Group by application status into `{pending, accepted, rejected, withdrawn}`.

Applications whose job row is missing (deleted) are skipped.

### Schema

In `backend/app/schemas/jobs.py`:

```python
class WorkerApplicationJob(JobResponse):
    application_id: UUID4
    application_status: str

class WorkerApplicationsGroupedResponse(BaseModel):
    pending: list[WorkerApplicationJob]
    accepted: list[WorkerApplicationJob]
    rejected: list[WorkerApplicationJob]
    withdrawn: list[WorkerApplicationJob]
```

### Withdraw

Reuses the existing `PATCH /applications/{application_id}` with
`status=withdrawn`. No new backend endpoint. Service already enforces the
"accepted → withdrawn before start date only" rule and worker ownership.

### Tests

`backend/tests/` — pytest hitting the live dev DB (project convention, no
mocking, `get_current_user` override). Cover:
- Worker sees only their own applications, correctly grouped by status.
- Role enforcement: an employer token gets 403.
- A withdrawn application appears in the `withdrawn` bucket.

## Frontend

### Repository

`getMyApplications()` in `api_application_repository.dart` →
`Future<WorkerApplicationsGrouped>`. Calls `GET /workers/me/applications`,
parses each bucket into `JobModel` plus the two extra fields. New value class
`WorkerApplicationsGrouped { pending, accepted, rejected, withdrawn }` holding
`List<WorkerApplicationItem>` where `WorkerApplicationItem` wraps a `JobModel`,
`applicationId`, and `applicationStatus`.

### Provider

`myApplicationsProvider` — `FutureProvider.autoDispose<WorkerApplicationsGrouped>`,
mirrors `myPostedJobsProvider`. Invalidated after a withdraw to refresh.

### Screen

`screens/worker/worker_jobs_screen.dart` — `WorkerJobsScreen`:
- Chip/tab filter bar: **All · Pending · Accepted · Done** (Done = rejected +
  withdrawn). Local `StateProvider`/`useState` for selected filter.
- Body reuses `JobCard` in a `ListView.builder`, with `RefreshIndicator` and
  the same loading / error-retry / empty-state widgets as `WorkerHomeScreen`
  (empty copy: "You haven't applied to any jobs yet").
- Card tap → `context.push('/worker/jobs/${job.id}')` (existing detail route).
- Pending cards, and accepted cards before `startDate`, show a **Withdraw**
  button → `PATCH /applications/{id}` then invalidate `myApplicationsProvider`.

### Widgets

`ApplicationStatusBadge` (`screens/shared/widgets/`) — color-coded badge for the
four application statuses (pending=amber, accepted=green, rejected=grey,
withdrawn=grey). `StatusBadge` is left unchanged (it only models the 5 job
statuses).

`JobCard` gains an optional `applicationStatus` param. When set: render
`ApplicationStatusBadge` in place of the job `StatusBadge`, and suppress the
Apply/phone button row (replaced by the optional Withdraw button passed in).

### Routing

- New `GoRoute(path: '/worker/jobs')` inside the worker `ShellRoute` in
  `app_router.dart`, rendering `WorkerJobsScreen`. Keep `/worker/jobs/:id` for
  detail.
- `worker_shell.dart`: `onTap` case 1 → `context.go('/worker/jobs')`;
  `_currentIndex` returns 1 when path is exactly `/worker/jobs` OR starts with
  `/worker/jobs/` (detail still highlights the Jobs tab).

## Data Flow

Jobs tab tap → `/worker/jobs` → `WorkerJobsScreen` watches
`myApplicationsProvider` → repo → `GET /workers/me/applications` → grouped
`JobModel`s → filtered by selected chip → `JobCard` list. Withdraw → PATCH →
invalidate provider → reload.

## Error Handling

- Endpoint: 403 for non-workers; empty buckets (not error) when no applications.
- Screen: error state with Retry (re-fetch provider), mirroring home.
- Withdraw failure (e.g. past start date): show SnackBar with backend message,
  leave list unchanged.

## Files

**New:** `worker_jobs_screen.dart`, `application_status_badge.dart`,
`my_applications_provider.dart`, backend test file.
**Modified:** `workers.py`, `schemas/jobs.py`, `api_application_repository.dart`,
`job_card.dart`, `app_router.dart`, `worker_shell.dart`, language strings.
