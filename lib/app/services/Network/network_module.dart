import 'dart:async';

import 'package:billkaro/app/services/auth/auth_session_service.dart';
import 'package:billkaro/app/services/Network/api_config.dart';
import 'package:billkaro/config/config.dart' hide Response;
import 'package:billkaro/utils/trusted_http_client.dart';
import 'package:dio/dio.dart';

String get _dioBaseUrl {
  const fromDefine = String.fromEnvironment('BASE_URL');
  if (fromDefine.isNotEmpty) return fromDefine;
  return ApiConfig.baseUrl;
}

class NetworkModule {
  // Flag to track if an error message is already shown
  static bool _isErrorBeingHandled = false;

  /// Single in-flight refresh so parallel 401s share one refresh call.
  static Completer<bool>? _refreshCompleter;

  /// Login / signup / OTP / refresh calls are not an active session.
  static bool _isPublicAuthRequest(RequestOptions options) {
    final path = '${options.uri.path} ${options.path}'.toLowerCase();
    return path.contains('auth/login') ||
        path.contains('auth/staff/login') ||
        path.contains('auth/register') ||
        path.contains('auth/refresh') ||
        path.contains('auth/forgot-password') ||
        path.contains('auth/staff/forgot-password') ||
        path.contains('auth/phone/') ||
        path.contains('auth/staff/phone/') ||
        path.contains('auth/resend-activation') ||
        path.contains('auth/verify-email') ||
        path.contains('auth/check-email') ||
        path.contains('auth/check-mobile');
  }

