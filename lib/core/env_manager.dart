import 'package:flutter/foundation.dart';

import 'package:flutter_env_switch/core/env_loader.dart';
import 'package:flutter_env_switch/core/env_store.dart';
import 'package:flutter_env_switch/models/env_exceptions.dart';

/// Central coordinator for environment loading, switching, and persistence.
///
/// [EnvManager] is a controlled singleton. Access it via [EnvManager.instance]
/// after calling [EnvManager.init].
///
/// Type parameter [E] must be the user-defined enum that identifies
/// environments (e.g. `Environment`).
class EnvManager<E extends Enum> {
  EnvManager._({
    required E defaultEnv,
    required EnvStore store,
    required Map<E, Map<String, String>> envs,
    required List<E> allEnumValues,
    required Set<E> lockedEnvironments,
    required bool persistSelection,
  })  : _store = store,
        _envs = envs,
        _allEnumValues = allEnumValues,
        _lockedEnvironments = lockedEnvironments,
        _persistSelection = persistSelection,
        currentNotifier = ValueNotifier<E>(defaultEnv);

  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static EnvManager<dynamic>? _instance;

  /// The active [EnvManager] singleton.
  ///
  /// Throws `EnvNotInitializedException` if [init] has not been called yet.
  static EnvManager<dynamic> get instance {
    if (_instance == null) throw EnvNotInitializedException();
    return _instance!;
  }

