import 'dart:io';
import 'dart:ui' as ui;

import 'package:eatme/core/models.dart';
import 'package:eatme/features/organize/planner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'application_test.dart' as support;
import 'meal_planning_review_test.dart' as planning;
import 'visual_reference_test.dart' as visual;

class SmartPlanApi extends planning.PlanningApi {
  SmartPlanApi() {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    saved = {
      'id': 'plan', 'version': 1, 'start_date': day,
      'data': {'meals': [
        {'date': day, 'slot': 'dinner', 'recipe_id': 'dinner', 'servings': 2, 'participants': [support.uid]},
      ], 'daily_limits': {}, 'preference_overrides': []},
    };
  }
  @override
  Future<Json> request(String method, String path, {Json? body, String? operationKey, bool allowCache = true}) async {
    if (path == '/plans' && body?['action'] == 'lock') {
      calls.add({'method': method, 'path': path, 'body': body});
      expect(body!['expected_version'], saved!['version']);
      final value = Map<String, dynamic>.from(saved!['data'] as Map);
      value['meals'] = [for (final raw in value['meals'] as List) {...Map<String, dynamic>.from(raw as Map), 'locked': body['locked']}];
      saved = {...saved!, 'version': (saved!['version'] as int) + 1, 'data': value};
      return saved!;
    }
    return super.request(method, path, body: body, operationKey: operationKey, allowCache: allowCache);
  }
}

void main() {
  setUpAll(visual.loadFonts);
  for (final dark in [false, true]) {
    for (final width in [320.0, 1024.0]) {
      testWidgets('persisted meal lock at $width ${dark ? 'dark' : 'light'}', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = SmartPlanApi();
        final boundary = GlobalKey();
        await tester.pumpWidget(support.harness(RepaintBoundary(key: boundary, child: const PlannerPage()), api, dark: dark));
        await tester.pumpAndSettle();
        final lock = find.byTooltip('Lock meal');
        await tester.ensureVisible(lock);
        await tester.pumpAndSettle();
        await tester.tap(lock);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Unlock meal'), findsOneWidget);
        expect((api.saved!['data']['meals'] as List).single['locked'], true);
        expect(api.calls.where((c) => c['body']?['action'] == 'lock').length, 1);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/screenshots/smart-plan-${width.toInt()}-${dark ? 'dark' : 'light'}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
