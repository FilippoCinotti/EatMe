import 'package:eatme/core/models.dart';
import 'package:eatme/core/state.dart';
import 'package:eatme/design_system/widgets.dart';
import 'package:eatme/features/fridge/fridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'application_test.dart' as support;
import 'premium_journeys_test.dart' as journey;

const food = Food(
  id: 'egg',
  name: {'en': 'Eggs', 'it': 'Uova'},
  unit: 'pcs',
  group: 'egg',
);
Batch batch(String id, DateTime? date, {String kind = 'use_by'}) =>
    Batch(id, food, '2', 'fridge', date, kind, 1, true);

class FridgeController extends support.TestController {
  @override
  AppState build() {
    final day = DateUtils.dateOnly(DateTime.now());
    return super.build().copy(
      inventory: [
        batch('expired', day.subtract(const Duration(days: 2))),
        batch('today', day),
        batch('tomorrow', day.add(const Duration(days: 1))),
        batch('unknown', null),
      ],
    );
  }
}

void main() {
  test(
    'expiry uses calendar days across timezones, month boundaries and leap days',
    () {
      expect(
        expiryDays(
          batch('a', DateTime(2026, 3, 30)),
          now: DateTime(2026, 3, 29, 23, 59),
        ),
        1,
      );
      expect(
        expiryDays(
          batch('b', DateTime(2024, 3, 1)),
          now: DateTime(2024, 2, 28),
        ),
        2,
      );
      expect(
        expiryDays(
          batch('c', DateTime(2025, 12, 31)),
          now: DateTime(2026, 1, 1),
        ),
        -1,
      );
      expect(expiryDays(batch('d', null)), isNull);
    },
  );
  for (final scale in [1.0, 1.6]) {
    testWidgets('compact fridge filters expired dates at scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        support.harness(
          RepaintBoundary(key: boundary, child: const FridgePage()),
          support.TestApi(),
          language: 'it',
          dark: true,
          scale: scale,
          controller: FridgeController.new,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Scaduti · 1'));
      await tester.tap(find.text('Scaduti · 1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(CompactBatchRow));
      expect(find.byType(CompactBatchRow), findsOneWidget);
      expect(find.text('Scaduto da 2 giorni'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await journey.capture(tester, boundary, 'compact-fridge-$scale');
    });
  }
}