  /// Typed convenience accessor — returns this cast to `EnvManager<E>`.
  ///
  /// Use when you have access to the concrete enum type.
  static EnvManager<E> instanceOf<E extends Enum>() {
    if (_instance == null) throw EnvNotInitializedException();
    return _instance! as EnvManager<E>;
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Initialises the singleton with [defaultEnv] and the [configs] map.
  ///
  /// Loads all `.env` asset files in parallel. If a previously persisted
  /// selection exists and [persistSelection] is `true`, it is restored;
  /// otherwise [defaultEnv] is used.
  ///
  /// [lockedEnvironments] is an optional set of environments from which
  /// switching is forbidden. When the active environment is in this set,
  /// `switchTo` throws `EnvSwitchLockedException`. Defaults to no lock.
  ///
  /// [persistSelection] controls whether the active environment is saved to
  /// and restored from `SharedPreferences` across sessions. When `false`, the
  /// store is cleared on init and switches are not written to the store.
  /// Defaults to `true`.
  ///
  /// Throws `EnvLoadException` when any asset fails to load.
  /// Safe to call multiple times (subsequent calls replace the instance).
  static Future<EnvManager<E>> init<E extends Enum>({
    required E defaultEnv,
    required Map<E, String> configs,
    Set<E>? lockedEnvironments,
    bool persistSelection = true,
    EnvLoader? loader,
    EnvStore? store,
  }) async {
    final resolvedLoader = loader ?? EnvLoader();
    final resolvedStore = store ?? EnvStore();

    // Load all env files concurrently.
    final entries = configs.entries.toList();
    final results = await Future.wait(
      entries.map((e) => resolvedLoader.load(e.value)),
    );

    final envs = <E, Map<String, String>>{};
    for (var i = 0; i < entries.length; i++) {
      envs[entries[i].key] = results[i];
    }

    final allEnumValues = configs.keys.toList();
    E startEnv = defaultEnv;

    if (persistSelection) {
      // Attempt to restore a previously persisted selection.
      final savedName = await resolvedStore.load();
      final restoredEnv = savedName != null
          ? allEnumValues.cast<E?>().firstWhere(
                (e) => e?.name == savedName,
                orElse: () => null,
              )
          : null;
      startEnv = restoredEnv ?? defaultEnv;
    } else {
      // Clear any leftover state so the store is always clean in session mode.
      await resolvedStore.clear();
    }

    final manager = EnvManager<E>._(
      defaultEnv: startEnv,
      store: resolvedStore,
      envs: envs,
      allEnumValues: allEnumValues,
      lockedEnvironments: lockedEnvironments ?? const {},
      persistSelection: persistSelection,
    );

    _instance = manager;
    return manager;
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final EnvStore _store;
  final Map<E, Map<String, String>> _envs;
  final List<E> _allEnumValues;
  final Set<E> _lockedEnvironments;
  bool _persistSelection;

  /// A [ValueNotifier] that broadcasts the currently active [E] whenever the
  /// environment is switched. Useful for reactive UI updates.
  final ValueNotifier<E> currentNotifier;

  /// The currently active environment.
  E get current => currentNotifier.value;

  /// All registered environment values, in declaration order.
  List<E> get allValues => List.unmodifiable(_allEnumValues);

  /// Whether the currently active environment is locked.
  ///
  /// When `true`, any call to [switchTo] will throw
  /// `EnvSwitchLockedException`.
  bool get isCurrentLocked => _lockedEnvironments.contains(current);

  /// Whether the active environment is saved to and restored from
  /// `SharedPreferences` across sessions.
  ///
  /// When `false`, switches are not written to the store and the next launch
  /// always starts from `defaultEnv`.
  bool get persistSelection => _persistSelection;

  /// All key/value pairs loaded for the current environment.
  ///
  /// Returns an unmodifiable view. Useful for in-panel inspection and
  /// debugging tooling.
  Map<String, String> get currentEnvData =>
      Map.unmodifiable(_envs[current] ?? {});

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  Map<String, String> get _currentEnv {
    final env = _envs[current];
    if (env == null) {
      throw EnvLoadException(
        'No loaded data found for environment "${current.name}". '
        'Ensure all configs were passed to Env.init().',
      );
    }
    return env;
  }

  /// Returns the raw string value for [key] in the current environment.
  ///
  /// Throws `EnvKeyNotFoundException` when the key is absent.
  String get(String key) {
    final value = _currentEnv[key];
    if (value == null) {
      throw EnvKeyNotFoundException(key, envName: current.name);
    }
    return value;
  }

  /// Returns the value for [key] as an [int].
  ///
  /// Throws `EnvKeyNotFoundException` if the key is absent, or
  /// [FormatException] if the value cannot be parsed as an integer.
  int getInt(String key) => int.parse(get(key));

  /// Returns the value for [key] as a [double].
  ///
  /// Throws `EnvKeyNotFoundException` if the key is absent, or
  /// [FormatException] if the value cannot be parsed as a double.
  double getDouble(String key) => double.parse(get(key));

  /// Returns the value for [key] as a [bool].
  ///
  /// Accepts `'true'` / `'1'` / `'yes'` (case-insensitive) as `true`;
  /// everything else is `false`.
  bool getBool(String key) {
    final raw = get(key).toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  /// Returns the raw string value for [key], or [fallback] if absent.
  String getOrElse(String key, String fallback) =>
      _currentEnv[key] ?? fallback;

  // ---------------------------------------------------------------------------
  // Switching
  // ---------------------------------------------------------------------------

  /// Switches the active environment to [env].
  ///
  /// When [persistSelection] is `true`, the new selection is written to
  /// `SharedPreferences`. When `false`, the switch is in-session only.
  ///
  /// Notifies [currentNotifier] listeners after persisting (or immediately
  /// when not persisting).
  ///
  /// Throws `EnvSwitchLockedException` when the current environment is locked
  /// (i.e. it was included in `lockedEnvironments` during [init]).
  ///
  /// Throws [ArgumentError] when [env] is not one of the registered values
  /// supplied during [init].
  Future<void> switchTo(E env) async {
    if (isCurrentLocked) {
      throw EnvSwitchLockedException(current.name);
    }
    if (!_allEnumValues.contains(env)) {
      throw ArgumentError.value(
        env,
        'env',
        'Unknown environment "${env.name}". '
        'Must be one of: ${_allEnumValues.map((e) => e.name).join(', ')}.',
      );
    }
    if (_persistSelection) await _store.save(env.name);
    currentNotifier.value = env;
  }

  /// Changes the persist mode at runtime.
  ///
  /// - Setting to `true`: saves the **current** environment immediately so
  ///   the next launch restores it.
  /// - Setting to `false`: clears the stored selection so the next launch
  ///   always starts from `defaultEnv`; future switches are not saved.
  Future<void> setPersistSelection(bool persist) async {
    _persistSelection = persist;
    if (persist) {
      await _store.save(current.name);
    } else {
      await _store.clear();
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Resets the singleton. Intended for testing only.
  @visibleForTesting
  static void reset() => _instance = null;
}
