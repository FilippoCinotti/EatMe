import 'package:eatme/core/cooking_timers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('deadlines remain correct after suspension and serialization', () {
    final start = DateTime.utc(2026, 10, 24, 12);
    final timer = CookingTimer(
      id: 1,
      name: 'Pasta',
      step: 2,
      durationSeconds: 120,
      deadline: start.add(const Duration(seconds: 120)),
    );
    final restored = CookingTimer.fromJson(timer.toJson());
    expect(restored.secondsAt(start.add(const Duration(seconds: 75))), 45);
    expect(restored.secondsAt(start.add(const Duration(hours: 2))), 0);
    final paused = restored.pause(start.add(const Duration(seconds: 75)));
    expect(paused.secondsAt(start.add(const Duration(hours: 2))), 45);
    expect(
      paused
          .resume(start.add(const Duration(hours: 2)))
          .secondsAt(start.add(const Duration(hours: 2, seconds: 15))),
      30,
    );
  });
  test('independent timers persist within account and recipe scope', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = CookingTimerStore('alice', 'pasta');
    final start = DateTime.utc(2026, 10, 24, 12);
    final first = CookingTimer(
      id: 1,
      name: 'Pasta',
      step: 1,
      durationSeconds: 60,
      deadline: start.add(const Duration(seconds: 60)),
    );
    final second = CookingTimer(
      id: 2,
      name: 'Sauce',
      step: 2,
      durationSeconds: 300,
      deadline: start.add(const Duration(seconds: 300)),
    );
    await store.write([first.pause(start), second]);
    final restored = await store.read();
    expect(restored[0].secondsAt(start.add(const Duration(seconds: 70))), 60);
    expect(restored[1].secondsAt(start.add(const Duration(seconds: 70))), 230);
    expect(await CookingTimerStore('bob', 'pasta').read(), isEmpty);
    expect(await CookingTimerStore('alice', 'salad').read(), isEmpty);
  });
}
