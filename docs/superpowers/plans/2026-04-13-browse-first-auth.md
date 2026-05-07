# Browse-First Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users browse the job feed and view job details without logging in; require authentication only when they attempt a protected action (apply, post job, view profile).

**Architecture:** Reuse existing `WorkerHomeScreen` and `WorkerJobDetailScreen` as the guest landing pages — no duplicate browse screens. Add a `guest` auth status and a `BrowseShell` (different bottom nav with Login tab). Backend gets an `optional_current_user` dependency for public endpoints. The Apply button gets an auth gate that saves the intended destination, runs the OTP flow, and resumes the action on success.

**Tech Stack:** Flutter (go_router, flutter_riverpod, dio), FastAPI (Python), Supabase PostgreSQL

---

## File Structure

### Backend (Python)

| File | Action | Responsibility |
|---|---|---|
| `backend/app/dependencies.py` | Modify | Add `optional_current_user` dependency (returns user dict or `None`) |
| `backend/app/routers/jobs.py` | Modify | Switch `list_jobs` and `get_job` to use `optional_current_user` |
| `backend/app/routers/categories.py` | Modify | Switch `list_categories` to use `optional_current_user` |
| `backend/tests/test_dependencies.py` | Modify | Add tests for `optional_current_user` |
| `backend/tests/test_public_endpoints.py` | Create | Tests that public endpoints work without auth |

### Frontend (Dart)

| File | Action | Responsibility |
|---|---|---|
| `dailywork/lib/providers/auth_provider.dart` | Modify | Add `guest` status, `pendingRedirect` field, `browseAsGuest()` |
| `dailywork/lib/core/router/app_router.dart` | Modify | Add `/browse` routes that render existing worker screens inside `BrowseShell`, handle pending redirect on auth |
| `dailywork/lib/core/router/auth_gate.dart` | Create | `requireAuth()` helper — checks auth, saves intended path, redirects to login |
| `dailywork/lib/screens/browse/browse_shell.dart` | Create | Bottom nav shell for guest users (Jobs + Login tabs) |
| `dailywork/lib/screens/worker/worker_home_screen.dart` | Modify | Make job card `onTap` path dynamic based on current route prefix (`/browse/` vs `/worker/`) |
| `dailywork/lib/screens/worker/worker_job_detail_screen.dart` | Modify | Wrap Apply button with `requireAuth()` for guest users |
| `dailywork/lib/screens/auth/phone_login_screen.dart` | Modify | Add "Continue browsing" link for guests |

---

## Task 1: Backend — Add `optional_current_user` Dependency

**Files:**
- Modify: `backend/app/dependencies.py:58-91`
- Test: `backend/tests/test_dependencies.py`

- [ ] **Step 1: Write the failing test for optional_current_user**

Add to the end of `backend/tests/test_dependencies.py`:

```python
import pytest
from unittest.mock import patch
from fastapi.security import HTTPAuthorizationCredentials
from app.dependencies import optional_current_user


@pytest.mark.asyncio
async def test_optional_current_user_returns_none_without_token():
    """When no Authorization header is present, should return None."""
    result = await optional_current_user(credentials=None)
    assert result is None


@pytest.mark.asyncio
async def test_optional_current_user_returns_user_with_valid_token():
    """When a valid token is present, should return the user dict."""
    mock_credentials = HTTPAuthorizationCredentials(
        scheme="Bearer", credentials="valid-token"
    )
    fake_user = {"id": "user-123", "user_type": "worker", "is_active": True}

    with patch("app.dependencies.get_current_user", return_value=fake_user):
        result = await optional_current_user(credentials=mock_credentials)
        assert result == fake_user


@pytest.mark.asyncio
async def test_optional_current_user_returns_none_on_invalid_token():
    """When token is invalid/expired, should return None (not raise)."""
    mock_credentials = HTTPAuthorizationCredentials(
        scheme="Bearer", credentials="expired-token"
    )

    with patch("app.dependencies.get_current_user", side_effect=Exception("Invalid")):
        result = await optional_current_user(credentials=mock_credentials)
        assert result is None
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd backend && python -m pytest tests/test_dependencies.py -v -k "optional"`
Expected: FAIL — `ImportError: cannot import name 'optional_current_user'`

