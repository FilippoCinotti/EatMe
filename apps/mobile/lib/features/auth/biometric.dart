import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/api.dart';
import '../../core/biometric_access.dart';
import '../../core/localization.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

final biometricProvider = Provider<BiometricAccess>((ref) {
  final auth = LocalAuthentication();
  final native =
      !kIsWeb &&
      !EatMeApi.development &&
      [
        TargetPlatform.iOS,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform);
  final access = BiometricAccess(
    available: () async =>
        native &&
        await auth.canCheckBiometrics &&
        (await auth.getAvailableBiometrics()).isNotEmpty,
    authenticate: (reason) => auth.authenticate(
      localizedReason: reason,
      biometricOnly: true,
      persistAcrossBackgrounding: false,
    ),
    read: (key) => EatMeApi.secure.read(key: key),
    write: (key, value) => EatMeApi.secure.write(key: key, value: value),
  );
  ref.onDispose(access.dispose);
  return access;
});

/// Covers the entire router, including deep links, until the session is unlocked.
class BiometricGate extends ConsumerStatefulWidget {
  const BiometricGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<BiometricGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_bind);
  }

  void _bind() {
    if (!mounted) return;
    ref
        .read(biometricProvider)
        .bind(EatMeApi.development ? null : ref.read(apiProvider).userId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final access = ref.read(biometricProvider);
    // System biometric prompts make the app inactive. Do not invalidate those.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (state == AppLifecycleState.inactive && !access.busy)) {
      FocusManager.instance.primaryFocus?.unfocus();
      access.lock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appProvider, (_, _) => _bind());
    final access = ref.watch(biometricProvider);
    return StreamBuilder<void>(
      stream: access.changes,
      builder: (context, _) {
        final blocked = access.checking || access.locked;
        return PopScope(
          canPop: !blocked,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Keep navigation state, but remove protected screens from paint,
              // hit testing and accessibility while locked.
              ExcludeFocus(
                excluding: blocked,
                child: TickerMode(
                  enabled: !blocked,
                  child: Offstage(offstage: blocked, child: widget.child),
                ),
              ),
              if (blocked)
                Scaffold(
                  body: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: access.checking
                            ? const CircularProgressIndicator()
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fingerprint,
                                    size: 40,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    context.t('biometric_unlock_title'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontSize: 24),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.t('biometric_unlock_body'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: 280,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(44, 44),
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                      onPressed: access.busy
                                          ? null
                                          : () => access.unlock(
                                              context.t('biometric_reason'),
                                            ),
                                      child: Text(
                                        context.t('biometric_unlock'),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: access.busy
                                        ? null
                                        : () async {
                                            await ref
                                                .read(apiProvider)
                                                .clearSession();
                                            await ref
                                                .read(appProvider.notifier)
                                                .restore();
                                            await access.bind(null);
                                          },
                                    child: Text(
                                      context.t('biometric_normal_login'),
                                    ),
                                  ),
                                  if (access.failed)
                                    Text(
                                      context.t('biometric_failed'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class BiometricPreference extends ConsumerWidget {
  const BiometricPreference({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(biometricProvider);
    return StreamBuilder<void>(
      stream: access.changes,
      builder: (context, _) {
        if (!access.supported && !access.enabled) {
          return const SizedBox.shrink();
        }
        return SettingsGroup(
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.t('biometric_title'),
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                context.t('biometric_body'),
                style: const TextStyle(fontSize: 12),
              ),
              value: access.enabled,
              onChanged: access.busy || access.checking
                  ? null
                  : (value) async {
                      await access.setEnabled(
                        value,
                        context.t('biometric_reason'),
                      );
                    },
            ),
            if (access.failed)
              Text(
                context.t('biometric_failed'),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        );
      },
    );
  }
}
