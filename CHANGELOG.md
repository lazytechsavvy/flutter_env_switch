## 1.1.5

* **`persistSelection`** — new `bool` parameter on `Env.init` and
  `EnvManager.init` (default `true`). When `false`, the app always starts
  from `defaultEnv` on each launch and switches are not written to
  `SharedPreferences`. Existing callers are unaffected.
* **`Env.persistSelection` / `EnvManager.persistSelection`** — getter
  exposing the current persist mode.
* **`Env.setPersistSelection(bool)` / `EnvManager.setPersistSelection(bool)`**
  — method to change the persist mode at runtime. Turning off clears the
  store; turning on immediately saves the current environment.
* **Debug panel "Persist env selection" toggle** — new `SwitchListTile` in
  the debug panel lets testers flip the persist mode without touching code.

## 1.1.4

* **`AppRestarter.onRestart`** — new optional `Future<void> Function()?` callback
  invoked **before** the widget tree rebuilds. Use it to re-initialise services
  (Sentry, Dio, etc.) that were set up in `main()` and need to pick up the new
  environment values.
* **`AppRestarter.builder`** — new `WidgetBuilder?` alternative to `child`.
  The builder is re-evaluated on every restart, allowing dynamic re-creation of
  widgets that hold references to re-created objects (e.g. `GoRouter`).
  Exactly one of `child` or `builder` must be provided.
* **`EnvSwitcher.enableInRelease`** — new `bool` parameter (default `true`).
  Controls whether the debug panel gesture is active in release builds.
  Set to `false` to restrict the panel to debug/profile builds only (the
  behaviour of prior versions).
* **`EnvSwitcher.enabled`** default changed from `!kReleaseMode` to `true` —
  the panel now works in release mode by default. Callers that need the old
  behaviour should set `enableInRelease: false`.

## 1.1.3

* Updated `CHANGELOG.md` to include entries for versions `1.1.2` and `1.1.3`.

## 1.1.2

* Added `CHANGELOG.md` entry for version `1.1.1`.
* Replaced deprecated `Color.withOpacity` calls with `Color.withValues(alpha:)` across
  all UI files to resolve pana static-analysis warnings.
* Corrected `repository` URL in `pubspec.yaml` to
  `https://github.com/lazytechsavvy/flutter_env_switch`.
* Bumped minimum Flutter SDK to `>=3.27.0` and Dart SDK to `>=3.3.0` to ensure
  `Color.withValues` is available in the target environment.

## 1.1.1

* Fixed deprecated `Color.withOpacity` calls — replaced with `Color.withValues(alpha:)`
  throughout the UI layer to eliminate pana static-analysis warnings.
* Bumped minimum Flutter SDK to `>=3.27.0` and Dart SDK to `>=3.3.0` to align with
  the `Color.withValues` API availability.
* Updated `repository` URL to the correct GitHub handle.

## 1.1.0

* **Tap-count trigger** — `EnvSwitcher` gains `triggerMode` (`EnvTriggerMode.longPress` |
  `EnvTriggerMode.tapCount`), `tapCount` (default 5), and `tapWindowMs` (default 3000)
  for the industry-standard hidden-panel gesture.
* **`onSwitched` callback** — `EnvSwitcher` and `showEnvDebugPanel` now accept an
  optional `VoidCallback? onSwitched` fired after each successful environment switch.
* **In-panel key browser** — the debug panel includes a collapsible "View loaded keys"
  section that enumerates all key/value pairs for the active environment. Sensitive keys
  (containing `KEY`, `SECRET`, `TOKEN`, etc.) are masked by default with an eye-toggle.
  All values can be copied to clipboard.
* **`EnvBadge<E>`** — new overlay widget that renders a persistent environment indicator
  badge in a corner of its child, reacting automatically to runtime switches.
* **`Env.currentEnvData`** — new static getter exposing all key/value pairs for the
  current environment as an unmodifiable `Map<String, String>`.
* **`EnvManager.currentEnvData`** — same, on the typed singleton.

## 1.0.0

* **Locked environments** — new `lockedEnvironments` parameter on `Env.init` prevents
  switching away from sensitive environments (e.g. production) at runtime.
* `Env.isLocked` static getter and `EnvManager.isCurrentLocked` for programmatic checks.
* `EnvSwitchLockedException` typed exception thrown when a locked-env switch is attempted.
* Debug panel renders a `LOCKED` badge and disables all environment tiles when locked.
* Restart-after-switch toggle is hidden in the panel when the environment is locked.

## 0.1.0

* Initial release.
* Multi-.env file loading from Flutter asset bundle.
* Enum-driven, type-safe environment switching.
* Runtime switching with `SharedPreferences` persistence.
* Gesture-triggered debug panel (long-press bottom sheet).
* `AppRestarter` for soft app restart via `UniqueKey`.
* `EnvSwitcher` widget wrapper — automatically disabled in release mode.
* Optional `EnvDioInterceptor` for Dio base URL injection.
* `ValueNotifier`-based reactive current-environment broadcasting.
* Full unit and widget test suite.
