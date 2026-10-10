import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:eatme/core/biometric_access.dart';

void main() {
  late Map<String, String> storage;
  late BiometricAccess access;
  late bool available, verified;
  late int prompts;

  setUp(() {
    storage = {};
    available = verified = true;
    prompts = 0;
    access = BiometricAccess(
      available: () async => available,
      authenticate: (_) async {
        prompts++;
        return verified;
      },
      read: (key) async => storage[key],
      write: (key, value) async {
        storage[key] = value;
      },
    );
  });
  tearDown(() => access.dispose());

  test(
    'first login does not prompt or enable biometrics automatically',
    () async {
      await access.bind('alice');
      expect(access.locked, isFalse);
      expect(access.enabled, isFalse);
      expect(prompts, 0);
    },
  );

  test('opt-in is verified, stored per account, and restored locked', () async {
    await access.bind('alice');
    expect(await access.setEnabled(true, 'reason'), isTrue);
    expect(storage[BiometricAccess.preferenceKey('alice')], 'true');
    await access.bind(null);
    await access.bind('alice');
    expect(access.locked, isTrue);
    expect(await access.unlock('reason'), isTrue);
    expect(access.locked, isFalse);
    access.lock();
    expect(access.locked, isTrue);
  });

  test('cancelled enrollment does not store consent', () async {
    await access.bind('alice');
    verified = false;
    expect(await access.setEnabled(true, 'reason'), isFalse);
    expect(storage, isEmpty);
  });

  test(
    'cancelled unlock and missing enrolled biometrics preserve the lock',
    () async {
      storage[BiometricAccess.preferenceKey('alice')] = 'true';
      available = verified = false;
      await access.bind('alice');
      expect(access.supported, isFalse);
      expect(await access.unlock('reason'), isFalse);
      expect(access.locked, isTrue);
      expect(await access.setEnabled(false, 'reason'), isFalse);
    },
  );

  test(
    'a new account never inherits another account unlock or preference',
    () async {
      storage[BiometricAccess.preferenceKey('alice')] = 'true';
      await access.bind('alice');
      await access.unlock('reason');
      await access.bind('bob');
      expect(access.enabled, isFalse);
      await access.bind('alice');
      expect(access.locked, isTrue);
    },
  );

  test('permission and lockout errors keep protected content locked', () async {
    access.dispose();
    access = BiometricAccess(
      available: () async => true,
      authenticate: (_) async => throw StateError('lockout'),
      read: (_) async => 'true',
      write: (_, _) async {},
    );
    await access.bind('alice');
    expect(await access.unlock('reason'), isFalse);
    expect(access.locked, isTrue);
    expect(access.failed, isTrue);
  });

  test('storage read errors fail closed', () async {
    access.dispose();
    access = BiometricAccess(
      available: () async => true,
      authenticate: (_) async => false,
      read: (_) async => throw StateError('keychain unavailable'),
      write: (_, _) async {},
    );
    await access.bind('alice');
    expect(access.checking, isFalse);
    expect(access.locked, isTrue);
  });

  test(
    'unsupported plugin does not lock users who have never opted in',
    () async {
      access.dispose();
      access = BiometricAccess(
        available: () async => throw StateError('unsupported device'),
        authenticate: (_) async => false,
        read: (_) async => null,
        write: (_, _) async {},
      );
      await access.bind('alice');
      expect(access.locked, isFalse);
      expect(access.supported, isFalse);
    },
  );

  test('delayed consent write does not enable a different account', () async {
    access.dispose();
    final write = Completer<void>(), started = Completer<void>();
    access = BiometricAccess(
      available: () async => true,
      authenticate: (_) async => true,
      read: (key) async => storage[key],
      write: (key, value) async {
        started.complete();
        await write.future;
        storage[key] = value;
      },
    );
    await access.bind('alice');
    final enable = access.setEnabled(true, 'reason');
    await started.future;
    await access.bind('bob');
    write.complete();
    expect(await enable, isFalse);
    expect(access.enabled, isFalse);
    expect(storage[BiometricAccess.preferenceKey('bob')], null);
  });

  test('backgrounding invalidates a pending authentication', () async {
    access.dispose();
    final result = Completer<bool>();
    access = BiometricAccess(
      available: () async => true,
      authenticate: (_) => result.future,
      read: (_) async => 'true',
      write: (_, _) async {},
    );
    await access.bind('alice');
    final unlock = access.unlock('reason');
    expect(await access.unlock('reason'), isFalse);
    access.lock();
    result.complete(true);
    expect(await unlock, isFalse);
    expect(access.locked, isTrue);
  });

  test(
    'old authentication cannot unlock an account selected meanwhile',
    () async {
      access.dispose();
      final result = Completer<bool>();
      access = BiometricAccess(
        available: () async => true,
        authenticate: (_) => result.future,
        read: (_) async => 'true',
        write: (_, _) async {},
      );
      await access.bind('alice');
      final unlock = access.unlock('reason');
      await access.bind('bob');
      result.complete(true);
      expect(await unlock, isFalse);
      expect(access.locked, isTrue);
    },
  );

  test(
    'disabling requires verification and takes effect on next launch',
    () async {
      await access.bind('alice');
      await access.setEnabled(true, 'reason');
      verified = false;
      expect(await access.setEnabled(false, 'reason'), isFalse);
      expect(access.enabled, isTrue);
      verified = true;
      expect(await access.setEnabled(false, 'reason'), isTrue);
      await access.bind(null);
      await access.bind('alice');
      expect(access.locked, isFalse);
    },
  );
}
