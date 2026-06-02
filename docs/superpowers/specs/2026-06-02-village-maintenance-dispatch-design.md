# ช่างใกล้บ้าน (ChangKlai) — Village Maintenance Dispatch Platform — Design Spec

**Name:** ช่างใกล้บ้าน ("the technician near your home") — Thai-root, low-literacy friendly; captures both wedges (trade clarity + hyperlocal). Short brand for handle/domain: **ChangKlai**.
**Date:** 2026-06-02
**Status:** Approved design, pre-implementation
**Origin:** Fork of `dailywork-bsc` (daily-wage job board). Reuses ~60–70% of stack.

> **Verify before locking name:** LINE OA handle (`@changklai`), `.co.th`/`.com` domain, DBD company-name + DIP trademark clash. Note: descriptive name → weaker trademark protection (acceptable for pilot). Prior pick "ช่างดี" dropped — clashes with Global House's service brand.

---

## 1. Concept

A maintenance / general-service platform (gardening, electrical, plumbing, handyman) for residential areas — starting with a single gated village (Supalai-type หมู่บ้านจัดสรร), expanding across Nakhonsawan as a real-business pilot ("proof of work").

Unlike the incumbent marketplaces (Fixzy, Seekster, ServisHero, Dvers, Fastwork) which are **Bangkok-first, pull-model marketplaces** (customer ↔ independent pro, platform takes commission, reliability is weak), this platform's wedge is:

1. **Managed workforce + control-center dispatch** — vetted **contractors** on committed shifts, a dispatcher pushes jobs. Reliability is the product. Workers are paid **hybrid: standby retainer + per-job commission** (not salaried) — see §4b.
2. **Hyper-local, secondary city** — dense village → Nakhonsawan town, where incumbents barely operate.

### Primary goal
**Lean real operating-business MVP.** Ship fast, run a real pilot. Rigor where it protects money/quality; YAGNI everywhere else.

### Business model — hybrid
- **B2B** — contract with village juristic person (นิติบุคคล) for scheduled common-area upkeep. Monthly fee, invoice, 3% withholding tax.
- **B2C** — residents book individual jobs, pay per job via payment gateway.

---

## 2. Market context (Thailand)

- SEA on-demand home-services market ≈ USD 137M (2024), ≈14% CAGR.
- Incumbents: **Fixzy** (~40k users, 1,200 handymen), **Seekster**, **ServisHero** (5,000+ pros), **Dvers** (1,500+ techs) — all marketplace, urban-first.
- Gap exploited: **reliability** (guaranteed show-up via a managed, shift-committed contractor workforce) + **secondary-city coverage**.

---

## 3. System shape

Four clients, one backend.

```
   Resident (B2C) ──► LINE OA + LIFF (book)            ─┐
   Village mgmt (B2B) ──► contract → scheduled jobs    ─┤
   Dispatcher (you) ──► Control-center web dashboard    ─┼─► FastAPI ◄─► Supabase
   Worker ──► LINE (Phase 1) → Flutter app (Phase 1.5)  ─┘   (backend)   (PG + PostGIS)
                                                              + Omise/2C2P (B2C escrow pay)
                                                              + LINE Messaging webhook
```

- **Backend:** FastAPI + Supabase/PostgreSQL + PostGIS. **Reuse** existing dailywork-bsc backend.
- **Resident channel:** LINE OA + LIFF mini-app (no app install). Flutter customer app later.
- **Worker channel:** LINE first weeks → **Flutter worker app** is the core (GPS, navigation, evidence). Pulled to **Phase 1.5** because jobs extend beyond the village.
- **Control-center dashboard:** new thin web app (React or server-rendered), same FastAPI backend. The dispatcher cockpit.
- **Payments:** payment gateway (Omise or 2C2P — both Thai, support PromptPay QR + cards) for a clean transaction ledger (accounting/VAT/WHT). Gateway requires a registered juristic company + KYC.

---

## 4. Worker-supply model — managed core + board overflow (Model C, phased)

