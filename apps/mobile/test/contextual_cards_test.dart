import 'dart:io';
import 'dart:ui' as ui;

import 'package:eatme/core/models.dart';
import 'package:eatme/core/state.dart';
import 'package:eatme/features/chef_table/chef_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'application_test.dart' as support;
import 'visual_reference_test.dart' as visual;

class ContextualController extends visual.VisualController {
  @override
  AppState build() => super.build().copy(contextual: [
    for (final entry in [('for_you', 'Pasta for you'), ('use_soon', 'Tomato bowl'), ('quick', 'Quick salad')]) {
      'kind': entry.$1,
      'recommendation': {
        'recipe': {'id': entry.$1, 'title': {'en': entry.$2}, 'minutes': 15, 'servings': 2, 'ingredients': <Json>[], 'steps': {'en': ['Prepare and serve.']}},
        'available_count': 2, 'ingredient_count': 2, 'use_soon_food_ids': <String>[], 'warnings': <Json>[],
      },
      'reasons': [{'code': 'smart_reason_available'}, {'code': 'smart_reason_minutes', 'count': 15}],
    },
  ]);
}

void main() {
  setUpAll(visual.loadFonts);
  for (final dark in [false, true]) {
    for (final width in [320.0, 1024.0]) {
      testWidgets('contextual cards at $width ${dark ? 'dark' : 'light'}', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await tester.pumpWidget(support.harness(RepaintBoundary(key: boundary, child: const ChefTablePage()), visual.VisualApi(), dark: dark, controller: ContextualController.new));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Recommended for you'));
        await tester.pumpAndSettle();
        for (final title in ['Pasta for you', 'Tomato bowl', 'Quick salad']) {
          expect(find.text(title), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/screenshots/contextual-${width.toInt()}-${dark ? 'dark' : 'light'}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
