# Job Cache Strategy Plan

## Problem
`jobListProvider` is `FutureProvider.autoDispose` — every filter, category, or navigation change hits the API. No local cache.

## Goal
Fetch once per category, filter locally. Refresh only on pull-down, 5-min timer, or app resume after 2+ min.

## Architecture

```
API ──fetch──> JobCacheNotifier
               ├─ cache per category (Map<String?, List<JobModel>>)
               ├─ stale-while-revalidate (show old, fetch new)
               ├─ 5-min auto-refresh timer (lives in notifier)
               └─ app resume check (registered in main.dart)
                        │
                  client-side wage/status filter
                        │
                  jobListProvider (instant, no network)
```

## Files

### 1. NEW: `lib/providers/job_cache_provider.dart`

`JobCacheNotifier` (AsyncNotifier):
- `Map<String?, List<JobModel>> _cache` — keyed by categoryId (null = all)
- `Map<String?, DateTime> _fetchedAt` — tracks staleness per category
- `build()` → initial fetch for current category
- `getJobs(String? categoryId, {bool force = false})`:
  - If `!force` and cache entry exists and <2 min old → return cached
  - Otherwise fetch from API, store in cache, return
  - On force refresh: return stale data immediately, fetch in background, swap when ready (stale-while-revalidate)
- `isStale(String? categoryId)` → true if entry missing or >2 min old
- **5-min timer**: `Timer.periodic(Duration(minutes: 5), ...)` started in constructor
  - Refreshes the currently-watched category
  - Timer resets on each successful fetch
  - Cancelled on dispose

### 2. MODIFY: `lib/repositories/api/api_job_repository.dart`

Keep existing `getJobs()` but the cache notifier calls it with only `categoryId` (no status/wage filters). The notifier gets the full set for that category; filtering happens in the provider layer.

### 3. MODIFY: `lib/providers/job_provider.dart`

Change `jobListProvider` from `FutureProvider.autoDispose` to a `Provider<AsyncValue<List<JobModel>>>`:
1. Watch `jobCacheProvider` (raw list for current category)
2. Watch `jobFilterProvider` (status + wage)
3. Apply status and wage filters client-side
4. Return `AsyncValue<List<JobModel>>` — zero network cost on filter/wage change

### 4. MODIFY: `lib/main.dart`

Register `AppLifecycleListener` at the app level:
- On `resume`: check `jobCacheNotifier.isStale(currentCategory)`
- If stale (>2 min since last fetch) → call `refresh()`
- This covers ALL screens, not just worker home

### 5. MODIFY: `lib/screens/worker/worker_home_screen.dart`

- Pull-to-refresh → `ref.read(jobCacheProvider.notifier).getJobs(category, force: true)`
- Remove any local timer/lifecycle code — that's handled by notifier + main.dart
- Screen stays `ConsumerWidget` (no StatefulWidget needed)

## Refresh Triggers

| Trigger | Condition | Behavior |
|---|---|---|
| Pull-to-refresh | User drags down | Force fetch, show stale data while loading |
| 5-min timer | Periodic in notifier | Background refresh, swap data when ready |
| App resume | `AppLifecycleState.resumed` | Refresh only if >2 min since last fetch |
| Category change | User taps chip | Check cache → serve if fresh, fetch if not |
| Filter/wage change | User adjusts filter | Client-side only, instant, no fetch |

## Design Decisions

- **Cache per category** (not fetch-all): Smaller payloads, better for slow 2G/3G connections and low-end devices per CLAUDE.md constraints
- **Stale-while-revalidate**: Show cached data immediately, fetch in background — no loading spinners on resume or timer refresh
- **Timer in notifier** (not screen): Survives navigation to detail/profile screens
- **Lifecycle in main.dart** (not screen): Fires regardless of which screen is active