  /// Call POST /auth/refresh with a bare Dio (no interceptors).
  static Future<bool> _tryRefreshTokens(AppPref appPref) async {
    final refresh = appPref.refreshToken.trim();
    if (refresh.isEmpty) return false;

    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: _dioBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      configureTrustedDio(refreshDio);

      final res = await refreshDio.post(
        refreshTokenPath,
        data: {'refresh_token': refresh},
      );

      if (res.statusCode == 200 && res.data is Map) {
        final data = Map<String, dynamic>.from(res.data as Map);
        final access = data['access_token']?.toString() ?? '';
        final newRefresh = data['refresh_token']?.toString() ?? '';
        if (access.isNotEmpty) {
          appPref.token = access;
          if (newRefresh.isNotEmpty) {
            appPref.refreshToken = newRefresh;
          }
          completer.complete(true);
          return true;
        }
      }

      completer.complete(false);
      return false;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      if (!completer.isCompleted) completer.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// On 401: refresh once, then retry the original request.
  static Future<Response?> _retryAfterRefresh(
    Dio dio,
    AppPref appPref,
    RequestOptions options,
  ) async {
    if (options.extra['tokenRetried'] == true) return null;
    if (_isPublicAuthRequest(options)) return null;
    if (appPref.refreshToken.trim().isEmpty) return null;

    final ok = await _tryRefreshTokens(appPref);
    if (!ok) return null;

    final opts = options.copyWith(
      headers: {...options.headers, 'authorization': 'Bearer ${appPref.token}'},
      extra: {...options.extra, 'tokenRetried': true},
    );
    return dio.fetch(opts);
  }

  static Future<void> _handleUnauthorizedResponse({
    required RequestOptions requestOptions,
    dynamic data,
  }) async {
    final message = AuthSessionService.messageFromBody(data);
    if (_isPublicAuthRequest(requestOptions)) {
      markApiErrorUiShown(requestOptions);
      showError(
        description: (message != null && message.trim().isNotEmpty)
            ? message
            : 'Invalid credentials',
      );
      return;
    }
    await AuthSessionService.handleUnauthorized(message: message);
  }

  static void _showHttpError(
    RequestOptions requestOptions,
    String? description,
  ) {
    markApiErrorUiShown(requestOptions);
    if (description == null || description.trim().isEmpty) return;
    showError(description: description);
  }

  static String? _messageFromData(dynamic data) {
    if (data is Map) {
      final message = data['message'];
      if (message is String) return message;
      if (message is List) return message.join(', ');
    }
    return null;
  }

  // Helper method to safely dismiss loaders with error handling
  static void safelyDismissLoader() {
    try {
      dismissAllAppLoader();
      debugPrint('Loader dismissed successfully');
    } catch (e) {
      debugPrint('Error dismissing loader: $e');
    }
  }

  static Dio prepareDio() {
    final dio = Dio();
    configureTrustedDio(dio);
    final appPref = Get.find<AppPref>();

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (option, handler) async {
          // Reset the error flag at the start of each request
          _isErrorBeingHandled = false;

          final customHeaders = <String, dynamic>{
            "authorization": "Bearer ${appPref.token}",
            "Content-Type": "application/json",
          };
          option.headers.addAll(customHeaders);

          handler.next(option);
        },
        onResponse: (response, handler) async {
          // Handle different status codes properly
          if (response.statusCode == 200) {
            return handler.next(response);
          } else if (response.statusCode == 401) {
            try {
              final retried = await _retryAfterRefresh(
                dio,
                appPref,
                response.requestOptions,
              );
              if (retried != null) {
                return handler.resolve(retried);
              }
            } catch (e) {
              debugPrint('Retry after token refresh failed: $e');
            }

            safelyDismissLoader();
            if (!_isErrorBeingHandled) {
              _isErrorBeingHandled = true;
              await _handleUnauthorizedResponse(
                requestOptions: response.requestOptions,
                data: response.data,
              );
            }
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          } else if (response.statusCode == 502) {
            if (!_isErrorBeingHandled) {
              _isErrorBeingHandled = true;
              safelyDismissLoader();
              debugPrint('Response: ${response.data}');
              _showHttpError(
                response.requestOptions,
                'Something went wrong. Please try again later.',
              );
            }
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          } else if (response.statusCode == 400) {
            if (!_isErrorBeingHandled) {
              _isErrorBeingHandled = true;
              safelyDismissLoader();
              debugPrint('Response: ${response.data}');
              _showHttpError(
                response.requestOptions,
                _messageFromData(response.data),
              );
            }
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          } else if (response.statusCode == 404) {
            safelyDismissLoader();
            _isErrorBeingHandled = true;
            _showHttpError(
              response.requestOptions,
              _messageFromData(response.data),
            );
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          } else if (response.statusCode == 409) {
            safelyDismissLoader();
            _isErrorBeingHandled = true;
            _showHttpError(
              response.requestOptions,
              _messageFromData(response.data),
            );
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          } else if ((response.statusCode ?? 0) >= 500) {
            if (!_isErrorBeingHandled) {
              _isErrorBeingHandled = true;
              safelyDismissLoader();
              final errorMessage = _messageFromData(response.data);
              _showHttpError(
                response.requestOptions,
                (errorMessage != null && errorMessage.trim().isNotEmpty)
                    ? errorMessage
                    : 'Something went wrong. Please try again later.',
              );
            }
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          }

          // Pass other successful responses through (e.g. 201 Created)
          handler.next(response);
        },
        onError: (DioException error, handler) async {
          // ALWAYS dismiss loader first for any error
          safelyDismissLoader();

          // Only handle errors if not already being handled
          if (!_isErrorBeingHandled) {
            _isErrorBeingHandled = true;

            if (error.response?.statusCode == 401) {
              try {
                final retried = await _retryAfterRefresh(
                  dio,
                  appPref,
                  error.requestOptions,
                );
                if (retried != null) {
                  _isErrorBeingHandled = false;
                  return handler.resolve(retried);
                }
                await _handleUnauthorizedResponse(
                  requestOptions: error.requestOptions,
                  data: error.response?.data,
                );
              } catch (e) {
                debugPrint(
                  'Error handling token expiration in error handler: $e',
                );
                safelyDismissLoader();
              }
            } else if (error.response?.statusCode == 502) {
              _showHttpError(
                error.requestOptions,
                'Server is temporarily unavailable. Please try again shortly.',
              );
            } else if (error.response?.statusCode == 400) {
              final errorMessage =
                  _messageFromData(error.response?.data) ??
                  error.message ??
                  'Bad request';
              _showHttpError(error.requestOptions, errorMessage);
            } else if (error.response?.statusCode == 409) {
              final errorMessage =
                  _messageFromData(error.response?.data) ??
                  error.message ??
                  'Bad request';
              _showHttpError(error.requestOptions, errorMessage);
            } else {
              // Reset flag for other errors that we're passing through
              _isErrorBeingHandled = false;
            }
          }

          handler.reject(error);
        },
      ),
    );

    /// print api log in DEBUG mode
    if (AppGlobal.debugLoggerEnable) {
      dio.interceptors.add(
        TalkerDioLogger(
          settings: TalkerDioLoggerSettings(
            printResponseMessage: false,
            printRequestHeaders: true,
            printErrorHeaders: false,
            responseFilter: (response) {
              return true;
            },
          ),
        ),
      );
    }

    // Add base options
    dio.options = BaseOptions(
      validateStatus: (status) {
        // Consider all responses as valid to handle them in interceptors
        return status! < 600;
      },
      receiveTimeout: const Duration(seconds: 30),
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    );

    return dio;
  }

  // Clears session and returns to login without a dialog
  static Future<void> _handleTokenExpiration() async {
    try {
      debugPrint('Starting token expiration handling...');

      safelyDismissLoader();
      await AuthSessionService.clearSessionData();
      Get.offAllNamed(AppRoute.main);

      debugPrint('Token expiration handling completed');
    } catch (e) {
      debugPrint('Error in _handleTokenExpiration: $e');
      safelyDismissLoader();

      try {
        Get.offAllNamed(AppRoute.main);
      } catch (navError) {
        debugPrint('Error navigating to main screen: $navError');
      }
    } finally {
      _isErrorBeingHandled = false;
      safelyDismissLoader();
    }
  }

  static ApiClient getApiClient() =>
      ApiClient(Get.find<Dio>(), baseUrl: _dioBaseUrl);
}
