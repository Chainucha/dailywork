# Auth Flow Restructure — Phone → OTP → Role Selection → Home

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate role selection from OTP verification so the flow is: Phone Login → OTP Verify → (if new user) Role Select → Home.

**Architecture:** The backend's `verify_otp` currently requires `user_type` for new users, but since Supabase OTPs are single-use, we can't verify first and ask for a role later with the same OTP. The fix: modify `verify_otp` to defer `users` row creation for new users (return tokens + `is_new_user: true`), and add a new `POST /auth/complete-registration` endpoint that creates the user row + profile. On the Flutter side, add a `needsRole` auth status that routes to a dedicated role selection screen.

**Tech Stack:** FastAPI (Python), Flutter/Dart, Riverpod, GoRouter, Supabase Auth

---

## File Structure

### Backend (modified)

| File | Action | Responsibility |
|------|--------|----------------|
| `backend/app/services/auth_service.py` | Modify | Remove 400 error for missing `user_type`; add `complete_registration()` |
| `backend/app/routers/auth.py` | Modify | Add `POST /complete-registration` endpoint |
| `backend/app/schemas/auth.py` | Modify | Add `is_new_user` to `TokenResponse`; add `CompleteRegistrationRequest`/`RegistrationResponse` |
| `backend/app/dependencies.py` | Modify | Add `get_auth_uid()` — JWT-only dependency (no `users` table lookup) |

### Flutter (modified)

| File | Action | Responsibility |
|------|--------|----------------|
| `dailywork/lib/providers/auth_provider.dart` | Modify | Add `needsRole` status; add `completeRegistration()` method |
| `dailywork/lib/repositories/api/api_auth_repository.dart` | Modify | Update `verifyOtp` return type; add `completeRegistration()` |
| `dailywork/lib/screens/auth/otp_verify_screen.dart` | Modify | Remove role picker — OTP-only screen |
| `dailywork/lib/screens/auth/role_select_screen.dart` | Modify | Rewrite to call `complete-registration` endpoint |
| `dailywork/lib/core/router/app_router.dart` | Modify | Add `/select-role` route; handle `needsRole` redirect |

---

## Task 1: Backend — Add `get_auth_uid` dependency and update `verify_otp` + schemas

**Files:**
- Modify: `backend/app/dependencies.py:58-91`
- Modify: `backend/app/schemas/auth.py`
- Modify: `backend/app/services/auth_service.py:16-67`
- Modify: `backend/app/routers/auth.py`

### Step-by-step

- [ ] **Step 1: Add `get_auth_uid` dependency to `dependencies.py`**

Add this function after `_decode_token` and before `get_current_user`:

```python
async def get_auth_uid(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
) -> str:
    """Validate JWT and return the user's auth UID (sub claim).

    Unlike get_current_user, this does NOT query the users table —
    use it for endpoints where the users row may not exist yet
    (e.g. complete-registration).
    """
    token = credentials.credentials
    try:
        payload = _decode_token(token)
    except pyjwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )
    return user_id
```

- [ ] **Step 2: Update `TokenResponse` schema and add new schemas in `schemas/auth.py`**

Update `TokenResponse` to include `is_new_user`:

```python
class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str
    user_type: str
    is_new_user: bool = False
```

Add two new schemas at the end of the file:

```python
class CompleteRegistrationRequest(BaseModel):
    user_type: Literal["worker", "employer"]


class RegistrationResponse(BaseModel):
    user_id: str
    user_type: str
```

- [ ] **Step 3: Modify `verify_otp` in `auth_service.py`**

Replace the current `verify_otp` function. The key change: when a new user has no `user_type`, return success with `is_new_user: True` instead of raising a 400 error. The OTP is consumed but the user can complete registration separately.

