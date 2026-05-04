import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_env_switch/core/env_loader.dart';
import 'package:flutter_env_switch/core/env_manager.dart';
import 'package:flutter_env_switch/core/env_store.dart';
import 'package:flutter_env_switch/integrations/dio_interceptor.dart';
import 'package:flutter_env_switch/models/env_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _Env { dev, production }

class _FakeBundle extends Fake implements AssetBundle {
  _FakeBundle(this._assets);
  final Map<String, String> _assets;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final c = _assets[key];
    if (c == null) throw Exception('Asset not found: $key');
    return c;
  }
}

const _assets = {
  'assets/.env.dev': 'BASE_URL=https://dev.api.example.com\nAPI=https://api2.example.com',
  'assets/.env.production': 'BASE_URL=https://api.example.com',
};

const _configs = {
  _Env.dev: 'assets/.env.dev',
  _Env.production: 'assets/.env.production',
};

Future<void> _initManager({_Env defaultEnv = _Env.production}) async {
  SharedPreferences.setMockInitialValues({});
  EnvManager.reset();
  await EnvManager.init<_Env>(
    defaultEnv: defaultEnv,
    configs: _configs,
    loader: EnvLoader(bundle: _FakeBundle(_assets)),
    store: EnvStore(),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(EnvManager.reset);

  group('EnvDioInterceptor', () {
    test('injects BASE_URL from active environment into request', () async {
      await _initManager();
      const interceptor = EnvDioInterceptor();

      final options = RequestOptions(path: '/endpoint');
      interceptor.onRequest(
        options,
        // No const constructor in Dio's RequestInterceptorHandler.
        // ignore: prefer_const_constructors
        RequestInterceptorHandler(),
      );

      expect(options.baseUrl, 'https://api.example.com');
    });

    test('uses custom baseUrlKey when provided', () async {
      await _initManager(defaultEnv: _Env.dev);
      const interceptor = EnvDioInterceptor(baseUrlKey: 'API');

      final options = RequestOptions(path: '/endpoint');
      interceptor.onRequest(
        options,
        // No const constructor in Dio's RequestInterceptorHandler.
        // ignore: prefer_const_constructors
        RequestInterceptorHandler(),
      );

      expect(options.baseUrl, 'https://api2.example.com');
    });

    test('throws EnvKeyNotFoundException when key is missing', () async {
      await _initManager();
      const interceptor = EnvDioInterceptor(baseUrlKey: 'MISSING_KEY');

      final options = RequestOptions(path: '/endpoint');

      expect(
        () => interceptor.onRequest(
          options,
          // No const constructor in Dio's RequestInterceptorHandler.
          // ignore: prefer_const_constructors
          RequestInterceptorHandler(),
        ),
        throwsA(isA<EnvKeyNotFoundException>()),
      );
    });

    test('reflects switched environment on next request', () async {
      await _initManager();
      await EnvManager.instance.switchTo(_Env.dev);

      const interceptor = EnvDioInterceptor();
      final options = RequestOptions(path: '/endpoint');
      interceptor.onRequest(
        options,
        // No const constructor in Dio's RequestInterceptorHandler.
        // ignore: prefer_const_constructors
        RequestInterceptorHandler(),
      );

      expect(options.baseUrl, 'https://dev.api.example.com');
    });
  });
}
