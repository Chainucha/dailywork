import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/network/api_client.dart';
import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/user_model.dart';
import 'package:dailywork/providers/auth_provider.dart';
import 'package:dailywork/repositories/api/api_user_repository.dart';

enum NameEntryMode { onboardingWorker, edit }

class NameEntryArgs {
  final NameEntryMode mode;
  final String? initialName;
  const NameEntryArgs({required this.mode, this.initialName});
}

class NameEntryScreen extends ConsumerStatefulWidget {
  final NameEntryArgs args;
  const NameEntryScreen({super.key, required this.args});

  @override
  ConsumerState<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends ConsumerState<NameEntryScreen> {
  late final TextEditingController _controller;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.args.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid => _controller.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.args.mode == NameEntryMode.onboardingWorker) {
        await ref
            .read(authProvider.notifier)
            .setupProfile('worker', displayName: trimmed);
        if (!mounted) return;
        context.go('/worker/home');
      } else {
        await ref.read(apiUserRepositoryProvider).updateDisplayName(trimmed);
        await ref.read(authProvider.notifier).refreshMe();
        if (!mounted) return;
        final user = ref.read(authProvider).user;
        context.go(user?.role == UserRole.worker
            ? '/worker/profile'
            : '/employer/profile');
      }
    } catch (e) {
      final apiError = ApiException.extract(e);
      if (mounted) {
        setState(() {
          _error = apiError?.message ?? 'Could not save. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnboarding = widget.args.mode == NameEntryMode.onboardingWorker;
    final heading = isOnboarding ? 'What should I call you?' : 'Edit your name';

    return Scaffold(
      appBar: isOnboarding
          ? null
          : AppBar(
              backgroundColor: AppTheme.primary,
              title: const Text('Edit name',
                  style: TextStyle(color: Colors.white)),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                heading,
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                maxLength: 60,
                enabled: !_loading,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _isValid ? _submit() : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Your name',
                ),
                style: GoogleFonts.nunito(fontSize: 18),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.nunito(fontSize: 13, color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isValid && !_loading) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Continue',
                          style: GoogleFonts.nunito(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