```python
def verify_otp(phone: str, token: str, user_type: str | None) -> dict:
    try:
        result = get_auth_client().auth.verify_otp(
            {"phone": phone, "token": token, "type": "sms"}
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid OTP: {str(e)}",
        )

    auth_user = result.user
    session = result.session

    db = get_supabase()
    existing = db.table("users").select("*").eq("id", auth_user.id).execute()

    if existing.data:
        # Existing user — return immediately
        user = existing.data[0]
        return {
            "access_token": session.access_token,
            "refresh_token": session.refresh_token,
            "token_type": "bearer",
            "user_id": user["id"],
            "user_type": user["user_type"],
            "is_new_user": False,
        }

    # New user — create row if user_type provided, otherwise defer
    if user_type:
        user_row = db.table("users").insert({
            "id": auth_user.id,
            "phone_number": phone,
            "user_type": user_type,
        }).execute()
        user = user_row.data[0]

        if user_type == "worker":
            db.table("worker_profiles").insert({"user_id": user["id"]}).execute()
        else:
            db.table("employer_profiles").insert({
                "user_id": user["id"],
                "business_name": "My Business",
            }).execute()

        return {
            "access_token": session.access_token,
            "refresh_token": session.refresh_token,
            "token_type": "bearer",
            "user_id": user["id"],
            "user_type": user["user_type"],
            "is_new_user": False,
        }

    # No user_type — defer registration to /complete-registration
    return {
        "access_token": session.access_token,
        "refresh_token": session.refresh_token,
        "token_type": "bearer",
        "user_id": auth_user.id,
        "user_type": "",
        "is_new_user": True,
    }
```

- [ ] **Step 4: Add `complete_registration` function to `auth_service.py`**

Add at the end of the file (before the last blank line):

```python
def complete_registration(user_id: str, user_type: str) -> dict:
    db = get_supabase()

    # Guard: don't re-register
    existing = db.table("users").select("id").eq("id", user_id).execute()
    if existing.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User already registered",
        )

    # Fetch phone from Supabase auth (the user exists there from verify_otp)
    auth_client = get_auth_client()
    auth_user = auth_client.auth.admin.get_user_by_id(user_id)
    phone = auth_user.user.phone

    user_row = db.table("users").insert({
        "id": user_id,
        "phone_number": phone,
        "user_type": user_type,
    }).execute()
    user = user_row.data[0]

    if user_type == "worker":
        db.table("worker_profiles").insert({"user_id": user["id"]}).execute()
    else:
        db.table("employer_profiles").insert({
            "user_id": user["id"],
            "business_name": "My Business",
        }).execute()

    return {"user_id": user["id"], "user_type": user["user_type"]}
```

- [ ] **Step 5: Add `/complete-registration` route to `routers/auth.py`**

Add the import for `get_auth_uid` and the new schema, then add the endpoint:

```python
from app.dependencies import get_current_user, get_auth_uid
from app.schemas.auth import (
    SendOtpRequest, VerifyOtpRequest, RefreshRequest,
    TokenResponse, MessageResponse,
    CompleteRegistrationRequest, RegistrationResponse,
)
```

Add the new route after `/verify-otp`:

```python
@router.post("/complete-registration", response_model=RegistrationResponse)
@limiter.limit("10/minute")
async def complete_registration(
    request: Request,
    body: CompleteRegistrationRequest,
    user_id: str = Depends(get_auth_uid),
):
    return auth_service.complete_registration(user_id, body.user_type)
```

- [ ] **Step 6: Verify backend starts without errors**

Run:
```bash
cd backend && python -c "from app.main import app; print('OK')"
```
Expected: `OK` with no import errors.

- [ ] **Step 7: Commit**

```bash
git add backend/app/dependencies.py backend/app/schemas/auth.py backend/app/services/auth_service.py backend/app/routers/auth.py
git commit -m "feat: add /complete-registration endpoint, defer user row creation for new users"
```

---

## Task 2: Flutter — Update auth provider and repository for new flow

**Files:**
- Modify: `dailywork/lib/providers/auth_provider.dart`
- Modify: `dailywork/lib/repositories/api/api_auth_repository.dart`

### Step-by-step

- [ ] **Step 1: Update `ApiAuthRepository` — change `verifyOtp` return type and add `completeRegistration`**

Replace the entire `verifyOtp` method and add the new method:

