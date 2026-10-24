import 'dart:convert';

import 'api.dart';
import 'models.dart';

/// A deadline, rather than a tick count, remains correct across suspension.
class CookingTimer {
  const CookingTimer({
    required this.id,
    required this.name,
    required this.step,
    required this.durationSeconds,
    this.deadline,
    this.pausedSeconds,
  });
  final int id;
  final String name;
  final int step, durationSeconds;
  final DateTime? deadline;
  final int? pausedSeconds;
  bool get paused => deadline == null;
  int secondsAt(DateTime now) =>
      pausedSeconds ??
      (((deadline!.difference(now).inMilliseconds + 999) ~/ 1000).clamp(
        0,
        durationSeconds,
      ));
  CookingTimer pause(DateTime now) => CookingTimer(
    id: id,
    name: name,
    step: step,
    durationSeconds: durationSeconds,
    pausedSeconds: secondsAt(now),
  );
  CookingTimer resume(DateTime now) => CookingTimer(
    id: id,
    name: name,
    step: step,
    durationSeconds: durationSeconds,
    deadline: now.add(Duration(seconds: secondsAt(now))),
  );
  Json toJson() => {
    'id': id,
    'name': name,
    'step': step,
    'duration': durationSeconds,
    'deadline': deadline?.toUtc().toIso8601String(),
    'paused': pausedSeconds,
  };
  factory CookingTimer.fromJson(Json value) => CookingTimer(
    id: value['id'] as int,
    name: value['name'] as String,
    step: value['step'] as int,
    durationSeconds: value['duration'] as int,
    deadline: value['deadline'] == null
        ? null
        : DateTime.parse(value['deadline'] as String),
    pausedSeconds: value['paused'] as int?,
  );
}

class CookingTimerStore {
  CookingTimerStore(this.accountId, this.recipeId);
  final String accountId, recipeId;
  String get key => 'cooking-timers-v1:$accountId:$recipeId';
  Future<List<CookingTimer>> read() async {
    final raw = await EatMeApi.secure.read(key: key);
    if (raw == null) return [];
    final values = jsonDecode(raw) as List;
    return values
        .map((v) => CookingTimer.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  Future<void> write(List<CookingTimer> timers) => EatMeApi.secure.write(
    key: key,
    value: jsonEncode(timers.map((t) => t.toJson()).toList()),
  );
}
