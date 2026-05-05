import 'package:flutter/material.dart';
import 'package:flutter_env_switch/core/env_loader.dart';
import 'package:flutter_env_switch/core/env_manager.dart';
import 'package:flutter_env_switch/core/env_store.dart';
import 'package:flutter_env_switch/ui/debug_panel.dart';
import 'package:flutter_env_switch/ui/env_badge.dart';
import 'package:flutter_env_switch/ui/env_switcher_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _Env { dev, staging, production }

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
  'assets/.env.dev': 'BASE_URL=https://dev.example.com',
  'assets/.env.staging': 'BASE_URL=https://staging.example.com',
  'assets/.env.production': 'BASE_URL=https://api.example.com',
};

const _configs = {
  _Env.dev: 'assets/.env.dev',
  _Env.staging: 'assets/.env.staging',
  _Env.production: 'assets/.env.production',
};

Future<void> _initManager({_Env defaultEnv = _Env.dev}) async {
  await EnvManager.init<_Env>(
    defaultEnv: defaultEnv,
    configs: _configs,
    loader: EnvLoader(bundle: _FakeBundle(_assets)),
    store: EnvStore(),
  );
}

Future<void> _initLockedManager({
  _Env defaultEnv = _Env.production,
  Set<_Env> lockedEnvironments = const {_Env.production},
}) async {
  await EnvManager.init<_Env>(
    defaultEnv: defaultEnv,
    configs: _configs,
    lockedEnvironments: lockedEnvironments,
    loader: EnvLoader(bundle: _FakeBundle(_assets)),
    store: EnvStore(),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EnvManager.reset();
  });

  tearDown(EnvManager.reset);

  group('AppRestarter', () {
    testWidgets('renders child', (tester) async {
      await _initManager();
      await tester.pumpWidget(
        const AppRestarter(
          child: MaterialApp(home: Text('Hello')),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('restart rebuilds the subtree with a new key', (tester) async {
      await _initManager();

      var buildCount = 0;

      await tester.pumpWidget(
        AppRestarter(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                buildCount++;
                return TextButton(
                  onPressed: () => AppRestarter.restart(context),
                  child: const Text('Restart'),
                );
              },
            ),
          ),
        ),
      );

      final countBefore = buildCount;

      await tester.tap(find.text('Restart'));
      await tester.pump();

      expect(buildCount, greaterThan(countBefore));
    });

    testWidgets('restart is a no-op when no AppRestarter ancestor exists',
        (tester) async {
      await _initManager();

      // Wrap in MaterialApp with no AppRestarter — restart should not throw.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppRestarter.restart(context),
              child: const Text('Restart'),
            ),
          ),
        ),
      );

      // Should complete silently.
      await tester.tap(find.text('Restart'));
      await tester.pump();
    });

    testWidgets(
        'onRestart callback fires before tree rebuilds',
        (tester) async {
      await _initManager();

      final log = <String>[];

      await tester.pumpWidget(
        AppRestarter(
          onRestart: () async => log.add('onRestart'),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                log.add('build');
                return TextButton(
                  onPressed: () => AppRestarter.restart(context),
                  child: const Text('Restart'),
                );
              },
            ),
          ),
        ),
      );

      // Clear the initial build entries.
      log.clear();

      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();

      // onRestart must appear before the subsequent build call.
      expect(log.first, 'onRestart');
      expect(log, contains('build'));
    });

    testWidgets('builder is re-evaluated on each restart', (tester) async {
      await _initManager();

      var builderCallCount = 0;

      await tester.pumpWidget(
        AppRestarter(
          builder: (ctx) {
            builderCallCount++;
            return MaterialApp(
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => AppRestarter.restart(context),
                  child: const Text('Restart'),
                ),
              ),
            );
          },
        ),
      );

      final countAfterFirstBuild = builderCallCount;

      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();

      expect(builderCallCount, greaterThan(countAfterFirstBuild));
    });
  });

  group('EnvSwitcher', () {
    testWidgets('renders child without gesture when disabled', (tester) async {
      await _initManager();

      await tester.pumpWidget(
        const MaterialApp(
          home: EnvSwitcher<_Env>(
            enabled: false,
            child: Text('App'),
          ),
        ),
      );

      // Long press should NOT open the panel.
      await tester.longPress(find.text('App'));
      await tester.pump();

      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('long press opens debug panel when enabled', (tester) async {
      await _initManager();

      await tester.pumpWidget(
        // MaterialApp cannot be const — breaks dynamic widget tests.
        // ignore: prefer_const_constructors
        MaterialApp(
          home: const Scaffold(
            body: EnvSwitcher<_Env>(
              child: SizedBox.expand(
                child: Text('App'),
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('App'));
      await tester.pumpAndSettle();

      expect(find.text('Environment'), findsOneWidget);
    });

    testWidgets(
        'enableInRelease: false still opens panel in non-release test env',
        (tester) async {
      // kReleaseMode is always false in tests, so the panel must open when
      // enableInRelease=false — the release guard is irrelevant here.
      await _initManager();

      await tester.pumpWidget(
        // MaterialApp cannot be const — wraps non-const EnvSwitcher.
        // ignore: prefer_const_constructors
        MaterialApp(
          home: const Scaffold(
            body: EnvSwitcher<_Env>(
              enableInRelease: false, // restrict to debug/profile — irrelevant
              //                        in tests because kReleaseMode == false.
              child: SizedBox.expand(child: Text('App')),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('App'));
      await tester.pumpAndSettle();

      expect(find.text('Environment'), findsOneWidget);
    });
  });

  group('EnvDebugPanel', () {
    testWidgets('shows all environment values', (tester) async {
      await _initManager();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showEnvDebugPanel<_Env>(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      for (final env in _Env.values) {
        expect(find.text(env.name), findsOneWidget);
      }
    });

    testWidgets('tapping a different env switches and closes panel',
        (tester) async {
      await _initManager();

      await tester.pumpWidget(
        AppRestarter(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showEnvDebugPanel<_Env>(
                        context,
                        showRestartToggle: false,
                      ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('staging'));
      await tester.pumpAndSettle();

      expect(EnvManager.instance.current, _Env.staging);
    });

    testWidgets('panel opens and shows LOCKED chip when current env is locked',
        (tester) async {
      await _initLockedManager();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showEnvDebugPanel<_Env>(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('LOCKED'), findsOneWidget);
      expect(find.text('DEV ONLY'), findsNothing);
    });

    testWidgets('env tiles are not interactive when panel is locked',
        (tester) async {
      await _initLockedManager();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showEnvDebugPanel<_Env>(context, showRestartToggle: false),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tapping a non-active tile should not trigger a switch.
      await tester.tap(find.text('dev'));
      await tester.pumpAndSettle();

      // Still in production — no switch happened.
      expect(EnvManager.instance.current, _Env.production);
      // Panel is still open (no pop triggered).
      expect(find.text('LOCKED'), findsOneWidget);
    });

    testWidgets(
        'restart toggle is hidden when panel is locked', (tester) async {
      await _initLockedManager();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showEnvDebugPanel<_Env>(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Restart app after switch'), findsNothing);
    });

    testWidgets('onSwitched callback fires after env switch', (tester) async {
      await _initManager();

      var callCount = 0;

      await tester.pumpWidget(
        AppRestarter(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showEnvDebugPanel<_Env>(
                    context,
                    showRestartToggle: false,
                    onSwitched: () => callCount++,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('staging'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });

    testWidgets('key browser expands to show loaded keys', (tester) async {
      await _initManager();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showEnvDebugPanel<_Env>(
                  context,
                  showRestartToggle: false,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Key browser header visible but keys hidden initially.
      expect(find.text('View loaded keys'), findsOneWidget);
      expect(find.text('BASE_URL'), findsNothing);

      // Tap to expand.
      await tester.tap(find.text('View loaded keys'));
      await tester.pumpAndSettle();

      expect(find.text('BASE_URL'), findsOneWidget);
    });
  });

  group('EnvSwitcher tap-count mode', () {
    testWidgets('5 rapid taps open the debug panel', (tester) async {
      await _initManager();

      await tester.pumpWidget(
        // MaterialApp cannot be const — wrapping non-const EnvSwitcher.
        // ignore: prefer_const_constructors
        MaterialApp(
          home: const Scaffold(
            body: EnvSwitcher<_Env>(
              triggerMode: EnvTriggerMode.tapCount,
              child: SizedBox.expand(child: Text('App')),
            ),
          ),
        ),
      );

      // Tap 4 times — panel should NOT open yet.
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('App'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Environment'), findsNothing);

      // 5th tap — panel must open.
      await tester.tap(find.text('App'));
      await tester.pumpAndSettle();

      expect(find.text('Environment'), findsOneWidget);
    });

    testWidgets('long-press does NOT open panel in tapCount mode',
        (tester) async {
      await _initManager();

      await tester.pumpWidget(
        // MaterialApp cannot be const — wrapping non-const EnvSwitcher.
        // ignore: prefer_const_constructors
        MaterialApp(
          home: const Scaffold(
            body: EnvSwitcher<_Env>(
              triggerMode: EnvTriggerMode.tapCount,
              child: SizedBox.expand(child: Text('App')),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('App'));
      await tester.pumpAndSettle();

      expect(find.text('Environment'), findsNothing);
    });

    testWidgets('onSwitched fires via EnvSwitcher widget', (tester) async {
      await _initManager();

      var callCount = 0;

      await tester.pumpWidget(
        AppRestarter(
          child:
              // MaterialApp cannot be const — wraps non-const AppRestarter.
              // ignore: prefer_const_constructors
              MaterialApp(
            home: Scaffold(
              body: EnvSwitcher<_Env>(
                showRestartToggle: false,
                onSwitched: () => callCount++,
                child: const SizedBox.expand(child: Text('App')),
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('App'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('staging'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });
  });

  group('EnvBadge', () {
    testWidgets('shows default badge with env name', (tester) async {
      await _initManager();

      await tester.pumpWidget(
        // MaterialApp cannot be const — wraps non-const EnvBadge context.
        // ignore: prefer_const_constructors
        MaterialApp(
          home: const EnvBadge<_Env>(
            child: Scaffold(body: Text('Content')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('DEV'), findsOneWidget);
    });

    testWidgets('updates badge when env is switched', (tester) async {
      await _initManager();

      await tester.pumpWidget(
        // MaterialApp cannot be const — wraps non-const EnvBadge context.
        // ignore: prefer_const_constructors
        MaterialApp(
          home: const EnvBadge<_Env>(
            child: Scaffold(body: Text('Content')),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('DEV'), findsOneWidget);

      await EnvManager.instanceOf<_Env>().switchTo(_Env.staging);
      await tester.pump();

      expect(find.text('STAGING'), findsOneWidget);
      expect(find.text('DEV'), findsNothing);
    });

    testWidgets('uses custom badgeBuilder when provided', (tester) async {
      await _initManager();

      await tester.pumpWidget(
        MaterialApp(
          home: EnvBadge<_Env>(
            badgeBuilder: (env) => Text('custom-${env.name}'),
            child: const Scaffold(body: Text('Content')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('custom-dev'), findsOneWidget);
    });
  });
}
