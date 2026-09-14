import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eatme/core/api.dart';
import 'package:eatme/core/models.dart';
import 'package:eatme/core/state.dart';
import 'package:eatme/design_system/theme.dart';
import 'package:eatme/features/organize/photo_acquisition.dart';
import 'package:eatme/features/organize/recipe_library.dart';
import 'package:eatme/features/organize/social_recipe_import.dart';
import 'package:eatme/features/organize/settings.dart';
import 'package:eatme/features/recipe/recipe.dart';
import 'application_test.dart' as support;
import 'visual_reference_test.dart' as visual;

const chickpea = Food(
  id: '1b55ff44-73b0-528f-90b7-3c10fb398451',
  name: {'en': 'Chickpeas', 'it': 'Ceci'},
  unit: 'g',
  group: 'pulse',
);

Json draft({bool partial = false, bool conflict = false}) => {
  'title': conflict ? 'Creamy feta pasta' : 'Tomato bowl',
  'servings': 2,
  'minutes': 25,
  'steps': ['Prepare the ingredients.', 'Cook and serve.'],
  'ingredient_rows': [
    {
      'source_text': '200 g tomatoes',
      'food_id': visual.tomato.id,
      'quantity': '200',
      'unit': 'g',
      'mapping_status': 'matched',
      'confirmed': true,
    },
    if (conflict)
      {
        'source_text': '100 g feta',
        'food_id': visual.feta.id,
        'quantity': '100',
        'unit': 'g',
        'mapping_status': 'matched',
        'confirmed': true,
      },
    if (partial)
      {
        'source_text': 'a handful of mystery herb',
        'food_id': null,
        'quantity': null,
        'unit': null,
        'mapping_status': 'unknown',
        'confirmed': false,
      },
  ],
  'source_url': 'https://www.youtube.com/watch?v=public',
  'source_platform': 'youtube',
  'source_title': 'Public source recipe',
  'source_creator': 'Public creator',
  'source_thumbnail_url': '',
  'imported_at': '2026-09-14T12:00:00+00:00',
  'provenance': 'public-social-link',
  'missing_fields': partial ? ['servings'] : <String>[],
};

Json fitResult({bool adapted = false}) => {
  'compatibility': {
    'status': 'fit',
    'reasons': <Json>[],
    'warnings': <Json>[],
    'classified_reasons': <Json>[],
    'unmapped_ingredients': <Json>[],
  },
  'inventory': {
    'available_count': adapted ? 2 : 1,
    'total_count': adapted ? 2 : 1,
    'items': <Json>[],
    'missing_food_ids': <String>[],
    'use_soon_food_ids': [visual.tomato.id],
    'unresolved_count': 0,
  },
  'substitutions': <Json>[],
  'active_diets': [
    {
      'id': 'diet',
      'slug': 'vegan',
      'name': {'en': 'Vegan', 'it': 'Vegana'},
      'medical': false,
    },
  ],
};

Json conflictResult({bool candidate = true}) => {
  'compatibility': {
    'status': 'conflict',
    'reasons': [
      {'code': 'diet_exclusion', 'food_id': visual.feta.id, 'diet_id': 'diet'},
    ],
    'warnings': <Json>[],
    'classified_reasons': [
      {
        'code': 'diet_exclusion',
        'food_id': visual.feta.id,
        'classification': 'diet',
      },
    ],
    'unmapped_ingredients': <Json>[],
  },
  'inventory': {
    'available_count': 1,
    'total_count': 2,
    'items': <Json>[],
    'missing_food_ids': [visual.feta.id],
    'use_soon_food_ids': [visual.tomato.id],
    'unresolved_count': 0,
  },
  'substitutions': [
    {
      'food_id': visual.feta.id,
      'candidates': candidate
          ? [
              {
                'food': {
                  'id': chickpea.id,
                  'slug': 'chickpea',
                  'name': chickpea.name,
                  'unit': 'g',
                  'group': 'pulse',
                },
                'role': 'salad_component',
                'review': 'culinary-review-2026-09',
                'at_home': true,
                'available': '300',
              },
            ]
          : <Json>[],
    },
  ],
  'active_diets': <Json>[],
};

