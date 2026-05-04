import 'package:flutter/foundation.dart';

import 'package:flutter_env_switch/core/env_loader.dart';
import 'package:flutter_env_switch/core/env_manager.dart';
import 'package:flutter_env_switch/core/env_store.dart';

export 'package:flutter_env_switch/core/env_manager.dart' show EnvManager;
export 'package:flutter_env_switch/models/env_config.dart';
export 'package:flutter_env_switch/models/env_exceptions.dart';

/// The primary public interface for **envify**.
///
/// ### Minimal setup
/// ```dart
/// await Env.init(
///   defaultEnv: Environment.production,
///   configs: {
///     Environment.dev:        'assets/env/.env.dev',
///     Environment.staging:    'assets/env/.env.staging',
///     Environment.production: 'assets/env/.env.production',
///   },
/// );
/// ```
///
/// ### Accessing values
/// ```dart
/// final baseUrl  = Env.get('BASE_URL');
/// final timeout  = Env.getInt('TIMEOUT');
/// final darkMode = Env.getBool('DARK_MODE');
/// ```
///
/// ### Switching at runtime
/// ```dart
/// await Env.switchTo(Environment.staging);
/// ```
///
/// All methods delegate to the [EnvManager] singleton; they throw
/// `EnvNotInitializedException` if called before [init].
abstract final class Env {
  Env._();

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Initialises envify, loading all `.env` assets and restoring any
  /// previously persisted environment selection.
  ///
  /// - [defaultEnv]: the environment used when no persisted selection exists.
  /// - [configs]: maps each enum value to its asset path.
  /// - [lockedEnvironments]: optional set of environments from which switching
  ///   is forbidden. When the active environment is in this set, `switchTo`
  ///   throws `EnvSwitchLockedException` and the debug panel is rendered in
  ///   a locked (non-interactive) state. Defaults to no lock.
  ///
  /// Must be `await`ed before calling any other [Env] method.
  static Future<void> init<E extends Enum>({
    required E defaultEnv,
    required Map<E, String> configs,
    Set<E>? lockedEnvironments,
    @visibleForTesting EnvLoader? loader,
    @visibleForTesting EnvStore? store,
  }) async {
    await EnvManager.init<E>(
      defaultEnv: defaultEnv,
      configs: configs,
      lockedEnvironments: lockedEnvironments,
      loader: loader,
      store: store,
    );
  }

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Returns the raw [String] value for [key] in the active environment.
  ///
  /// Throws `EnvKeyNotFoundException` if the key does not exist.
  static String get(String key) => EnvManager.instance.get(key);

  /// Returns the value for [key] parsed as an [int].
  ///
  /// Throws `EnvKeyNotFoundException` or [FormatException].
  static int getInt(String key) => EnvManager.instance.getInt(key);

  /// Returns the value for [key] parsed as a [double].
  ///
  /// Throws `EnvKeyNotFoundException` or [FormatException].
  static double getDouble(String key) => EnvManager.instance.getDouble(key);

  /// Returns the value for [key] parsed as a [bool].
  ///
  /// `'true'`, `'1'`, `'yes'` (case-insensitive) → `true`; otherwise `false`.
  static bool getBool(String key) => EnvManager.instance.getBool(key);

  /// Returns the value for [key], or [fallback] if the key is absent.
  static String getOrElse(String key, String fallback) =>
      EnvManager.instance.getOrElse(key, fallback);

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The currently active environment enum value.
  static Enum get current => EnvManager.instance.current as Enum;

  /// Whether the currently active environment is locked.
  ///
  /// When `true`, any call to [switchTo] will throw
  /// `EnvSwitchLockedException`. Use this to conditionally show or hide
  /// environment-switching UI in your own widgets.
  ///
  /// ```dart
  /// if (!Env.isLocked) {
  ///   await Env.switchTo(Environment.staging);
  /// }
  /// ```
  static bool get isLocked => EnvManager.instance.isCurrentLocked;

  /// All key/value pairs loaded for the currently active environment.
  ///
  /// Returns an unmodifiable map. Useful for diagnostics, export, or custom
  /// tooling that needs to enumerate config values at runtime.
  static Map<String, String> get currentEnvData =>
      EnvManager.instance.currentEnvData;

  /// A [ValueNotifier] that emits the active environment whenever it changes.
  ///
  /// Useful for driving reactive widgets without wrapping the entire app:
  /// ```dart
  /// ValueListenableBuilder(
  ///   valueListenable: Env.currentNotifier,
  ///   builder: (context, env, _) => Text(env.name),
  /// )
  /// ```
  static ValueNotifier<dynamic> get currentNotifier =>
      EnvManager.instance.currentNotifier;

  // ---------------------------------------------------------------------------
  // Switching
  // ---------------------------------------------------------------------------

  /// Switches the active environment to [env] and persists the selection.
  ///
  /// Throws `EnvSwitchLockedException` when the current environment is locked.
  /// Throws [ArgumentError] if [env] was not registered during [init].
  /// Call `AppRestarter.restart` separately if you need a full widget-tree
  /// rebuild, or use `EnvSwitcher` which handles this automatically.
  static Future<void> switchTo(Enum env) async {
    await EnvManager.instance.switchTo(env);
  }
}
