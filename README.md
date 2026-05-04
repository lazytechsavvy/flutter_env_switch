# flutter_env_switch

A lightweight, type-safe runtime environment & config switcher for Flutter.

[![pub.dev](https://img.shields.io/pub/v/flutter_env_switch.svg)](https://pub.dev/packages/flutter_env_switch)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Table of contents

1. [The problem](#the-problem)
2. [Why choose flutter_env_switch?](#why-choose-flutter_env_switch)
3. [Features](#features)
4. [Installation](#installation)
5. [Quick start](#quick-start)
6. [Reading config values](#reading-config-values)
7. [Current environment](#current-environment)
8. [Switching environments](#switching-environments)
9. [Reactive UI](#reactive-ui)
10. [Debug panel](#debug-panel)
11. [Tap-count trigger](#tap-count-trigger)
12. [On-switch callback](#on-switch-callback)
13. [Locking environments](#locking-environments)
14. [In-panel key browser](#in-panel-key-browser)
15. [Environment badge](#environment-badge)
16. [Soft app restart](#soft-app-restart)
17. [Dio integration](#dio-integration)
18. [EnvConfig — optional convenience type](#envconfig--optional-convenience-type)
19. [.env file syntax](#env-file-syntax)
20. [Error handling](#error-handling)
21. [Testing](#testing)
22. [Advanced: typed singleton access](#advanced-typed-singleton-access)
23. [FAQ](#faq)
24. [API reference](#api-reference)

---

## The problem

Most Flutter apps tie environment configuration to compile-time flags (`--dart-define`) or hard-coded constants. Changing from staging to production means a full rebuild. Debugging a production-only issue requires shipping a special build.

**flutter_env_switch** takes a different approach: all environment configs are loaded from `.env` asset files at startup, and the active environment can be switched at runtime — no rebuild needed.

---

## Why choose flutter_env_switch?

| Feature | [dev_env_switcher](https://pub.dev/packages/dev_env_switcher) | [env_switcher](https://pub.dev/packages/env_switcher) | **flutter_env_switch** |
|---|---|---|---|
| Env identification | strings | strings | **enum (compile-time safe)** |
| Config source | inline Dart maps | inline Dart maps | **.env asset files** |
| Typed accessors | raw map | `getExtra<T>()` | **`getInt` / `getDouble` / `getBool` / `getOrElse`** |
| Locked environments | — | — | **YES — unique** |
| Soft app restart | — | manual | **`AppRestarter`** |
| Dio integration | — | — | **YES** |
| Reactive notifier | — | `addListener` | **`ValueNotifier`** |
| Gesture trigger | widget toggle | multi-tap (configurable) | **both long-press and tap-count** |
| On-switch callback | — | `onEnvironmentChanged` | **`onSwitched`** |
| Release-mode guard | manual | `enabled` flag | **double-guard (compile + runtime)** |
| In-panel key browser | — | — | **YES — with sensitive-key masking** |
| On-screen env badge | — | — | **`EnvBadge`** |

---

## Features

| | |
|---|---|
| **Multi-.env loading** | Load all environment configs in parallel at startup |
| **Enum-driven** | Your own enum identifies environments — no magic strings |
| **Runtime switching** | Switch the active env without rebuilding the app |
| **Persistent selection** | The last chosen environment survives app restarts |
| **Gesture debug panel** | Long-press **or** tap-count to open a bottom-sheet switcher |
| **On-switch callback** | `onSwitched` fires after every successful environment switch |
| **Locked environments** | Prevent switching away from sensitive envs (e.g. production) |
| **In-panel key browser** | Inspect all loaded key/value pairs — sensitive keys masked by default |
| **Environment badge** | `EnvBadge` renders a persistent overlay corner badge that updates reactively |
| **Release-safe** | Debug panel is always disabled in release mode |
| **Dio integration** | Optional interceptor that injects `BASE_URL` per request |
| **Reactive** | `ValueNotifier` lets any widget rebuild on env change |
| **Minimal deps** | Only `shared_preferences` and optionally `dio` |

---

## Installation

Add `flutter_env_switch` to your app's `pubspec.yaml`:

```yaml
dependencies:
  flutter_env_switch: ^1.1.1
```

`shared_preferences` is a transitive dependency — no separate entry needed. `dio` is also included for the optional Dio interceptor.

---

## Quick start

### 1. Declare your `.env` assets

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/env/.env.dev
    - assets/env/.env.staging
    - assets/env/.env.production
```

### 2. Create your `.env` files

```dotenv
# assets/env/.env.dev
BASE_URL=https://dev.api.example.com
APP_NAME=MyApp (Dev)
TIMEOUT=10
LOG_LEVEL=debug
FEATURE_ANALYTICS=false
FEATURE_DARK_MODE=true
```

```dotenv
# assets/env/.env.staging
BASE_URL=https://staging.api.example.com
APP_NAME=MyApp (Staging)
TIMEOUT=20
LOG_LEVEL=info
FEATURE_ANALYTICS=true
FEATURE_DARK_MODE=false
```

```dotenv
# assets/env/.env.production
BASE_URL=https://api.example.com
APP_NAME=MyApp
TIMEOUT=30
LOG_LEVEL=error
FEATURE_ANALYTICS=true
FEATURE_DARK_MODE=false
```

### 3. Initialise in `main.dart`

```dart
import 'package:flutter_env_switch/flutter_env_switch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum Environment { dev, staging, production }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.init<Environment>(
    defaultEnv: Environment.production,
    configs: {
      Environment.dev:        'assets/env/.env.dev',
      Environment.staging:    'assets/env/.env.staging',
      Environment.production: 'assets/env/.env.production',
    },
  );

  runApp(
    AppRestarter(
      child: EnvBadge<Environment>(        // ← shows active env name in corner
        child: EnvSwitcher<Environment>(
          enabled: !kReleaseMode,          // panel is always off in release builds
          child: const MyApp(),
        ),
      ),
    ),
  );
}
```

> **`defaultEnv`** is used only when no previously persisted selection exists. Production release builds always start with their correct environment regardless of what a tester last chose on their device.

---

## Reading config values

Import the package once at the top of any file:

```dart
import 'package:flutter_env_switch/flutter_env_switch.dart';
```

Then call the static accessors anywhere after `Env.init` completes:

```dart
// Raw string — throws EnvKeyNotFoundException if the key is absent
final baseUrl = Env.get('BASE_URL');

// Typed accessors
final timeout   = Env.getInt('TIMEOUT');          // int
final retryDelay = Env.getDouble('RETRY_DELAY');  // double
final analytics = Env.getBool('FEATURE_ANALYTICS'); // bool

// Safe fallback — never throws, returns fallback if key is absent
final logLevel = Env.getOrElse('LOG_LEVEL', 'info');
```

### `getBool` truthy values

The following raw string values (case-insensitive) evaluate to `true`:

| Raw value | Result |
|-----------|--------|
| `true` | `true` |
| `1` | `true` |
| `yes` | `true` |
| anything else | `false` |

```dotenv
FEATURE_NEW_UI=yes    # true
FEATURE_NEW_UI=1      # true
FEATURE_NEW_UI=True   # true
FEATURE_NEW_UI=false  # false
FEATURE_NEW_UI=0      # false
```

### Choosing between `get` and `getOrElse`

```dart
// Explicit — your code cannot proceed without this key:
final apiKey = Env.get('BASE_URL');

// Optional — a sensible default exists:
final pageSize = Env.getOrElse('PAGE_SIZE', '20');
```

---

## Current environment

```dart
// The active enum value:
final env = Env.current;         // Enum
print(env.name);                 // 'production'

// Cast back to your own type when you need it:
final typedEnv = Env.current as Environment;
if (typedEnv == Environment.dev) {
  // dev-only path
}
```

---

## Switching environments

### Programmatically

```dart
// Switch and persist — completes once SharedPreferences confirms the write.
await Env.switchTo(Environment.staging);
```

The switch takes effect immediately: `Env.get(...)` calls on the next line already return values from the new environment. Widgets that depend on `Env.currentNotifier` are notified synchronously after the persist completes.

If you need the whole widget tree to rebuild (e.g. to pick up a new `BASE_URL` injected into your Dio client at construction), trigger a soft restart:

```dart
await Env.switchTo(Environment.staging);
AppRestarter.restart(context); // rebuilds tree from the root
```

### Via the debug panel

Long-press anywhere on the screen (when wrapped with `EnvSwitcher`) to open the panel. Tap any environment row to switch. The optional "restart after switch" toggle handles the `AppRestarter.restart` call automatically.

### Guard against switching when locked

```dart
if (!Env.isLocked) {
  await Env.switchTo(Environment.staging);
}
```

Or handle the exception explicitly:

```dart
try {
  await Env.switchTo(Environment.staging);
} on EnvSwitchLockedException catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.toString())),
  );
}
```

---

## Reactive UI

`Env.currentNotifier` is a `ValueNotifier<dynamic>`. Wrap any widget that should rebuild when the environment changes:

```dart
ValueListenableBuilder<dynamic>(
  valueListenable: Env.currentNotifier,
  builder: (context, env, child) {
    return Column(
      children: [
        Text('Active: ${env.name}'),
        Text('API: ${Env.get('BASE_URL')}'),
      ],
    );
  },
)
```

### Rebuilding `MaterialApp` on switch

Wrapping `MaterialApp` itself lets the app re-read all config (e.g. theme, title) after a switch without a hard restart:

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<dynamic>(
      valueListenable: Env.currentNotifier,
      builder: (context, env, _) {
        final isDark = Env.getBool('FEATURE_DARK_MODE');
        return MaterialApp(
          title: Env.get('APP_NAME'),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          // ...
        );
      },
    );
  }
}
```

### Typed notifier via `EnvManager`

If you prefer working with the concrete enum type:

```dart
final manager = EnvManager.instanceOf<Environment>();

ValueListenableBuilder<Environment>(
  valueListenable: manager.currentNotifier,
  builder: (context, env, _) => Text(env.name),
)
```

---

## Debug panel

The debug panel is a modal bottom sheet that lists all registered environments, highlights the active one, and lets testers switch at runtime.

### Setup (already done in Quick start)

```dart
runApp(
  AppRestarter(               // ← enables soft restart after switch
    child: EnvSwitcher<Environment>(
      enabled: !kReleaseMode, // ← disables panel in production builds
      child: const MyApp(),
    ),
  ),
);
```

### Opening the panel

| Method | How |
|--------|-----|
| **Long-press gesture** | Long-press any part of the screen wrapped by `EnvSwitcher` (default) |
| **Tap-count gesture** | Set `triggerMode: EnvTriggerMode.tapCount` — tap `tapCount` times (default 5) within `tapWindowMs` |
| **Programmatically** | Call `showEnvDebugPanel<Environment>(context)` from a button, drawer, etc. |

```dart
// From a settings screen, drawer, or debug menu:
TextButton(
  onPressed: () => showEnvDebugPanel<Environment>(context),
  child: const Text('Switch Environment'),
),
```

### Hiding the restart toggle

```dart
showEnvDebugPanel<Environment>(context, showRestartToggle: false);
```

### Release mode

`EnvSwitcher` always disables the gesture in release builds regardless of the `enabled` flag — the flag is an additional guard for debug/profile builds. There is no way to accidentally ship the switcher to end users.

### Locked state

When the active environment is locked, the panel still opens (so developers can see the lock state rather than getting a silent no-op). It renders a red `LOCKED` badge in the header, shows an explanatory subtitle, and disables all environment tiles. See [Locking environments](#locking-environments) for details.

---

## Tap-count trigger

The industry-standard "hidden QA panel" gesture — popularised by Flutter's own diagnostic tools — is available via `EnvTriggerMode.tapCount`. Configure the tap count and time window:

```dart
EnvSwitcher<Environment>(
  triggerMode: EnvTriggerMode.tapCount,
  tapCount: 5,        // default 5
  tapWindowMs: 3000,  // default 3000 ms
  child: const MyApp(),
)
```

Each tap resets the window if more than `tapWindowMs` milliseconds have elapsed since the first tap in the sequence. When `tapCount` consecutive taps arrive within the window, the panel opens.

`longPress` remains the default to avoid breaking existing integrations:

```dart
// Default (long-press) — unchanged from before
EnvSwitcher<Environment>(child: const MyApp())
```

### Choosing a trigger mode

| | `longPress` | `tapCount` |
|---|---|---|
| Discoverability | Low — accidental long-presses can occur | High — the hidden tap-count pattern is familiar to QA teams |
| Accessibility | Works with voice-over long-press | Works with repeated taps |
| Risk of accidental trigger | Higher on scrollable areas | Lower — requires deliberate rapid taps |

---

## On-switch callback

`onSwitched` fires **after** the environment switch (and optional app restart) completes. Use it to show a confirmation snackbar, log an analytics event, or update external state.

### Via `EnvSwitcher`

```dart
EnvSwitcher<Environment>(
  onSwitched: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Environment switched!')),
    );
  },
  child: const MyApp(),
)
```

### Via `showEnvDebugPanel`

```dart
showEnvDebugPanel<Environment>(
  context,
  onSwitched: () => analytics.track('env_switched'),
);
```

---



Pass `lockedEnvironments` to `Env.init` to prevent switching away from specific environments at runtime. The canonical use-case is locking production so that no in-app tooling can redirect a live app to a staging server.

```dart
await Env.init<Environment>(
  defaultEnv: Environment.production,
  configs: { ... },
  lockedEnvironments: {Environment.production},
);
```

### How the lock works

The lock applies to the **currently active environment**, not to the target. When `production` is locked:

```
dev        ──────────────────▶  staging      (allowed)
staging    ──────────────────▶  dev          (allowed)
dev        ──────────────────▶  production   (allowed — transitioning IN is fine)
staging    ──────────────────▶  production   (allowed — transitioning IN is fine)
production ──────────────────▶  dev          (BLOCKED — EnvSwitchLockedException)
production ──────────────────▶  staging      (BLOCKED — EnvSwitchLockedException)
```

Key points:
- You **cannot switch away** from a locked environment (the critical guard).
- You **can reach** a locked environment from any unlocked one.
- Once in a locked environment, the only way out is a new `Env.init` call (e.g. after a fresh install / cleared storage).

### Checking the lock state

```dart
// Static shortcut:
if (Env.isLocked) {
  // Hide or disable any switch UI.
}

// Via the typed manager:
final manager = EnvManager.instanceOf<Environment>();
if (manager.isCurrentLocked) { ... }
```

### Locking multiple environments

```dart
lockedEnvironments: {Environment.staging, Environment.production},
```

### Debug panel in locked state

The panel still opens on long-press (to provide visibility), but:
- The header badge changes from `DEV ONLY` (blue) to `LOCKED` (red).
- A subtitle explains that switching is disabled.
- All environment tiles are non-interactive (grey text, no tap handler).
- The "restart after switch" toggle is hidden.

### Handling the exception

```dart
try {
  await Env.switchTo(Environment.dev);
} on EnvSwitchLockedException catch (e) {
  // e.envName — the name of the locked environment
  debugPrint(e.toString());
  // EnvSwitchLockedException: switching is disabled
  //   while the active environment is "production".
}
```

---

## In-panel key browser

The debug panel includes a collapsible "View loaded keys" section. Tap it to expand a scrollable list of all key/value pairs loaded for the active environment — no debugger needed.

### Sensitive-key masking

Keys whose names contain `KEY`, `SECRET`, `TOKEN`, `PASSWORD`, `PASS`, `PWD`, `AUTH`, or `CREDENTIAL` are **automatically masked** with bullet characters. An eye-toggle reveals the real value. The copy button always copies the **original** (unmasked) value to the clipboard.

```
API_KEY       ••••••••••••  [👁] [copy]   ← masked by default
BASE_URL      https://dev.api.example.com  [copy]
TIMEOUT       10                            [copy]
```

The key browser requires no configuration — it is always present in the debug panel and shows the data for whichever environment is currently active.

---

## Environment badge

`EnvBadge<E>` renders a persistent overlay showing the active environment. It reacts to switches automatically via `ValueNotifier`.

### Basic usage

Wrap any widget (typically `MaterialApp`) to get a corner badge:

```dart
EnvBadge<Environment>(
  child: MaterialApp(...),
)
```

This renders a semi-transparent pill in the **top-right** corner with the environment name in uppercase (e.g. `DEV`, `STAGING`).

### Custom position

```dart
EnvBadge<Environment>(
  alignment: Alignment.bottomLeft,
  child: MaterialApp(...),
)
```

### Custom badge widget

```dart
EnvBadge<Environment>(
  badgeBuilder: (env) => Chip(
    label: Text(env.name.toUpperCase()),
    backgroundColor: env == Environment.dev ? Colors.orange : Colors.blue,
  ),
  child: MaterialApp(...),
)
```

### Padding

```dart
EnvBadge<Environment>(
  padding: const EdgeInsets.all(16),
  child: MaterialApp(...),
)
```

### Release-mode visibility

By default the badge is hidden in release builds. Set `visibleInRelease: true` for internal distribution builds (e.g. TestFlight):

```dart
EnvBadge<Environment>(
  visibleInRelease: kProfileMode, // visible in profile, hidden in release
  child: MaterialApp(...),
)
```

### Full example with `AppRestarter` and `EnvSwitcher`

```dart
runApp(
  AppRestarter(
    child: EnvBadge<Environment>(
      child: EnvSwitcher<Environment>(
        triggerMode: EnvTriggerMode.tapCount,
        child: const MyApp(),
      ),
    ),
  ),
);
```

---

## Soft app restart

`AppRestarter` is a `StatefulWidget` that rebuilds its entire subtree by assigning a new `UniqueKey` to its child. This achieves a "soft restart" — re-running all `initState` calls and reading fresh config — without a cold process restart.

### Setup

Place `AppRestarter` **above** `MaterialApp` in the widget tree (ideally at the very root as shown in Quick start):

```dart
runApp(
  AppRestarter(
    child: EnvSwitcher<Environment>(
      enabled: !kReleaseMode,
      child: const MyApp(),
    ),
  ),
);
```

### Triggering a restart

```dart
// From any widget inside the AppRestarter subtree:
AppRestarter.restart(context);
```

If no `AppRestarter` ancestor is found, the call is a **silent no-op** — safe to call unconditionally.

### When to use it

| Scenario | Restart needed? |
|----------|-----------------|
| Changing a feature flag read inside `build` | No — `ValueListenableBuilder` handles it |
| Changing `BASE_URL` used by a Dio client built once in `initState` | **Yes** |
| Changing the app theme driven by an env key | No — wrap `MaterialApp` with `ValueListenableBuilder` |
| Changing any config that is read in `main()` | **Yes** |

The debug panel's "restart after switch" toggle automates this for testers — they do not need to understand this distinction.

---

## Dio integration

`flutter_env_switch` ships an optional Dio interceptor. Since `dio` is already a dependency of the package, no extra `pubspec.yaml` entry is required.

```dart
import 'package:flutter_env_switch/integrations/dio_interceptor.dart';

final dio = Dio()..interceptors.add(EnvDioInterceptor());
```

The interceptor reads `BASE_URL` from the active environment on **every request**, so it always reflects the currently selected environment — including after a runtime switch.

### Custom key

```dart
final dio = Dio()
  ..interceptors.add(EnvDioInterceptor(baseUrlKey: 'API_ENDPOINT'));
```

### How it works

On each request, `EnvDioInterceptor.onRequest`:

1. Calls `Env.get(baseUrlKey)` to resolve the current base URL.
2. Rewrites `options.baseUrl` in-place.
3. Passes the modified options to the next interceptor via `handler.next(options)`.

If the key is absent from the active environment, `EnvKeyNotFoundException` is thrown, which Dio surfaces as a `DioException`.

### With environment switching

Because the interceptor reads the value on every request, you do not need to recreate the `Dio` instance after switching environments:

```dart
await Env.switchTo(Environment.staging);
// Next Dio request automatically uses the staging BASE_URL.
```

---

## EnvConfig — optional convenience type

`EnvConfig<E>` pairs an enum value with its asset path. It is entirely optional — `Env.init` accepts a plain `Map<E, String>` and that is the recommended approach for most apps.

`EnvConfig` is useful for teams that want to declare environment descriptors in a separate file and iterate over them:

```dart
// env_configs.dart
const envConfigs = [
  EnvConfig(env: Environment.dev,        assetPath: 'assets/env/.env.dev'),
  EnvConfig(env: Environment.staging,    assetPath: 'assets/env/.env.staging'),
  EnvConfig(env: Environment.production, assetPath: 'assets/env/.env.production'),
];
```

```dart
// main.dart
await Env.init<Environment>(
  defaultEnv: Environment.production,
  configs: Map.fromEntries(
    envConfigs.map((c) => MapEntry(c.env, c.assetPath)),
  ),
);
```

---

## `.env` file syntax

The parser handles all standard `.env` idioms:

| Syntax | Behaviour |
|--------|-----------|
| `KEY=value` | Standard pair |
| `KEY="quoted value"` | Quotes stripped; content used verbatim |
| `KEY='single quoted'` | Same as double-quoted |
| `KEY=a=b=c` | `=` inside a value is preserved |
| `# full-line comment` | Line ignored |
| `KEY=value # inline note` | Inline comment stripped (unquoted values only) |
| `KEY="value # not a comment"` | Quoted values — `#` inside quotes is **not** stripped |
| `KEY=` | Empty string value — key present, value is `""` |
| Blank lines | Ignored |
| CRLF / CR line endings | Normalised transparently |

### Examples

```dotenv
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=myapp_dev

# URLs with = signs in query strings are safe
CALLBACK_URL=https://auth.example.com/callback?redirect=https://app.example.com

# Quoted value preserves internal # character
REGEX_PATTERN="^[a-z]#[0-9]+$"

# Inline comment is stripped from unquoted values
TIMEOUT=30  # seconds — this comment is stripped; value is "30"

# Empty value
OPTIONAL_KEY=

# Boolean flags
FEATURE_X=true
FEATURE_Y=1
FEATURE_Z=yes
```

### Key name rules

- Leading and trailing whitespace around the key is stripped.
- Lines without a `=` delimiter are silently ignored.
- Lines with an empty key (e.g. `=value`) are silently ignored.
- Duplicate keys: the **last** occurrence wins.

---

## Error handling

All exceptions implement `Exception` and have descriptive `toString()` messages suitable for logging.

| Exception | When thrown | Common cause |
|-----------|-------------|--------------|
| `EnvNotInitializedException` | Any accessor called before `Env.init` | Forgot `await Env.init(...)` before `runApp` |
| `EnvLoadException` | `Env.init` — an asset file cannot be loaded | Asset path typo, not declared in `pubspec.yaml` |
| `EnvKeyNotFoundException` | `get`, `getInt`, `getDouble`, `getBool` | Key missing from the active `.env` file |
| `EnvSwitchLockedException` | `switchTo` while current env is locked | Attempted to switch away from a locked environment |
| `ArgumentError` | `switchTo` called with an unregistered enum | Passed an enum value not in `configs` map |
| `FormatException` | `getInt`, `getDouble` | Value exists but is not a valid number |

### Defensive patterns

```dart
// 1. Safe read with fallback — no exception possible
final timeout = Env.getOrElse('TIMEOUT', '30');
final timeoutMs = int.tryParse(timeout) ?? 30;

// 2. Guarded switch
if (!Env.isLocked) {
  await Env.switchTo(Environment.staging);
}

// 3. Full error handling
try {
  await Env.switchTo(Environment.staging);
} on EnvSwitchLockedException catch (e) {
  logger.warning(e.toString());
} on ArgumentError catch (e) {
  logger.error('Unknown environment: $e');
}

// 4. Catching missing keys during debug
try {
  final apiKey = Env.get('STRIPE_KEY');
} on EnvKeyNotFoundException catch (e) {
  // e.key      → 'STRIPE_KEY'
  // e.envName  → 'development'
  throw StateError('Missing required key: ${e.key} in ${e.envName}');
}
```

---

## Testing

### Unit testing code that reads `Env`

Inject a fake loader and an in-memory store to keep tests hermetic:

```dart
import 'package:flutter_env_switch/core/env_loader.dart';
import 'package:flutter_env_switch/core/env_manager.dart';
import 'package:flutter_env_switch/core/env_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TestEnv { dev, prod }

class FakeBundle extends Fake implements AssetBundle {
  FakeBundle(this._assets);
  final Map<String, String> _assets;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final content = _assets[key];
    if (content == null) throw Exception('Asset not found: $key');
    return content;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EnvManager.reset(); // clear singleton between tests
  });

  tearDown(EnvManager.reset);

  test('reads BASE_URL from active env', () async {
    await EnvManager.init<TestEnv>(
      defaultEnv: TestEnv.dev,
      configs: {
        TestEnv.dev:  'assets/.env.dev',
        TestEnv.prod: 'assets/.env.prod',
      },
      loader: EnvLoader(bundle: FakeBundle({
        'assets/.env.dev':  'BASE_URL=https://dev.example.com',
        'assets/.env.prod': 'BASE_URL=https://example.com',
      })),
      store: EnvStore(), // SharedPreferences is mocked above
    );

    expect(Env.get('BASE_URL'), 'https://dev.example.com');
  });

  test('switching env updates the value', () async {
    final manager = await EnvManager.init<TestEnv>(
      defaultEnv: TestEnv.dev,
      configs: {
        TestEnv.dev:  'assets/.env.dev',
        TestEnv.prod: 'assets/.env.prod',
      },
      loader: EnvLoader(bundle: FakeBundle({
        'assets/.env.dev':  'BASE_URL=https://dev.example.com',
        'assets/.env.prod': 'BASE_URL=https://example.com',
      })),
      store: EnvStore(),
    );

    await manager.switchTo(TestEnv.prod);
    expect(Env.get('BASE_URL'), 'https://example.com');
  });
}
```

### Widget testing

```dart
testWidgets('shows correct env badge', (tester) async {
  SharedPreferences.setMockInitialValues({});
  EnvManager.reset();

  await EnvManager.init<TestEnv>(
    defaultEnv: TestEnv.dev,
    configs: { ... },
    loader: EnvLoader(bundle: FakeBundle({ ... })),
    store: EnvStore(),
  );

  await tester.pumpWidget(
    const MaterialApp(home: MyHomePage()),
  );

  expect(find.text('DEV'), findsOneWidget);
});
```

### Key rules for tests

1. Always call `SharedPreferences.setMockInitialValues({})` before each test.
2. Always call `EnvManager.reset()` in `setUp` **and** `tearDown` so tests are isolated.
3. Pass a `FakeBundle` (or any `AssetBundle` implementation) to `EnvLoader` — do not rely on the real asset bundle in unit tests.
4. The `@visibleForTesting` `loader` and `store` parameters on both `Env.init` and `EnvManager.init` exist specifically for this injection pattern.

---

## Advanced: typed singleton access

`EnvManager<E>` is the underlying singleton. The `Env` static class delegates to it. For advanced use (e.g. subscribing to the typed notifier, inspecting `allValues`), access it directly:

```dart
// Typed access — throws if not initialised
final manager = EnvManager.instanceOf<Environment>();

// All registered envs in declaration order
final envs = manager.allValues; // List<Environment>

// Typed ValueNotifier — no dynamic cast needed
manager.currentNotifier.addListener(() {
  print('Switched to: ${manager.current.name}');
});

// Direct typed switch (same as Env.switchTo but typed)
await manager.switchTo(Environment.staging);

// Lock state
print(manager.isCurrentLocked); // bool
```

`EnvManager.instance` (untyped, returns `EnvManager<dynamic>`) is available if you need access before knowing the concrete type:

```dart
final raw = EnvManager.instance; // EnvManager<dynamic>
print(raw.current.name);         // still works via Enum.name
```

---

## FAQ

**Can I add flutter_env_switch to an existing app without changing CI or build scripts?**

Yes. `Env.init` is a runtime call, not a build-time one. Pass your production enum value as `defaultEnv` — it applies only when no persisted selection exists (i.e. a fresh install). Your existing release pipeline and builds are unaffected.

---

**Does flutter_env_switch read `.env` files from the device filesystem?**

No. It reads from the Flutter asset bundle (declared under `flutter.assets` in `pubspec.yaml`). This is intentional — filesystem paths are sandboxed on mobile and the asset bundle is the correct mechanism for shipping static files with the app.

---

**Is it safe to store secrets in `.env` files?**

**No.** Assets are bundled inside the app binary and can be extracted. `flutter_env_switch` is designed for **non-secret runtime config**: API base URLs, feature flags, timeouts, app names, log levels. Do not store API keys, private keys, or credentials in `.env` files.

---

**What happens if a key is missing from an `.env` file?**

`get`, `getInt`, `getDouble`, and `getBool` throw `EnvKeyNotFoundException`. Use `getOrElse` to supply a fallback without throwing. This is intentional — silent misconfigurations are harder to debug than loud exceptions.

---

**Can two environments share some keys while overriding others?**

Yes — each `.env` file is completely independent. There is no inheritance or merging. Include all required keys in every file; use `getOrElse` in your code for keys that may not always be present.

---

**What is `defaultEnv` actually used for?**

It is the environment selected on first launch (or after `SharedPreferences` is cleared). On subsequent launches, `flutter_env_switch` restores whatever was last persisted. In production, set `defaultEnv` to your production enum value so a fresh install starts in the correct state.

---

**The debug panel does not appear. What should I check?**

1. Confirm `EnvSwitcher` wraps the widget you are long-pressing.
2. Confirm `enabled: !kReleaseMode` (or `enabled: true` in debug mode).
3. Confirm `EnvSwitcher` is typed with your enum: `EnvSwitcher<Environment>`.
4. The panel is **always disabled** in release mode — test in debug or profile.

---

**`AppRestarter.restart` does nothing. Why?**

`AppRestarter` must be an ancestor of the widget calling `restart`. Ensure it is placed above your `MaterialApp` (ideally as the outermost widget in `runApp`). If no ancestor is found, the call is a silent no-op.

---

**Can I use `flutter_env_switch` without the debug panel at all?**

Yes. Just call `Env.init`, `Env.get`, and `Env.switchTo` directly. `AppRestarter` and `EnvSwitcher` are optional UI helpers; the core package works fine without them.

---

**Does switching persist across hot restarts?**

Yes. The selected environment is stored in `SharedPreferences` and restored on the next `Env.init` call.

---

**Which trigger mode should I use — `longPress` or `tapCount`?**

Use `longPress` (default) for small internal teams where discoverability is not a concern. Use `tapCount` for QA teams and external testers who should not accidentally open the panel — the 5-tap pattern is familiar and deliberate. You can also offer both in different builds.

---

**How do I hide the `EnvBadge` for certain environments?**

Use `badgeBuilder` to return an empty widget:

```dart
EnvBadge<Environment>(
  badgeBuilder: (env) =>
      env == Environment.production ? const SizedBox.shrink() : null,
  child: MaterialApp(...),
)
```

Or set `visibleInRelease: false` (the default) so it is always hidden in release builds, which already covers production in most CI setups.

---

**The key browser shows no keys. Why?**

The panel uses `EnvManager.currentEnvData` which is populated by `Env.init`. If the map is empty the active `.env` file itself is empty or blank. Verify the asset file path in `pubspec.yaml` and that the file contains valid `KEY=value` lines.

---

**Can I read `currentEnvData` outside the panel (e.g. for export)?**

Yes — `Env.currentEnvData` is a plain `Map<String, String>` available anywhere after `Env.init`:

```dart
final data = Env.currentEnvData;
final json = jsonEncode(data); // for export/logging
```

---

## API reference

### `Env` — static facade

| Member | Description |
|--------|-------------|
| `Env.init<E>(...)` | Loads all `.env` assets and initialises the singleton |
| `Env.get(key)` | `String` — throws `EnvKeyNotFoundException` if absent |
| `Env.getInt(key)` | `int` — throws `EnvKeyNotFoundException` or `FormatException` |
| `Env.getDouble(key)` | `double` — throws `EnvKeyNotFoundException` or `FormatException` |
| `Env.getBool(key)` | `bool` — `true`/`1`/`yes` → `true`, else `false` |
| `Env.getOrElse(key, fallback)` | `String` — returns `fallback` if key absent; never throws |
| `Env.current` | `Enum` — the active environment enum value |
| `Env.isLocked` | `bool` — `true` when the active env is in `lockedEnvironments` |
| `Env.currentEnvData` | `Map<String, String>` — all key/value pairs for the active env |
| `Env.currentNotifier` | `ValueNotifier<dynamic>` — emits on every switch |
| `Env.switchTo(env)` | `Future<void>` — switches and persists; throws if locked or unregistered |

### `Env.init` parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `defaultEnv` | `E` | ✓ | Environment used on first launch |
| `configs` | `Map<E, String>` | ✓ | Maps each enum value to its asset path |
| `lockedEnvironments` | `Set<E>?` | — | Envs from which switching is forbidden |
| `loader` | `EnvLoader?` | — | Override for testing |
| `store` | `EnvStore?` | — | Override for testing |

### `EnvManager<E>` — typed singleton

| Member | Description |
|--------|-------------|
| `EnvManager.init<E>(...)` | Initialises (same parameters as `Env.init`) |
| `EnvManager.instance` | `EnvManager<dynamic>` — untyped access |
| `EnvManager.instanceOf<E>()` | `EnvManager<E>` — typed access |
| `EnvManager.reset()` | `@visibleForTesting` — clears the singleton |
| `manager.current` | `E` — active env (typed) |
| `manager.allValues` | `List<E>` — all registered envs |
| `manager.isCurrentLocked` | `bool` |
| `manager.currentEnvData` | `Map<String, String>` — all key/value pairs for the active env |
| `manager.currentNotifier` | `ValueNotifier<E>` — typed notifier |
| `manager.get(key)` | Delegates to `Env.get` |
| `manager.switchTo(env)` | Delegates to `Env.switchTo` |

### UI components

| Component | Description |
|-----------|-------------|
| `AppRestarter` | `StatefulWidget` — place at root to enable soft restarts |
| `AppRestarter.restart(context)` | Static method — triggers rebuild from root; no-op if no ancestor |
| `EnvSwitcher<E>` | Wraps child with a gesture (long-press or tap-count) to open the debug panel |
| `EnvTriggerMode` | Enum — `longPress` (default) or `tapCount` |
| `showEnvDebugPanel<E>(context, {...})` | Imperative — shows the panel as a modal bottom sheet |
| `EnvBadge<E>` | Overlay widget — persistent env badge that updates reactively on switch |

### `EnvSwitcher` parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `child` | `Widget` | required | Widget to wrap |
| `enabled` | `bool` | `!kReleaseMode` | Whether the gesture is active |
| `showRestartToggle` | `bool` | `true` | Show restart-after-switch toggle in panel |
| `triggerMode` | `EnvTriggerMode` | `longPress` | Gesture type |
| `tapCount` | `int` | `5` | Taps required (tapCount mode only) |
| `tapWindowMs` | `int` | `3000` | Ms window for tap sequence (tapCount mode only) |
| `onSwitched` | `VoidCallback?` | `null` | Called after a successful switch |

### `showEnvDebugPanel` parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `showRestartToggle` | `bool` | `true` | Show restart-after-switch toggle |
| `onSwitched` | `VoidCallback?` | `null` | Called after a successful switch |

### `EnvBadge` parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `child` | `Widget` | required | Widget to overlay |
| `alignment` | `AlignmentGeometry` | `Alignment.topRight` | Badge corner position |
| `badgeBuilder` | `Widget Function(E env)?` | `null` | Custom badge widget |
| `padding` | `EdgeInsetsGeometry` | `EdgeInsets.all(12)` | Badge edge padding |
| `visibleInRelease` | `bool` | `false` | Show in release builds |

---

### Exceptions

| Exception | Key properties |
|-----------|----------------|
| `EnvNotInitializedException` | — |
| `EnvLoadException` | `message: String` |
| `EnvKeyNotFoundException` | `key: String`, `envName: String?` |
| `EnvSwitchLockedException` | `envName: String` |

---

## License

MIT — see [LICENSE](LICENSE).
