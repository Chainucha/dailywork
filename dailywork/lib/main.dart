import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'models/job_model.dart';
import 'providers/job_cache_provider.dart';
import 'providers/category_provider.dart';

void main() {
  runApp(const ProviderScope(child: DailyWorkApp()));
}

class DailyWorkApp extends ConsumerStatefulWidget {
  const DailyWorkApp({super.key});

  @override
  ConsumerState<DailyWorkApp> createState() => _DailyWorkAppState();
}

class _DailyWorkAppState extends ConsumerState<DailyWorkApp> {
  late AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // Only refresh if jobs were already loaded (i.e., user is authenticated
        // and navigated to worker home).
        final cacheState = ref.read(jobCacheProvider);
        if (cacheState is! AsyncData<List<JobModel>>) return;
        final category = ref.read(selectedCategoryProvider);
        final notifier = ref.read(jobCacheProvider.notifier);
        if (notifier.isStale(category)) {
          notifier.getJobs(category, force: true).ignore();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'DailyWork',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
