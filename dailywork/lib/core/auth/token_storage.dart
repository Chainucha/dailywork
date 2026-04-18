import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _accessKey = 'dw_access_token';
  static const _refreshKey = 'dw_refresh_token';

  // In-memory cache — populated on save so tokens are immediately available
  // for the next request even if FlutterSecureStorage is slow or unreliable
  // on the current device/emulator.
  String? _accessCache;
  String? _refreshCache;

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    _accessCache = access;
    _refreshCache = refresh;
    await Future.wait([
      _storage.write(key: _accessKey, value: access),
      _storage.write(key: _refreshKey, value: refresh),
    ]);
  }

  Future<String?> readAccess() async =>
      _accessCache ?? await _storage.read(key: _accessKey);

  Future<String?> readRefresh() async =>
      _refreshCache ?? await _storage.read(key: _refreshKey);

  Future<void> clear() async {
    _accessCache = null;
    _refreshCache = null;
    await _storage.deleteAll();
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
