import 'package:flutter/services.dart';
import 'package:flutter_env_switch/core/env_loader.dart';
import 'package:flutter_env_switch/core/env_manager.dart';
import 'package:flutter_env_switch/core/env_store.dart';
import 'package:flutter_env_switch/models/env_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _Env { dev, staging, production }

/// In-memory asset bundle for testing.
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

EnvLoader _loader(Map<String, String> assets) =>
    EnvLoader(bundle: _FakeBundle(assets));

const Map<_Env, String> _configs = {
  _Env.dev: 'assets/.env.dev',
  _Env.staging: 'assets/.env.staging',
  _Env.production: 'assets/.env.production',
};

const Map<String, String> _assets = {
  'assets/.env.dev':
      'BASE_URL=https://dev.example.com\nFEATURE_X=true\n'
      'FEATURE_BOOL_ONE=1\nFEATURE_BOOL_YES=yes\n'
      'TIMEOUT=5\nRATIO=1.5\nBAD_INT=notanint\nBAD_DOUBLE=notadouble',
  'assets/.env.staging':
      'BASE_URL=https://staging.example.com\nFEATURE_X=false\nTIMEOUT=15\nRATIO=0.5',
  'assets/.env.production':
      'BASE_URL=https://api.example.com\nFEATURE_X=false\nTIMEOUT=30\nRATIO=2.0',
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EnvManager.reset();
  });

  tearDown(EnvManager.reset);

  group('EnvManager.init', () {
    test('loads all environments and sets default', () async {
      final manager = await EnvManager.init<_Env>(
        defaultEnv: _Env.production,
        configs: _configs,
        loader: _loader(_assets),
        store: EnvStore(),
      );

      expect(manager.current, _Env.production);
    });

    test('restores persisted environment on init', () async {
      SharedPreferences.setMockInitialValues({
        'envify_selected_env': 'staging',
      });

      final manager = await EnvManager.init<_Env>(
        defaultEnv: _Env.production,
        configs: _configs,
        loader: _loader(_assets),
        store: EnvStore(),
      );

      expect(manager.current, _Env.staging);
    });

    test('falls back to default when persisted value is unknown', () async {
      SharedPreferences.setMockInitialValues({
        'envify_selected_env': 'unknown_env',
      });

      final manager = await EnvManager.init<_Env>(
        defaultEnv: _Env.dev,
        configs: _configs,
        loader: _loader(_assets),
        store: EnvStore(),
      );

      expect(manager.current, _Env.dev);
    });

    test('throws EnvLoadException when asset is missing', () async {
      expect(
        () => EnvManager.init<_Env>(
          defaultEnv: _Env.dev,
          configs: _configs,
          loader: _loader({}), // empty bundle
          store: EnvStore(),
        ),
        throwsA(isA<EnvLoadException>()),
      );
    });
  });

  group('EnvManager accessors', () {
    late EnvManager<_Env> manager;

    setUp(() async {
      manager = await EnvManager.init<_Env>(
        defaultEnv: _Env.dev,
        configs: _configs,
        loader: _loader(_assets),
        store: EnvStore(),
      );
    });

    test('get returns correct string value', () {
      expect(manager.get('BASE_URL'), 'https://dev.example.com');
    });

    test('getInt returns parsed int', () {
      expect(manager.getInt('TIMEOUT'), 5);
    });

    test('getBool returns true for "true"', () {
      expect(manager.getBool('FEATURE_X'), isTrue);
    });

    test('getBool returns false for "false"', () async {
      await manager.switchTo(_Env.staging);
      expect(manager.getBool('FEATURE_X'), isFalse);
    });

    test('getOrElse returns value when key exists', () {
      expect(manager.getOrElse('BASE_URL', 'fallback'),
          'https://dev.example.com');
    });

    test('getOrElse returns fallback when key missing', () {
      expect(manager.getOrElse('MISSING_KEY', 'fallback'), 'fallback');
    });

    test('get throws EnvKeyNotFoundException for missing key', () {
      expect(
        () => manager.get('DOES_NOT_EXIST'),
        throwsA(isA<EnvKeyNotFoundException>()),
      );
    });

    test('getDouble returns parsed double', () {
      expect(manager.getDouble('RATIO'), 1.5);
    });

    test('getBool returns true for "1"', () {
      expect(manager.getBool('FEATURE_BOOL_ONE'), isTrue);
    });

    test('getBool returns true for "yes"', () {
      expect(manager.getBool('FEATURE_BOOL_YES'), isTrue);
    });

    test('getInt throws FormatException for non-integer value', () {
      expect(
        () => manager.getInt('BAD_INT'),
        throwsA(isA<FormatException>()),
      );
    });

    test('getDouble throws FormatException for non-double value', () {
      expect(
        () => manager.getDouble('BAD_DOUBLE'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('EnvManager.switchTo', () {
    late EnvManager<_Env> manager;

    setUp(() async {
      manager = await EnvManager.init<_Env>(
        defaultEnv: _Env.dev,
        configs: _configs,
        loader: _loader(_assets),
        store: EnvStore(),
      );
    });

    test('updates current environment', () async {
      await manager.switchTo(_Env.staging);
      expect(manager.current, _Env.staging);
    });

    test('notifies ValueNotifier listeners', () async {
      _Env? notified;
      manager.currentNotifier.addListener(() {
        notified = manager.currentNotifier.value;
      });
      await manager.switchTo(_Env.production);
      expect(notified, _Env.production);
    });

    test('persists the new selection', () async {
      await manager.switchTo(_Env.staging);
      final store = EnvStore();
      expect(await store.load(), 'staging');
    });

    test('accessing values reflects switched environment', () async {
      await manager.switchTo(_Env.production);
      expect(manager.get('BASE_URL'), 'https://api.example.com');
      expect(manager.getInt('TIMEOUT'), 30);
    });

    test('switching to same environment is a no-op (no error)', () async {
      await manager.switchTo(_Env.dev);
      expect(manager.current, _Env.dev);
    });

    test('does not write to store when persistSelection is false', () async {
      EnvManager.reset();
      SharedPreferences.setMockInitialValues({});
      final m = await EnvManager.init<_Env>(
        defaultEnv: _Env.dev,
        configs: _configs,
        loader: _loader(_assets),
        store: EnvStore(),
        persistSelection: false,
      );

      await m.switchTo(_Env.staging);
      expect(m.current, _Env.staging);

      // Store must still be empty — no write happened.
      final store = EnvStore();
      expect(await store.load(), isNull);
    });
  });

  group('EnvManager.instance', () {
    test('throws EnvNotInitializedException before init', () {
      expect(
        () => EnvManager.instance,
        throwsA(isA<EnvNotInitializedException>()),
      );
    });

    test('returns singleton after init', () async {
      await EnvManager.init<_Env>(
        defaultEnv: _Env.dev,
        configs: _configs,
        loader: _loader(_assets),
        store: EnvStore(),
      );
      expect(EnvManager.instance, isNotNull);
    });
  });

  group('EnvManager persistSelection', () {
    test('defaults to true — persists and restores selection', () async {
      final m = await EnvManager.init<_Env>(
        defaultEnv: _Env.dev,
        configs: _configs,
        loader: _loader(_assets),
        store: EnvStore(),
      );

      expect(m.persistSelection, isTrue);

      await m.switchTo(_Env.staging);
      expect(await EnvStore().load(), 'staging');
    });

    test('persistSelection: false clears store on init', () async {
      // Pre-seed a stored value.
      SharedPreferences.setMockInitialValues({
        'envify_selected_env': 'staging',
      });

      final m = await EnvManager.init<_Env>(
        defaultEnv: _Env.dev,
        configs: _configs,
        loader: _loader(_assets),
        store: EnvStore(),
        persistSelection: false,
      );

      // Store is cleared; always uses defaultEnv.
      expect(m.current, _Env.dev);
      expect(await EnvStore().load(), isNull);
    });

    test('persistSelection: false ignores persisted env', () async {
      SharedPreferences.setMockInitialValues({
        'envify_selected_env': 'production',
      });

      final m = await EnvManager.init<_Env>(
        defaultEnv: _Env.dev,
        configs: _configs,
        loader: _loader(_assets),
        store: EnvStore(),
        persistSelection: false,
      );

      expect(m.current, _Env.dev);
    });

    test('setPersistSelection(false) clears the store', () async {
      final m = await EnvManager.init<_Env>(
        defaultEnv: _Env.dev,
        configs: _configs,
        loader: _loader(_assets),
        store: EnvStore(),
      );

      await m.switchTo(_Env.staging);
      expect(await EnvStore().load(), 'staging');

      await m.setPersistSelection(false);
      expect(m.persistSelection, isFalse);
      expect(await EnvStore().load(), isNull);
    });

    test('setPersistSelection(true) saves current env immediately', () async {
      final m = await EnvManager.init<_Env>(
        defaultEnv: _Env.dev,
        configs: _configs,
        loader: _loader(_assets),
        store: EnvStore(),
        persistSelection: false,
      );

      // Switch in-session (not saved).
      await m.switchTo(_Env.production);
      expect(await EnvStore().load(), isNull);

      // Enable persist — current env must be saved right away.
      await m.setPersistSelection(true);
      expect(m.persistSelection, isTrue);
      expect(await EnvStore().load(), 'production');
    });
  });

  group('EnvManager locked environments', () {
    Future<EnvManager<_Env>> initLocked({
      _Env defaultEnv = _Env.production,
      Set<_Env>? lockedEnvironments,
    }) =>
        EnvManager.init<_Env>(
          defaultEnv: defaultEnv,
          configs: _configs,
          loader: _loader(_assets),
          store: EnvStore(),
          lockedEnvironments: lockedEnvironments,
        );

    test('isCurrentLocked is true when current env is in locked set', () async {
      final manager = await initLocked(
        lockedEnvironments: {_Env.production},
      );
      expect(manager.isCurrentLocked, isTrue);
    });

    test('isCurrentLocked is false when current env is not in locked set',
        () async {
      final manager = await initLocked(
        defaultEnv: _Env.dev,
        lockedEnvironments: {_Env.production},
      );
      expect(manager.isCurrentLocked, isFalse);
    });

    test('switchTo throws EnvSwitchLockedException when current env is locked',
        () async {
      final manager = await initLocked(
        lockedEnvironments: {_Env.production},
      );
      expect(
        () => manager.switchTo(_Env.dev),
        throwsA(isA<EnvSwitchLockedException>()),
      );
    });

    test(
        'switching works normally in non-locked env when other envs are locked',
        () async {
      final manager = await initLocked(
        defaultEnv: _Env.dev,
        lockedEnvironments: {_Env.production},
      );
      await manager.switchTo(_Env.staging);
      expect(manager.current, _Env.staging);
    });

    test('switching TO a locked env from a non-locked env succeeds', () async {
      final manager = await initLocked(
        defaultEnv: _Env.dev,
        lockedEnvironments: {_Env.production},
      );
      // From dev (not locked) → production (locked) is allowed.
      await manager.switchTo(_Env.production);
      expect(manager.current, _Env.production);
      // Now in production (locked) — further switching is blocked.
      expect(
        () => manager.switchTo(_Env.dev),
        throwsA(isA<EnvSwitchLockedException>()),
      );
    });

    test('no lock applies when lockedEnvironments is null (default)', () async {
      final manager = await initLocked();
      expect(manager.isCurrentLocked, isFalse);
      await manager.switchTo(_Env.dev);
      expect(manager.current, _Env.dev);
    });

    test('multiple envs can be locked simultaneously', () async {
      final manager = await initLocked(
        defaultEnv: _Env.dev,
        lockedEnvironments: {_Env.dev, _Env.production},
      );
      expect(manager.isCurrentLocked, isTrue);
      expect(
        () => manager.switchTo(_Env.staging),
        throwsA(isA<EnvSwitchLockedException>()),
      );
    });
  });
}
