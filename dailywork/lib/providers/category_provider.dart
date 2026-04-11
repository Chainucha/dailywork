import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../repositories/job_repository.dart';
import '../repositories/mock_job_repository.dart';

// The repository provider — swap MockJobRepository for ApiJobRepository to use real API
final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return MockJobRepository();
});

// Categories are loaded once per session and not autoDisposed — intentional,
// as the category list is static for the app's lifetime.
final categoryListProvider = FutureProvider<List<CategoryModel>>((ref) {
  return ref.read(jobRepositoryProvider).getCategories();
});

// Currently selected category chip (null = "All")
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
