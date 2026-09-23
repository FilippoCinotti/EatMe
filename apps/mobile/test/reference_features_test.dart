import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'visual_reference_test.dart' as visual;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatme/core/models.dart';
import 'package:eatme/features/organize/wellbeing.dart';
import 'package:eatme/features/organize/scanning.dart';
import 'package:eatme/features/fridge/custom_food.dart';
import 'application_test.dart' as support;

class FeatureApi extends support.TestApi {
  int version = 1;
  bool completed = false;
  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    if (path == '/wellbeing') {
      calls.add({
        'method': method,
        'path': path,
        'body': body,
        'key': operationKey,
      });
      if (method == 'POST') {
        completed = body!['completed'] as bool;
        version++;
      }
      return {
        'version': version,
        'week_start': '2026-09-07',
        'goals': [
          {
            'id': 'waste_less',
            'target': 5,
            'completed_days': completed ? 1 : 0,
            'done_today': completed,
          },
        ],
      };
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
  setUpAll(visual.loadFonts);
  for (final dark in [false, true]) {
    for (final page in [
      ('wellbeing', const WellbeingPage()),
      ('custom-food', const CustomFoodPage()),
    ]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('${page.$1} mobile layout dark=$dark scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            support.harness(
              RepaintBoundary(key: boundary, child: page.$2),
              FeatureApi(),
              dark: dark,
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/screenshots/${page.$1}-${dark ? 'dark' : 'light'}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        });
      }
    }
  }

  testWidgets(
    'habit check-in and undo use the latest version and reload progress',
    (tester) async {
      final api = FeatureApi();
      await tester.pumpWidget(support.harness(const WellbeingPage(), api));
      await tester.pumpAndSettle();
      expect(find.text('0 of 5 days this week'), findsOneWidget);
      await tester.tap(find.text('Done today'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 5 days this week'), findsOneWidget);
      await tester.tap(find.text('Undo today’s check-in'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 5 days this week'), findsOneWidget);
      final updates = api.calls.where((c) => c['method'] == 'POST').toList();
      expect(updates.map((c) => c['body']['expected_version']).toList(), [
        1,
        2,
      ]);
      expect(updates.every((c) => c['key'] != null), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('custom food rejects an empty name before uploading or saving', (
    tester,
  ) async {
    final api = FeatureApi();
    await tester.pumpWidget(support.harness(const CustomFoodPage(), api));
    await tester.pumpAndSettle();
    final button = find.text('Add to Fridge');
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(api.calls.where((c) => c['method'] == 'POST'), isEmpty);
    expect(find.text('This field is required.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'scan review requires explicit confirmation and keeps remaining item edits',
    (tester) async {
      final api = FeatureApi();
      final job = <String, dynamic>{
        'id': 'scan',
        'result': {
          'items': [
            {
              'food_id': visual.tomato.id,
              'name': 'First item',
              'quantity': '100',
              'unit': 'g',
              'confidence': 0.8,
            },
            {
              'food_id': visual.tomato.id,
              'name': 'Second item',
              'quantity': '250',
              'unit': 'g',
              'confidence': 0.7,
            },
          ],
        },
      };
      await tester.pumpWidget(
        support.harness(DetectionReviewPage(job: job), api),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        isFalse,
      );
      expect(find.text('Tomatoes · Vegetables'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      expect(find.text('First item'), findsNothing);
      expect(find.text('250'), findsOneWidget);
      expect(api.calls.where((c) => c['method'] == 'POST'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
