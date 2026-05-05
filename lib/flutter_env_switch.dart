/// flutter_env_switch — lightweight, type-safe runtime environment switcher
/// for Flutter.
///
/// Import this library to access the full public surface:
/// ```dart
/// import 'package:flutter_env_switch/flutter_env_switch.dart';
/// ```
///
/// ## Exports
///
/// - `Env` — static facade for initialisation, accessors, and switching.
/// - `EnvManager` — typed singleton; use `EnvManager.instanceOf` for reactive
///   listening or advanced access.
/// - `EnvConfig` — convenience model pairing an enum value with an asset path.
///   Optional: `Env.init` accepts a plain `Map<E, String>` so `EnvConfig` is
///   not required for typical usage.
/// - `EnvKeyNotFoundException`, `EnvLoadException`,
///   `EnvNotInitializedException`, `EnvSwitchLockedException` — typed
///   exceptions thrown by the accessors and init.
/// - `AppRestarter` — `StatefulWidget` enabling soft app restart via a new
///   `UniqueKey`. Accepts an optional `onRestart` async callback fired before
///   the tree rebuilds, and a `builder` alternative to `child` for dynamic
///   subtree re-creation on restart.
/// - `EnvSwitcher` — wraps its child with a gesture that opens the debug
///   panel. Controlled by `enabled` and `enableInRelease` (both default
///   `true`); set `enableInRelease: false` to restrict to debug/profile only.
/// - `EnvTriggerMode` — choose between `longPress` and `tapCount` gestures.
/// - `EnvBadge` — persistent on-screen badge showing the active environment.
/// - `showEnvDebugPanel` — shows the environment switcher bottom sheet
///   imperatively.
library;

// Core public API — exceptions are re-exported transitively through env.dart;
// the explicit EnvConfig export below is kept for top-level discoverability.
export 'package:flutter_env_switch/env.dart';
export 'package:flutter_env_switch/models/env_config.dart';
export 'package:flutter_env_switch/ui/debug_panel.dart'
    show AppRestarter, showEnvDebugPanel;
export 'package:flutter_env_switch/ui/env_badge.dart';
export 'package:flutter_env_switch/ui/env_switcher_widget.dart';
