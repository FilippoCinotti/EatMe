import 'package:eatme/core/models.dart';
import 'package:eatme/core/state.dart';
import 'package:eatme/design_system/widgets.dart';
import 'package:eatme/features/fridge/fridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'application_test.dart' as support;
import 'premium_journeys_test.dart' as journey;
import 'visual_reference_test.dart' as visual;

final sampleFood = Food(
  id: '00000000-0000-4000-8000-000000000111',
  name: {'it': 'Ciliegia', 'en': 'Cherry'},
  unit: 'g',
  group: 'fruit',
);
final sampleBatch = Batch(
  '00000000-0000-4000-8000-000000000112',
  sampleFood,
  '250',
  'fridge',
  DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 5)),
  'estimated',
  1,
  true,
);

class SheetController extends support.TestController {
  @override
  AppState build() => super.build().copy(inventory: [sampleBatch]);
}

class SheetApi extends support.TestApi {
  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    if (path == '/inventory/metadata' ||
        path == '/inventory/bulk-remove' ||
        (path.startsWith('/inventory/') && method == 'PATCH')) {
      calls.add({
        'method': method,
        'path': path,
        'body': body,
        'operation_key': operationKey,
      });
      return {'id': sampleBatch.id, 'version': 2};
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

Widget sheetHarness(
  SheetApi api, {
  bool dark = false,
  double scale = 1,
  Batch? batch,
}) => support.harness(
  Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () =>
              sheet(context, BatchSheet(batch: batch ?? sampleBatch)),
          child: const Text('Open item'),
        ),
      ),
    ),
  ),
  api,
  dark: dark,
  language: 'it',
  scale: scale,
  controller: SheetController.new,
);

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open item'));
  await tester.pumpAndSettle();
  expect(find.byType(BatchSheet), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(visual.loadFonts);
  for (final dark in [false, true]) {
    testWidgets('compact item renders in ${dark ? 'dark' : 'light'} mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(sheetHarness(SheetApi(), dark: dark));
      await tester.pumpAndSettle();
      await openSheet(tester);
      expect(find.text('Ciliegia'), findsOneWidget);
      expect(find.text('Modifica'), findsOneWidget);
      expect(find.text('Sposta'), findsOneWidget);
      expect(find.text('Altro'), findsOneWidget);
      expect(find.text('Segna come consumato'), findsOneWidget);
      expect(find.byKey(const ValueKey('batch-expiry-badge')), findsOneWidget);
      final photo = tester.widget<FoodImage>(find.byType(FoodImage).first);
      expect(photo.width, 104);
      expect(photo.height, 104);
      expect(tester.takeException(), isNull);
      await journey.captureFinder(
        tester,
        find.byKey(const ValueKey('batch-detail-capture')),
        'batch-detail-${dark ? 'dark' : 'light'}',
      );
    });
  }

  testWidgets('small screen and enlarged text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(sheetHarness(SheetApi(), scale: 1.6));
    await tester.pumpAndSettle();
    await openSheet(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(BatchSheet), findsOneWidget);
  });

  testWidgets('expiry badge and details use same state and days', (
    tester,
  ) async {
    final expired = Batch(
      sampleBatch.id,
      sampleFood,
      '250',
      'fridge',
      DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 8)),
      'use_by',
      1,
      false,
    );
    await tester.pumpWidget(sheetHarness(SheetApi(), batch: expired));
    await tester.pumpAndSettle();
    await openSheet(tester);
    expect(find.text('Scaduto da 8 giorni'), findsOneWidget);
    expect(batchExpiryStatus(expired), BatchExpiryStatus.expired);
    expect(tester.takeException(), isNull);
  });

  testWidgets('move commits a single optimistic-lock-protected request', (
    tester,
  ) async {
    final api = SheetApi();
    await tester.pumpWidget(sheetHarness(api));
    await tester.pumpAndSettle();
    await openSheet(tester);
    await tester.tap(find.byTooltip('Sposta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('batch-move-freezer')));
    await tester.pumpAndSettle();
    final moves = api.calls.where(
      (call) => call['path'] == '/inventory/${sampleBatch.id}',
    );
    expect(moves.length, 1);
    expect(moves.single['body']['action'], 'moved');
    expect(moves.single['body']['location'], 'freezer');
    expect(moves.single['body']['expected_version'], 1);
    expect(find.byType(BatchSheet), findsNothing);
  });

  testWidgets('delete requires confirmation and does not record waste', (
    tester,
  ) async {
    final api = SheetApi();
    await tester.pumpWidget(sheetHarness(api));
    await tester.pumpAndSettle();
    await openSheet(tester);
    await tester.tap(find.byTooltip('Altro'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('batch-delete')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(
      api.calls.where((call) => call['path'] == '/inventory/bulk-remove'),
      isEmpty,
    );
    await tester.tap(find.byTooltip('Altro'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('batch-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-batch-delete')));
    await tester.pumpAndSettle();
    final deletes = api.calls.where(
      (call) => call['path'] == '/inventory/bulk-remove',
    );
    expect(deletes.length, 1);
    expect(deletes.single['body']['items'], [
      {'id': sampleBatch.id, 'expected_version': 1},
    ]);
    expect(find.byType(BatchSheet), findsNothing);
  });

  testWidgets('edit persists quantity and expiry in one transaction', (
    tester,
  ) async {
    // This test checks the save contract; the separate small-screen test
    // covers scrolling/overflow. Use a tall viewport to expose the action.
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = SheetApi();
    await tester.pumpWidget(sheetHarness(api));
    await tester.pumpAndSettle();
    await openSheet(tester);
    await tester.tap(find.byTooltip('Modifica'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-batch-quantity')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('edit-batch-quantity')),
      '350',
    );
    await tester.ensureVisible(find.text('Salva'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    final saved = api.calls.where(
      (call) => call['path'] == '/inventory/metadata',
    );
    expect(saved.length, 1);
    expect(saved.single['body']['quantity'], '350');
    expect(saved.single['body']['expiry_kind'], 'estimated');
    expect(saved.single['body']['expected_version'], 1);
    expect(find.byType(BatchSheet), findsNothing);
  });

  testWidgets('consume commits exactly once and closes the sheet', (
    tester,
  ) async {
    final api = SheetApi();
    await tester.pumpWidget(sheetHarness(api));
    await tester.pumpAndSettle();
    await openSheet(tester);
    await tester.tap(find.text('Segna come consumato'));
    await tester.pumpAndSettle();
    final actions = api.calls.where(
      (call) => call['path'] == '/inventory/${sampleBatch.id}',
    );
    expect(actions.length, 1);
    expect(actions.single['body']['action'], 'consumed');
    expect(find.byType(BatchSheet), findsNothing);
  });
}