- **Phase 1:** managed contractors only, on **shifts**, **manual dispatch**. No board.
- **Phase 2:** add a **vetted job-board overflow** (reuse the dailywork-bsc application flow) for demand spikes / off-shift gaps.

The board is **not** an open Fastwork-style marketplace. It is gated:

1. **Vetted pool** — gig worker onboards once (ID, trade test/interview, references). Not open signup.
2. **Category gating** — a worker only sees/applies to jobs in categories an admin approved (`category_approvals`). Electrician jobs are invisible to non-approved electricians.
3. **Dispatcher confirm** — control center approves the board match before dispatch. Human gate kills bad matches. Low ratings → suspended.

**Unfilled board job** never reaches the customer as a failure: control center absorbs it — call in an off-shift/standby worker (overtime), surge-bump the pay, or reschedule and set expectations. The managed shift-committed workforce is the guarantee; the board only saves cost when it can. B2B common-area work is scheduled and never has fill risk.

---

## 4b. Worker compensation — hybrid (retainer + commission)

Workers are **contractors, not salaried employees**. Pay = **standby retainer + per-job commission**. This decouples *how workers are paid* from *how jobs are dispatched* — the dispatch/zone/completion architecture is unchanged.

- **Standby retainer** — small fixed pay for committing to a shift window. Rewards being available; underpins the auto-accept reliability guarantee.
- **Per-job commission** — worker is paid out per completed job. More jobs → more pay = motivation. No idle-payroll cost to the platform.
- **Platform fee (middleman)** — the platform takes a fee per job (% per category, Grab-style). This is the revenue model on the B2C side.

Mechanics reuse the escrow already in the design:
```
job price → gateway escrow (held)
  on complete → split:
     platform_fee  (platform cut, % per category)
     worker_payout (remainder)
  release → worker paid, platform keeps fee
```

**Why hybrid, not pure commission:** pure commission + free-to-decline → cherry-picking → marketplace no-show problem (the weakness being beaten). The retainer + on-shift auto-accept preserves availability; commission preserves motivation; decline rate hurts rating + shift priority.

**TH legal note:** contractor (not employee) → simpler payroll, withhold **3% WHT** on payouts, no social-security obligation. Cleaner for the pilot. Revisit classification if a worker becomes effectively full-time.

---

## 5. Dispatch — zone-based (cheap Grab)

Adopts Grab's mechanism at pilot scale, skipping the heavy parts.

**Stolen from Grab:** geohash/zone + allocation radius, radius-expand when none found, auto-accept to prevent cherry-picking.
**Skipped:** routing-distance K-nearest (straight-line `ST_DWithin` is fine in a small town), order batching (service = 1 worker / 1 job), supply-demand RL.

```
job.location_point ──► derive job.zone (PostGIS polygon / geohash)

dispatch candidates =
    on-shift + category-approved workers IN job.zone
    ranked by longest-idle (or nearest via ST_DWithin)

  dispatcher manual-assign within X min?
     yes → assigned
     no (dispatcher away/slow) → AUTO-ASSIGN longest-idle on-shift worker in zone
        accept timeout → SELF-CLAIM: job shown to all on-shift category workers,
                         first to claim takes it (push → pull fallback)
        none in zone → expand to adjacent zones (radius++)
        still none → board overflow (Phase 2) / escalate to backstop

  off-hours: non-urgent → queue for next shift
             urgent → auto-assign to on-call worker

on-shift contractor = auto-accept (Grab's cherry-pick fix = the shift model)
```

This single mechanism resolves three concerns together:
- **Outside-village scope** → zones scale beyond the village.
- **Worker not ready to accept** → on-shift = auto-accept; accepting assigned jobs is the job.
- **Dispatcher (you) unavailable** → auto-assign by zone + longest-idle, then self-claim.

**Service hours** are defined per site/zone; off-hours urgent jobs route to on-call workers, non-urgent queue.

---

## 6. Location & maps

Two distinct needs, deliberately separated.

