import 'package:flutter/services.dart';
import 'package:flutter_env_switch/core/env_loader.dart';
import 'package:flutter_env_switch/models/env_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal [AssetBundle] that serves from an in-memory map.
class _FakeBundle extends Fake implements AssetBundle {
  _FakeBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final content = _assets[key];
    if (content == null) throw Exception('Asset not found: $key');
    return content;
  }
}

void main() {
  group('EnvLoader', () {
    test('loads and parses a valid asset', () async {
      final bundle = _FakeBundle({
        'assets/.env.dev': 'BASE_URL=https://dev.example.com\nTIMEOUT=10',
      });
      final loader = EnvLoader(bundle: bundle);

      final result = await loader.load('assets/.env.dev');

      expect(result['BASE_URL'], 'https://dev.example.com');
      expect(result['TIMEOUT'], '10');
    });

    test('throws EnvLoadException for missing asset', () async {
      final bundle = _FakeBundle({});
      final loader = EnvLoader(bundle: bundle);

      expect(
        () => loader.load('assets/.env.missing'),
        throwsA(isA<EnvLoadException>()),
      );
    });

    test('returns empty map for empty asset file', () async {
      final bundle = _FakeBundle({'assets/.env': ''});
      final loader = EnvLoader(bundle: bundle);

      final result = await loader.load('assets/.env');
      expect(result.isEmpty, isTrue);
    });
  });
}
