import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/language_provider.dart';

class WizardScaffold extends ConsumerWidget {
  const WizardScaffold({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabel,
    required this.child,
    required this.onBack,
    required this.onNext,
    required this.nextEnabled,
    this.nextLabel,
  });

  final int currentStep;
  final int totalSteps;
  final String stepLabel;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final bool nextEnabled;
  final String? nextLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          strings['post_job_title'] ?? 'Post a job',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalSteps, (i) {
                  final isActive = i == currentStep;
                  final isDone = i < currentStep;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      key: ValueKey('wizard-dot-$i'),
                      width: 36,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.accent
                            : isDone
                                ? AppTheme.accent.withOpacity(0.5)
                                : Colors.grey[300],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                stepLabel,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: SingleChildScrollView(child: child)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('wizard-back'),
                      onPressed: onBack,
                      child: Text(strings['back'] ?? 'Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      key: const ValueKey('wizard-next'),
                      onPressed: nextEnabled ? onNext : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(nextLabel ?? strings['next'] ?? 'Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
