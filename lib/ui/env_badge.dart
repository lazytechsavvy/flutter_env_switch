import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_env_switch/core/env_manager.dart';

/// An overlay widget that displays the currently active environment as a
/// persistent badge in a corner of its [child].
///
/// Place [EnvBadge] anywhere in the tree where you want the badge to appear.
/// Typically you wrap [MaterialApp] or a top-level `Scaffold` so the badge is
/// always visible:
///
/// ```dart
/// EnvBadge<Environment>(
///   child: MaterialApp(...),
/// )
/// ```
///
/// The badge reacts automatically to environment switches via
/// `EnvManager`'s [ValueNotifier] — no manual rebuilds needed.
///
/// ### Custom badge widget
/// ```dart
/// EnvBadge<Environment>(
///   alignment: Alignment.bottomLeft,
///   badgeBuilder: (env) => Chip(label: Text(env.name.toUpperCase())),
///   child: MaterialApp(...),
/// )
/// ```
///
/// ### Release-mode visibility
/// By default the badge is hidden in release builds. Set
/// [visibleInRelease] to `true` if you need it in production (e.g. for an
/// internal distribution build):
/// ```dart
/// EnvBadge<Environment>(
///   visibleInRelease: true,
///   child: MaterialApp(...),
/// )
/// ```
class EnvBadge<E extends Enum> extends StatelessWidget {
  /// Creates an [EnvBadge].
  const EnvBadge({
    super.key,
    required this.child,
    this.alignment = Alignment.topRight,
    this.badgeBuilder,
    this.padding = const EdgeInsets.all(12),
    this.visibleInRelease = false,
  });

  /// The widget tree over which the badge is overlaid.
  final Widget child;

  /// Corner alignment of the badge within the [child]. Defaults to
  /// [Alignment.topRight].
  final AlignmentGeometry alignment;

  /// Optional builder for a custom badge widget.
  ///
  /// When `null`, the default pill-shaped badge is rendered.
  final Widget Function(E env)? badgeBuilder;

  /// Padding between the badge and the edge of [child].
  final EdgeInsetsGeometry padding;

  /// Whether to show the badge in release mode. Defaults to `false`.
  final bool visibleInRelease;

  @override
  Widget build(BuildContext context) {
    if (!visibleInRelease && kReleaseMode) return child;

    return Stack(
      children: [
        child,
        ValueListenableBuilder<E>(
          valueListenable: EnvManager.instanceOf<E>().currentNotifier,
          builder: (context, env, _) => Align(
            alignment: alignment,
            child: Padding(
              padding: padding,
              child: badgeBuilder != null
                  ? badgeBuilder!(env)
                  : _DefaultEnvBadge(envName: env.name),
            ),
          ),
        ),
      ],
    );
  }
}

/// The default badge rendered by [EnvBadge] when no `badgeBuilder` is
/// provided. Shows the environment name in a semi-transparent pill.
class _DefaultEnvBadge extends StatelessWidget {
  const _DefaultEnvBadge({required this.envName});

  final String envName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withOpacity(0.75),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          envName.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onInverseSurface,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
