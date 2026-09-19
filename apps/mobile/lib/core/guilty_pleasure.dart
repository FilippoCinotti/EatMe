import 'models.dart';

class GuiltyPleasureContext {
  const GuiltyPleasureContext({required this.scope, required this.expiresAt});

  final String scope;
  final DateTime expiresAt;

  bool activeAt(DateTime now) =>
      (scope == 'meal' || scope == 'day') && now.isBefore(expiresAt);

  static GuiltyPleasureContext? restore(
    String? scope,
    String? expiresAt,
    DateTime now,
  ) {
    final parsed = expiresAt == null ? null : DateTime.tryParse(expiresAt);
    if (parsed == null || (scope != 'meal' && scope != 'day')) return null;
    final value = GuiltyPleasureContext(scope: scope!, expiresAt: parsed);
    return value.activeAt(now) ? value : null;
  }
}

DateTime guiltyPleasureExpiry(String scope, DateTime now) {
  if (scope == 'day') {
    return DateTime(now.year, now.month, now.day + 1);
  }
  return now.add(const Duration(hours: 4));
}

String mealSlotAt(DateTime value) {
  if (value.hour < 10) return 'breakfast';
  if (value.hour < 15) return 'lunch';
  if (value.hour < 18) return 'snack';
  return 'dinner';
}

String scheduledPreferenceMode(
  List<Json> plans,
  DateTime value, {
  String? slot,
}) {
  final day =
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  final targetSlot = slot ?? mealSlotAt(value);
  for (final plan in plans) {
    final data = Map<String, dynamic>.from(plan['data'] as Map? ?? {});
    for (final raw in data['preference_overrides'] as List? ?? const []) {
      final item = Map<String, dynamic>.from(raw as Map);
      if (item['mode'] != 'guilty_pleasure' || item['date'] != day) continue;
      if (item['scope'] == 'day' ||
          (item['scope'] == 'meal' && item['slot'] == targetSlot)) {
        return 'guilty_pleasure';
      }
    }
  }
  return 'for_you';
}
