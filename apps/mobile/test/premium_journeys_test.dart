import 'package:eatme/features/healthy_food/healthy_food.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatme/core/models.dart';
import 'package:eatme/core/state.dart';
import 'package:eatme/design_system/widgets.dart';
import 'package:eatme/features/auth/login.dart';
import 'package:eatme/features/chef_table/chef_table.dart';
import 'package:eatme/features/fridge/fridge.dart';
import 'package:eatme/features/fridge/expiry.dart';
import 'package:eatme/features/profile/diet_health.dart';
import 'package:eatme/features/organize/settings.dart';
import 'package:eatme/features/organize/household.dart';
import 'package:eatme/features/profile/profile.dart';
import 'package:eatme/features/recipe/recipe.dart';
import 'application_test.dart' as support;
import 'visual_reference_test.dart' as visual;

/// Explicit test-only household state; no synthetic metrics enter production.
class JourneyController extends visual.VisualController {
  @override
  AppState build() => super.build().copy(
    profile: {
      ...super.build().profile,
      'household_size': 2,
      'settings': {
        'timezone': 'Europe/Rome',
        'diets': <Json>[],
        'allergies': <String>[],
        'intolerances': <String>[],
      },
    },
  );
}

class JourneyApi extends support.TestApi {
  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    if (path.endsWith('/compatibility')) {
      return {
        'food': {
          'ingredient_status': 'known',
          'allergens': ['milk'],
        },
        'assessment': {
          'status': 'blocked',
          'reasons': [
            {'code': 'contains_allergen'},
          ],
          'warnings': <Json>[],
          'notice': 'demo_data_not_a_safety_guarantee',
        },
        'nutrition': null,
        'evidence': <Json>[],
      };
    }
    if (path == '/preferences') {
      return {'version': 1, 'data': <String, dynamic>{}};
    }
    if (path == '/notifications') {
      return {
        'version': 1,
        'preferences': {
          'enabled': false,
          'categories': <String>[],
          'quiet_start': 22,
          'quiet_end': 7,
          'daily_cap': 3,
        },
        'items': <Json>[],
      };
    }
    if (path.startsWith('/recipes/')) {
      return {
        'id': '50773917-c954-51f2-a53b-1cf4b3c00690',
        'title': {'en': 'Zucchini & spinach pasta'},
        'minutes': 25,
        'servings': 2,
        'ingredients': [
          {'food_id': visual.zucchini.id, 'quantity': '250'},
        ],
        'steps': {
          'en': ['Prepare the ingredients.', 'Cook and serve.'],
        },
        'favorite': false,
      };
    }
    if (path == '/cooking/preview') {
      return {
        'ingredients': [
          {
            'food': {'name': visual.zucchini.name, 'unit': 'g'},
            'quantity': '250',
            'available': '250',
          },
        ],
        'shortages': <Json>[],
        'diet_rules_version': <String, dynamic>{},
        'nutrition': null,
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

Future<void> capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(visual.loadFonts);
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.6]) {
      for (final page in <(String, Widget)>[
        ('welcome', const LoginPage()),
        ('preferences', const PreferencesPage()),
        ('notifications', const NotificationsPage()),
        ('household', const HouseholdPage()),
        ('privacy', const PrivacyPage()),
        ('diet-health', const DietHealthPage()),
        (
          'recipe',
          const RecipePage(recipeId: '50773917-c954-51f2-a53b-1cf4b3c00690'),
        ),
        ('filters', const Scaffold(body: ChefFilters())),
        (
          'add-ingredient',
          const Scaffold(body: AddFoodSheet(initialFood: visual.zucchini)),
        ),
        (
          'add-methods',
          Scaffold(body: AddFoodMethodsPanel(onSelected: (_) {})),
        ),
      ]) {
        testWidgets('${page.$1} ${dark ? 'dark' : 'light'} scale $scale', (
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
              JourneyApi(),
              dark: dark,
              scale: scale,
              controller: JourneyController.new,
            ),
          );
          await tester.runAsync(
            () => precacheImage(
              const AssetImage(FoodImage.asset),
              tester.element(find.byType(MaterialApp)),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await capture(
              tester,
              boundary,
              '${page.$1}-${dark ? 'dark' : 'light'}',
            );
          }
          if (page.$1 == 'welcome') {
            final login = find.text('I already have an account');
            await tester.scrollUntilVisible(
              login,
              250,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.tap(login);
            await tester.pumpAndSettle();
            expect(find.byType(AutofillGroup), findsOneWidget);
            expect(find.text('Welcome back'), findsOneWidget);
            expect(tester.takeException(), isNull);
            if (scale == 1) {
              await capture(
                tester,
                boundary,
                'login-${dark ? 'dark' : 'light'}',
              );
              await tester.tap(find.text('New to EatMe? Create an account'));
              await tester.pumpAndSettle();
              expect(find.text('Create your account'), findsOneWidget);
              await capture(
                tester,
                boundary,
                'sign-up-${dark ? 'dark' : 'light'}',
              );
            }
          }
          // Exercise lower content instead of validating only the first viewport.
          if (find.byType(Scrollable).evaluate().isNotEmpty) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -550),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }
  testWidgets('allergen conflict stays visible on every assessment tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      support.harness(
        const Scaffold(body: FoodAssessment(food: visual.feta)),
        JourneyApi(),
        controller: JourneyController.new,
      ),
    );
    await tester.pumpAndSettle();
    for (final tab in ['Information', 'Nutrition', 'For you']) {
      final choice = find.text(tab);
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(
        find.text('Contains an allergen declared in your profile.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  for (final page in <Widget>[
    const ChefTablePage(),
    const FridgePage(),
    const HealthyFoodPage(),
    const ProfilePage(),
  ]) {
    testWidgets('${page.runtimeType} Italian compact phone with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        support.harness(
          page,
          JourneyApi(),
          language: 'it',
          scale: 1.6,
          controller: JourneyController.new,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
