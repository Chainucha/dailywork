# Daily Wage Worker Job Board

A **mobile-first job marketplace** connecting **daily wage workers** (construction, cleaning, delivery, etc.) with **employers offering short-term or urgent work**.

Designed specifically for:
- Low-end Android devices  
- Slow or unreliable internet  
- Low-literacy users (icon-driven UX)

---

## Tech Stack

| Layer        | Technology |
|-------------|-----------|
| **Frontend** | Flutter (Android-first) |
| **Backend**  | FastAPI (Python 3.11+) |
| **Database** | Supabase (PostgreSQL + PostGIS) |
| **Cache**    | Redis |
| **Queue**    | Celery + Redis |
| **Auth**     | Phone OTP (Supabase / Twilio) + JWT |
| **Maps**     | OpenStreetMap + Nominatim |
| **Push**     | Firebase Cloud Messaging (FCM) |

---

## System Architecture

```mermaid
graph TD
    A[Flutter App] --> B[FastAPI Backend]
    B --> C[Supabase PostgreSQL]
    B --> D[Redis]
    D --> E[Celery Workers]
    B --> F[External Services]
    F --> G[FCM / Maps / OTP]
```

## User Flow Diagram

```mermaid
flowchart TD

%% ── App Entry ────────────────────────────────────────────────────
OPEN[Open App] --> SPLASH[Splash Screen\nbootstrap token]
SPLASH --> STATUS{Auth Status}

STATUS -- authenticated\ntoken found --> ROLE_CHECK
STATUS -- guest\nno token --> BROWSE

%% ── Guest Browse ─────────────────────────────────────────────────
BROWSE[Browse Jobs /browse\nBrowseShell: Jobs · Login tabs]
BROWSE --> B_DETAIL[View Job Detail\n/browse/jobs/:id]
BROWSE --> LOGIN_TAP[Tap Login tab]

B_DETAIL --> TRY_APPLY{Try to Apply}
TRY_APPLY -- not logged in --> PENDING[Save pending redirect\ngo to /login]
TRY_APPLY -- already logged in --> W_APPLY

LOGIN_TAP --> LOGIN

%% ── Auth Flow ────────────────────────────────────────────────────
LOGIN[Phone Login\nCountry code + number\n/login]
LOGIN --> CONTINUE[Continue browsing\nwithout login]
CONTINUE --> BROWSE

LOGIN --> SEND[Send OTP]
SEND --> OTP[OTP Verify Screen /verify-otp\nEnter 6-digit code\n+ Pick role new users]
PENDING --> OTP

OTP -- verified --> AUTH_OK{Pending\nredirect?}
AUTH_OK -- yes --> SAVED_ROUTE[Resume saved route\ne.g. job detail]
AUTH_OK -- no --> ROLE_CHECK

%% ── Role Split ───────────────────────────────────────────────────
ROLE_CHECK{User Role}
ROLE_CHECK -- worker --> W_HOME
ROLE_CHECK -- employer --> E_HOME

%% ================= WORKER FLOW =================
W_HOME[Worker Home /worker/home\nJob feed with filters & categories]
W_HOME --> W_FILTER[Filter · Search · Category chips]
W_FILTER --> W_HOME
W_HOME --> W_DETAIL[Job Detail /worker/jobs/:id]
W_HOME --> W_PROFILE[Worker Profile /worker/profile]

W_DETAIL --> W_APPLY{Apply for job?}
W_APPLY -- yes --> W_SUBMIT[Submit Application]
W_SUBMIT --> W_NOTIF[Push Notification sent]
W_SUBMIT --> W_WAIT[Await employer response]

W_WAIT --> W_STATUS{Application\nStatus}
W_STATUS -- accepted --> W_ASSIGNED[Job Assigned → In Progress]
W_ASSIGNED --> W_DONE[Job Completed]
W_DONE --> W_RATE[Rate Employer]
W_RATE --> W_HOME

W_STATUS -- rejected --> W_HOME
W_STATUS -- pending --> W_HOME

%% ================= EMPLOYER FLOW =================
E_HOME[Employer Home /employer/home\nMy posted jobs]
E_HOME --> E_POST[Post New Job]
E_POST --> E_HOME
E_HOME --> E_DETAIL[Job Detail /employer/jobs/:id]
E_HOME --> E_PROFILE[Employer Profile /employer/profile]

E_DETAIL --> E_APPS[View Applications]
E_APPS --> E_DECIDE{Accept or\nReject worker?}

E_DECIDE -- accept --> E_ASSIGN[Worker Assigned]
E_ASSIGN --> E_NOTIF[Push Notification sent]
E_ASSIGN --> E_PROGRESS[Job In Progress]
E_PROGRESS --> E_DONE[Mark Job Complete]
E_DONE --> E_RATE[Rate Worker]
E_RATE --> E_HOME

E_DECIDE -- reject --> E_REJECT_NOTIF[Notify Worker]
E_REJECT_NOTIF --> E_APPS

%% ── Logout ───────────────────────────────────────────────────────
W_PROFILE --> LOGOUT[Logout]
E_PROFILE --> LOGOUT
LOGOUT --> BROWSE
```
