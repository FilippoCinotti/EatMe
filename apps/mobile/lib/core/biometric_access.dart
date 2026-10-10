import 'dart:async';

/// A local session lock. Credentials and biometric data never enter this class.
class BiometricAccess {
  BiometricAccess({
    required this.available,
    required this.authenticate,
    required this.read,
    required this.write,
  });

  final Future<bool> Function() available;
  final Future<bool> Function(String reason) authenticate;
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  bool checking = true, enabled = false, supported = false;
  bool locked = false, busy = false, failed = false;
  String? _user;
  int _binding = 0, _epoch = 0;

  static String preferenceKey(String user) => 'eatme.biometric.$user';

  Future<void> bind(String? user) async {
    if (_user == user && !checking) return;
    if (_user == user && _binding > 0) return;
    final binding = ++_binding;
    _epoch++;
    _user = user;
    checking = true;
    enabled = supported = locked = failed = false;
    _notify();
    if (user == null) {
      checking = false;
      _notify();
      return;
    }
    try {
      final optedIn = await read(preferenceKey(user)) == 'true';
      if (binding != _binding) return;
      enabled = optedIn;
      // Removing biometrics or denying permission must not bypass the lock.
      locked = optedIn;
      try {
        final canUse = await available();
        if (binding != _binding) return;
        supported = canUse;
      } catch (_) {
        if (binding != _binding) return;
        supported = false;
        failed = optedIn;
      }
    } catch (_) {
      if (binding != _binding) return;
      enabled = locked = failed = true;
    }
    if (binding == _binding) {
      checking = false;
      _notify();
    }
  }

  void lock() {
    _epoch++;
    if (enabled) locked = true;
    _notify();
  }

  Future<bool> unlock(String reason) async {
    if (busy || checking || !locked || _user == null) return false;
    return _verify(reason, () async {
      locked = false;
    });
  }

  Future<bool> setEnabled(bool value, String reason) async {
    if (busy || checking || locked || _user == null) return false;
    if (value && !supported) return false;
    final user = _user!, binding = _binding;
    return _verify(reason, () async {
      await write(preferenceKey(user), value.toString());
      if (binding == _binding) enabled = value;
    });
  }

  Future<bool> _verify(String reason, Future<void> Function() accept) async {
    final binding = _binding, epoch = _epoch;
    busy = true;
    failed = false;
    _notify();
    try {
      final verified = await authenticate(reason);
      if (!verified || binding != _binding || epoch != _epoch) return false;
      await accept();
      // A write may finish after backgrounding; preserve the lock in that case.
      if (binding == _binding && epoch != _epoch && enabled) locked = true;
      return binding == _binding && epoch == _epoch;
    } catch (_) {
      if (binding == _binding) failed = true;
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() => _changes.close();
}
