import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_env_switch/ui/debug_panel.dart';
import 'package:flutter_env_switch/ui/gesture_detector.dart';

/// Determines how the flutter_env_switch debug panel is triggered
/// from [EnvSwitcher].
enum EnvTriggerMode {
  /// A sustained long-press anywhere within the wrapped widget opens the panel.
  ///
  /// This is the default. Familiar to developers but less discoverable.
  longPress,

  /// Rapid successive taps (default 5) within a time window open the panel.
  ///
  /// This is the industry-standard QA-panel gesture. Configure the count
  /// and window with [EnvSwitcher.tapCount] and [EnvSwitcher.tapWindowMs].
  tapCount,
}

/// Wraps [child] with a gesture that opens the envify debug panel.
///
/// The panel is automatically disabled in release mode regardless of the
/// [enabled] flag. Use [triggerMode] to choose between a long-press and a
/// configurable rapid-tap gesture.
///
/// ### Long-press (default)
/// ```dart
/// EnvSwitcher<Environment>(
///   child: const AppLogo(),
/// )
/// ```
///
/// ### Tap-count
/// ```dart
/// EnvSwitcher<Environment>(
///   triggerMode: EnvTriggerMode.tapCount,
///   tapCount: 5,
///   tapWindowMs: 3000,
///   child: const AppLogo(),
/// )
/// ```
class EnvSwitcher<E extends Enum> extends StatelessWidget {
  /// Creates an [EnvSwitcher].
  ///
  /// [enabled] defaults to `!kReleaseMode`.
  const EnvSwitcher({
    super.key,
    required this.child,
    bool? enabled,
    this.showRestartToggle = true,
    this.triggerMode = EnvTriggerMode.longPress,
    this.tapCount = 5,
    this.tapWindowMs = 3000,
    this.onSwitched,
  }) : enabled = enabled ?? !kReleaseMode;

  /// The widget tree to wrap.
  final Widget child;

  /// Whether the debug panel gesture is active.
  ///
  /// Always `false` in release mode regardless of this value.
  final bool enabled;

  /// Whether to show the restart-after-switch toggle in the debug panel.
  final bool showRestartToggle;

  /// Which gesture opens the debug panel.
  ///
  /// Defaults to [EnvTriggerMode.longPress].
  final EnvTriggerMode triggerMode;

  /// Number of taps required when [triggerMode] is [EnvTriggerMode.tapCount].
  ///
  /// Defaults to `5`. Ignored when [triggerMode] is [EnvTriggerMode.longPress].
  final int tapCount;

  /// Millisecond window within which [tapCount] taps must occur.
  ///
  /// Defaults to `3000` (3 seconds). Ignored for [EnvTriggerMode.longPress].
  final int tapWindowMs;

  /// Optional callback fired after the environment switch (and optional app
  /// restart) completes.
  ///
  /// Useful for triggering analytics events, showing a snackbar, etc.
  final VoidCallback? onSwitched;

  @override
  Widget build(BuildContext context) {
    // Double-guard: never enable in release mode.
    final active = enabled && !kReleaseMode;

    void openPanel() => showEnvDebugPanel<E>(
          context,
          showRestartToggle: showRestartToggle,
          onSwitched: onSwitched,
        );

    if (!active) return child;

    return switch (triggerMode) {
      EnvTriggerMode.longPress => LongPressDetector(
          onLongPress: openPanel,
          child: child,
        ),
      EnvTriggerMode.tapCount => TapCountDetector(
          onTriggered: openPanel,
          requiredTaps: tapCount,
          windowMs: tapWindowMs,
          child: child,
        ),
    };
  }
}