- [ ] **Step 3: Implement `optional_current_user` in dependencies.py**

Add after the existing `get_current_user` function in `backend/app/dependencies.py`:

```python
optional_bearer = HTTPBearer(auto_error=False)


async def optional_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_bearer),
) -> dict | None:
    """Like get_current_user but returns None instead of raising 401.

    Used for public endpoints where auth enhances (but isn't required for) the response.
    """
    if credentials is None:
        return None
    try:
        return await get_current_user(credentials)
    except Exception:
        return None
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd backend && python -m pytest tests/test_dependencies.py -v -k "optional"`
Expected: PASS — all 3 tests green

- [ ] **Step 5: Commit**

```bash
git add backend/app/dependencies.py backend/tests/test_dependencies.py
git commit -m "feat: add optional_current_user dependency for public endpoints"
```

---

## Task 2: Backend — Make Jobs and Categories Endpoints Public

**Files:**
- Modify: `backend/app/routers/jobs.py:22-36` (list_jobs) and `backend/app/routers/jobs.py:59-71` (get_job)
- Modify: `backend/app/routers/categories.py:15-19` (list_categories)
- Test: `backend/tests/test_public_endpoints.py`

- [ ] **Step 1: Write failing tests for public access**

Create `backend/tests/test_public_endpoints.py`:

```python
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_list_jobs_without_auth():
    """GET /api/v1/jobs/ should return 200 without Authorization header."""
    response = client.get("/api/v1/jobs/", params={"lat": 12.97, "lng": 77.59})
    assert response.status_code != 401
    assert response.status_code != 403


def test_list_categories_without_auth():
    """GET /api/v1/categories/ should return 200 without Authorization header."""
    response = client.get("/api/v1/categories/")
    assert response.status_code != 401
    assert response.status_code != 403


def test_get_job_without_auth():
    """GET /api/v1/jobs/{id} should not return 401 without Authorization header."""
    response = client.get("/api/v1/jobs/00000000-0000-0000-0000-000000000000")
    assert response.status_code != 401
    assert response.status_code != 403


def test_create_job_still_requires_auth():
    """POST /api/v1/jobs/ must still require auth."""
    response = client.post("/api/v1/jobs/", json={
        "title": "test",
        "category_id": "00000000-0000-0000-0000-000000000000",
        "location_lat": 12.97,
        "location_lng": 77.59,
        "wage_per_day": 500,
        "workers_needed": 1,
        "start_date": "2026-05-01",
    })
    assert response.status_code in (401, 403)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/test_public_endpoints.py -v`
Expected: `test_list_jobs_without_auth` FAILS (gets 403), `test_list_categories_without_auth` FAILS (gets 403)

- [ ] **Step 3: Update `list_jobs` to use optional auth**

In `backend/app/routers/jobs.py`, add the import and change the `list_jobs` signature:

```python
from app.dependencies import get_current_user, require_employer, optional_current_user

@router.get("/", response_model=JobListResponse)
async def list_jobs(
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    radius_km: float = Query(25.0, gt=0, le=200),
    category_id: str | None = Query(None),
    status: str = Query("open"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: dict | None = Depends(optional_current_user),
):
```

- [ ] **Step 4: Update `get_job` to use optional auth**

In `backend/app/routers/jobs.py`, change the `get_job` signature:

```python
@router.get("/{job_id}", response_model=JobResponse)
async def get_job(
    job_id: str,
    current_user: dict | None = Depends(optional_current_user),
):
```

- [ ] **Step 5: Update `list_categories` to use optional auth**

In `backend/app/routers/categories.py`:

```python
from app.dependencies import optional_current_user

@router.get("/", response_model=list[CategoryResponse])
async def list_categories(current_user: dict | None = Depends(optional_current_user)):
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/test_public_endpoints.py -v`
Expected: All 4 tests PASS

- [ ] **Step 7: Run all existing backend tests to check for regressions**

