import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_storage.dart';
import '../config/api_config.dart';

// ---------------------------------------------------------------------------
// Typed error
// ---------------------------------------------------------------------------

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  /// Extracts an [ApiException] from any thrown error.
  /// Handles both direct throws and the case where Dio wraps it in
  /// [DioException.error] after passing through [_ErrorInterceptor].
  static ApiException? extract(Object err) {
    if (err is ApiException) return err;
    if (err is DioException && err.error is ApiException) {
      return err.error as ApiException;
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ---------------------------------------------------------------------------
// Auth interceptor — attaches Bearer token to every outgoing request
// ---------------------------------------------------------------------------

class _AuthInterceptor extends Interceptor {
  final TokenStorage tokenStorage;

  _AuthInterceptor(this.tokenStorage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStorage.readAccess();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

// ---------------------------------------------------------------------------
// Error interceptor — maps DioException → ApiException
// (Added before _RefreshInterceptor so it fires AFTER refresh on errors)
// ---------------------------------------------------------------------------

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode ?? 0;
    final detail = err.response?.data is Map
        ? (err.response!.data['detail'] as String?)
        : null;

    final message = switch (statusCode) {
      401 => detail ?? 'Unauthorized — please log in',
      403 => detail ?? 'Access denied',
      404 => detail ?? 'Not found',
      409 => detail ?? 'Conflict',
      429 => 'Too many requests — slow down',
      500 => 'Server error — try again',
      0 => 'No connection — check your internet',
      _ => detail ?? 'Something went wrong',
    };

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: ApiException(statusCode: statusCode, message: message),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Refresh interceptor — handles 401s, refreshes tokens once, retries queued
// requests, then passes remaining errors to _ErrorInterceptor.
// Added last so it fires FIRST on errors (Dio reverses interceptor order for
// onResponse/onError).
// ---------------------------------------------------------------------------

class _RefreshInterceptor extends Interceptor {
  final TokenStorage tokenStorage;
  final Dio dio;

  bool _isRefreshing = false;
  final List<({RequestOptions options, ErrorInterceptorHandler handler})>
      _queue = [];

  _RefreshInterceptor({required this.tokenStorage, required this.dio});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final refreshToken = await tokenStorage.readRefresh();
    if (refreshToken == null) {
      await tokenStorage.clear();
      handler.next(err);
      return;
    }

    // Queue this request if another refresh is already in-flight
    if (_isRefreshing) {
      _queue.add((options: err.requestOptions, handler: handler));
      return;
    }

    _isRefreshing = true;
    try {
      // Use a plain Dio (no interceptors) for the refresh call to avoid loops
      final refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      final response = await refreshDio.post(
        '${ApiConfig.apiPrefix}/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newAccess = response.data['access_token'] as String;
      final newRefresh = response.data['refresh_token'] as String;
      await tokenStorage.saveTokens(access: newAccess, refresh: newRefresh);

      // Retry original request with new token
      final retried = await _retry(err.requestOptions, newAccess);
      handler.resolve(retried);

      // Drain queue
      for (final queued in _queue) {
        try {
          final r = await _retry(queued.options, newAccess);
          queued.handler.resolve(r);
        } catch (e) {
          queued.handler.next(err);
        }
      }
    } catch (_) {
      await tokenStorage.clear();
      for (final queued in _queue) {
        queued.handler.next(err);
      }
      handler.next(err);
    } finally {
      _isRefreshing = false;
      _queue.clear();
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options, String token) {
    return dio.request<dynamic>(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: Options(
        method: options.method,
        headers: {...options.headers, 'Authorization': 'Bearer $token'},
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Factory + provider
// ---------------------------------------------------------------------------

Dio createApiClient(TokenStorage tokenStorage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl + ApiConfig.apiPrefix,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  // Interceptors are added in this order:
  //   [_AuthInterceptor, _ErrorInterceptor, _RefreshInterceptor]
  //
  // Dio fires onRequest in insertion order and onError in REVERSE order, so:
  //   onRequest:  Auth → Error → Refresh
  //   onError:    Refresh → Error → Auth
  //
  // This ensures _RefreshInterceptor sees 401s first and can resolve them
  // before _ErrorInterceptor converts them to ApiExceptions.
  dio.interceptors.addAll([
    _AuthInterceptor(tokenStorage),
    _ErrorInterceptor(),
    _RefreshInterceptor(tokenStorage: tokenStorage, dio: dio),
  ]);

  return dio;
}

final apiClientProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return createApiClient(tokenStorage);
});
