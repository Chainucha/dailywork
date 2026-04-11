import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../repositories/job_repository.dart';
import '../repositories/mock_job_repository.dart';

// The repository provider — swap MockJobRepository for ApiJobRepository to use real API
final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return MockJobRepository();
});

// Fetches all categories
final categoryListProvider = FutureProvider<List<CategoryModel>>((ref) {
  return ref.watch(jobRepositoryProvider).getCategories();
});

// Currently selected category chip (null = "All")
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
