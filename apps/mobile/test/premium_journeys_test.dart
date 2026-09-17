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
      'version': 4,
      'household_size': 2,
      'settings': {
        'timezone': 'Europe/Rome',
        'diets': <Json>[
          {'diet_id': 'diet-med', 'strictness': 'standard'},
          {'diet_id': 'diet-rad', 'strictness': 'strict'},
        ],
        'primary_diet': 'diet-rad',
        'allergies': <String>['milk'],
        'intolerances': <String>['lactose'],
        'never_suggest': <String>[visual.feta.id],
        'unknown_ingredient_policy': 'review',
      },
    },
    allergens: const ['gluten', 'eggs', 'peanut', 'milk', 'nuts'],
    diets: const [
      Diet(
        'diet-med',
        'mediterranean',
        {'en': 'Mediterranean'},
        true,
        'PUBLISHED',
        false,
      ),
      Diet(
        'diet-vegetarian',
        'vegetarian',
        {'en': 'Vegetarian'},
        true,
        'PUBLISHED',
        false,
      ),
      Diet('diet-vegan', 'vegan', {'en': 'Vegan'}, true, 'PUBLISHED', false),
      Diet(
        'diet-pescatarian',
        'pescatarian',
        {'en': 'Pescatarian'},
        true,
        'PUBLISHED',
        false,
      ),
      Diet(
        'diet-protein',
        'high-protein',
        {'en': 'High protein'},
        true,
        'PUBLISHED',
        false,
      ),
      Diet(
        'diet-gluten',
        'gluten-free',
        {'en': 'Gluten free'},
        true,
        'PUBLISHED',
        false,
      ),
      Diet('diet-celiac', 'celiac', {'en': 'Celiac'}, true, 'PUBLISHED', true),
      Diet('diet-rad', 'rad', {'en': 'RAD'}, true, 'PUBLISHED', true),
    ],
  );

  @override
  Future<void> hydrate() async {}
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

Future<void> captureFinder(
  WidgetTester tester,
  Finder boundary,
  String name,
) async {
  await tester.runAsync(() async {
    final image =
        await (tester.renderObject(boundary) as RenderRepaintBoundary)
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
            await tester.pumpAndSettle();
            if (tester.getCenter(login).dy > 800) {
              await tester.drag(
                find.byType(Scrollable).first,
                const Offset(0, -120),
              );
              await tester.pumpAndSettle();
            }
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
              expect(find.text('Create your account'), findsAtLeastNWidgets(1));
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

  testWidgets('Diet & Health directly saves profiles and unknown policy', (
    tester,
  ) async {
    final api = JourneyApi();
    await tester.pumpWidget(
      support.harness(
        const DietHealthPage(),
        api,
        controller: JourneyController.new,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('diet-section-eating')));
    await tester.pumpAndSettle();
    final vegan = find.byKey(const ValueKey('diet-vegan'));
    await tester.scrollUntilVisible(
      vegan,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    tester
        .widget<InkWell>(
          find.descendant(of: vegan, matching: find.byType(InkWell)),
        )
        .onTap!();
    await tester.pump();
    final save = find.byKey(const ValueKey('save-diet-health'));
    await tester.scrollUntilVisible(
      save,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    final unknownSection = find.byKey(
      const ValueKey('diet-section-unknown'),
    );
    tester.widget<SettingRow>(unknownSection).onTap!();
    await tester.pumpAndSettle();
    final strictUnknown = find.byKey(const ValueKey('unknown-strict'));
    tester
        .widget<InkWell>(
          find.descendant(of: strictUnknown, matching: find.byType(InkWell)),
        )
        .onTap!();
    await tester.pump();
    await tester
        .widget<AsyncAction>(
          find.byKey(const ValueKey('save-diet-health')),
        )
        .action();
    await tester.pumpAndSettle();
    final calls = api.calls
        .where(
          (value) => value['method'] == 'PUT' && value['path'] == '/profile',
        )
        .toList();
    final eatingBody = Map<String, dynamic>.from(calls.first['body'] as Map);
    final unknownBody = Map<String, dynamic>.from(calls.last['body'] as Map);
    expect(
      (eatingBody['diets'] as List).any(
        (value) => value['diet_id'] == 'diet-vegan',
      ),
      isTrue,
    );
    expect(unknownBody['unknown_ingredient_policy'], 'strict');
    expect(unknownBody['never_suggest'], [visual.feta.id]);
    expect(find.text('Diet & Health updated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('Diet & Health review states ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        support.harness(
          RepaintBoundary(key: boundary, child: const DietHealthPage()),
          JourneyApi(),
          dark: dark,
          controller: JourneyController.new,
        ),
      );
      await tester.pumpAndSettle();
      await capture(
        tester,
        boundary,
        'diet-health-hub-${dark ? 'dark' : 'light'}',
      );
      for (final target in <(Key, Key, String)>[
        (
          const ValueKey('diet-section-medical'),
          const ValueKey('diet-rad'),
          'diet-health-medical',
        ),
        (
          const ValueKey('diet-section-allergies'),
          const ValueKey('allergen-milk'),
          'diet-health-allergies',
        ),
        (
          const ValueKey('diet-section-exclusions'),
          ValueKey('exclude-${visual.feta.id}'),
          'diet-health-exclusions',
        ),
        (
          const ValueKey('diet-section-unknown'),
          const ValueKey('unknown-review'),
          'diet-health-unknown-policy',
        ),
      ]) {
        final section = find.byKey(target.$1);
        await tester.scrollUntilVisible(
          section,
          260,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(section);
        await tester.pumpAndSettle();
        final finder = find.byKey(target.$2);
        await tester.scrollUntilVisible(
          finder,
          360,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await captureFinder(
          tester,
          find.byKey(const ValueKey('diet-health-editor-boundary')),
          '${target.$3}-${dark ? 'dark' : 'light'}',
        );
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  }

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
