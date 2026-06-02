import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/core/network/api_client.dart';

class Review {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String reviewerDisplayName;

  const Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.reviewerDisplayName,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        rating: json['rating'] as int,
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        reviewerDisplayName: (json['reviewer_display_name'] as String?) ?? '',
      );
}

class ReviewPage {
  final List<Review> items;
  final int total;
  final int limit;
  final int offset;

  const ReviewPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory ReviewPage.fromJson(Map<String, dynamic> json) => ReviewPage(
        items: (json['items'] as List<dynamic>)
            .map((e) => Review.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        limit: json['limit'] as int,
        offset: json['offset'] as int,
      );
}

class ApiReviewRepository {
  final Dio _dio;
  ApiReviewRepository(this._dio);

  Future<ReviewPage> getUserReviews(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/$userId/reviews',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return ReviewPage.fromJson(res.data!);
  }

  /// Submit a review for a completed job. [revieweeId] is the user being rated
  /// (the employer when a worker reviews, the worker when an employer reviews).
  /// Throws a [DioException] on failure (e.g. 409 if already reviewed).
  Future<void> submitReview({
    required String revieweeId,
    required String jobId,
    required int rating,
    String? comment,
  }) async {
    final trimmed = comment?.trim();
    await _dio.post<Map<String, dynamic>>(
      '/reviews/',
      data: {
        'reviewee_id': revieweeId,
        'job_id': jobId,
        'rating': rating,
        if (trimmed != null && trimmed.isNotEmpty) 'comment': trimmed,
      },
    );
  }
}

final apiReviewRepositoryProvider = Provider<ApiReviewRepository>((ref) {
  return ApiReviewRepository(ref.watch(apiClientProvider));
});

final userReviewsProvider =
    FutureProvider.family<ReviewPage, String>((ref, userId) async {
  return ref.watch(apiReviewRepositoryProvider).getUserReviews(userId);
});
