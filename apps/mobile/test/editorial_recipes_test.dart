import 'package:eatme/core/models.dart';
import 'package:eatme/main.dart';
import 'package:eatme/design_system/widgets.dart';
import 'package:eatme/features/chef_table/chef_table.dart';
import 'package:eatme/features/cooking/cooking.dart';
import 'package:eatme/features/recipe/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'application_test.dart' as support;
import 'premium_journeys_test.dart' as journey;
import 'visual_reference_test.dart' as visual;

const recipeId = 'b6e34b78-ba48-558f-bcc8-43cf54c9131c';

class EditorialApi extends journey.JourneyApi {
  EditorialApi({this.emptySteps = false});
  final bool emptySteps;

  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    if (path == '/cooking/preview') {
      return {
        'ingredients': [
          {
            'food_id': 'eggs',
            'food': {
              'name': {'en': 'Eggs', 'it': 'Uova'},
              'unit': 'pcs',
            },
            'quantity': '2',
            'available': '4',
          },
          {
            'food_id': 'oil',
            'food': {
              'name': {'en': 'Olive oil', 'it': 'Olio di oliva'},
              'unit': 'ml',
            },
            'quantity': '5',
            'available': '50',
          },
          {
            'food_id': 'pepper',
            'food': {
              'name': {'en': 'Black pepper', 'it': 'Pepe nero'},
              'unit': 'g',
            },
            'quantity': '1',
            'available': '0',
          },
        ],
        'shortages': [
          {'food_id': 'pepper', 'quantity': '1'},
        ],
        'allocations': <Json>[],
        'profile_version': 1,
        'diet_rules_version': <String, dynamic>{},
        'nutrition': null,
      };
    }
    if (path.startsWith('/recipes/')) {
      return {
        'id': recipeId,
        'title': {'en': 'Marshmallow eggs', 'it': 'Uova marshmallow'},
        'description': {
          'en':
              'Soft whipped whites envelop a tender yolk. A simple brunch recipe, cooked gently in a ring and finished with freshly ground pepper.',
          'it':
              'Albumi soffici che avvolgono un tuorlo morbido. Una ricetta semplice per il brunch, cotta delicatamente in un anello e completata con pepe appena macinato.',
        },
        'minutes': 10,
        'servings': 2,
        'ingredients': [
          {'food_id': 'eggs', 'quantity': '2'},
          {'food_id': 'oil', 'quantity': '5'},
          {'food_id': 'pepper', 'quantity': '1'},
        ],
        'steps': {
          'en': emptySteps
              ? []
              : [
                  {
                    'text': 'Separate the eggs and whisk the whites.',
                    'timer_seconds': 300,
                  },
                  {'text': 'Cook gently, season and serve.'},
                ],
        },
        'compatibility': {
          'status': 'compatible',
          'reasons': <Json>[],
          'warnings': <Json>[],
        },
        'favorite': false,
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(visual.loadFonts);

  for (final (width, scale) in [(390.0, 1.0), (320.0, 1.6)]) {
    testWidgets(
      'editorial discovery and recipe remain usable at $width/$scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final (name, page) in <(String, Widget)>[
          ('chef', const AppShell(path: '/chef', child: ChefTablePage())),
          ('recipe', const RecipePage(recipeId: recipeId)),
        ]) {
          await tester.pumpWidget(const SizedBox.shrink());
          final boundary = GlobalKey();
          await tester.pumpWidget(
            support.harness(
              RepaintBoundary(key: boundary, child: page),
              EditorialApi(),
              dark: true,
              language: 'it',
              scale: scale,
              controller: visual.VisualController.new,
            ),
          );
          await tester.runAsync(() async {
            final context = tester.element(find.byType(MaterialApp));
            await precacheImage(const AssetImage(FoodImage.asset), context);
            if (context.mounted) {
              await precacheImage(
                AssetImage(FoodImage.recipeAssets[recipeId]!),
                context,
              );
            }
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await journey.capture(tester, boundary, 'editorial-$name-top-it');
          }
          if (name == 'recipe') {
            final cook = find.widgetWithText(FilledButton, 'Cucina ora');
            expect(cook.hitTestable(), findsOneWidget);
            final before = tester.getRect(cook);
            await tester.scrollUntilVisible(
              find.byType(EatMeTabStrip),
              250,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.ensureVisible(find.byType(EatMeTabStrip));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Ingredienti'));
            await tester.pumpAndSettle();
            expect(tester.getRect(cook), before);
            expect(cook.hitTestable(), findsOneWidget);
            final tab = tester.widget<Text>(find.text('Panoramica'));
            expect(tab.maxLines, 1);
          } else {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -1400),
            );
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await journey.capture(tester, boundary, 'editorial-$name-lower-it');
          }
        }
      },
    );
  }

  testWidgets(
    'custom cooking timer survives step navigation and finish requires confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        support.harness(
          RepaintBoundary(
            key: boundary,
            child: const CookingPage(recipeId: recipeId, servings: 2),
          ),
          EditorialApi(),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();
      await journey.capture(tester, boundary, 'editorial-cooking-step');
      await tester.ensureVisible(find.text('Set timer duration'));
      await tester.tap(find.text('Set timer duration'));
      // AsyncAction remains busy behind the open dialog until it is answered.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start 2-minute timer'));
      await tester.tap(find.text('Start 2-minute timer'));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.textContaining(RegExp(r'Cancel · (02:00|01:[0-5][0-9])')),
        findsOneWidget,
      );
      await tester.tap(find.text('Next step'));
      await tester.pump();
      expect(find.text('Cook gently, season and serve.'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'Cancel · (02:00|01:[0-5][0-9])')),
        findsOneWidget,
      );
      await journey.capture(tester, boundary, 'editorial-cooking-timer');
      await tester.tap(find.text('I’m done'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmCookingPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await journey.capture(tester, boundary, 'editorial-cooking-confirm');
    },
  );

  testWidgets(
    'untimed step has no invented timer and ingredients use preview quantities',
    (tester) async {
      await tester.pumpWidget(
        support.harness(
          const CookingPage(recipeId: recipeId, servings: 2),
          EditorialApi(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingredients'));
      await tester.pumpAndSettle();
      expect(find.text('Eggs'), findsOneWidget);
      expect(find.text('2 pcs'), findsOneWidget);
      Navigator.of(tester.element(find.text('Eggs'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next step'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Start 5-minute timer'), findsNothing);
      expect(find.text('Set timer duration'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recipe without instructions shows an empty state without indexing a step',
    (tester) async {
      await tester.pumpWidget(
        support.harness(
          const CookingPage(recipeId: recipeId, servings: 2),
          EditorialApi(emptySteps: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Preparation steps are not available for this recipe.'),
        findsOneWidget,
      );
      expect(find.byType(RecipeActionBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