```dart
/// Verifies OTP. Returns a map with:
///   - 'user_type': String (empty for new users)
///   - 'is_new_user': bool
/// Saves tokens to secure storage on success.
Future<Map<String, dynamic>> verifyOtp({
  required String phone,
  required String token,
}) async {
  final body = {'phone': phone, 'token': token};
  final response = await _dio.post<Map<String, dynamic>>(
    '/auth/verify-otp',
    data: body,
  );
  final data = response.data!;
  await _tokenStorage.saveTokens(
    access: data['access_token'] as String,
    refresh: data['refresh_token'] as String,
  );
  return {
    'user_type': data['user_type'] as String,
    'is_new_user': data['is_new_user'] as bool,
  };
}

/// Sets the role for a newly registered user.
/// Returns the user_type string.
Future<String> completeRegistration(String userType) async {
  final response = await _dio.post<Map<String, dynamic>>(
    '/auth/complete-registration',
    data: {'user_type': userType},
  );
  return response.data!['user_type'] as String;
}
```

Note: the `userType` parameter is removed from `verifyOtp` — role selection is now a separate step.

- [ ] **Step 2: Update `AuthNotifier` and `AuthState` in `auth_provider.dart`**

Add `needsRole` to the `AuthStatus` enum:

```dart
enum AuthStatus { unknown, unauthenticated, authenticated, needsRole }
```

Replace the `verifyOtp` method in `AuthNotifier`:

```dart
/// Verifies OTP. Sets state to [AuthStatus.authenticated] for existing users,
/// or [AuthStatus.needsRole] for new users who haven't picked a role yet.
Future<void> verifyOtp({
  required String phone,
  required String token,
}) async {
  final result = await _authRepo.verifyOtp(phone: phone, token: token);
  final isNew = result['is_new_user'] as bool;

  if (isNew) {
    state = const AuthState(status: AuthStatus.needsRole);
  } else {
    final user = await _userRepo.getMe();
    state = AuthState(user: user, status: AuthStatus.authenticated);
  }
}
```

Add a new `completeRegistration` method to `AuthNotifier`:

```dart
/// Called after a new user picks their role on the role-select screen.
Future<void> completeRegistration(String userType) async {
  await _authRepo.completeRegistration(userType);
  final user = await _userRepo.getMe();
  state = AuthState(user: user, status: AuthStatus.authenticated);
}
```

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/providers/auth_provider.dart dailywork/lib/repositories/api/api_auth_repository.dart
git commit -m "feat: add needsRole auth status and completeRegistration flow"
```

---

## Task 3: Flutter — Simplify OTP screen (remove role picker)

**Files:**
- Modify: `dailywork/lib/screens/auth/otp_verify_screen.dart`

### Step-by-step

- [ ] **Step 1: Rewrite `OtpVerifyScreen` — remove role picker, simplify to OTP-only**

Replace the entire file content:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailywork/core/network/api_client.dart';
import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/auth_provider.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({required this.phone, super.key});

  final String phone;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _otpController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).verifyOtp(
            phone: widget.phone,
            token: otp,
          );
      // Router redirect handles navigation:
      //   existing user → home
      //   new user → role selection (needsRole status)
    } catch (e) {
      final apiError = ApiException.extract(e);
      setState(
        () => _error = apiError?.message ?? 'Verification failed. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter OTP',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Code sent to ${widget.phone}',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: '------',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Verify',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

The `_RoleOption` widget class at the bottom of the file is removed entirely since role selection is now on its own screen.

- [ ] **Step 2: Commit**

```bash
git add dailywork/lib/screens/auth/otp_verify_screen.dart
git commit -m "feat: simplify OTP screen — remove inline role picker"
```

---

## Task 4: Flutter — Rewrite role selection screen for registration flow

**Files:**
- Modify: `dailywork/lib/screens/auth/role_select_screen.dart`

### Step-by-step

- [ ] **Step 1: Rewrite `RoleSelectScreen` to call `completeRegistration`**

The current screen just navigates to home routes. Replace it with a stateful screen that calls the backend:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailywork/core/network/api_client.dart';
import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/auth_provider.dart';

class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  String? _selectedRole;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_selectedRole == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).completeRegistration(_selectedRole!);
      // Router redirect handles navigation to the correct home screen
    } catch (e) {
      final apiError = ApiException.extract(e);
      setState(
        () => _error = apiError?.message ?? 'Registration failed. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.work_outline, size: 72, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'Almost there!',
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'How will you use DailyWork?',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),

                // Worker card
                _RoleCard(
                  icon: Icons.construction,
                  title: 'Worker',
                  subtitle: 'Find daily wage work near you',
                  selected: _selectedRole == 'worker',
                  onTap: () => setState(() => _selectedRole = 'worker'),
                ),
                const SizedBox(height: 16),

                // Employer card
                _RoleCard(
                  icon: Icons.business,
                  title: 'Employer',
                  subtitle: 'Post jobs and hire workers',
                  selected: _selectedRole == 'employer',
                  onTap: () => setState(() => _selectedRole = 'employer'),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: GoogleFonts.nunito(fontSize: 14, color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading || _selectedRole == null ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Get Started',
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Colors.amber.shade100 : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? const BorderSide(color: Colors.amber, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: Colors.amber, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add dailywork/lib/screens/auth/role_select_screen.dart
git commit -m "feat: rewrite role select screen to call complete-registration API"
```

