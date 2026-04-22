import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/category_provider.dart';
import 'package:dailywork/providers/job_provider.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/providers/my_posted_jobs_provider.dart';
import 'package:dailywork/providers/post_job_wizard_provider.dart';
import 'package:dailywork/repositories/api/api_job_repository.dart';
import 'package:dailywork/screens/shared/widgets/location_picker_sheet.dart';
import 'package:dailywork/screens/shared/widgets/wizard_scaffold.dart';

class EmployerPostJobScreen extends ConsumerStatefulWidget {
  const EmployerPostJobScreen({super.key, this.jobId});

  final String? jobId;

  @override
  ConsumerState<EmployerPostJobScreen> createState() =>
      _EmployerPostJobScreenState();
}

class _EmployerPostJobScreenState extends ConsumerState<EmployerPostJobScreen> {
  int _step = 0;
  bool _hydrated = false;
  bool _submitting = false;

  Future<void> _hydrateIfEditing() async {
    if (_hydrated || widget.jobId == null) return;
    _hydrated = true;
    final job = await ref.read(jobDetailProvider(widget.jobId!).future);
    ref.read(postJobWizardProvider.notifier).update((_) => PostJobWizardState(
      categoryId: job.categoryId,
      title: job.title,
      description: job.description,
      locationLat: job.locationLat,
      locationLng: job.locationLng,
      addressText: job.addressText,
      startDate: job.startDate,
      endDate: job.endDate,
      startTime: job.startTime,
      endTime: job.endTime,
      workersNeeded: job.workersNeeded,
      wagePerDay: job.wagePerDay,
      isUrgent: job.isUrgent,
    ));
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final repo = ref.read(apiJobRepositoryProvider);
    final body = ref.read(postJobWizardProvider).toCreateBody();
    final strings = ref.read(stringsProvider);
    try {
      if (widget.jobId == null) {
        await repo.createJob(body);
      } else {
        await repo.updateJob(widget.jobId!, body);
      }
      ref.invalidate(myPostedJobsProvider);
      ref.read(postJobWizardProvider.notifier).reset();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings['job_posted'] ?? 'Job posted ✓')),
      );
      context.go('/employer/my-jobs');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _hydrateIfEditing();
    final state = ref.watch(postJobWizardProvider);
    final strings = ref.watch(stringsProvider);

    final stepLabel = switch (_step) {
      0 => strings['wizard_step_1'] ?? 'What & where',
      1 => strings['wizard_step_2'] ?? 'When & how many',
      _ => strings['wizard_step_3'] ?? 'Pay & confirm',
    };
    final nextEnabled = switch (_step) {
      0 => state.step1Valid,
      1 => state.step2Valid,
      _ => state.step3Valid && !_submitting,
    };
    final nextLabel = _step == 2
        ? (widget.jobId == null
            ? strings['submit_post'] ?? 'Post job'
            : strings['save_changes'] ?? 'Save changes')
        : strings['next'] ?? 'Next';

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step--);
      },
      child: WizardScaffold(
        currentStep: _step,
        totalSteps: 3,
        stepLabel: stepLabel,
        onBack: () {
          if (_step == 0) {
            context.pop();
          } else {
            setState(() => _step--);
          }
        },
        onNext: () {
          if (_step < 2) {
            setState(() => _step++);
          } else {
            _submit();
          }
        },
        nextEnabled: nextEnabled,
        nextLabel: nextLabel,
        child: switch (_step) {
          0 => _Step1(state: state),
          1 => _Step2(state: state),
          _ => _Step3(state: state),
        },
      ),
    );
  }
}

