import 'package:eatme/features/chef_table/chef_table.dart';
import 'package:eatme/features/cooking/cooking.dart';
import 'package:eatme/features/organize/planner.dart';
import 'package:eatme/features/organize/shopping.dart';
import 'package:eatme/features/recipe/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'application_test.dart' as support;
import 'contextual_cards_test.dart' as contextual;
import 'editorial_recipes_test.dart' as editorial;
import 'premium_journeys_test.dart' as journey;
import 'smart_plan_test.dart' as planning;
import 'shopping_estimates_test.dart' as shopping;
import 'visual_reference_test.dart' as visual;

void main() {
  setUpAll(visual.loadFonts);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final dark in [false, true]) {
    for (final size in [const Size(390, 844), const Size(820, 1180), const Size(1366, 1024)]) {
      for (final name in ['chef', 'plan', 'recipe', 'cooking', 'confirmation', 'shopping']) {
        testWidgets('$name adaptive ${size.width} dark=$dark', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final Widget page = switch (name) {
            'chef' => const ChefTablePage(),
            'plan' => const PlannerPage(),
            'recipe' => const RecipePage(recipeId: editorial.recipeId),
            'cooking' => const CookingPage(recipeId: editorial.recipeId, servings: 2),
            'confirmation' => const ConfirmCookingPage(recipeId: editorial.recipeId, servings: 2),
            _ => const ShoppingPage(),
          };
          final api = name == 'plan' ? planning.SmartPlanApi()
              : name == 'shopping' ? shopping.ShoppingApi() : editorial.EditorialApi();
          final boundary = GlobalKey();
          await tester.pumpWidget(support.harness(
            RepaintBoundary(key: boundary, child: page), api, dark: dark,
            controller: contextual.ContextualController.new,
          ));
          await tester.pumpAndSettle();
          if (name == 'plan' && size.width >= 1100) {
            await tester.ensureVisible(find.byKey(const ValueKey('planner-week-calendar')));
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('planner-week-calendar')), findsOneWidget);
          }
          if (name == 'cooking' && size.width >= 850) {
            expect(find.byKey(const ValueKey('cooking-split-layout')), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await journey.capture(tester, boundary, 'smart-$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}');
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
