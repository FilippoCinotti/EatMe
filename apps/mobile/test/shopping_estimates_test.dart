import 'dart:io';
import 'dart:ui' as ui;

import 'package:eatme/core/models.dart';
import 'package:eatme/core/state.dart';
import 'package:eatme/design_system/widgets.dart';
import 'package:eatme/features/organize/shopping.dart';
import 'package:eatme/features/organize/shopping_estimate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'application_test.dart' as support;
import 'visual_reference_test.dart' as visual;

class ShoppingController extends support.TestController {
  @override
  AppState build() => super.build().copy(
    foods: [
      visual.tomato,
      visual.zucchini,
      visual.feta,
      const Food(
        id: 'sauce',
        name: {'en': 'Barbecue sauce', 'it': 'Salsa barbecue'},
        unit: 'g',
        group: 'condiment',
      ),
    ],
  );
}

class ShoppingApi extends support.TestApi {
  List<Json> rows = [
    {
      'id': 'sauce',
      'food_id': 'sauce',
      'label': 'Barbecue sauce',
      'category': 'condiment',
      'quantity': '90',
      'unit': 'g',
      'version': 1,
      'checked': false,
    },
    {
      'id': 'tomato',
      'food_id': visual.tomato.id,
      'label': 'Tomatoes',
      'category': 'vegetable',
      'quantity': '300',
      'unit': 'g',
      'version': 1,
      'checked': false,
    },
    {
      'id': 'zucchini',
      'food_id': visual.zucchini.id,
      'label': 'Zucchini',
      'category': 'vegetable',
      'quantity': '250',
      'unit': 'g',
      'version': 1,
      'checked': false,
    },
    {
      'id': 'feta',
      'food_id': visual.feta.id,
      'label': 'Feta',
      'category': 'dairy',
      'quantity': '100',
      'unit': 'g',
      'version': 1,
      'checked': false,
    },
  ];
  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    if (path == '/shopping') {
      if (method == 'GET') return {'items': rows};
      calls.add({
        'method': method,
        'path': path,
        'body': body,
        'key': operationKey,
      });
      final i = rows.indexWhere((r) => r['id'] == body?['id']);
      if (body?['action'] == 'check') {
        rows[i] = {
          ...rows[i],
          'checked': body!['checked'],
          'version': (rows[i]['version'] as int) + 1,
        };
      }
      if (body?['action'] == 'edit') {
        rows[i] = {
          ...rows[i],
          'quantity': body!['quantity'],
          'version': (rows[i]['version'] as int) + 1,
        };
      }
      if (body?['action'] == 'delete') rows.removeAt(i);
      return {'updated': true};
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(visual.loadFonts);
  test(
    'quantity estimates convert mass, volume and pieces and round per line',
    () {
      expect(ShoppingEstimate.forQuantity('vegetable', 'g', '300')!.cents, 90);
      expect(ShoppingEstimate.forQuantity('vegetable', 'kg', '.3')!.cents, 90);
      expect(ShoppingEstimate.forQuantity('dairy', 'ml', '500')!.cents, 85);
      expect(ShoppingEstimate.forQuantity('dairy', 'l', '.5')!.cents, 85);
      expect(ShoppingEstimate.forQuantity('egg', 'pcs', '2')!.cents, 80);
      expect(ShoppingEstimate.forQuantity('condiment', 'g', '90')!.cents, 72);
      expect(ShoppingEstimate.forQuantity('grain', 'g', '1')!.cents, 0);
      for (final amount in ['-1', '0', 'NaN', 'Infinity', 'invalid']) {
        expect(ShoppingEstimate.forQuantity('vegetable', 'g', amount), isNull);
      }
      expect(ShoppingEstimate.forQuantity('unknown', 'g', '100'), isNull);
      expect(ShoppingEstimate.forQuantity('vegetable', 'pcs', '2'), isNull);
      expect(ShoppingEstimate.forQuantity('dairy', 'oz', '2'), isNull);
    },
  );

  testWidgets('missing category is a safe heading, not a retry error', (
    tester,
  ) async {
    final api = ShoppingApi();
    api.rows = [
      {...api.rows.first, 'category': 'future_category', 'food_id': null},
    ];
    await tester.pumpWidget(support.harness(const ShoppingPage(), api));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Other'));
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
    expect(find.text('Estimated partial total'), findsOneWidget);
    expect(find.text('€ 0.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'total includes all quantities and checking does not remove prices',
    (tester) async {
      final api = ShoppingApi();
      await tester.pumpWidget(
        support.harness(
          const ShoppingPage(),
          api,
          controller: ShoppingController.new,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('€ 3.27'), findsOneWidget);
      await tester.ensureVisible(find.text('Barbecue sauce'));
      final sauceImage = tester
          .widgetList<FoodImage>(find.byType(FoodImage))
          .firstWhere((image) => image.id == 'sauce');
      expect(sauceImage.width, double.infinity);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('shopping-total')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('€ 3.27'), findsOneWidget);
      expect(api.calls.last['body']['expected_version'], 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ingredient tiles are square and use three columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ShoppingApi();
    api.rows = [
      for (var index = 0; index < 3; index++)
        {
          ...api.rows[1],
          'id': 'vegetable-$index',
          'label': 'Vegetable $index',
        },
    ];
    await tester.pumpWidget(
      support.harness(
        const ShoppingPage(),
        api,
        controller: ShoppingController.new,
      ),
    );
    await tester.pumpAndSettle();
    final tiles = [
      for (var index = 0; index < 3; index++)
        find.byKey(ValueKey('shopping-item-vegetable-$index')),
    ];
    for (final tile in tiles) {
      expect(tester.getSize(tile).aspectRatio, closeTo(1, .001));
    }
    expect(tester.getTopLeft(tiles[0]).dy, tester.getTopLeft(tiles[1]).dy);
    expect(tester.getTopLeft(tiles[1]).dy, tester.getTopLeft(tiles[2]).dy);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing and deleting update the displayed grand total', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ShoppingApi();
    await tester.pumpWidget(
      support.harness(
        const ShoppingPage(),
        api,
        controller: ShoppingController.new,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    // The action remains busy while its edit dialog is open.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextFormField), '180');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('€ 3.99'), findsOneWidget);
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('€ 2.55'), findsOneWidget);
    expect(api.calls.last['body']['expected_version'], 2);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('shopping actual light/dark capture ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        support.harness(
          RepaintBoundary(key: boundary, child: const ShoppingPage()),
          ShoppingApi(),
          dark: dark,
          language: 'it',
          controller: ShoppingController.new,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Salse e condimenti'), findsOneWidget);
      expect(find.text('€ 3,27'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File(
          'build/screenshots/shopping-estimates-${dark ? 'dark' : 'light'}.png',
        );
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
    for (final language in ['en', 'it', 'es', 'fr', 'de', 'zh']) {
      testWidgets('small screen 200% text $language $dark', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          support.harness(
            const ShoppingPage(),
            ShoppingApi(),
            dark: dark,
            language: language,
            scale: 2,
            controller: ShoppingController.new,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 24; i++) {
          final position = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          if (position.pixels >= position.maxScrollExtent) break;
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -450),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
