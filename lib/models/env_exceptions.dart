/// Thrown when `Env.get` (or typed variants) is called with a key that does
/// not exist in the currently loaded environment.
class EnvKeyNotFoundException implements Exception {
  /// Creates an [EnvKeyNotFoundException] for the given [key].
  const EnvKeyNotFoundException(this.key, {this.envName});

  /// The missing key.
  final String key;

  /// The name of the environment that was queried (optional, for diagnostics).
  final String? envName;

  @override
  String toString() {
    final env = envName != null ? ' in environment "$envName"' : '';
    return 'EnvKeyNotFoundException: key "$key" not found$env.';
  }
}

/// Thrown when `Env.init` is called but a config asset cannot be loaded.
class EnvLoadException implements Exception {
  /// Creates an [EnvLoadException] with the given [message].
  const EnvLoadException(this.message);

  /// Human-readable description of the load failure.
  final String message;

  @override
  String toString() => 'EnvLoadException: $message';
}

/// Thrown when an `Env` accessor is called before `Env.init` has completed.
class EnvNotInitializedException implements Exception {
  @override
  String toString() =>
      'EnvNotInitializedException: Env.init() must be called before '
      'accessing environment values.';
}

/// Thrown when `Env.switchTo` or `EnvManager.switchTo` is called while the
/// current environment is included in the `lockedEnvironments` set.
///
/// A locked environment prevents switching away from it entirely — both
/// programmatic calls and the debug panel UI respect this guard.
class EnvSwitchLockedException implements Exception {
  /// Creates an [EnvSwitchLockedException] for the given [envName].
  const EnvSwitchLockedException(this.envName);

  /// The name of the locked environment that blocked the switch.
  final String envName;

  @override
  String toString() =>
      'EnvSwitchLockedException: switching is disabled '
      'while the active environment is "$envName".';
}