---

## Task 5: Flutter — Update router to handle `needsRole` status

**Files:**
- Modify: `dailywork/lib/core/router/app_router.dart`

### Step-by-step

- [ ] **Step 1: Add `/select-role` to auth routes and import `RoleSelectScreen`**

Add the import at the top:

```dart
import 'package:dailywork/screens/auth/role_select_screen.dart';
```

Update the auth routes set:

```dart
const _authRoutes = {'/login', '/verify-otp', '/select-role'};
```

- [ ] **Step 2: Add `needsRole` case to the `redirect` logic**

Replace the `redirect` function body with:

```dart
redirect: (context, state) {
  final auth = ref.read(authProvider);
  final loc = state.uri.path;

  switch (auth.status) {
    case AuthStatus.unknown:
      return loc == '/' ? null : '/';

    case AuthStatus.unauthenticated:
      return _authRoutes.contains(loc) ? null : '/login';

    case AuthStatus.needsRole:
      // New user must pick a role before accessing any other screen.
      return loc == '/select-role' ? null : '/select-role';

    case AuthStatus.authenticated:
      if (loc == '/' || _authRoutes.contains(loc)) {
        return auth.user!.role == UserRole.worker
            ? '/worker/home'
            : '/employer/home';
      }
      return null;
  }
},
```

- [ ] **Step 3: Add the `/select-role` GoRoute**

Add it after the `/verify-otp` route in the `routes` list:

```dart
GoRoute(
  path: '/select-role',
  builder: (context, state) => const RoleSelectScreen(),
),
```

- [ ] **Step 4: Commit**

```bash
git add dailywork/lib/core/router/app_router.dart
git commit -m "feat: add /select-role route with needsRole redirect logic"
```

---

## Task 6: Cleanup — Remove unused imports and dead code

**Files:**
- Modify: `dailywork/lib/screens/auth/role_select_screen.dart` (remove old language_provider/widget imports)

### Step-by-step

- [ ] **Step 1: Verify no remaining references to the old `RoleSelectScreen` behavior**

The old `RoleSelectScreen` imported `language_provider.dart` and `language_toggle_button.dart`. The rewritten version no longer uses these. Verify the old imports are gone (they should be, since Task 4 rewrites the file).

Run:
```bash
cd dailywork && grep -rn "language_provider\|language_toggle_button" lib/screens/auth/role_select_screen.dart
```
Expected: No output (imports are gone).

- [ ] **Step 2: Verify `SendOtpRequest.user_type` field is still present in schema (backward compat)**

The `SendOtpRequest` in `backend/app/schemas/auth.py` has `user_type` — this field is unused by the send-otp endpoint but harmless. Leave it for backward compatibility. No change needed.

- [ ] **Step 3: Run Flutter analysis**

```bash
cd dailywork && flutter analyze
```

Fix any issues found.

- [ ] **Step 4: Commit any cleanup fixes**

```bash
git add -A
git commit -m "chore: cleanup unused imports after auth flow restructure"
```

---

## Summary of the new auth flow

```
Phone Login ──→ Send OTP ──→ OTP Verify Screen ──→ POST /verify-otp
                                                          │
                                            ┌─────────────┴─────────────┐
                                            │                           │
                                      is_new_user=false           is_new_user=true
                                            │                           │
                                      AuthStatus.authenticated    AuthStatus.needsRole
                                            │                           │
                                      Router → /worker/home       Router → /select-role
                                            or /employer/home           │
                                                                  User picks role
                                                                        │
                                                                  POST /complete-registration
                                                                        │
                                                                  AuthStatus.authenticated
                                                                        │
                                                                  Router → home
```
