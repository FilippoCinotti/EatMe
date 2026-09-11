import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';

class Reminders {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool initialized = false;
  static Future<void> initialize() async {
    if (initialized) return;
    tzdata.initializeTimeZones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    initialized = true;
  }

  static Future<bool> requestPermission() async {
    await initialize();
    final android = await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final ios = await plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: false, sound: true);
    return android ?? ios ?? false;
  }

  static Future<void> clear() async {
    await initialize();
    await plugin.cancelAll();
  }

  static Future<void> schedule(
    Json prefs,
    List<Batch> inventory,
    List<Json> plans,
    String timezone,
    String language,
  ) async {
    await initialize();
    await plugin.cancelAll();
    if (prefs['enabled'] != true) return;
    final zone = tz.getLocation(timezone),
        now = tz.TZDateTime.now(tz.getLocation(timezone));
    final categories = List<String>.from(prefs['categories'] as List? ?? []);
    final cap = (prefs['daily_cap'] as int? ?? 3).clamp(1, 10);
    final start = prefs['quiet_start'] as int? ?? 22,
        end = prefs['quiet_end'] as int? ?? 8;
    final candidates = <(String, DateTime, String)>[];
    if (categories.contains('expiry')) {
      for (final batch in inventory) {
        if (batch.expiryDate != null)
          candidates.add((
            'expiry:${batch.id}:${batch.expiryDate}',
            batch.expiryDate!,
            'expiry',
          ));
      }
    }
    if (categories.contains('plans')) {
      for (final plan in plans) {
        for (final meal in plan['data']['meals'] as List) {
          candidates.add((
            'plan:${plan['id']}:${meal['date']}:${meal['slot']}',
            DateTime.parse(meal['date'] as String),
            'plans',
          ));
        }
      }
    }
    candidates.sort((a, b) => a.$2.compareTo(b.$2));
    final counts = <String, int>{};
    final seen = <String>{};
    for (final item in candidates) {
      if (!seen.add(item.$1)) continue;
      var hour = item.$3 == 'plans' ? 17 : 10;
      final quiet = start > end
          ? hour >= start || hour < end
          : hour >= start && hour < end;
      if (quiet) hour = end;
      final when = tz.TZDateTime(
        zone,
        item.$2.year,
        item.$2.month,
        item.$2.day,
        hour,
      );
      if (!when.isAfter(now) || when.difference(now).inDays > 7) continue;
      final day = '${when.year}-${when.month}-${when.day}';
      if ((counts[day] ?? 0) >= cap) continue;
      counts[day] = (counts[day] ?? 0) + 1;
      var identifier = 17;
      for (final code in item.$1.codeUnits) {
        identifier = (identifier * 31 + code) & 0x7fffffff;
      }
      await plugin.zonedSchedule(
        id: identifier,
        title: 'EatMe',
        body: language == 'it'
            ? 'Un momento per organizzare la tua cucina.'
            : 'A moment to check in with your kitchen.',
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'kitchen_reminders',
            'Kitchen reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: item.$3,
      );
    }
  }
}
