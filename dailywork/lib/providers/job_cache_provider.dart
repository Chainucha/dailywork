import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/job_model.dart';
import '../repositories/api/api_job_repository.dart';
import 'category_provider.dart';

class JobCacheNotifier extends AsyncNotifier<List<JobModel>> {
  // Per-category caches keyed by categoryId (null = "All")
  final Map<String?, List<JobModel>> _cache = {};
  final Map<String?, DateTime> _fetchedAt = {};
  Timer? _timer;

  // The repository is set once per build() call
  late ApiJobRepository _repo;

  static const _staleDuration = Duration(minutes: 2);
  static const _refreshDuration = Duration(minutes: 5);

  @override
  Future<List<JobModel>> build() async {
    // Watch the selected category so the notifier rebuilds when it changes.
    final currentCategory = ref.watch(selectedCategoryProvider);

    // Obtain the repository via read (not watch) to avoid rebuild loops.
    _repo = ref.read(apiJobRepositoryProvider);

    // Reset the periodic refresh timer for the new category.
    _timer?.cancel();
    _timer = Timer.periodic(_refreshDuration, (_) {
      getJobs(ref.read(selectedCategoryProvider), force: true);
    });

    // Ensure the timer is cancelled when the notifier is disposed.
    ref.onDispose(() {
      _timer?.cancel();
    });

    // Respect cache freshness on the initial load.
    return getJobs(currentCategory);
  }

  /// Returns whether the cached data for [categoryId] is missing or older than
  /// [_staleDuration].
  bool isStale(String? categoryId) {
    final fetchedAt = _fetchedAt[categoryId];
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) >= _staleDuration;
  }

  /// Retrieves jobs for [categoryId].
  ///
  /// * If the cache is fresh (< 2 min old) and [force] is false, the cached
  ///   list is returned immediately without a network call.
  /// * If [force] is true and stale data exists, state is set to the stale
  ///   data first (stale-while-revalidate), then the network is hit in the
  ///   background.
  /// * On error, state is only overwritten with [AsyncError] when there is no
  ///   stale data to fall back on.
  Future<List<JobModel>> getJobs(String? categoryId, {bool force = false}) async {
    // Fresh-cache fast path.
    if (!force && !isStale(categoryId)) {
      final cached = _cache[categoryId]!;
      state = AsyncData(cached);
      return cached;
    }

    final staleData = _cache[categoryId];
    final hasStale = staleData != null;

    if (force && hasStale) {
      // Show stale data immediately while the network request is in-flight.
      state = AsyncData(staleData);
    } else if (!hasStale) {
      // No data at all — show loading so the UI can display a spinner.
      state = const AsyncLoading();
    }

    try {
      final jobs = await _fetchAndCache(categoryId);
      state = AsyncData(jobs);
      return jobs;
    } catch (e, st) {
      // Only replace state with an error when there is nothing better to show.
      if (!hasStale) {
        state = AsyncError(e, st);
      }
      // If stale data was already shown, leave it in place.
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Fetches jobs for [categoryId] from the network, stores the result in the
  /// cache, and returns it.
  Future<List<JobModel>> _fetchAndCache(String? categoryId) async {
    final jobs = await _repo.getJobs(categoryId: categoryId);
    _cache[categoryId] = jobs;
    _fetchedAt[categoryId] = DateTime.now();
    return jobs;
  }
}

final jobCacheProvider =
    AsyncNotifierProvider<JobCacheNotifier, List<JobModel>>(
  JobCacheNotifier.new,
);
