/// Pairs a user-defined enum value with the asset path of its .env file.
///
/// `EnvConfig` is an **optional** convenience type. `Env.init` (and
/// `EnvManager.init`) accept a plain `Map<E, String>` — you do not need
/// `EnvConfig` for typical usage. It is provided for teams that prefer to
/// declare environment descriptors in a centralised list:
///
/// ```dart
/// const configs = [
///   EnvConfig(env: Environment.dev,
///             assetPath: 'assets/env/.env.dev'),
///   EnvConfig(env: Environment.production,
///             assetPath: 'assets/env/.env.production'),
/// ];
///
/// await Env.init<Environment>(
///   defaultEnv: Environment.production,
///   configs: Map.fromEntries(
///     configs.map((c) => MapEntry(c.env, c.assetPath)),
///   ),
/// );
/// ```
class EnvConfig<E extends Enum> {
  /// Creates an [EnvConfig] with the given [env] and [assetPath].
  const EnvConfig({
    required this.env,
    required this.assetPath,
  });

  /// The enum value identifying this environment.
  final E env;

  /// The asset path to the `.env` file for this environment.
  ///
  /// Must be declared in the host app's `pubspec.yaml` under `flutter.assets`.
  final String assetPath;

  @override
  String toString() => 'EnvConfig(env: $env, assetPath: $assetPath)';
}
