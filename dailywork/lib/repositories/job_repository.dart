import '../models/category_model.dart';
import '../models/job_model.dart';
import '../models/job_filter.dart';

abstract class JobRepository {
  Future<List<JobModel>> getJobs({String? categoryId, JobFilter? filter});
  Future<JobModel> getJobById(String id);
  Future<List<CategoryModel>> getCategories();
}
