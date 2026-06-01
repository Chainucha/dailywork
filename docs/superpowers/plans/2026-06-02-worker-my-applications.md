# Worker "My Applications" Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the worker bottom-nav "Jobs" tab show the worker's job applications (grouped by status, with withdraw), wired to a new backend endpoint.

**Architecture:** New `GET /workers/me/applications` endpoint mirrors the existing `/employers/me/jobs` grouping pattern, reusing `job_service._enrich_rows_batch`. Flutter side adds a repository method, a Riverpod `FutureProvider`, a `WorkerJobsScreen` with status-filter chips reusing `JobCard`, a new `/worker/jobs` route, and fixes the dead Jobs-tab navigation in `worker_shell.dart`.

**Tech Stack:** FastAPI + Supabase (Python 3.11), pytest (live dev DB, no mocking); Flutter + Riverpod + go_router + Dio.

---

## File Structure

**Backend**
- Modify `backend/app/schemas/jobs.py` — add `WorkerApplicationJob`, `WorkerApplicationsGroupedResponse`.
- Modify `backend/app/routers/workers.py` — add `GET /me/applications`.
- Create `backend/tests/test_workers_me_applications.py` — endpoint tests.

**Frontend**
- Modify `dailywork/lib/repositories/job_repository.dart` — add `WorkerApplicationItem`, `WorkerApplicationsGrouped` value classes.
- Modify `dailywork/lib/repositories/api/api_application_repository.dart` — add `getMyApplications()`.
- Create `dailywork/lib/providers/my_applications_provider.dart` — `myApplicationsProvider`.
- Create `dailywork/lib/screens/shared/widgets/application_status_badge.dart` — `ApplicationStatusBadge`.
- Modify `dailywork/lib/screens/shared/widgets/job_card.dart` — optional `applicationStatus` + `trailing` slot.
- Create `dailywork/lib/screens/worker/worker_jobs_screen.dart` — `WorkerJobsScreen`.
- Modify `dailywork/lib/core/router/app_router.dart` — add `/worker/jobs` route.
- Modify `dailywork/lib/screens/worker/worker_shell.dart` — fix Jobs-tab nav + index.
- Modify `dailywork/lib/providers/language_provider.dart` — add strings.
- Create `dailywork/test/worker_applications_parse_test.dart` — repo-model parse unit test.

---

## Task 1: Backend response schemas

**Files:**
- Modify: `backend/app/schemas/jobs.py` (append after `EmployerJobsGroupedResponse`, line 94)

- [ ] **Step 1: Add the two schema classes**

Append to `backend/app/schemas/jobs.py`:

```python


class WorkerApplicationJob(JobResponse):
    application_id: UUID
    application_status: str


class WorkerApplicationsGroupedResponse(BaseModel):
    pending: list[WorkerApplicationJob] = []
    accepted: list[WorkerApplicationJob] = []
    rejected: list[WorkerApplicationJob] = []
    withdrawn: list[WorkerApplicationJob] = []
```

(`UUID` and `BaseModel` are already imported at the top of the file.)

- [ ] **Step 2: Verify it imports cleanly**

Run: `cd backend && python -c "from app.schemas.jobs import WorkerApplicationsGroupedResponse; print('ok')"`
Expected: prints `ok`

- [ ] **Step 3: Commit**

```bash
git add backend/app/schemas/jobs.py
git commit -m "feat(backend): worker applications grouped response schema"
```

---

## Task 2: Backend endpoint (TDD)

**Files:**
- Test: `backend/tests/test_workers_me_applications.py` (create)
- Modify: `backend/app/routers/workers.py`

**Note:** Tests hit the live dev DB (project convention — no mocking). They require `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` env vars. The `applications.workers_assigned`-style triggers do not affect this endpoint.

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_workers_me_applications.py`:

```python
import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user, require_worker
from app.supabase_client import get_supabase

client = TestClient(app)


