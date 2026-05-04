// This file provides an optional integration with the `dio` HTTP client
// package. Since `dio` is a peer dependency (not a hard dependency of
// `flutter_env_switch`), we suppress the `depend_on_referenced_packages`
// warning that would otherwise require `dio` to be listed in
// flutter_env_switch's own pubspec.yaml.
// ignore: depend_on_referenced_packages
import 'package:dio/dio.dart';

import 'package:flutter_env_switch/env.dart';

/// A [Dio] [Interceptor] that injects `BASE_URL` from the active environment
/// into every outgoing request.
///
/// **Peer dependency:** `dio` is not a hard dependency of `flutter_env_switch`.
/// Add it to your own `pubspec.yaml`:
/// ```yaml
/// dependencies:
///   dio: ^5.0.0
/// ```
///
/// ### Usage
/// ```dart
/// final dio = Dio()..interceptors.add(EnvDioInterceptor());
/// ```
///
/// By default, the interceptor reads `'BASE_URL'` from the active env. You
/// can customise the key with the [baseUrlKey] constructor parameter.
class EnvDioInterceptor extends Interceptor {
  /// Creates an [EnvDioInterceptor].
  ///
  /// [baseUrlKey] defaults to `'BASE_URL'`.
  const EnvDioInterceptor({this.baseUrlKey = 'BASE_URL'});

  /// The `.env` key whose value is used as `options.baseUrl`.
  final String baseUrlKey;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    options.baseUrl = Env.get(baseUrlKey);
    handler.next(options);
  }
}
