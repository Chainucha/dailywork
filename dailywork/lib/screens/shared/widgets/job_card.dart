import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/screens/shared/widgets/status_badge.dart';

const List<Color> _categoryColors = [
  Color(0xFF1976D2), // blue
  Color(0xFF388E3C), // green
  Color(0xFFF57C00), // orange
  Color(0xFF7B1FA2), // purple
  Color(0xFF0097A7), // teal
];

Color _colorForCategory(String categoryId) {
  return _categoryColors[categoryId.hashCode.abs() % _categoryColors.length];
}

IconData _iconForCategory(String categoryName) {
  final name = categoryName.toLowerCase();
  if (name.contains('mason') || name.contains('brick') || name.contains('construct')) {
    return Icons.construction;
  }
  if (name.contains('clean')) return Icons.cleaning_services;
  if (name.contains('deliver') || name.contains('cargo')) return Icons.local_shipping;
  if (name.contains('electric')) return Icons.electrical_services;
  if (name.contains('plumb')) return Icons.plumbing;
  if (name.contains('paint')) return Icons.format_paint;
  if (name.contains('garden') || name.contains('farm')) return Icons.grass;
  if (name.contains('security') || name.contains('guard')) return Icons.security;
  if (name.contains('cook') || name.contains('food')) return Icons.restaurant;
  if (name.contains('drive') || name.contains('transport')) return Icons.drive_eta;
  return Icons.work_outline;
}

String _formatShortDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

class JobCard extends ConsumerWidget {
  final JobModel job;
  final VoidCallback onTap;
  final bool isEmployerView;

  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.isEmployerView = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final categoryColor = _colorForCategory(job.categoryId);
    final categoryIcon = _iconForCategory(job.categoryName);
    final dateRange =
        '${_formatShortDate(job.startDate)} – ${_formatShortDate(job.endDate)}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: category icon box ───────────────────────────
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(categoryIcon, color: categoryColor, size: 26),
              ),
              const SizedBox(width: 12),

              // ── Right: all content ────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + URGENT / status badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            job.title,
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A2E),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (job.isUrgent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8D6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              strings['urgent'] ?? 'URGENT',
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFE65100),
                                letterSpacing: 0.3,
                              ),
                            ),
                          )
                        else
                          StatusBadge(status: job.status),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Category name subtitle
                    Text(
                      job.categoryName,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Wage
                    Text(
                      '₹${job.wagePerDay.toInt()} / Day',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Location row
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            strings['km_away'] ?? '',
                            style: GoogleFonts.nunito(
                                fontSize: 12, color: Colors.grey[500]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Date range row
                    Row(
                      children: [
                        Icon(Icons.schedule_outlined,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          dateRange,
                          style: GoogleFonts.nunito(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Apply + phone buttons  OR  applicant count
                    if (!isEmployerView)
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton(
                                onPressed: () {
                                  final message =
                                      '${strings['apply_success'] ?? 'Application submitted successfully'}: ${job.title}';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                ),
                                child: Text(
                                  strings['apply'] ?? 'Apply',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 38,
                            height: 38,
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              child: Icon(Icons.phone_outlined,
                                  size: 18, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        '${job.applicantCount} ${strings['applicants'] ?? 'applicants'}',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