@pytest.fixture
def seeded_worker_with_applications():
    """One worker who applied to 3 jobs: pending, accepted, withdrawn."""
    db = get_supabase()
    wid = str(uuid.uuid4())
    eid = str(uuid.uuid4())
    db.table("users").insert(
        {"id": wid, "phone_number": f"+1{wid[:10]}", "user_type": "worker"}
    ).execute()
    db.table("worker_profiles").insert({"user_id": wid}).execute()
    db.table("users").insert(
        {"id": eid, "phone_number": f"+1{eid[:10]}", "user_type": "employer"}
    ).execute()
    db.table("employer_profiles").insert(
        {"user_id": eid, "business_name": "AppCo"}
    ).execute()
    cat_id = db.table("categories").select("id").limit(1).execute().data[0]["id"]

    job_ids = []
    for app_status in ("pending", "accepted", "withdrawn"):
        job = db.table("jobs").insert({
            "employer_id": eid,
            "category_id": cat_id,
            "title": f"app-job-{app_status}-{uuid.uuid4()}",
            "location_lat": 0, "location_lng": 0,
            "wage_per_day": 100, "workers_needed": 1,
            "start_date": "2026-01-01", "end_date": "2026-01-02",
            "status": "open",
        }).execute().data[0]
        job_ids.append(job["id"])
        db.table("applications").insert({
            "job_id": job["id"],
            "worker_id": wid,
            "status": app_status,
        }).execute()

    yield wid
    db.table("applications").delete().eq("worker_id", wid).execute()
    for jid in job_ids:
        db.table("jobs").delete().eq("id", jid).execute()
    db.table("worker_profiles").delete().eq("user_id", wid).execute()
    db.table("employer_profiles").delete().eq("user_id", eid).execute()
    db.table("users").delete().eq("id", wid).execute()
    db.table("users").delete().eq("id", eid).execute()


def test_worker_me_applications_groups_by_status(seeded_worker_with_applications):
    fake = {"id": seeded_worker_with_applications, "user_type": "worker"}
    app.dependency_overrides[get_current_user] = lambda: fake
    app.dependency_overrides[require_worker] = lambda: fake
    try:
        res = client.get("/api/v1/workers/me/applications")
        assert res.status_code == 200, res.text
        body = res.json()
        assert len(body["pending"]) == 1
        assert len(body["accepted"]) == 1
        assert len(body["withdrawn"]) == 1
        assert len(body["rejected"]) == 0
        # each job row carries the application metadata
        row = body["pending"][0]
        assert row["application_status"] == "pending"
        assert "application_id" in row
        assert "title" in row and "wage_per_day" in row
    finally:
        app.dependency_overrides.clear()


