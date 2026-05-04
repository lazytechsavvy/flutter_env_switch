import 'package:flutter_env_switch/core/env_loader.dart';
import 'package:flutter_env_switch/core/env_manager.dart';
import 'package:flutter_env_switch/core/env_store.dart';
import 'package:flutter_env_switch_example/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

const _fakeAssets = {
  'assets/env/.env.dev':
      'BASE_URL=https://dev.example.com\nAPP_NAME=Envify Example (Dev)\n'
      'FEATURE_DARK_MODE=true\nFEATURE_ANALYTICS=false\n'
      'TIMEOUT=5\nLOG_LEVEL=debug',
  'assets/env/.env.staging':
      'BASE_URL=https://staging.example.com\nAPP_NAME=Envify Example (Staging)\n'
      'FEATURE_DARK_MODE=true\nFEATURE_ANALYTICS=true\n'
      'TIMEOUT=15\nLOG_LEVEL=info',
  'assets/env/.env.production':
      'BASE_URL=https://api.example.com\nAPP_NAME=Envify Example\n'
      'FEATURE_DARK_MODE=false\nFEATURE_ANALYTICS=true\n'
      'TIMEOUT=30\nLOG_LEVEL=error',
};

Future<void> _initEnv({Environment defaultEnv = Environment.production}) async {
  SharedPreferences.setMockInitialValues({});
  EnvManager.reset();
  await EnvManager.init<Environment>(
    defaultEnv: defaultEnv,
    configs: {
      Environment.dev: 'assets/env/.env.dev',
      Environment.staging: 'assets/env/.env.staging',
      Environment.production: 'assets/env/.env.production',
    },
    loader: EnvLoader(bundle: _FakeBundle(_fakeAssets)),
    store: EnvStore(),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(EnvManager.reset);

  testWidgets('renders home page with active env badge', (tester) async {
    await _initEnv();

    await tester.pumpWidget(const FlutterEnvSwitchExampleApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('PRODUCTION'), findsOneWidget);
  });

  testWidgets('displays BASE_URL from active environment', (tester) async {
    await _initEnv();

    await tester.pumpWidget(const FlutterEnvSwitchExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('https://api.example.com'), findsOneWidget);
  });

  testWidgets('displays feature flag tiles', (tester) async {
    await _initEnv();

    await tester.pumpWidget(const FlutterEnvSwitchExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Dark Mode', skipOffstage: false), findsOneWidget);
    expect(find.text('Analytics', skipOffstage: false), findsOneWidget);
  });

  testWidgets('reflects dev environment values when switched', (tester) async {
    await _initEnv(defaultEnv: Environment.dev);

    await tester.pumpWidget(const FlutterEnvSwitchExampleApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('DEV'), findsOneWidget);
    expect(find.text('https://dev.example.com'), findsOneWidget);
  });
}