### A. Worker navigation to the site — Phase 1, cheap
- Every job carries **coords + address**; customer drops a pin at booking.
- Worker screen → **"นำทาง / Navigate" → deep-links to Google Maps app** (turn-by-turn, free, best TH routing). Works from LINE and Flutter.
- In-app preview → **flutter_map (OSM)** + **Nominatim geocoding** (already in dailywork-bsc stack).
- **No custom routing engine.**

### B. Live worker tracking (dispatcher watches workers move) — Phase 1.5/2
- LINE **cannot** do continuous GPS (only one-shot location share; LIFF geolocation is foreground-only, one-shot).
- True live GPS → **Flutter worker app** (`geolocator`, background).
- **Phase 1** survives on **one-shot location check-ins** (on accept / on arrival, via LIFF) + clock-in location. Rough but workable for zone+idle dispatch.

**New requirement:** customer must **set job location** at booking (LIFF map picker or LINE location share) → `jobs.location_point`. No implicit village address once jobs go outside.

---

## 7. Job completion — Grab model (no customer gate)

Grab/Lineman do **not** use an active customer approval. They use **trust-by-default + proof + post-hoc dispute** (driver must capture a photo at the location before the app allows "Completed"; GPS + timestamp; customer can only dispute on mismatch). Adopted, with richer per-category evidence because service work isn't binary like delivery.

```
worker marks done
   → MANDATORY: evidence + GPS-at-site
        visual jobs (garden/clean/paint) → before-photo (on arrival) + after-photo
        functional jobs (electric/plumbing/appliance) → short test video + after-photo
        worker cannot tap "done" until required evidence uploaded
   → job [completed_pending], escrow held
   → customer notified on LINE (info only + [⚠ Report problem] link)
   → 24h dispute window:
        silence    → release escrow → [completed]   (pure Grab default)
        report     → [disputed] → dispatcher QA reviews evidence → decide
```

- **No customer approve button** (dropped). Customer is passive; dispute-only.
- **Before photo taken by worker on arrival** (not customer at booking) — consistent timing, kills the "it was already broken / you damaged it" dispute. The customer's booking photo separately captures the problem.
- **Gate is on worker proof + GPS**, not customer action → no stuck jobs.
- **Escrow:** gateway holds the B2C charge at booking, releases on auto-complete (or refunds on upheld dispute). Clean link between "finished" and "paid," and the tax ledger.
- **AI before/after image diff → V2** (assist dispatcher QA). Unreliable + useless for functional jobs; YAGNI for pilot.

---

## 8. Data model

Reuse the 8 dailywork-bsc tables; tweak some; add 8.

### Reuse / tweak
- **`users`** — add roles `resident` (B2C), `dispatcher`/`admin` alongside `worker`. Keep phone-OTP auth.
- **`categories`** — reuse; **add `required_evidence`** (e.g. `["before","after"]` vs `["test_video","after"]`), **`base_price`**, **`platform_fee_pct`**.
- **`worker_profiles`** — reuse `skills[]`, `rating_avg`; **add `worker_type`** (`contractor` = shift-committed core | `gig` = board), **`home_zone`**, **`comp_model`**, **`commission_rate`**, **`retainer_rate`**.
- **`jobs`** — add `site_id`, `zone_id`, `source` (b2c/b2b), `scheduled_at`, `urgency`, `sla_deadline`, `price`, `address_detail`, `completion_status` (completed_pending / completed / disputed). `location_point` now **mandatory** (customer pin).
- **`reviews`, `notifications`** — reuse as-is.
- **`applications`** — **dormant in Phase 1**; becomes the Phase-2 board (gig applies / self-claim).