def test_worker_me_applications_requires_worker(seeded_worker_with_applications):
    # An employer identity must be rejected by require_worker.
    fake_employer = {"id": str(uuid.uuid4()), "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake_employer
    try:
        res = client.get("/api/v1/workers/me/applications")
        assert res.status_code == 403, res.text
    finally:
        app.dependency_overrides.clear()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd backend && pytest tests/test_workers_me_applications.py -v`
Expected: `test_worker_me_applications_groups_by_status` FAILS with 404 (route not defined yet). `test_worker_me_applications_requires_worker` may already pass (404 vs 403) — ignore until impl.

- [ ] **Step 3: Implement the endpoint**

In `backend/app/routers/workers.py`, update the imports at the top:

```python
from fastapi import APIRouter, Depends, HTTPException
from app.dependencies import get_current_user, require_worker
from app.schemas.workers import WorkerProfileResponse, WorkerProfileUpdate
from app.schemas.jobs import WorkerApplicationsGroupedResponse
from app.services.job_service import _enrich_rows_batch
from app.supabase_client import get_supabase
```

Then add this route (place it after `update_my_profile`, before `get_worker_profile` at line 55, so the static `/me/applications` path is declared before `/{user_id}/profile`):

```python
@router.get("/me/applications", response_model=WorkerApplicationsGroupedResponse)
async def get_my_applications(current_user: dict = Depends(require_worker)):
    db = get_supabase()

    apps = (
        db.table("applications")
        .select("id, job_id, status, created_at")
        .eq("worker_id", current_user["id"])
        .order("created_at", desc=True)
        .execute()
        .data
        or []
    )
    if not apps:
        return {"pending": [], "accepted": [], "rejected": [], "withdrawn": []}

    job_ids = [a["job_id"] for a in apps]
    job_rows = (
        db.table("jobs")
        .select("*, categories(name)")
        .in_("id", job_ids)
        .execute()
        .data
        or []
    )
    enriched = {r["id"]: r for r in _enrich_rows_batch(db, job_rows)}

    grouped = {"pending": [], "accepted": [], "rejected": [], "withdrawn": []}
    for a in apps:
        job = enriched.get(a["job_id"])
        if job is None:  # job deleted — skip orphaned application
            continue
        bucket = grouped.get(a["status"])
        if bucket is None:
            continue
        row = dict(job)
        row["application_id"] = a["id"]
        row["application_status"] = a["status"]
        bucket.append(row)
    return grouped
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd backend && pytest tests/test_workers_me_applications.py -v`
Expected: both tests PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/workers.py backend/tests/test_workers_me_applications.py
git commit -m "feat(backend): GET /workers/me/applications grouped by status"
```

---

## Task 3: Frontend repository model + method

**Files:**
- Modify: `dailywork/lib/repositories/job_repository.dart` (add value classes after `EmployerJobsGrouped`, line 26)
- Modify: `dailywork/lib/repositories/api/api_application_repository.dart`

- [ ] **Step 1: Add value classes to `job_repository.dart`**

Insert after the `EmployerJobsGrouped` class (after line 26), before `abstract class JobRepository`:

```dart
class WorkerApplicationItem {
  final JobModel job;
  final String applicationId;
  final String applicationStatus; // pending | accepted | rejected | withdrawn
  const WorkerApplicationItem({
    required this.job,
    required this.applicationId,
    required this.applicationStatus,
  });
}

class WorkerApplicationsGrouped {
  final List<WorkerApplicationItem> pending;
  final List<WorkerApplicationItem> accepted;
  final List<WorkerApplicationItem> rejected;
  final List<WorkerApplicationItem> withdrawn;
  const WorkerApplicationsGrouped({
    required this.pending,
    required this.accepted,
    required this.rejected,
    required this.withdrawn,
  });

  List<WorkerApplicationItem> get all =>
      [...pending, ...accepted, ...rejected, ...withdrawn];

  factory WorkerApplicationsGrouped.fromJson(Map<String, dynamic> json) {
    List<WorkerApplicationItem> parse(String key) =>
        ((json[key] as List<dynamic>?) ?? []).map((e) {
      final m = e as Map<String, dynamic>;
      return WorkerApplicationItem(
        job: JobModel.fromJson(m),
        applicationId: m['application_id'] as String,
        applicationStatus: m['application_status'] as String,
      );
    }).toList();
    return WorkerApplicationsGrouped(
      pending: parse('pending'),
      accepted: parse('accepted'),
      rejected: parse('rejected'),
      withdrawn: parse('withdrawn'),
    );
  }
}
```

- [ ] **Step 2: Add `getMyApplications()` to the API repository**

In `dailywork/lib/repositories/api/api_application_repository.dart`, add the import at the top (after line 3):

```dart
import 'package:dailywork/repositories/job_repository.dart';
```

Add this method inside `ApiApplicationRepository` (after `withdraw`, before the closing brace at line 89):

```dart
  Future<WorkerApplicationsGrouped> getMyApplications() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/workers/me/applications');
    return WorkerApplicationsGrouped.fromJson(response.data!);
  }
```

- [ ] **Step 3: Add a parse unit test**

Create `dailywork/test/worker_applications_parse_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywork/repositories/job_repository.dart';

void main() {
  test('WorkerApplicationsGrouped.fromJson parses buckets and metadata', () {
    final json = {
      'pending': [
        {
          'id': 'job-1',
          'employer_id': 'emp-1',
          'category_id': 'cat-1',
          'title': 'Test job',
          'location_lat': 0.0,
          'location_lng': 0.0,
          'wage_per_day': 100,
          'workers_needed': 1,
          'workers_assigned': 0,
          'status': 'open',
          'start_date': '2026-01-01',
          'end_date': '2026-01-02',
          'created_at': '2026-01-01T00:00:00Z',
          'application_id': 'app-1',
          'application_status': 'pending',
        }
      ],
      'accepted': [],
      'rejected': [],
      'withdrawn': [],
    };

    final grouped = WorkerApplicationsGrouped.fromJson(json);

    expect(grouped.pending.length, 1);
    expect(grouped.pending.first.applicationId, 'app-1');
    expect(grouped.pending.first.applicationStatus, 'pending');
    expect(grouped.pending.first.job.title, 'Test job');
    expect(grouped.all.length, 1);
  });
}
```

- [ ] **Step 4: Run the test**

Run: `cd dailywork && flutter test test/worker_applications_parse_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add dailywork/lib/repositories/job_repository.dart dailywork/lib/repositories/api/api_application_repository.dart dailywork/test/worker_applications_parse_test.dart
git commit -m "feat(app): worker applications repository model + parse test"
```

---

## Task 4: Riverpod provider

**Files:**
- Create: `dailywork/lib/providers/my_applications_provider.dart`

- [ ] **Step 1: Create the provider**

Create `dailywork/lib/providers/my_applications_provider.dart` (mirrors `my_posted_jobs_provider.dart`):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/repositories/api/api_application_repository.dart';
import 'package:dailywork/repositories/job_repository.dart';

final myApplicationsProvider =
    FutureProvider.autoDispose<WorkerApplicationsGrouped>((ref) async {
  final repo = ref.watch(apiApplicationRepositoryProvider);
  return repo.getMyApplications();
});
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `cd dailywork && flutter analyze lib/providers/my_applications_provider.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/providers/my_applications_provider.dart
git commit -m "feat(app): myApplicationsProvider"
```

---

## Task 5: ApplicationStatusBadge widget

**Files:**
- Create: `dailywork/lib/screens/shared/widgets/application_status_badge.dart`

- [ ] **Step 1: Create the widget**

Create `dailywork/lib/screens/shared/widgets/application_status_badge.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailywork/providers/language_provider.dart';

/// Color-coded badge for an application status
/// (pending | accepted | rejected | withdrawn). Distinct from [StatusBadge],
/// which models the five *job* statuses.
class ApplicationStatusBadge extends ConsumerWidget {
  final String status;
  const ApplicationStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    late final Color color;
    late final String label;
    switch (status) {
      case 'accepted':
        color = const Color(0xFF388E3C); // green
        label = strings['accepted_label'] ?? 'Accepted';
      case 'pending':
        color = const Color(0xFFF57C00); // amber/orange
        label = strings['pending_label'] ?? 'Pending';
      case 'rejected':
        color = Colors.grey;
        label = strings['rejected_label'] ?? 'Rejected';
      case 'withdrawn':
        color = Colors.grey;
        label = strings['withdrawn_label'] ?? 'Withdrawn';
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `cd dailywork && flutter analyze lib/screens/shared/widgets/application_status_badge.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/screens/shared/widgets/application_status_badge.dart
git commit -m "feat(app): ApplicationStatusBadge widget"
```

---

## Task 6: JobCard — optional application view

**Files:**
- Modify: `dailywork/lib/screens/shared/widgets/job_card.dart`

The card currently shows either an `URGENT` chip or a job `StatusBadge` (line 113-132), and either an Apply/phone row or applicant count (line 192-251). Add an `applicationStatus` mode that shows the `ApplicationStatusBadge` and replaces the action row with an optional `trailing` widget (the Withdraw button).

- [ ] **Step 1: Add imports and fields**

In `dailywork/lib/screens/shared/widgets/job_card.dart`, add after line 7 (`status_badge.dart` import):

```dart
import 'package:dailywork/screens/shared/widgets/application_status_badge.dart';
```

Replace the field/constructor block (lines 47-56):

```dart
  final JobModel job;
  final VoidCallback onTap;
  final bool isEmployerView;

  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.isEmployerView = false,
  });
