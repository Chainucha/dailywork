import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_filter.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/job_provider.dart';
import 'package:dailywork/providers/language_provider.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late List<JobStatus> _selectedStatuses;
  late double _minWage;
  late double _maxWage;

  static const List<JobStatus> _activeStatuses = [
    JobStatus.open,
    JobStatus.assigned,
    JobStatus.inProgress,
  ];

  @override
  void initState() {
    super.initState();
    final currentFilter = ref.read(jobFilterProvider);
    _selectedStatuses = List<JobStatus>.from(currentFilter.statuses);
    _minWage = currentFilter.minWage;
    _maxWage = currentFilter.maxWage;
  }

  String _statusLabel(JobStatus status, Map<String, String> strings) {
    switch (status) {
      case JobStatus.open:
        return strings['open'] ?? 'Open';
      case JobStatus.assigned:
        return strings['assigned'] ?? 'Assigned';
      case JobStatus.inProgress:
        return strings['in_progress'] ?? 'In Progress';
      case JobStatus.completed:
        return strings['completed'] ?? 'Completed';
      case JobStatus.cancelled:
        return strings['cancelled'] ?? 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status section
            Text(
              strings['status'] ?? 'Status',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _activeStatuses.map((status) {
                final isSelected = _selectedStatuses.contains(status);
                return FilterChip(
                  label: Text(
                    _statusLabel(status, strings),
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.primary,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedStatuses = [..._selectedStatuses, status];
                      } else {
                        _selectedStatuses = _selectedStatuses
                            .where((s) => s != status)
                            .toList();
                      }
                    });
                  },
                  selectedColor: AppTheme.accent,
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: isSelected ? AppTheme.accent : AppTheme.primary,
                    width: 1.5,
                  ),
                  showCheckmark: false,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Wage range section
            Text(
              strings['wage_range'] ?? 'Wage Range',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${_minWage.toInt()} – ₹${_maxWage.toInt()}',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            RangeSlider(
              values: RangeValues(_minWage, _maxWage),
              min: 200,
              max: 2000,
              divisions: 18,
              activeColor: AppTheme.accent,
              inactiveColor: AppTheme.accent.withAlpha(64),
              onChanged: (values) {
                setState(() {
                  _minWage = values.start;
                  _maxWage = values.end;
                });
              },
            ),
            const SizedBox(height: 20),

            // Apply button
            ElevatedButton(
              onPressed: () {
                ref.read(jobFilterProvider.notifier).state = JobFilter(
                  statuses: _selectedStatuses,
                  minWage: _minWage,
                  maxWage: _maxWage,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                strings['apply_filters'] ?? 'Apply Filters',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Reset button
            Center(
              child: TextButton(
                onPressed: () {
                  ref.read(jobFilterProvider.notifier).state =
                      const JobFilter();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                child: Text(
                  'Reset',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
