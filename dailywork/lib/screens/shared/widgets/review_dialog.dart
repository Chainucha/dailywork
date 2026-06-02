import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/language_provider.dart';

/// Result of the review dialog — a 1-5 star rating plus an optional comment.
class ReviewInput {
  final int rating;
  final String? comment;
  const ReviewInput({required this.rating, this.comment});
}

/// Shows a star-rating + comment dialog. Returns the [ReviewInput] when the
/// user submits, or null if they dismiss. Submit is disabled until a star is
/// picked, so a returned value always has rating >= 1.
Future<ReviewInput?> showReviewDialog(BuildContext context) {
  return showDialog<ReviewInput>(
    context: context,
    builder: (_) => const _ReviewDialog(),
  );
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog();

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return AlertDialog(
      title: Text(strings['review_title'] ?? 'Leave a review'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  iconSize: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: strings['review_comment_hint'] ?? 'Add a comment (optional)',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings['review_cancel'] ?? 'Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: _rating == 0
              ? null
              : () => Navigator.pop(
                    context,
                    ReviewInput(rating: _rating, comment: _commentCtrl.text),
                  ),
          child: Text(
            strings['review_submit'] ?? 'Submit',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
