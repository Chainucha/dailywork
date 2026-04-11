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

%% Entry
A[Open App] --> B{User Logged In?}

%% Auth Flow
B -- No --> C[Enter Phone Number]
C --> D[Request OTP]
D --> E[Verify OTP]
E --> F[Select Role]
F --> G[Create Profile]
G --> H[Go to Dashboard]

B -- Yes --> H

%% Role Split
H --> I{User Type}

%% ================= WORKER FLOW =================
I -- Worker --> W1[View Nearby Jobs]
W1 --> W2[Filter/Search Jobs]
W2 --> W3[View Job Details]

W3 --> W4{Apply?}
W4 -- Yes --> W5[Submit Application]
W5 --> W6[Wait for Employer Response]

W6 --> W7{Application Status}
W7 -- Accepted --> W8[Job Assigned]
W8 --> W9[Start Job]
W9 --> W10[Complete Job]
W10 --> W11[Rate Employer]

W7 -- Rejected --> W12[Browse Other Jobs]
W7 -- Pending --> W1

%% Notifications
W5 --> N1[Receive Notification]

%% ================= EMPLOYER FLOW =================
I -- Employer --> E1[Post Job]
E1 --> E2[Job Live]

E2 --> E3[View Applications]
E3 --> E4{Select Worker}

E4 -- Accept --> E5[Assign Worker]
E5 --> E6[Job In Progress]
E6 --> E7[Mark Job Complete]
E7 --> E8[Rate Worker]

E4 -- Reject --> E9[Notify Worker]

%% Notifications
E5 --> N1
E9 --> N1

%% ================= COMMON =================
N1 --> H
```
