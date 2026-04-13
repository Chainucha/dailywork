import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailywork/core/network/api_client.dart';
import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/auth_provider.dart';

class _Country {
  final String flag;
  final String name;
  final String dialCode;
  const _Country(this.flag, this.name, this.dialCode);
}

const _countries = [
  _Country('🇮🇳', 'India', '+91'),
  _Country('🇧🇩', 'Bangladesh', '+880'),
  _Country('🇵🇰', 'Pakistan', '+92'),
  _Country('🇳🇵', 'Nepal', '+977'),
  _Country('🇱🇰', 'Sri Lanka', '+94'),
  _Country('🇲🇲', 'Myanmar', '+95'),
  _Country('🇵🇭', 'Philippines', '+63'),
  _Country('🇮🇩', 'Indonesia', '+62'),
  _Country('🇸🇦', 'Saudi Arabia', '+966'),
  _Country('🇦🇪', 'UAE', '+971'),
  _Country('🇶🇦', 'Qatar', '+974'),
  _Country('🇲🇾', 'Malaysia', '+60'),
  _Country('🇬🇧', 'UK', '+44'),
  _Country('🇺🇸', 'USA', '+1'),
  _Country('🇦🇺', 'Australia', '+61'),
];

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  _Country _selected = _countries.first; // default India +91
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<_Country>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CountryPickerSheet(selected: _selected),
    );
    if (picked != null) setState(() => _selected = picked);
  }

  String _buildPhone() {
    final digits = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    return '${_selected.dialCode}$digits';
  }

  Future<void> _sendOtp() async {
    final digits = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.isEmpty) {
      setState(() => _error = 'Please enter your phone number');
      return;
    }
    if (digits.length < 7 || digits.length > 15) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final phone = _buildPhone();
    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      if (mounted) context.push('/verify-otp', extra: phone);
    } catch (e) {
      final apiError = ApiException.extract(e);
      setState(() => _error = apiError?.message ?? 'Could not send OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.work_outline, size: 48, color: Colors.white),
              const SizedBox(height: 24),
              Text(
                'Welcome to\nDailyWork',
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your phone number to continue',
                style: GoogleFonts.nunito(fontSize: 15, color: Colors.white70),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Country code selector button
                    GestureDetector(
                      onTap: _pickCountry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Colors.grey.shade300, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_selected.flag, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 6),
                            Text(
                              _selected.dialCode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 20, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                    // Phone number input
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 17),
                        decoration: const InputDecoration(
                          hintText: 'Phone number',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: GoogleFonts.nunito(fontSize: 13, color: Colors.amber.shade200),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Send OTP',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  if (!mounted) return;
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/browse');
                  }
                },
                child: Text(
                  'Continue browsing without login',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white70,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white70,
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

class _CountryPickerSheet extends StatefulWidget {
  final _Country selected;
  const _CountryPickerSheet({required this.selected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  List<_Country> get _filtered => _query.isEmpty
      ? _countries
      : _countries
          .where((c) =>
              c.name.toLowerCase().contains(_query.toLowerCase()) ||
              c.dialCode.contains(_query))
          .toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search country',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final c = _filtered[i];
              final isSelected = c.dialCode == widget.selected.dialCode;
              return ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                title: Text(c.name, style: const TextStyle(fontSize: 15)),
                trailing: Text(
                  c.dialCode,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppTheme.primary : Colors.black54,
                  ),
                ),
                selected: isSelected,
                onTap: () => Navigator.pop(context, c),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