```

with:

```dart
  final JobModel job;
  final VoidCallback onTap;
  final bool isEmployerView;

  /// When set, the card renders in "my application" mode: shows an
  /// [ApplicationStatusBadge] instead of the job status badge, and renders
  /// [trailing] (e.g. a Withdraw button) in place of the apply/applicant row.
  final String? applicationStatus;
  final Widget? trailing;

  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.isEmployerView = false,
    this.applicationStatus,
    this.trailing,
  });
```

- [ ] **Step 2: Show the application badge**

Replace the badge `else` branch (lines 131-132):

```dart
                        else
                          StatusBadge(status: job.status),
```

with:

```dart
                        else if (applicationStatus != null)
                          ApplicationStatusBadge(status: applicationStatus!)
                        else
                          StatusBadge(status: job.status),
```

- [ ] **Step 3: Swap the action row for the trailing slot in application mode**

Replace the action block (lines 191-251), which currently begins
`if (!isEmployerView)` and ends with the applicant-count `Text(...)` in the
`else`, with:

```dart
                    // Apply + phone buttons  OR  applicant count  OR  trailing
                    if (applicationStatus != null)
                      (trailing ?? const SizedBox.shrink())
                    else if (!isEmployerView)
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton(
                                onPressed: () {
                                  final message =
                                      '${strings['apply_success'] ?? 'Application submitted successfully'}: ${job.title}';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                ),
                                child: Text(
                                  strings['apply'] ?? 'Apply',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 38,
                            height: 38,
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              child: Icon(Icons.phone_outlined,
                                  size: 18, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        '${job.applicantCount} ${strings['applicants'] ?? 'applicants'}',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
```

- [ ] **Step 4: Verify it analyzes clean**

Run: `cd dailywork && flutter analyze lib/screens/shared/widgets/job_card.dart`
Expected: "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add dailywork/lib/screens/shared/widgets/job_card.dart
git commit -m "feat(app): JobCard supports application-status view + trailing slot"
```

---

## Task 7: Language strings

**Files:**
- Modify: `dailywork/lib/providers/language_provider.dart`

- [ ] **Step 1: Add English strings**

In `_enStrings`, add before the closing `};` (after line 96 `'no_rating': 'New',`):

```dart
  'my_applications': 'My Applications',
  'tab_all': 'All',
  'tab_pending': 'Pending',
  'tab_accepted': 'Accepted',
  'tab_done': 'Done',
  'withdraw': 'Withdraw',
  'no_applications': "You haven't applied to any jobs yet",
  'application_withdrawn': 'Application withdrawn',
```

- [ ] **Step 2: Add Kannada strings**

In `_knStrings`, add before its closing `};` (the Kannada map starts at line 100):

```dart
  'my_applications': 'ನನ್ನ ಅರ್ಜಿಗಳು',
  'tab_all': 'ಎಲ್ಲಾ',
  'tab_pending': 'ಬಾಕಿ',
  'tab_accepted': 'ಸ್ವೀಕೃತ',
  'tab_done': 'ಮುಗಿದಿದೆ',
  'withdraw': 'ಹಿಂಪಡೆಯಿರಿ',
  'no_applications': 'ನೀವು ಇನ್ನೂ ಯಾವುದೇ ಕೆಲಸಕ್ಕೆ ಅರ್ಜಿ ಸಲ್ಲಿಸಿಲ್ಲ',
  'application_withdrawn': 'ಅರ್ಜಿ ಹಿಂಪಡೆಯಲಾಗಿದೆ',
```

- [ ] **Step 3: Verify it analyzes clean**

Run: `cd dailywork && flutter analyze lib/providers/language_provider.dart`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add dailywork/lib/providers/language_provider.dart
git commit -m "feat(app): strings for worker applications tab"
```

---

## Task 8: WorkerJobsScreen

**Files:**
- Create: `dailywork/lib/screens/worker/worker_jobs_screen.dart`

The screen mirrors `WorkerHomeScreen`'s loading/error/empty/RefreshIndicator structure. A local filter chip bar selects All / Pending / Accepted / Done (Done = rejected + withdrawn). Pending items — and accepted items whose `startDate` is in the future — get a Withdraw button via `JobCard.trailing`.

- [ ] **Step 1: Create the screen**

Create `dailywork/lib/screens/worker/worker_jobs_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/providers/my_applications_provider.dart';
import 'package:dailywork/repositories/api/api_application_repository.dart';
import 'package:dailywork/repositories/job_repository.dart';
import 'package:dailywork/screens/shared/widgets/job_card.dart';
import 'package:dailywork/screens/shared/widgets/language_toggle_button.dart';

enum _AppFilter { all, pending, accepted, done }

final _filterProvider =
    StateProvider.autoDispose<_AppFilter>((ref) => _AppFilter.all);

class WorkerJobsScreen extends ConsumerWidget {
  const WorkerJobsScreen({super.key});

  List<WorkerApplicationItem> _select(
      WorkerApplicationsGrouped g, _AppFilter f) {
    switch (f) {
      case _AppFilter.all:
        return g.all;
      case _AppFilter.pending:
        return g.pending;
      case _AppFilter.accepted:
        return g.accepted;
      case _AppFilter.done:
        return [...g.rejected, ...g.withdrawn];
    }
  }

  Future<void> _withdraw(
      BuildContext context, WidgetRef ref, String applicationId) async {
    final strings = ref.read(stringsProvider);
    try {
      await ref.read(apiApplicationRepositoryProvider).withdraw(applicationId);
      ref.invalidate(myApplicationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  strings['application_withdrawn'] ?? 'Application withdrawn')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(strings['action_failed_toast'] ?? 'Action failed — try again')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final async = ref.watch(myApplicationsProvider);
    final filter = ref.watch(_filterProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(
          strings['my_applications'] ?? 'My Applications',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [LanguageToggleButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _FilterBar(selected: filter),
          const SizedBox(height: 8),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load applications',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(myApplicationsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              data: (grouped) {
                final items = _select(grouped, filter);
                return RefreshIndicator(
                  color: AppTheme.accent,
                  onRefresh: () async => ref.invalidate(myApplicationsProvider),
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.work_off_outlined,
                                        size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      strings['no_applications'] ??
                                          "You haven't applied to any jobs yet",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.nunito(
                                        fontSize: 16,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final canWithdraw = item.applicationStatus ==
                                    'pending' ||
                                (item.applicationStatus == 'accepted' &&
                                    item.job.startDate.isAfter(DateTime.now()));
                            return JobCard(
                              job: item.job,
                              applicationStatus: item.applicationStatus,
                              onTap: () =>
                                  context.push('/worker/jobs/${item.job.id}'),
                              trailing: canWithdraw
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _withdraw(
                                            context, ref, item.applicationId),
                                        icon: const Icon(Icons.close, size: 16),
                                        label: Text(
                                            strings['withdraw'] ?? 'Withdraw'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red[700],
                                          side: BorderSide(
                                              color: Colors.red[200]!),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final _AppFilter selected;
  const _FilterBar({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final entries = <(_AppFilter, String)>[
      (_AppFilter.all, strings['tab_all'] ?? 'All'),
      (_AppFilter.pending, strings['tab_pending'] ?? 'Pending'),
      (_AppFilter.accepted, strings['tab_accepted'] ?? 'Accepted'),
      (_AppFilter.done, strings['tab_done'] ?? 'Done'),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label) = entries[i];
          final isSel = value == selected;
          return ChoiceChip(
            label: Text(label),
            selected: isSel,
            onSelected: (_) =>
                ref.read(_filterProvider.notifier).state = value,
            selectedColor: AppTheme.accent,
            labelStyle: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              color: isSel ? Colors.white : Colors.grey[700],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `cd dailywork && flutter analyze lib/screens/worker/worker_jobs_screen.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/screens/worker/worker_jobs_screen.dart
git commit -m "feat(app): WorkerJobsScreen with status filter + withdraw"
```

---

## Task 9: Route + fix dead Jobs tab

**Files:**
- Modify: `dailywork/lib/core/router/app_router.dart`
- Modify: `dailywork/lib/screens/worker/worker_shell.dart`

- [ ] **Step 1: Add the route import**

In `dailywork/lib/core/router/app_router.dart`, add an import alongside the other worker screen imports (search for `worker_home_screen.dart` and add next to it):

```dart
import 'package:dailywork/screens/worker/worker_jobs_screen.dart';
```

- [ ] **Step 2: Register `/worker/jobs` in the worker ShellRoute**

In the worker `ShellRoute` (lines 146-164), add a `GoRoute` between `/worker/home` (line 149-152) and `/worker/jobs/:id` (line 153-158):

```dart
          GoRoute(
            path: '/worker/jobs',
            builder: (context, state) => const WorkerJobsScreen(),
          ),
```

Result order: `/worker/home`, `/worker/jobs`, `/worker/jobs/:id`, `/worker/profile`. The static `/worker/jobs` precedes the dynamic `/worker/jobs/:id`.

- [ ] **Step 3: Fix the Jobs-tab navigation**

In `dailywork/lib/screens/worker/worker_shell.dart`, replace the `onTap` switch (lines 43-52):

```dart
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/worker/home');
            case 1:
              context.go('/worker/home');
            case 2:
              context.go('/worker/profile');
          }
        },
```

with:

```dart
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/worker/home');
            case 1:
              context.go('/worker/jobs');
            case 2:
              context.go('/worker/profile');
          }
        },
```

- [ ] **Step 4: Fix the selected-index detection**

Replace `_currentIndex` (lines 14-19):

```dart
  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.contains('/worker/profile')) return 2;
    if (location.contains('/worker/jobs/')) return 1;
    return 0;
  }
```

with:

```dart
  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.contains('/worker/profile')) return 2;
    if (location.contains('/worker/jobs')) return 1; // list and /jobs/:id detail
    return 0;
  }
```

- [ ] **Step 5: Verify analyze + full test suite**

Run: `cd dailywork && flutter analyze`
Expected: "No issues found!"

Run: `cd dailywork && flutter test`
Expected: all tests PASS (including the new parse test).

- [ ] **Step 6: Commit**

```bash
git add dailywork/lib/core/router/app_router.dart dailywork/lib/screens/worker/worker_shell.dart
git commit -m "feat(app): wire worker Jobs tab to /worker/jobs"
```

---

## Final Verification

- [ ] **Backend tests**

Run: `cd backend && pytest tests/test_workers_me_applications.py -v`
Expected: 2 passed.

- [ ] **Flutter analyze + tests**

Run: `cd dailywork && flutter analyze && flutter test`
Expected: no issues; all tests pass.

- [ ] **Manual smoke (optional, requires running stack)**

Log in as a worker who has applied to jobs → tap the Jobs tab → see grouped
applications, filter chips work, tab highlights, withdraw on a pending item
removes it from Pending and shows the toast.
```
