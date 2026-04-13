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
    OPEN[Open App] --> SPLASH{Token\nfound?}
    SPLASH -- no --> BROWSE[Browse Jobs\nGuest mode]
    SPLASH -- yes --> ROLE

    BROWSE -- tap Login --> LOGIN[Phone + OTP\nPick role]
    BROWSE -- try to apply --> LOGIN

    LOGIN -- verified --> ROLE{Role?}
    LOGIN -- skip --> BROWSE

    ROLE -- worker --> W[Worker Home\nJob Feed]
    ROLE -- employer --> E[Employer Home\nMy Jobs]

    W --> WD[View Job] --> WA[Apply]
    WA -- accepted --> WC[Complete Job] --> WR[Rate Employer] --> W
    WA -- rejected --> W

    E --> EP[Post Job]
    E --> ED[View Applications]
    ED -- accept --> EC[Complete Job] --> ER[Rate Worker] --> E
    ED -- reject --> E

    W -- logout --> BROWSE
    E -- logout --> BROWSE
```