Run: `cd backend && python -m pytest -v`
Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add backend/app/routers/jobs.py backend/app/routers/categories.py backend/tests/test_public_endpoints.py
git commit -m "feat: make jobs list, job detail, and categories endpoints public"
```

---

## Task 3: Frontend — Extend AuthState with Guest Status

**Files:**
- Modify: `dailywork/lib/providers/auth_provider.dart`

- [ ] **Step 1: Add `guest` to the `AuthStatus` enum**

In `dailywork/lib/providers/auth_provider.dart`, change line 7:

```dart
enum AuthStatus { unknown, unauthenticated, guest, authenticated }
```

- [ ] **Step 2: Add `pendingRedirect` field to `AuthState`**

Replace the `AuthState` class (lines 9-18):

```dart
class AuthState {
  final UserModel? user;
  final AuthStatus status;
  /// Path to navigate to after successful login (set by auth gate).
  final String? pendingRedirect;

  const AuthState({this.user, required this.status, this.pendingRedirect});

  AuthState copyWith({
    UserModel? user,
    AuthStatus? status,
    String? pendingRedirect,
    bool clearRedirect = false,
  }) =>
      AuthState(
        user: user ?? this.user,
        status: status ?? this.status,
        pendingRedirect:
            clearRedirect ? null : (pendingRedirect ?? this.pendingRedirect),
      );
}
```

- [ ] **Step 3: Add `browseAsGuest()`, `setPendingRedirect()`, `consumePendingRedirect()` to AuthNotifier**

Add these methods to the `AuthNotifier` class, after the `bootstrap()` method:

```dart
  /// Transitions to guest browse mode.
  void browseAsGuest() {
    state = const AuthState(status: AuthStatus.guest);
  }

  /// Saves where the user wanted to go before being asked to log in.
  void setPendingRedirect(String path) {
    state = state.copyWith(pendingRedirect: path);
  }

  /// Clears the pending redirect and returns it (or null).
  String? consumePendingRedirect() {
    final path = state.pendingRedirect;
    if (path != null) {
      state = state.copyWith(clearRedirect: true);
    }
    return path;
  }
```

- [ ] **Step 4: Update `bootstrap()` to go to guest instead of unauthenticated**

Change both `unauthenticated` fallbacks in `bootstrap()` to `guest`:

```dart
  Future<void> bootstrap() async {
    final token = await _tokenStorage.readAccess();
    if (token == null) {
      state = const AuthState(status: AuthStatus.guest);
      return;
    }
    try {
      final user = await _userRepo.getMe();
      state = AuthState(user: user, status: AuthStatus.authenticated);
    } catch (_) {
      await _tokenStorage.clear();
      state = const AuthState(status: AuthStatus.guest);
    }
  }
```

- [ ] **Step 5: Verify the app compiles (expect router errors — fixed in Task 5)**

Run: `cd dailywork && flutter analyze --no-fatal-infos`
Expected: Errors in `app_router.dart` because it doesn't handle the new `guest` case yet — that's expected.

- [ ] **Step 6: Commit**

```bash
git add dailywork/lib/providers/auth_provider.dart
git commit -m "feat: add guest auth status and pending redirect support"
```

---

## Task 4: Frontend — Create Auth Gate Helper and Browse Shell

**Files:**
- Create: `dailywork/lib/core/router/auth_gate.dart`
- Create: `dailywork/lib/screens/browse/browse_shell.dart`

- [ ] **Step 1: Create the auth gate utility**

Create `dailywork/lib/core/router/auth_gate.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dailywork/providers/auth_provider.dart';

/// Checks if the user is authenticated. If not, saves [intendedPath] and
/// navigates to the login screen. Returns `true` if authenticated.
bool requireAuth(WidgetRef ref, BuildContext context,
    {required String intendedPath}) {
  final auth = ref.read(authProvider);
  if (auth.status == AuthStatus.authenticated) {
    return true;
  }
  ref.read(authProvider.notifier).setPendingRedirect(intendedPath);
  context.push('/login');
  return false;
}
```

- [ ] **Step 2: Create `BrowseShell` — guest bottom navigation with Jobs + Login tabs**

Create `dailywork/lib/screens/browse/browse_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/language_provider.dart';

