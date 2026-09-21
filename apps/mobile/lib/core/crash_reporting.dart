import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Production-only crash collection with no user, recipe, diet or health keys.
class CrashReporting {
  static const configured = bool.fromEnvironment(
    'FIREBASE_CRASHLYTICS_ENABLED',
  );
  static const forceInNonRelease = bool.fromEnvironment(
    'FIREBASE_CRASHLYTICS_FORCE_ENABLE',
  );
  static bool _ready = false;

  static Future<void> initialize() async {
    if (!configured) return;
    try {
      await Firebase.initializeApp();
      final enabled = kReleaseMode || forceInNonRelease;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        enabled,
      );
      if (!enabled) return;
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
        );
        return true;
      };
      _ready = true;
    } on Object {
      debugPrint('Crash reporting initialization failed.');
    }
  }

  static void recordUncaught(Object error, StackTrace stack) {
    if (!_ready) return;
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
    );
  }

  static Future<void> sendControlledValidationEvent() async {
    if (!_ready) return;
    await FirebaseCrashlytics.instance.recordError(
      StateError('Controlled EatMe+ Crashlytics validation event'),
      StackTrace.current,
      reason: 'release-validation',
      fatal: false,
    );
  }

  static void forceControlledValidationCrash() {
    if (_ready) FirebaseCrashlytics.instance.crash();
  }
}
