import 'package:flutter_env_switch/flutter_env_switch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum Environment { dev, staging, production }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.init<Environment>(
    defaultEnv: Environment.production,
    configs: {
      Environment.dev: 'assets/env/.env.dev',
      Environment.staging: 'assets/env/.env.staging',
      Environment.production: 'assets/env/.env.production',
    },
  );

  runApp(
    const AppRestarter(
      child: EnvSwitcher<Environment>(
        enabled: !kReleaseMode,
        child: FlutterEnvSwitchExampleApp(),
      ),
    ),
  );
}

class FlutterEnvSwitchExampleApp extends StatelessWidget {
  const FlutterEnvSwitchExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<dynamic>(
      valueListenable: Env.currentNotifier,
      builder: (context, env, _) {
        final isDark = Env.getBool('FEATURE_DARK_MODE');
        return MaterialApp(
          title: Env.get('APP_NAME'),
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          home: const HomePage(),
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_env_switch example'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _EnvBadge(env: Env.current),
            const SizedBox(height: 24),
            const _SectionHeader('Configuration Values'),
            const SizedBox(height: 12),
            _ConfigTile(
              label: 'BASE_URL',
              value: Env.get('BASE_URL'),
              icon: Icons.link_rounded,
            ),
            _ConfigTile(
              label: 'APP_NAME',
              value: Env.get('APP_NAME'),
              icon: Icons.label_rounded,
            ),
            _ConfigTile(
              label: 'TIMEOUT',
              value: '${Env.getInt('TIMEOUT')}s',
              icon: Icons.timer_rounded,
            ),
            _ConfigTile(
              label: 'LOG_LEVEL',
              value: Env.get('LOG_LEVEL'),
              icon: Icons.bug_report_rounded,
            ),
            const SizedBox(height: 24),
            const _SectionHeader('Feature Flags'),
            const SizedBox(height: 12),
            _FeatureTile(
              label: 'Dark Mode',
              enabled: Env.getBool('FEATURE_DARK_MODE'),
            ),
            _FeatureTile(
              label: 'Analytics',
              enabled: Env.getBool('FEATURE_ANALYTICS'),
            ),
            const SizedBox(height: 32),
            Card(
              color: colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: colorScheme.onSecondaryContainer,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Switch Environment',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kReleaseMode
                          ? 'Debug panel is disabled in release mode.'
                          : 'Long-press anywhere on the screen to open the '
                              'environment switcher panel.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvBadge extends StatelessWidget {
  const _EnvBadge({required this.env});

  final Enum env;

  Color _color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (env.name) {
      'dev' => Colors.orange,
      'staging' => Colors.blue,
      'production' => scheme.primary,
      _ => scheme.secondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Active: ${env.name.toUpperCase()}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _ConfigTile extends StatelessWidget {
  const _ConfigTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(label, style: theme.textTheme.labelMedium),
        subtitle: Text(
          value,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: enabled
                ? Colors.green.withValues(alpha: 0.15)
                : theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            enabled ? 'ON' : 'OFF',
            style: theme.textTheme.labelMedium?.copyWith(
              color: enabled
                  ? Colors.green.shade700
                  : theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
