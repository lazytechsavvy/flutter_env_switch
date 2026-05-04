import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_env_switch/core/env_manager.dart';

/// Shows the envify debug panel as a modal bottom sheet.
///
/// Lists all registered environments, highlights the active one, and lets
/// the user tap to switch. An optional "restart after switch" toggle is
/// shown when [showRestartToggle] is `true`.
///
/// [onSwitched] is called after the environment switch (and optional app
/// restart) completes.
Future<void> showEnvDebugPanel<E extends Enum>(
  BuildContext context, {
  bool showRestartToggle = true,
  VoidCallback? onSwitched,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _EnvDebugPanel<E>(
      showRestartToggle: showRestartToggle,
      onSwitched: onSwitched,
    ),
  );
}

class _EnvDebugPanel<E extends Enum> extends StatefulWidget {
  const _EnvDebugPanel({
    super.key,
    required this.showRestartToggle,
    this.onSwitched,
  });

  final bool showRestartToggle;
  final VoidCallback? onSwitched;

  @override
  State<_EnvDebugPanel<E>> createState() => _EnvDebugPanelState<E>();
}

class _EnvDebugPanelState<E extends Enum>
    extends State<_EnvDebugPanel<E>> {
  late final EnvManager<E> _manager;
  bool _restartAfterSwitch = true;
  bool _showKeyBrowser = false;

  // Keys whose values are masked by default.
  static const _sensitivePatterns = [
    'KEY',
    'SECRET',
    'TOKEN',
    'PASSWORD',
    'PASS',
    'PWD',
    'AUTH',
    'CREDENTIAL',
  ];

  // Per-key visibility state for sensitive values.
  final Map<String, bool> _revealed = {};

  @override
  void initState() {
    super.initState();
    _manager = EnvManager.instanceOf<E>();
  }

  bool _isSensitive(String key) {
    final upper = key.toUpperCase();
    return _sensitivePatterns.any(upper.contains);
  }

  Future<void> _onTap(E env) async {
    if (env == _manager.current) {
      Navigator.of(context).pop();
      return;
    }

    await _manager.switchTo(env);

    if (!mounted) return;
    Navigator.of(context).pop();

    if (_restartAfterSwitch) {
      AppRestarter.restart(context);
    }

    widget.onSwitched?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLocked = _manager.isCurrentLocked;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Environment',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (isLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 12,
                            color: colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LOCKED',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'DEV ONLY',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (isLocked) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Switching is disabled in this environment.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            ValueListenableBuilder<E>(
              valueListenable: _manager.currentNotifier,
              builder: (context, current, _) {
                return Column(
                  children: _manager.allValues.map((env) {
                    final isActive = env == current;
                    final textColor = isLocked && !isActive
                        ? colorScheme.onSurface.withOpacity(0.38)
                        : isActive
                            ? colorScheme.primary
                            : colorScheme.onSurface;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      leading: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? colorScheme.primary
                              : isLocked
                                  ? colorScheme.outlineVariant.withOpacity(0.4)
                                  : colorScheme.outlineVariant,
                        ),
                      ),
                      title: Text(
                        env.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: textColor,
                        ),
                      ),
                      trailing: isActive
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: colorScheme.primary,
                            )
                          : null,
                      // Disable taps entirely when locked.
                      onTap: isLocked ? null : () => _onTap(env),
                    );
                  }).toList(),
                );
              },
            ),
            if (!isLocked && widget.showRestartToggle) ...[
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: const Text('Restart app after switch'),
                subtitle: const Text('Recommended for full env reload'),
                value: _restartAfterSwitch,
                onChanged: (v) => setState(() => _restartAfterSwitch = v),
              ),
            ],
            // ── Key browser ──────────────────────────────────────────────────
            const Divider(height: 1),
            _KeyBrowserTile(
              isExpanded: _showKeyBrowser,
              onToggle: () =>
                  setState(() => _showKeyBrowser = !_showKeyBrowser),
            ),
            if (_showKeyBrowser) _buildKeyBrowser(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyBrowser(ThemeData theme, ColorScheme colorScheme) {
    final data = _manager.currentEnvData;

    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text(
          'No keys loaded for this environment.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final keys = data.keys.toList()..sort();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        shrinkWrap: true,
        itemCount: keys.length,
        itemBuilder: (context, index) {
          final key = keys[index];
          final value = data[key]!;
          final sensitive = _isSensitive(key);
          final isRevealed = _revealed[key] ?? false;
          final displayValue = (sensitive && !isRevealed)
              ? '•' * value.length.clamp(8, 20)
              : value;

          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(
              key,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              displayValue,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: sensitive && !isRevealed
                    ? colorScheme.onSurface.withOpacity(0.4)
                    : colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sensitive)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      isRevealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: isRevealed ? 'Hide value' : 'Reveal value',
                    onPressed: () =>
                        setState(() => _revealed[key] = !isRevealed),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.copy_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Copy value',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Copied $key',
                          style: const TextStyle(fontSize: 13),
                        ),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        width: 200,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A list tile that acts as the expand/collapse header for the key browser.
class _KeyBrowserTile extends StatelessWidget {
  const _KeyBrowserTile({
    required this.isExpanded,
    required this.onToggle,
  });

  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(
        Icons.manage_search_rounded,
        size: 18,
        color: colorScheme.onSurfaceVariant,
      ),
      title: Text(
        'View loaded keys',
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        isExpanded ? Icons.expand_less : Icons.expand_more,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onToggle,
    );
  }
}

/// A [StatefulWidget] that enables soft app restart by rebuilding its subtree.
///
/// Place [AppRestarter] near the root of your widget tree (above
/// [MaterialApp]):
///
/// ```dart
/// runApp(AppRestarter(child: MyApp()));
/// ```
///
/// Then call [AppRestarter.restart] from anywhere in the tree to trigger
/// a full rebuild:
///
/// ```dart
/// AppRestarter.restart(context);
/// ```
class AppRestarter extends StatefulWidget {
  /// Creates an [AppRestarter].
  const AppRestarter({super.key, required this.child});

  /// The subtree that will be rebuilt on restart.
  final Widget child;

  /// Triggers a full rebuild of the [AppRestarter] subtree.
  ///
  /// Finds the nearest [AppRestarter] ancestor in the widget tree and forces
  /// it to rebuild with a new [UniqueKey], effectively restarting the subtree.
  ///
  /// If no [AppRestarter] ancestor is found, this call is a **no-op**.
  /// Ensure [AppRestarter] is placed above the widget calling this method
  /// (typically at the root, wrapping your `MaterialApp`).
  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_AppRestarterState>()?.restart();
  }

  @override
  State<AppRestarter> createState() => _AppRestarterState();
}

class _AppRestarterState extends State<AppRestarter> {
  Key _key = UniqueKey();

  void restart() {
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