class _Step1 extends ConsumerWidget {
  const _Step1({required this.state});
  final PostJobWizardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final categoriesAsync = ref.watch(categoryListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        categoriesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (err, st) => const Text('Failed to load categories'),
          data: (cats) => DropdownButtonFormField<String>(
            initialValue: state.categoryId,
            decoration: InputDecoration(
              labelText: strings['job_category'] ?? 'Category',
              border: const OutlineInputBorder(),
            ),
            items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => ref
                .read(postJobWizardProvider.notifier)
                .update((s) => s.copyWith(categoryId: v)),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: state.title,
          decoration: InputDecoration(
            labelText: strings['job_title_field'] ?? 'Job title',
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => ref
              .read(postJobWizardProvider.notifier)
              .update((s) => s.copyWith(title: v)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: state.description,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: strings['job_description'] ?? 'Description (optional)',
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => ref
              .read(postJobWizardProvider.notifier)
              .update((s) => s.copyWith(description: v)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.location_on_outlined),
          label: Text(state.addressText ??
              (state.locationLat != null
                  ? '${state.locationLat!.toStringAsFixed(4)}, ${state.locationLng!.toStringAsFixed(4)}'
                  : strings['pick_location'] ?? 'Pick location')),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => LocationPickerSheet(
                initialLat: state.locationLat,
                initialLng: state.locationLng,
                initialAddress: state.addressText,
                onPicked: (p) {
                  ref.read(postJobWizardProvider.notifier).update((s) =>
                      s.copyWith(locationLat: p.lat, locationLng: p.lng, addressText: p.address));
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Step2 extends ConsumerWidget {
  const _Step2({required this.state});
  final PostJobWizardState state;

  String _fmt(DateTime? d) =>
      d == null ? '—' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _fmtT(String? t) => t ?? '—';

  Future<DateTime?> _pickDate(BuildContext context, DateTime? init) =>
      showDatePicker(
        context: context,
        initialDate: init ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

  Future<TimeOfDay?> _pickTime(BuildContext context, String? init) =>
      showTimePicker(
        context: context,
        initialTime: init == null
            ? TimeOfDay.now()
            : TimeOfDay(hour: int.parse(init.split(':')[0]), minute: int.parse(init.split(':')[1])),
      );

  String _toHms(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final notifier = ref.read(postJobWizardProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final d = await _pickDate(context, state.startDate);
                  if (d != null) notifier.update((s) => s.copyWith(startDate: d));
                },
                child: Text('${strings['start_date'] ?? 'Start'}: ${_fmt(state.startDate)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final d = await _pickDate(context, state.endDate);
                  if (d != null) notifier.update((s) => s.copyWith(endDate: d));
                },
                child: Text('${strings['end_date'] ?? 'End'}: ${_fmt(state.endDate)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final t = await _pickTime(context, state.startTime);
                  if (t != null) notifier.update((s) => s.copyWith(startTime: _toHms(t)));
                },
                child: Text('${strings['start_time_field'] ?? 'Start time'}: ${_fmtT(state.startTime)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final t = await _pickTime(context, state.endTime);
                  if (t != null) notifier.update((s) => s.copyWith(endTime: _toHms(t)));
                },
                child: Text('${strings['end_time_field'] ?? 'End time'}: ${_fmtT(state.endTime)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(strings['workers_count'] ?? 'Workers needed', style: GoogleFonts.nunito(fontSize: 14)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: state.workersNeeded > 1
                  ? () => notifier.update((s) => s.copyWith(workersNeeded: s.workersNeeded - 1))
                  : null,
            ),
            Text('${state.workersNeeded}', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => notifier.update((s) => s.copyWith(workersNeeded: s.workersNeeded + 1)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Step3 extends ConsumerStatefulWidget {
  const _Step3({required this.state});
  final PostJobWizardState state;

  @override
  ConsumerState<_Step3> createState() => _Step3State();
}

class _Step3State extends ConsumerState<_Step3> {
  late final TextEditingController _wage =
      TextEditingController(text: widget.state.wagePerDay?.toStringAsFixed(0) ?? '');

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final state = ref.watch(postJobWizardProvider);
    final notifier = ref.read(postJobWizardProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _wage,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '₹ ',
            labelText: strings['wage'] ?? 'Wage per day',
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => notifier.update((s) => s.copyWith(wagePerDay: double.tryParse(v))),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text(strings['mark_urgent'] ?? 'Mark as urgent'),
          value: state.isUrgent,
          onChanged: (v) => notifier.update((s) => s.copyWith(isUrgent: v)),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings['preview'] ?? 'Preview',
                    style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(state.title.isEmpty ? '—' : state.title,
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                Text('₹${state.wagePerDay?.toStringAsFixed(0) ?? '0'} ${strings['per_day'] ?? '/day'}',
                    style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.accent)),
                if (state.addressText != null) Text(state.addressText!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _wage.dispose();
    super.dispose();
  }
}
