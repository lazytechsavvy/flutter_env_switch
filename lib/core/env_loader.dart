import 'package:flutter/services.dart';

import 'package:flutter_env_switch/core/env_parser.dart';
import 'package:flutter_env_switch/models/env_exceptions.dart';

/// Loads a `.env` asset file from the Flutter asset bundle and parses it.
///
/// Delegates parsing to [EnvParser]. Throws [EnvLoadException] when the asset
/// cannot be found or read.
class EnvLoader {
  /// Creates an [EnvLoader] backed by the given [_bundle].
  ///
  /// Defaults to [rootBundle] when no bundle is supplied, which is the
  /// correct choice for production. Pass a custom bundle in tests.
  EnvLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final EnvParser _parser = EnvParser();

  /// Loads and parses the `.env` file at [path].
  ///
  /// Throws [EnvLoadException] if the asset cannot be loaded.
  Future<Map<String, String>> load(String path) async {
    try {
      final raw = await _bundle.loadString(path);
      return _parser.parse(raw);
    } catch (e) {
      throw EnvLoadException(
        'Failed to load env asset at "$path": $e',
      );
    }
  }
}