class BrowseShell extends ConsumerWidget {
  const BrowseShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: Colors.grey,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/browse');
            case 1:
              context.push('/login');
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.work_outline),
            activeIcon: const Icon(Icons.work),
            label: strings['jobs'] ?? 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.login),
            activeIcon: const Icon(Icons.login),
            label: strings['login'] ?? 'Login',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/core/router/auth_gate.dart dailywork/lib/screens/browse/browse_shell.dart
git commit -m "feat: add requireAuth helper and BrowseShell for guest navigation"
```

---

## Task 5: Frontend — Modify Existing Screens for Guest Reuse

**Files:**
- Modify: `dailywork/lib/screens/worker/worker_home_screen.dart:128-130`
- Modify: `dailywork/lib/screens/worker/worker_job_detail_screen.dart:34-58,262-298`

- [ ] **Step 1: Make WorkerHomeScreen job card navigation dynamic**

The job card currently hardcodes `context.push('/worker/jobs/${job.id}')`. Change it to detect whether we're on a `/browse` or `/worker` route and navigate accordingly.

In `dailywork/lib/screens/worker/worker_home_screen.dart`, add this import at the top:

```dart
import 'package:go_router/go_router.dart';
```

Then change the `onTap` in the `JobCard` builder (around line 129). Replace:

```dart
                          return JobCard(
                            job: job,
                            onTap: () => context.push('/worker/jobs/${job.id}'),
                            isEmployerView: false,
                          );
```

With:

```dart
                          return JobCard(
                            job: job,
                            onTap: () {
                              final loc = GoRouterState.of(context).uri.path;
                              final prefix = loc.startsWith('/browse') ? '/browse' : '/worker';
                              context.push('$prefix/jobs/${job.id}');
                            },
                            isEmployerView: false,
                          );
```

- [ ] **Step 2: Add auth gate to WorkerJobDetailScreen Apply button**

In `dailywork/lib/screens/worker/worker_job_detail_screen.dart`, add the import:

```dart
import 'package:dailywork/core/router/auth_gate.dart';
import 'package:dailywork/providers/auth_provider.dart';
```

Then change the Apply button's `onPressed` (around line 276). Replace:

```dart
                    onPressed: (_applying || job.status != JobStatus.open)
                        ? null
                        : () => _apply(job.id),
```

With:

```dart
                    onPressed: (_applying || job.status != JobStatus.open)
                        ? null
                        : () {
                            if (!requireAuth(ref, context,
                                intendedPath: '/worker/jobs/${job.id}')) {
                              return;
                            }
                            _apply(job.id);
                          },
```

Note: `WorkerJobDetailScreen` is a `ConsumerStatefulWidget`, so `ref` is available via `this.ref` in the `State`. The `requireAuth` function takes a `WidgetRef` — in `ConsumerState`, use `ref` directly.

- [ ] **Step 3: Verify the app compiles (expect router errors — fixed in Task 6)**

Run: `cd dailywork && flutter analyze --no-fatal-infos`

- [ ] **Step 4: Commit**

```bash
git add dailywork/lib/screens/worker/worker_home_screen.dart dailywork/lib/screens/worker/worker_job_detail_screen.dart
git commit -m "feat: make worker screens reusable for guest browsing with auth gate on Apply"
```

---

## Task 6: Frontend — Rewire the Router for Browse-First Flow

**Files:**
- Modify: `dailywork/lib/core/router/app_router.dart`

This is the critical task. The router must handle four auth states: `unknown` (splash), `guest` (browse with `BrowseShell`), `unauthenticated` (login flow triggered from browse), and `authenticated` (full worker/employer shell).

- [ ] **Step 1: Replace the entire router with the browse-first version**

Replace the contents of `dailywork/lib/core/router/app_router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dailywork/models/user_model.dart';
import 'package:dailywork/providers/auth_provider.dart';
import 'package:dailywork/screens/auth/splash_screen.dart';
import 'package:dailywork/screens/auth/phone_login_screen.dart';
import 'package:dailywork/screens/auth/otp_verify_screen.dart';
import 'package:dailywork/screens/browse/browse_shell.dart';
import 'package:dailywork/screens/worker/worker_home_screen.dart';
import 'package:dailywork/screens/worker/worker_shell.dart';
import 'package:dailywork/screens/worker/worker_job_detail_screen.dart';
import 'package:dailywork/screens/worker/worker_profile_screen.dart';
import 'package:dailywork/screens/employer/employer_shell.dart';
import 'package:dailywork/screens/employer/employer_home_screen.dart';
import 'package:dailywork/screens/employer/employer_job_detail_screen.dart';
import 'package:dailywork/screens/employer/employer_profile_screen.dart';

