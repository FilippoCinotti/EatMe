import 'package:eatme/core/models.dart';
import 'package:eatme/core/state.dart';
import 'package:eatme/design_system/widgets.dart';
import 'package:eatme/features/fridge/fridge.dart';
import 'package:eatme/features/fridge/inventory_grid.dart';
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

class BulkFridgeApi extends support.TestApi {
  final removals = <Json>[];
  final actions = <Json>[];
  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    if (path == '/inventory/bulk-remove') {
      removals.add(body!);
      return {
        'count': (body['items'] as List).length,
        'removed': (body['items'] as List)
            .map((item) => (item as Map)['id'])
            .toList(),
      };
    }
    if (path == '/inventory/bulk-action') {
      actions.add(body!);
      return {'count': (body['items'] as List).length};
    }
    return super.request(
      method,
      path,
      body: body,
      operationKey: operationKey,
      allowCache: allowCache,
    );
  }
}

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
  test('expiry uses calendar days across timezones, month boundaries and leap days', () {
    expect(
      expiryDays(
        batch('a', DateTime(2026, 3, 30)),
        now: DateTime(2026, 3, 29, 23, 59),
      ),
      1,
    );
    expect(
      expiryDays(batch('b', DateTime(2024, 3, 1)), now: DateTime(2024, 2, 28)),
      2,
    );
    expect(
      expiryDays(batch('c', DateTime(2025, 12, 31)), now: DateTime(2026, 1, 1)),
      -1,
    );
    expect(expiryDays(batch('d', null)), isNull);
  });

  test('catalog taxonomy has one stable visual category per food', () {
    expect(inventoryCategory(food), 'dairy');
    expect(
      inventoryCategory(
        const Food(id: 'rice', name: {'en': 'Rice'}, unit: 'g', group: 'grain'),
      ),
      'grain',
    );
    expect(
      inventoryCategory(
        const Food(
          id: 'unmapped',
          name: {'en': 'Unmapped'},
          unit: 'g',
          group: 'unsupported_new_group',
        ),
      ),
      'other',
    );
    expect(inventoryColumns(350, 1), 2);
    expect(inventoryColumns(750, 1), inInclusiveRange(3, 4));
    expect(inventoryColumns(1100, 1), 5);
    expect(inventoryColumns(350, 1.6), 1);
  });

  testWidgets('multi-select uses batch ids and confirms bulk removal', (
    tester,
  ) async {
    final api = BulkFridgeApi();
    await tester.pumpWidget(
      support.harness(
        const FridgePage(),
        api,
        language: 'it',
        controller: FridgeController.new,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory-select-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory-select-all')));
    await tester.pumpAndSettle();
    expect(find.text('4 selezionati'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('inventory-bulk-remove')),
    );
    await tester.tap(find.byKey(const ValueKey('inventory-bulk-remove')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Eliminare 4 elementi'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(api.removals, isEmpty);

    await tester.tap(find.byKey(const ValueKey('inventory-bulk-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina selezionati').last);
    await tester.pumpAndSettle();
    expect(api.removals.length, 1);
    final records = api.removals.single['items'] as List;
    expect(records.length, 4);
    expect(records.map((x) => x['id']).toSet(), {
      'expired',
      'today',
      'tomorrow',
      'unknown',
    });
    expect(records.every((x) => x['expected_version'] == 1), isTrue);
    expect(find.byKey(const ValueKey('inventory-select-all')), findsNothing);
  });

  testWidgets('bulk move uses one request with versions and destination', (
    tester,
  ) async {
    final api = BulkFridgeApi();
    await tester.pumpWidget(
      support.harness(
        const FridgePage(),
        api,
        language: 'it',
        controller: FridgeController.new,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory-select-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory-select-all')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('inventory-bulk-move')),
    );
    await tester.tap(find.byKey(const ValueKey('inventory-bulk-move')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory-bulk-move-freezer')));
    await tester.pumpAndSettle();
    expect(api.actions.length, 1);
    expect(api.actions.single['action'], 'moved');
    expect(api.actions.single['location'], 'freezer');
    expect((api.actions.single['items'] as List).length, 4);
  });

  for (final scale in [1.0, 1.6]) {
    testWidgets('grouped fridge filters expiry at scale $scale', (
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
      expect(find.text('Latticini e uova'), findsOneWidget);
      await tester.tap(find.text('Scaduti'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('inventory-batch-expired')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('inventory-batch-unknown')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await journey.capture(tester, boundary, 'compact-fridge-$scale');
    });
  }

  for (final dark in [false, true]) {
    testWidgets('iPad grid renders on resize in ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        support.harness(
          RepaintBoundary(key: boundary, child: const FridgePage()),
          BulkFridgeApi(),
          language: 'it',
          dark: dark,
          controller: FridgeController.new,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Latticini e uova'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await journey.capture(
        tester,
        boundary,
        'fridge-ipad-${dark ? 'dark' : 'light'}',
      );
    });
  }
}
