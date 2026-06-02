import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';
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
        // Accepted = still-active accepted apps (job not yet finished).
        return g.accepted
            .where((i) => i.job.status != JobStatus.completed)
            .toList();
      case _AppFilter.done:
        // Done = finished jobs the worker was accepted on, plus terminal apps.
        return [
          ...g.accepted.where((i) => i.job.status == JobStatus.completed),
          ...g.rejected,
          ...g.withdrawn,
        ];
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
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(detail ??
                  (strings['action_failed_toast'] ?? 'Action failed — try again'))),
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
        separatorBuilder: (context, index) => const SizedBox(width: 8),
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