// ---------------------------------------------------------------------------
// Auth → Router bridge
// ---------------------------------------------------------------------------

class _AuthListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}

// ---------------------------------------------------------------------------
// Route helpers
// ---------------------------------------------------------------------------

const _authRoutes = {'/login', '/verify-otp'};

bool _isBrowseRoute(String loc) =>
    loc == '/browse' || loc.startsWith('/browse/');

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable();

  ref.listen<AuthState>(authProvider, (_, __) => listenable.notify());
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.uri.path;

      switch (auth.status) {
        case AuthStatus.unknown:
          return loc == '/' ? null : '/';

        case AuthStatus.guest:
          // Guest can access browse routes and auth routes (login/otp).
          if (loc == '/') return '/browse';
          if (_isBrowseRoute(loc) || _authRoutes.contains(loc)) return null;
          return '/browse';

        case AuthStatus.unauthenticated:
          // Actively in login flow — allow auth routes and browse routes.
          if (_authRoutes.contains(loc) || _isBrowseRoute(loc)) return null;
          return '/login';

        case AuthStatus.authenticated:
          // Check for pending redirect from auth gate.
          final pending =
              ref.read(authProvider.notifier).consumePendingRedirect();
          if (pending != null &&
              (loc == '/' ||
                  _authRoutes.contains(loc) ||
                  _isBrowseRoute(loc))) {
            return pending;
          }
          // Redirect away from splash, auth, and browse routes.
          if (loc == '/' || _authRoutes.contains(loc) || _isBrowseRoute(loc)) {
            return auth.user!.role == UserRole.worker
                ? '/worker/home'
                : '/employer/home';
          }
          return null;
      }
    },
    routes: [
      // Splash — shown while bootstrap() runs
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth flow
      GoRoute(
        path: '/login',
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) =>
            OtpVerifyScreen(phone: state.extra as String),
      ),

      // Guest browse — reuses existing worker screens inside BrowseShell
      ShellRoute(
        builder: (context, state, child) => BrowseShell(child: child),
        routes: [
          GoRoute(
            path: '/browse',
            builder: (context, state) => const WorkerHomeScreen(),
          ),
          GoRoute(
            path: '/browse/jobs/:id',
            builder: (context, state) => WorkerJobDetailScreen(
              jobId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),

      // Worker section (authenticated only)
      ShellRoute(
        builder: (context, state, child) => WorkerShell(child: child),
        routes: [
          GoRoute(
            path: '/worker/home',
            builder: (context, state) => const WorkerHomeScreen(),
          ),
          GoRoute(
            path: '/worker/jobs/:id',
            builder: (context, state) => WorkerJobDetailScreen(
              jobId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/worker/profile',
            builder: (context, state) => const WorkerProfileScreen(),
          ),
        ],
      ),

      // Employer section (authenticated only)
      ShellRoute(
        builder: (context, state, child) => EmployerShell(child: child),
        routes: [
          GoRoute(
            path: '/employer/home',
            builder: (context, state) => const EmployerHomeScreen(),
          ),
          GoRoute(
            path: '/employer/jobs/:id',
            builder: (context, state) => EmployerJobDetailScreen(
              jobId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/employer/profile',
            builder: (context, state) => const EmployerProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
```

- [ ] **Step 2: Verify the full app compiles cleanly**

Run: `cd dailywork && flutter analyze --no-fatal-infos`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/core/router/app_router.dart
git commit -m "feat: rewire router for browse-first flow with guest access to existing worker screens"
```

---

## Task 7: Frontend — Update Login Screen with "Continue Browsing" Link

**Files:**
- Modify: `dailywork/lib/screens/auth/phone_login_screen.dart:117-118`

- [ ] **Step 1: Add "Continue browsing without login" link after the Send OTP button**

In `dailywork/lib/screens/auth/phone_login_screen.dart`, add after the Send OTP `SizedBox` button (after line 118, the closing `)` of the ElevatedButton's SizedBox), before the closing `],` of the Column:

```dart
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/browse');
                  }
                },
                child: Text(
                  'Continue browsing without login',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white70,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white70,
                  ),
                ),
              ),
```

The `go_router` import is already present in this file.

- [ ] **Step 2: Verify it compiles**

Run: `cd dailywork && flutter analyze --no-fatal-infos`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/screens/auth/phone_login_screen.dart
git commit -m "feat: add 'continue browsing' link to login screen for guest users"
```

---

## Task 8: Smoke Test the Full Flow

**Files:** No new files — verification only.

- [ ] **Step 1: Start the backend**

Run: `cd backend && uvicorn app.main:app --reload --port 8000`

- [ ] **Step 2: Test public endpoints without auth**

```bash
# Should return 200 with job data (or empty list)
curl http://localhost:8000/api/v1/jobs/?lat=12.97&lng=77.59

# Should return 200 with categories
curl http://localhost:8000/api/v1/categories/

# Should return 404 (not 401) for non-existent job
curl http://localhost:8000/api/v1/jobs/00000000-0000-0000-0000-000000000000

# Should return 401/403 for protected endpoint
curl -X POST http://localhost:8000/api/v1/jobs/ -H "Content-Type: application/json" -d '{}'
```

- [ ] **Step 3: Run the Flutter app and verify the browse-first flow**

Run: `cd dailywork && flutter run`

Verify:
1. App opens → splash → job feed (NOT login screen) — inside `BrowseShell` with Jobs + Login tabs
2. Job cards are visible, categories load
3. Tapping a job card opens detail screen at `/browse/jobs/:id`
4. Tapping "Apply" on detail screen → redirects to login with pending redirect saved
5. "Continue browsing without login" link → goes back to browse
6. Completing OTP login → lands on the worker job detail page (via pending redirect)
7. After login, worker bottom nav (Home/Jobs/Profile) appears instead of browse nav

- [ ] **Step 4: Run all backend tests**

Run: `cd backend && python -m pytest -v`
Expected: All tests pass.

- [ ] **Step 5: Run Flutter analyze**

Run: `cd dailywork && flutter analyze --no-fatal-infos`
Expected: No errors.

- [ ] **Step 6: Commit any fixes from smoke testing (only if needed)**

```bash
git add -A
git commit -m "fix: smoke test fixes for browse-first auth flow"
```

---

## Summary of User Flow After Implementation

```
App Launch
    │
    ▼
Splash (bootstrap)
    │
    ├── Has valid token? ──▶ Worker/Employer Home (authenticated)
    │
    └── No token ──▶ Job Feed in BrowseShell (guest)
                         │
                         ├── View jobs ✓ (no auth needed)
                         ├── View job detail ✓ (no auth needed)
                         ├── Filter / search ✓ (no auth needed)
                         │
                         ├── Tap "Apply" ──▶ Login (OTP) ──▶ Resume at job detail (worker view)
                         ├── Tap "Login" tab ──▶ Login (OTP) ──▶ Worker/Employer Home
                         └── Tap "Continue browsing" ──▶ Back to job feed
```

### Key Design Decision: Reuse, Don't Duplicate

Guest users see the **exact same** `WorkerHomeScreen` and `WorkerJobDetailScreen` that authenticated workers see. The only differences are:

1. **Shell**: `BrowseShell` (Jobs + Login tabs) vs `WorkerShell` (Home + Jobs + Profile tabs)
2. **Route prefix**: `/browse/jobs/:id` vs `/worker/jobs/:id` — detected via `GoRouterState` in the `onTap` handler
3. **Apply button**: `requireAuth()` gate redirects guests to login, then resumes via `pendingRedirect`
