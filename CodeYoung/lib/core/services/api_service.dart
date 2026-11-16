import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Thin typed wrapper over Dio with session handling.
///
/// * Persists the bearer token in SharedPreferences.
/// * Attaches it automatically to every request.
/// * Surfaces failures as [ApiException] so screens can render friendly
///   error states instead of raw stack traces.
class ApiService {
  ApiService._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBase,
        connectTimeout: const Duration(milliseconds: AppConfig.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeout),
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.json,
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          if (e.response != null && e.response!.statusCode == 401) {
            // Session expired — drop it so the next screen shows login.
            clearSession();
          }
          handler.next(e);
        },
      ),
    );
  }

  static final ApiService instance = ApiService._();

  late final Dio _dio;
  String? _token;
  Dio get dio => _dio;

  // ---------------------------------------------------------------- auth ---

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
    } catch (_) {
      _token = null;
    }
  }

  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> _saveToken(String? value) async {
    _token = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null || value.isEmpty) {
        await prefs.remove('auth_token');
      } else {
        await prefs.setString('auth_token', value);
      }
    } catch (_) {
      // Non-fatal: in-memory token still works for this run.
    }
  }

  Future<void> clearSession() => _saveToken(null);

  // -------------------------------------------------------------- helpers ---

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    bool requireAuth = false,
  }) async {
    final data = await _request(
      () => _dio.get<Map<String, dynamic>>(path, queryParameters: query),
      path,
      requireAuth: requireAuth,
    );
    return data;
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
    bool requireAuth = false,
  }) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        path,
        queryParameters: query,
        options: Options(
          headers: _token != null ? {'Authorization': 'Bearer $_token'} : null,
        ),
      );
      if (res.statusCode == 401 && requireAuth) {
        throw const ApiException('Your session expired. Please sign in again.', 401);
      }
      if (res.statusCode == 404) return const [];
      if (res.statusCode == 401) return const [];
      if (res.data == null) return const [];
      if (res.statusCode != 200) {
        throw ApiException(_messageOf(res.data), res.statusCode ?? 500);
      }
      return res.data!;
    } on DioException catch (e) {
      throw _wrap(e, path);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool requireAuth = false,
    bool rawToken = false,
  }) {
    // Login/register often race a cold server on first open — wait it out
    // once rather than fail the user with a network error on their first tap.
    return _withWarmRetry(() async {
      try {
        final res = await _dio.post<Map<String, dynamic>>(path, data: body);
        if (res.statusCode == 401 && requireAuth) {
          throw const ApiException('Your session expired. Please sign in again.', 401);
        }
        if (res.data == null) return const {};
        if (res.statusCode != 200 && res.statusCode != 201) {
          throw ApiException(_messageOf(res.data), res.statusCode ?? 500);
        }
        if (rawToken) {
          final t = res.data!['token'];
          if (t is String) await _saveToken(t);
        }
        return res.data!;
      } on DioException catch (e) {
        throw _wrap(e, path);
      }
    }, (e) => e.isOffline);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body, {
    bool requireAuth = true,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(path, data: body);
      if (res.statusCode == 401 && requireAuth) {
        throw const ApiException('Your session expired. Please sign in again.', 401);
      }
      if (res.data == null) return const {};
      if (res.statusCode != 200) {
        throw ApiException(_messageOf(res.data), res.statusCode ?? 500);
      }
      return res.data!;
    } on DioException catch (e) {
      throw _wrap(e, path);
    }
  }

  /// DELETE helper (used to clear chat history).
  Future<Map<String, dynamic>> delete(
    String path, {
    bool requireAuth = false,
  }) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>(path);
      if (res.statusCode == 401 && requireAuth) {
        throw const ApiException('Your session expired. Please sign in again.', 401);
      }
      if (res.data == null) return const {};
      if (res.statusCode != 200 && res.statusCode != 204) {
        throw ApiException(_messageOf(res.data), res.statusCode ?? 500);
      }
      return res.data!;
    } on DioException catch (e) {
      throw _wrap(e, path);
    }
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<Map<String, dynamic>>> Function() call,
    String path, {
    required bool requireAuth,
  }) async {
    try {
      final res = await call();
      if (res.statusCode == 401) {
        if (requireAuth) {
          throw const ApiException('Your session expired. Please sign in again.', 401);
        }
        return const {};
      }
      if (res.statusCode == 404) return const {};
      if (res.data == null) return const {};
      if (res.statusCode != 200) {
        throw ApiException(_messageOf(res.data), res.statusCode ?? 500);
      }
      return res.data!;
    } on DioException catch (e) {
      throw _wrap(e, path);
    }
  }

  String _messageOf(dynamic data) {
    if (data is Map) {
      final m = data['error'] ?? data['message'] ?? data['detail'];
      if (m is String && m.isNotEmpty) return m;
    }
    return 'Something went wrong. Please try again.';
  }

  DateTime? _wokeAt;

  /// Wake the API from free-tier sleep.
  ///
  /// The hosted backend parks after ~15 minutes idle and takes up to a minute
  /// to answer its first request. Ordinary requests use a short timeout so the
  /// app stays snappy, but login/register on a cold server would then fail
  /// before the server is ready. This helper pings /health with a long
  /// deadline and remembers when the server last answered, so the warm-up
  /// cost is paid once per session rather than on every screen.
  Future<bool> wake({Duration timeout = const Duration(seconds: 65)}) async {
    if (_wokeAt != null) return true;
    try {
      final wakeDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBase,
          connectTimeout: timeout,
          receiveTimeout: timeout,
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.json,
        ),
      );
      final res = await wakeDio.get<Map<String, dynamic>>('/health');
      if (res.statusCode != 200) return false;
      _wokeAt = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fire-and-forget app-start ping. Never blocks the UI; by the time the
  /// user taps login, the server is usually already warm.
  void wakeInBackground() {
    unawaited(wake());
  }

  /// Retry a request once after waiting for a cold server.
  Future<T> _withWarmRetry<T>(
    Future<T> Function() request,
    bool Function(ApiException e) retryOn,
  ) async {
    try {
      return await request();
    } on ApiException catch (e) {
      if (!retryOn(e)) rethrow;
      // Cold start: wait for /health, then try once more.
      final up = await wake();
      if (!up) {
        throw const ApiException(
          'The CodeYoung server is still starting up. Please wait about a '
          'minute and tap again — your details are safe.',
          0,
        );
      }
      return request();
    }
  }

  ApiException _wrap(DioException e, String path) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ApiException(
        'The CodeYoung server is still waking up — this can take up to a '
        'minute if it has been idle. Please try again in a moment.',
        0,
        path: path,
      );
    }
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return ApiException(_messageOf(data), e.response?.statusCode ?? 0, path: path);
    }
    if (e.response != null) {
      return ApiException('Server error (${e.response?.statusCode}). Please try again.',
          e.response?.statusCode ?? 0, path: path);
    }
    return ApiException('Unexpected network error. Please check your connection.', 0,
        path: path);
  }
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode, {this.path});

  final String message;
  final int statusCode;
  final String? path;

  bool get isUnauthorized => statusCode == 401;
  bool get isOffline => statusCode == 0;

  @override
  String toString() => message;

  @visibleForTesting
  String debug() => 'ApiException($statusCode, $path): $message';
}
