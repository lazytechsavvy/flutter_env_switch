import 'package:flutter/material.dart';

/// Wraps its [child] in an invisible layer that triggers [onLongPress] when
/// the user performs a long-press anywhere within the widget.
///
/// When [enabled] is `false` (e.g. in release mode) the child is returned
/// as-is with zero overhead.
class LongPressDetector extends StatelessWidget {
  /// Creates a [LongPressDetector].
  const LongPressDetector({
    super.key,
    required this.child,
    required this.onLongPress,
    this.enabled = true,
  });

  /// The widget beneath the gesture layer.
  final Widget child;

  /// Callback invoked on a long press.
  final VoidCallback onLongPress;

  /// When `false`, [child] is rendered without any gesture detection.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: onLongPress,
      child: child,
    );
  }
}

/// Detects [requiredTaps] rapid successive taps within [windowMs] milliseconds
/// and fires [onTriggered] when the threshold is reached.
///
/// The tap counter resets automatically when the time window expires between
/// taps. This is the industry-standard "hidden panel" gesture used by QA
/// teams (equivalent to the Flutter Inspector easter-egg tap pattern).
///
/// When [enabled] is `false` the child is returned as-is.
class TapCountDetector extends StatefulWidget {
  /// Creates a [TapCountDetector].
  const TapCountDetector({
    super.key,
    required this.child,
    required this.onTriggered,
    this.requiredTaps = 5,
    this.windowMs = 3000,
    this.enabled = true,
  });

  /// The widget beneath the gesture layer.
  final Widget child;

  /// Callback fired when [requiredTaps] taps are received within [windowMs].
  final VoidCallback onTriggered;

  /// Number of taps required to fire [onTriggered]. Defaults to `5`.
  final int requiredTaps;

  /// Maximum milliseconds allowed between the first and last tap of a
  /// sequence. Defaults to `3000` (3 seconds).
  final int windowMs;

  /// When `false`, [child] is rendered without any gesture detection.
  final bool enabled;

  @override
  State<TapCountDetector> createState() => _TapCountDetectorState();
}

class _TapCountDetectorState extends State<TapCountDetector> {
  int _count = 0;
  DateTime? _windowStart;

  void _onTap() {
    final now = DateTime.now();

    // Expired window or first tap — start a new sequence.
    if (_windowStart == null ||
        now.difference(_windowStart!).inMilliseconds > widget.windowMs) {
      _windowStart = now;
      _count = 1;
    } else {
      _count++;
    }

    if (_count >= widget.requiredTaps) {
      _count = 0;
      _windowStart = null;
      widget.onTriggered();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _onTap,
      child: widget.child,
    );
  }
}
