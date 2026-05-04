import 'package:flutter_env_switch/core/env_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EnvStore', () {
    test('save and load round-trip', () async {
      final store = EnvStore();
      await store.save('staging');
      final loaded = await store.load();
      expect(loaded, 'staging');
    });

    test('load returns null when nothing saved', () async {
      final store = EnvStore();
      final loaded = await store.load();
      expect(loaded, isNull);
    });

    test('save overwrites a previous value', () async {
      final store = EnvStore();
      await store.save('staging');
      await store.save('production');
      expect(await store.load(), 'production');
    });

    test('clear removes the stored value', () async {
      final store = EnvStore();
      await store.save('staging');
      await store.clear();
      expect(await store.load(), isNull);
    });
  });
}