### New tables
| Table | Purpose | Key fields |
|---|---|---|
| `zones` | dispatch zones (village = one zone) | id, name, polygon `GEOGRAPHY`, geohash |
| `sites` | villages served | id, name, location_point, juristic_contact, service_hours |
| `contracts` | B2B village deals | site_id, monthly_fee, scope, wht_rate, billing_day |
| `worker_shifts` | clock-in / availability | worker_id, start, end, status (clocked_in/out), last_assigned_at, on_call |
| `dispatch_assignments` | push-assign (managed flow) | job_id, worker_id, status, assigned_by, accepted_at, timeout_at |
| `category_approvals` | gig skill-gating | worker_id, category_id, approved_by |
| `job_evidence` | completion proof | job_id, kind (before/after/test_video), url, uploaded_by, taken_at, geo |
| `payments` | tax trail + escrow + split | job_id, amount, method, gateway_ref, status, escrow_status (held/released/refunded), platform_fee, worker_payout, wht_withheld, paid_at |

**Job status flow:** `requested → assigned → accepted → en_route → in_progress → completed_pending → completed`; `requested → cancelled`; `completed_pending → disputed`.

---

## 9. Control-center dashboard

Single dispatcher cockpit (new web app, same FastAPI backend). Tabs:

1. **Live queue** — incoming `[requested]` jobs (B2C from LINE + B2B scheduled), sorted by urgency / SLA.
2. **Dispatch** — pick job → see **on-shift workers** in zone, category-matched, ranked by idle/proximity → assign; watch accept/timeout; trigger escalate.
3. **Active jobs** — live status, evidence thumbnails, disputes flagged.
4. **Workers** — roster, shifts, `category_approvals`, ratings.
5. **Billing** — B2C payments/escrow status; B2B contracts + monthly invoices (WHT).
6. **Board** *(Phase 2)* — overflow jobs, vetted-gig applicants, approve match.

Phase 1 dashboard uses **on-shift roster + check-in pings**, not a live map (live map arrives with Flutter worker app).

---

## 10. Build sequence (Phase 1, dependency order)

1. **Backend schema** — add 8 tables + job fields; define zones. Supabase migration. Reuse existing.
2. **Auth/roles** — add `resident` / `dispatcher` roles to existing OTP auth.
3. **LINE OA + LIFF booking** — webhook → create job `[requested]` with location pin. *(New integration.)*
4. **Dispatch service** — assign endpoint; zone + category + shift filter; longest-idle rank; auto-fallback timer; self-claim endpoint.
5. **Worker LINE flow** — receive assignment, accept, status updates, **Navigate deep link**, evidence + GPS upload.
6. **Control dashboard** — tabs 1, 2, 3 first.
7. **Payment gateway** — Omise/2C2P: escrow charge on booking, release on complete; `payments` rows.
8. **Completion + dispute** — evidence gate, 24h window, dispatcher QA.
9. **Pilot** — one village, few workers, B2C urgent + B2B scheduled.

### Later phases
- **Phase 1.5** — **Flutter worker app** (live GPS, background tracking, dispatcher live map). Pulled early because jobs leave the village.
- **Phase 2** — vetted job-board overflow, category gating, surge bump, Flutter customer app.
- **Phase 3** — semi-auto dispatch suggestions, routing-distance ranking, B2B billing automation, AI evidence QA.

---

## 11. Reuse summary (vs dailywork-bsc)

- ✅ **Reuse:** Flutter stack, FastAPI backend, Supabase/PostGIS, phone-OTP auth, worker profiles, jobs table, categories, reviews, notifications, flutter_map (OSM), Nominatim geocoding, `applications` (→ Phase-2 board).
- 🔄 **Change:** `employer` role → `resident` + village `sites`/`contracts`; `applications` pull-model → `dispatch_assignments` push-model; add dispatcher actor.
- ➕ **New:** control-center dashboard, LINE OA/LIFF integration, payment gateway/escrow, dispatch service (zone-based), `job_evidence` + completion gate, `worker_shifts`, `zones`.

Core transformation: **marketplace pull-model → command-dispatch push-model with a job-board fallback.**

---

## 12. Open items / non-goals

- **Open:** exact gateway (Omise vs 2C2P); company registration timing (blocks gateway KYC); precise dispute-window length; B2B job auto-generation cadence.
- **Non-goals (V2+):** AI matching/evidence diff, routing-distance dispatch, order batching, supply-demand RL, Flutter customer app, multi-tenant licensing to other operators.
