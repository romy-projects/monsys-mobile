import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monsys_mobile/core/constants/api_constants.dart';
import 'package:monsys_mobile/core/auth/auth_storage.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref);
});

class ApiService {
  final Ref _ref;
  late final Dio _dio;
  bool _isRefreshing = false;

  ApiService(this._ref) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.timeout,
      receiveTimeout: ApiConstants.timeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _ref.read(authStorageProvider).getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // On 401, try to refresh the Sanctum token once and replay the
        // original request. Auth/login/refresh calls themselves are excluded,
        // as are already-retried requests (prevents infinite loops).
        final path = e.requestOptions.path;
        final alreadyRetried = e.requestOptions.extra['_retried'] == true;

        if (e.response?.statusCode == 401 &&
            !alreadyRetried &&
            path != ApiConstants.login &&
            path != ApiConstants.authRefresh) {
          final newToken = await _tryRefreshToken();

          if (newToken != null) {
            final retryOptions = e.requestOptions
              ..extra['_retried'] = true
              ..headers['Authorization'] = 'Bearer $newToken';
            try {
              final response = await _dio.fetch(retryOptions);
              return handler.resolve(response);
            } on DioException catch (retryError) {
              return handler.next(retryError);
            }
          }

          // Refresh failed -> the session is gone. Clear stored credentials
          // so the router redirect sends the user back to /login.
          await _ref.read(authStorageProvider).clearAll();
        }
        return handler.next(e);
      },
    ));

    // Add logging in dev mode
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  /// Attempts POST /auth/refresh (panelx deletes the current access token and
  /// issues a fresh 90-day one). Returns the new token, or null on failure.
  ///
  /// A simple single-flight guard keeps parallel 401s from triggering
  /// multiple refreshes.
  Future<String?> _tryRefreshToken() async {
    if (_isRefreshing) return null;
    _isRefreshing = true;
    try {
      final authStorage = _ref.read(authStorageProvider);
      final currentToken = await authStorage.getToken();
      if (currentToken == null) return null;

      final response = await _dio.post(
        ApiConstants.authRefresh,
        options: Options(headers: {'Authorization': 'Bearer $currentToken'}),
      );

      final data = response.data;
      final payload = data is Map && data['data'] is Map
          ? data['data'] as Map
          : data is Map
              ? data
              : null;
      final newToken =
          payload != null && payload['token'] is String ? payload['token'] as String : null;

      if (newToken != null) {
        await authStorage.saveToken(newToken);
        return newToken;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
}
