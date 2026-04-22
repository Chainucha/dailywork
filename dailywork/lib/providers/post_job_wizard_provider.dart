import 'package:flutter_riverpod/flutter_riverpod.dart';

class PostJobWizardState {
  final String? categoryId;
  final String title;
  final String? description;
  final double? locationLat;
  final double? locationLng;
  final String? addressText;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? startTime;
  final String? endTime;
  final int workersNeeded;
  final double? wagePerDay;
  final bool isUrgent;

  const PostJobWizardState({
    this.categoryId,
    this.title = '',
    this.description,
    this.locationLat,
    this.locationLng,
    this.addressText,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.workersNeeded = 1,
    this.wagePerDay,
    this.isUrgent = false,
  });

  PostJobWizardState copyWith({
    String? categoryId,
    String? title,
    String? description,
    double? locationLat,
    double? locationLng,
    String? addressText,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    String? endTime,
    int? workersNeeded,
    double? wagePerDay,
    bool? isUrgent,
  }) => PostJobWizardState(
    categoryId: categoryId ?? this.categoryId,
    title: title ?? this.title,
    description: description ?? this.description,
    locationLat: locationLat ?? this.locationLat,
    locationLng: locationLng ?? this.locationLng,
    addressText: addressText ?? this.addressText,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    workersNeeded: workersNeeded ?? this.workersNeeded,
    wagePerDay: wagePerDay ?? this.wagePerDay,
    isUrgent: isUrgent ?? this.isUrgent,
  );

  bool get step1Valid =>
      categoryId != null && title.trim().isNotEmpty &&
      locationLat != null && locationLng != null;

  bool get step2Valid =>
      startDate != null && endDate != null &&
      !endDate!.isBefore(startDate!) && workersNeeded >= 1;

  bool get step3Valid => wagePerDay != null && wagePerDay! > 0;

  Map<String, dynamic> toCreateBody() => {
    'category_id': categoryId,
    'title': title,
    if (description != null && description!.isNotEmpty) 'description': description,
    'location_lat': locationLat,
    'location_lng': locationLng,
    if (addressText != null) 'address_text': addressText,
    'wage_per_day': wagePerDay,
    'workers_needed': workersNeeded,
    'start_date': startDate!.toIso8601String().split('T').first,
    'end_date': endDate!.toIso8601String().split('T').first,
    if (startTime != null) 'start_time': startTime,
    if (endTime != null) 'end_time': endTime,
    'is_urgent': isUrgent,
  };
}

class PostJobWizardNotifier extends StateNotifier<PostJobWizardState> {
  PostJobWizardNotifier() : super(const PostJobWizardState());

  void update(PostJobWizardState Function(PostJobWizardState s) fn) {
    state = fn(state);
  }

  void reset() => state = const PostJobWizardState();
}

final postJobWizardProvider =
    StateNotifierProvider.autoDispose<PostJobWizardNotifier, PostJobWizardState>(
  (ref) => PostJobWizardNotifier(),
);
