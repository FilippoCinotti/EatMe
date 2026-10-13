import 'package:eatme/core/models.dart';
import 'package:eatme/features/organize/planner.dart';
import 'package:eatme/features/organize/recipe_picker.dart';
import 'package:eatme/features/recipe/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'application_test.dart' as support;
import 'editorial_recipes_test.dart' as editorial;

const recipes = <Json>[
  {
    'id': 'dinner',
    'title': {'en': 'Tomato pasta'},
    'minutes': 20,
    'meal_types': ['lunch', 'dinner'],
    'ingredients': [
      {'food_id': 'tomato'},
    ],
  },
  {
    'id': 'breakfast',
    'title': {'en': 'Breakfast oats'},
    'minutes': 5,
    'meal_types': ['breakfast'],
    'ingredients': [],
  },
  {
    'id': 'snack',
    'title': {'en': 'Fruit bowl'},
    'minutes': 5,
    'meal_types': ['merenda'],
    'ingredients': [],
  },
];

class PlanningApi extends support.TestApi {
  Json? saved;
  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    if (path == '/recipes') return {'items': recipes};
    if (path == '/plans') {
      calls.add({'method': method, 'path': path, 'body': body});
      if (method == 'POST') {
        saved = {
          'id': 'plan',
          'version': 1,
          'start_date': body!['start_date'],
          'data': {'meals': body['meals'], 'preference_overrides': []},
        };
        return saved!;
      }
      return {
        'items': [if (saved != null) saved],
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

class ReviewApi extends editorial.EditorialApi {
  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    final value = await super.request(
      method,
      path,
      body: body,
      operationKey: operationKey,
      allowCache: allowCache,
    );
    if (path.startsWith('/recipes/')) {
      value['compatibility'] = {
        'status': 'no_known_conflict',
        'reasons': <Json>[],
        'warnings': [
          {'code': 'medical_profile_requires_review', 'profile': 'diabetes'},
          {'code': 'medical_profile_requires_review', 'profile': 'renal'},
        ],
      };
    }
    return value;
  }
}

void main() {
  test('each meal prioritizes its tagged recipes and retains alternatives', () {
    for (final entry in {
      'breakfast': 'breakfast',
      'lunch': 'dinner',
      'snack': 'snack',
      'dinner': 'dinner',
    }.entries) {
      final items = recipesForMeal(recipes, [], entry.key, '', 'en');
      expect(items.first['id'], entry.value);
      expect(items.length, 3);
    }
  });

  test('search matches localized ingredient names and recipe titles', () {
    const foods = [
      Food(
        id: 'tomato',
        name: {'en': 'Tomato', 'it': 'Pomodoro'},
        unit: 'g',
        group: 'vegetable',
      ),
    ];
    expect(
      recipesForMeal(
        recipes,
        foods,
        'breakfast',
        ' POMODORO ',
        'it',
      ).single['id'],
      'dinner',
    );
    expect(
      recipesForMeal(recipes, foods, 'dinner', 'oats', 'en').single['id'],
      'breakfast',
    );
    expect(recipesForMeal(recipes, foods, 'lunch', 'absent', 'en'), isEmpty);
  });

  testWidgets(
    'planning requires meal selection and saves selected day and slot',
    (tester) async {
      final api = PlanningApi();
      await tester.pumpWidget(
        support.harness(const PlannerPage(initialRecipeId: 'dinner'), api),
      );
      await tester.pumpAndSettle();
      final confirm = find.byKey(const ValueKey('schedule-confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(api.saved, isNull);
      await tester.tap(find.byKey(const ValueKey('schedule-day')));
      await tester.pumpAndSettle();
      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      final tomorrow = DateUtils.dateOnly(
        DateTime.now(),
      ).add(const Duration(days: 1));
      picker.onDateChanged(tomorrow);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-lunch')));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(api.saved, isNull);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final meal = (api.saved!['data']['meals'] as List).single as Map;
      expect(meal['slot'], 'lunch');
      expect(meal['date'], tomorrow.toIso8601String().substring(0, 10));
      expect(meal['recipe_id'], 'dinner');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dismissing schedule does not create a meal', (tester) async {
    final api = PlanningApi();
    await tester.pumpWidget(
      support.harness(const PlannerPage(initialRecipeId: 'dinner'), api),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(MealScheduleSheet))).pop();
    await tester.pumpAndSettle();
    expect(api.saved, isNull);
  });

  testWidgets('review card and details identify all triggering medical tags', (
    tester,
  ) async {
    await tester.pumpWidget(
      support.harness(
        const RecipePage(recipeId: editorial.recipeId),
        ReviewApi(),
      ),
    );
    await tester.pumpAndSettle();
    final notice = find.textContaining('Selected medical tag:');
    await tester.ensureVisible(notice);
    expect(find.textContaining('Diabetes'), findsOneWidget);
    expect(find.textContaining('Kidney / renal restriction'), findsOneWidget);
    await tester.tap(notice);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('not an identified ingredient conflict'),
      findsNWidgets(2),
    );
    expect(tester.takeException(), isNull);
  });
}