class SocialController extends visual.VisualController {
  @override
  AppState build() =>
      super.build().copy(foods: [...super.build().foods, chickpea]);
}

class SocialApi extends support.TestApi {
  Completer<Json>? importGate, reviewGate;
  String? importError;
  Json importDraft = draft();
  Json reviewResult = fitResult();
  bool saved = false;

  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    calls.add({'method': method, 'path': path, 'body': body});
    if (path == '/recipes/import-url') {
      if (importError != null) throw ApiFailure(importError!);
      return importGate == null ? importDraft : importGate!.future;
    }
    if (path == '/recipes/import-review') {
      return reviewGate == null ? reviewResult : reviewGate!.future;
    }
    if (path == '/recipes' && method == 'POST' && body?['action'] == 'save') {
      saved = true;
      return {'id': '50773917-c954-51f2-a53b-1cf4b3c00690'};
    }
    if (path == '/recipes' && method == 'GET') {
      return {
        'items': [
          {
            'id': '50773917-c954-51f2-a53b-1cf4b3c00690',
            'title': {
              'en': 'Reviewed social recipe',
              'it': 'Ricetta social rivista',
            },
            'minutes': 25,
            'servings': 2,
            'favorite': false,
            'private': true,
            'source_platform': 'youtube',
          },
        ],
      };
    }
    if (path.startsWith('/recipes/')) {
      return {
        'id': '50773917-c954-51f2-a53b-1cf4b3c00690',
        'title': {
          'en': 'Reviewed social recipe',
          'it': 'Ricetta social rivista',
        },
        'minutes': 25,
        'servings': 2,
        'ingredients': [
          {'food_id': visual.tomato.id, 'quantity': '200'},
        ],
        'steps': {
          'en': ['Prepare the ingredients.', 'Cook and serve.'],
          'it': ['Prepara gli ingredienti.', 'Cuoci e servi.'],
        },
        'favorite': false,
        'private': true,
        'source_url': 'https://www.youtube.com/watch?v=public',
        'source_platform': 'youtube',
        'source_creator': 'Public creator',
        'adaptations': [
          {'from_food_id': visual.feta.id, 'to_food_id': chickpea.id},
        ],
        'compatibility': {'reasons': <Json>[], 'warnings': <Json>[]},
        'diet_rules_version': <String, dynamic>{},
        'nutrition': null,
      };
    }
    if (path == '/cooking/preview') {
      return {
        'ingredients': [
          {
            'food': {'name': visual.tomato.name, 'unit': 'g'},
            'quantity': '200',
            'available': '300',
          },
        ],
        'shortages': <Json>[],
        'diet_rules_version': <String, dynamic>{},
        'nutrition': null,
      };
    }
    if (path == '/insights') {
      return {
        'recorded_quantities': {
          'g': {'used': '350', 'discarded': '0'},
        },
        'inventory_event_counts': {'cooked': 2},
        'cooked_meals': 2,
        'different_recipes': 1,
        'money_saved': {
          'estimated': true,
          'amounts': [
            {'currency': 'EUR', 'value': '4.20'},
          ],
          'covered_events': 2,
        },
        'carbon_saved': {
          'estimated': true,
          'value': '0.42',
          'covered_quantity_g': '300.0',
          'eligible_quantity_g': '350.0',
        },
        'savings_method': {
          'eligible_events': 2,
          'factor_source': {
            'url': 'https://ourworldindata.org/grapher/ghg-per-kg-poore',
          },
        },
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

Widget routedHarness(SocialApi api) {
  final router = GoRouter(
    initialLocation: '/recipe-import',
    routes: [
      GoRoute(
        path: '/recipe-import',
        builder: (_, _) => const ImportRecipePage(),
      ),
      GoRoute(
        path: '/recipes/:id',
        builder: (_, state) =>
            Scaffold(body: Text('saved:${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/cook/:id',
        builder: (_, _) => const Scaffold(body: Text('cook-screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(api),
      appProvider.overrideWith(SocialController.new),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('it')],
      localizationsDelegates: const [
        support.TestStrings(),
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: Tokens.theme(Brightness.light),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(visual.loadFonts);

  testWidgets('full reviewed import does not save until final confirmation', (
    tester,
  ) async {
    final api = SocialApi();
    await tester.pumpWidget(routedHarness(api));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('social_url')),
      'https://www.youtube.com/watch?v=public',
    );
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.byKey(const Key('start_social_import')));
    await tester.pumpAndSettle();
    expect(find.text('Review imported recipe'), findsAtLeastNWidgets(1));
    expect(api.saved, isFalse);
    await tester.scrollUntilVisible(
      find.byKey(const Key('review_next')),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('review_next')));
    await tester.pumpAndSettle();
    expect(find.text('Review ingredient matches'), findsAtLeastNWidgets(1));
    expect(api.saved, isFalse);
    await tester.scrollUntilVisible(
      find.byKey(const Key('mapping_check')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('mapping_check')));
    await tester.pumpAndSettle();
    expect(find.text('Fits your profile'), findsOneWidget);
    expect(api.saved, isFalse);
    await tester.scrollUntilVisible(
      find.byKey(const Key('save_imported_recipe')),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('save_imported_recipe')));
    await tester.pumpAndSettle();
    expect(api.saved, isTrue);
    expect(find.textContaining('saved:'), findsOneWidget);
  });

  testWidgets('review supports corrections deletion and addition before save', (
    tester,
  ) async {
    final api = SocialApi();
    await tester.pumpWidget(
      support.harness(
        ImportedRecipeReviewPage(draft: draft(conflict: true)),
        api,
        controller: SocialController.new,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('import_title')),
      'Corrected title',
    );
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -650),
    );
    await tester.pumpAndSettle();
    final remove = find.byTooltip('Delete').first;
    await tester.tap(remove);
    await tester.pumpAndSettle();
    final add = find.byKey(const Key('review_add_ingredient'));
    await tester.scrollUntilVisible(
      add,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(add, findsOneWidget);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsAtLeastNWidgets(7));
    expect(api.saved, isFalse);
  });

  testWidgets('curated substitution is selected then fully rechecked', (
    tester,
  ) async {
    final api = SocialApi()..reviewResult = fitResult(adapted: true);
    await tester.pumpWidget(
      support.harness(
        SubstitutionSelectionPage(
          draft: draft(conflict: true),
          result: conflictResult(),
        ),
        api,
        controller: SocialController.new,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chickpeas'));
    await tester.pumpAndSettle();
    expect(find.text('Selected'), findsOneWidget);
    await tester.tap(find.byKey(const Key('apply_substitutions')));
    await tester.pumpAndSettle();
    expect(find.text('Now fits your profile'), findsOneWidget);
    final checks = api.calls.where(
      (call) => call['path'] == '/recipes/import-review',
    );
    expect(checks.length, 1);
    final rows = checks.single['body']['ingredient_rows'] as List;
    expect(rows.any((row) => row['food_id'] == chickpea.id), isTrue);
  });

  testWidgets('unsupported and inaccessible sources remain recoverable', (
    tester,
  ) async {
    final api = SocialApi()..importError = 'source_private_or_unavailable';
    await tester.pumpWidget(
      support.harness(
        const ImportProcessingPage(
          sourceUrl: 'https://www.instagram.com/reel/private',
        ),
        api,
        controller: SocialController.new,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This content appears private or cannot be accessed.'),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('photo acquisition exposes permission denial safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      support.harness(
        PhotoAcquisitionPage(
          kind: 'food',
          picker: (ImageSource _) async =>
              throw PlatformException(code: 'camera_access_denied'),
        ),
        SocialApi(),
        controller: SocialController.new,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('camera_shutter')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera access is off'), findsOneWidget);
  });

  for (final page in <Widget>[
    const ImportRecipePage(),
    ImportedRecipeReviewPage(draft: draft(partial: true)),
    IngredientMappingPage(draft: draft(partial: true)),
    ImportedRecipeResultPage(
      draft: draft(conflict: true),
      result: conflictResult(),
    ),
    SubstitutionSelectionPage(
      draft: draft(conflict: true),
      result: conflictResult(),
    ),
    const PhotoAcquisitionPage(kind: 'food'),
  ]) {
    testWidgets('${page.runtimeType} supports compact Italian large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        support.harness(
          page,
          SocialApi(),
          language: 'it',
          scale: 1.6,
          controller: SocialController.new,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (find.byType(Scrollable).evaluate().isNotEmpty) {
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final dark in [false, true]) {
    testWidgets('social import approved states ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final suffix = dark ? 'dark' : 'light';
      final states = <(String, Widget, SocialApi)>[
        (
          'photo-acquisition',
          const PhotoAcquisitionPage(kind: 'food'),
          SocialApi(),
        ),
        ('recipe-library-entry', const RecipeLibraryPage(), SocialApi()),
        ('recipe-library-imported', const RecipeLibraryPage(), SocialApi()),
        ('import-recipe', const ImportRecipePage(), SocialApi()),
        (
          'import-processing',
          const ImportProcessingPage(sourceUrl: 'https://youtu.be/public'),
          SocialApi()..importGate = Completer<Json>(),
        ),
        (
          'import-review',
          ImportedRecipeReviewPage(draft: draft(partial: true)),
          SocialApi(),
        ),
        (
          'ingredient-mapping',
          IngredientMappingPage(draft: draft(partial: true)),
          SocialApi(),
        ),
        (
          'compatibility-fit',
          ImportedRecipeResultPage(draft: draft(), result: fitResult()),
          SocialApi(),
        ),
        (
          'compatibility-conflict',
          ImportedRecipeResultPage(
            draft: draft(conflict: true),
            result: conflictResult(),
          ),
          SocialApi(),
        ),
        (
          'suggested-substitutions',
          SubstitutionSelectionPage(
            draft: draft(conflict: true),
            result: conflictResult(),
          ),
          SocialApi(),
        ),
        (
          'substitution-selection',
          SubstitutionSelectionPage(
            draft: draft(conflict: true),
            result: conflictResult(),
          ),
          SocialApi(),
        ),
        (
          'rechecking-adapted',
          CompatibilityCheckingPage(
            draft: draft(conflict: true),
            adaptedCount: 1,
          ),
          SocialApi()..reviewGate = Completer<Json>(),
        ),
        (
          'adapted-success',
          ImportedRecipeResultPage(
            draft: {
              ...draft(),
              'adaptations': [const <String, dynamic>{}],
            },
            result: fitResult(adapted: true),
            adaptedCount: 1,
          ),
          SocialApi(),
        ),
        (
          'no-valid-substitution',
          ImportedRecipeResultPage(
            draft: draft(conflict: true),
            result: conflictResult(candidate: false),
          ),
          SocialApi(),
        ),
        (
          'imported-final-recipe',
          const RecipePage(recipeId: '50773917-c954-51f2-a53b-1cf4b3c00690'),
          SocialApi(),
        ),
        (
          'imported-final-cook-now',
          const RecipePage(recipeId: '50773917-c954-51f2-a53b-1cf4b3c00690'),
          SocialApi(),
        ),
      ];
      for (final state in states) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          support.harness(
            RepaintBoundary(key: boundary, child: state.$2),
            state.$3,
            dark: dark,
            controller: SocialController.new,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        if (state.$1 == 'substitution-selection') {
          await tester.tap(find.text('Chickpeas'));
          await tester.pumpAndSettle();
        }
        if (state.$1 == 'imported-final-cook-now') {
          await tester.scrollUntilVisible(
            find.text('Start cooking'),
            500,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: state.$1);
        await capture(tester, boundary, '${state.$1}-$suffix');
      }

      final impactBoundary = GlobalKey();
      await tester.pumpWidget(
        support.harness(
          RepaintBoundary(key: impactBoundary, child: const InsightsPage()),
          SocialApi(),
          dark: dark,
          controller: SocialController.new,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impact'));
      await tester.pumpAndSettle();
      expect(find.text('€4.20'), findsOneWidget);
      expect(find.text('0.42 kg CO₂e'), findsOneWidget);
      await capture(tester, impactBoundary, 'estimated-savings-$suffix');
    });
  }
}
