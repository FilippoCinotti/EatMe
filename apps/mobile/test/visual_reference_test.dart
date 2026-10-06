import 'premium_fonts.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatme/core/models.dart';
import 'package:eatme/core/guilty_pleasure.dart';
import 'package:eatme/core/state.dart';
import 'package:eatme/design_system/widgets.dart';
import 'package:eatme/features/chef_table/chef_table.dart';
import 'package:eatme/features/fridge/fridge.dart';
import 'package:eatme/features/organize/dinners.dart';
import 'package:eatme/features/organize/guilty_pleasure.dart';
import 'package:eatme/features/organize/planner.dart';
import 'package:eatme/features/profile/profile.dart';
import 'package:eatme/main.dart';

import 'application_test.dart' as support;

const tomato = Food(
  id: '1536dc24-7d91-5bb7-bb5b-8c2ba6a0620e',
  name: {'en': 'Tomatoes', 'it': 'Pomodori'},
  unit: 'g',
  group: 'vegetable',
);
const zucchini = Food(
  id: 'd72ab6c9-e21e-57c5-9674-2c0bc0fdca2e',
  name: {'en': 'Zucchini', 'it': 'Zucchine'},
  unit: 'g',
  group: 'vegetable',
);
const spinach = Food(
  id: 'b488bbff-0384-5e44-9973-7a23778efcc2',
  name: {'en': 'Spinach', 'it': 'Spinaci'},
  unit: 'g',
  group: 'vegetable',
);
const feta = Food(
  id: '533cdc59-9b73-5059-9bd2-60e268df96d6',
  name: {'en': 'Feta', 'it': 'Feta'},
  unit: 'g',
  group: 'dairy',
);

class VisualController extends support.TestController {
  @override
  AppState build() {
    final day = DateUtils.dateOnly(DateTime.now());
    return super.build().copy(
      isDemo: true,
      profile: {
        ...super.build().profile,
        'version': 2,
        'settings': {
          'timezone': 'Europe/Rome',
          'diets': <Json>[
            {'diet_id': 'diet-med', 'strictness': 'standard'},
          ],
          'primary_diet': 'diet-med',
          'allergies': <String>[],
          'intolerances': <String>[],
          'never_suggest': <String>[],
          'unknown_ingredient_policy': 'strict',
        },
      },
      diets: const [
        Diet(
          'diet-med',
          'mediterranean',
          {'en': 'Mediterranean', 'it': 'Mediterranea'},
          true,
          'PUBLISHED',
          false,
        ),
      ],
      foods: [tomato, zucchini, spinach, feta],
      inventory: [
        Batch(
          'z',
          zucchini,
          '250',
          'fridge',
          day.add(const Duration(days: 1)),
          'best_before',
          1,
          true,
        ),
        Batch(
          't',
          tomato,
          '300',
          'fridge',
          day.add(const Duration(days: 2)),
          'best_before',
          1,
          true,
        ),
        Batch(
          's',
          spinach,
          '100',
          'fridge',
          day.add(const Duration(days: 3)),
          'best_before',
          1,
          true,
        ),
      ],
      recommendations: [
        const Recommendation(
          Recipe(
            '50773917-c954-51f2-a53b-1cf4b3c00690',
            {'en': 'Zucchini & spinach pasta'},
            25,
            2,
            [],
            {
              'en': ['Cook and serve.'],
            },
          ),
          4,
          4,
          [],
          [],
        ),
      ],
    );
  }
}

class GuiltyVisualController extends VisualController {
  @override
  AppState build() => super.build().copy(
    mode: 'guilty_pleasure',
    guiltyPleasure: GuiltyPleasureContext(
      scope: 'meal',
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
    ),
  );
}

class AvatarVisualController extends VisualController {
  @override
  AppState build() {
    final state = super.build();
    final settings = Map<String, dynamic>.from(
      state.profile['settings'] as Map? ?? {},
    );
    return state.copy(
      profile: {
        ...state.profile,
        'settings': {...settings, 'avatar_media_id': 'avatar-1'},
      },
    );
  }
}

class VisualApi extends support.TestApi {
  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    if (method == 'GET' && path == '/dinners') {
      return {
        'items': [
          {
            'id': 'dinner-1',
            'title': 'Dinner with friends',
            'starts_at': '2030-09-20T17:00:00+00:00',
            'status': 'planned',
          },
        ],
      };
    }
    if (method == 'GET' && path == '/media/avatar-1') {
      return {
        'base64':
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZlYQAAAAASUVORK5CYII=',
      };
    }
    if (method == 'GET' && path.startsWith('/recipes/')) {
      return {'favorite': false};
    }
    if (method == 'GET' && path == '/preferences') {
      return {
        'version': 1,
        'data': {
          'favorite_foods': [tomato.id, zucchini.id],
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

Future<void> loadFonts() async {
  await loadEatMeFonts();
  final sdk = Platform.environment['FLUTTER_ROOT'];
  if (sdk == null) return;
  final directory = Directory('$sdk/bin/cache/artifacts/material_fonts');
  final fonts = FontLoader('Roboto');
  for (final file in directory.listSync().whereType<File>().where(
    (file) => file.path.endsWith('.ttf') && file.path.contains('Roboto-'),
  )) {
    fonts.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await fonts.load();
  final icons = FontLoader('MaterialIcons');
  icons.addFont(
    Future.value(
      ByteData.sublistView(
        File('${directory.path}/MaterialIcons-Regular.otf').readAsBytesSync(),
      ),
    ),
  );
  await icons.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);
  for (final dark in [false, true]) {
    for (final page in <(String, String, Widget)>[
      ('chef', '/chef', const ChefTablePage()),
      ('fridge', '/fridge', const FridgePage()),
      ('plan', '/plan', const PlannerPage()),
      ('dinners', '/plan/dinners', const DinnersPage()),
      ('profile', '/profile', const ProfilePage()),
    ]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
          '${page.$1} reference layout ${dark ? 'dark' : 'light'} at $scale',
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
                  child: AppShell(path: page.$2, child: page.$3),
                ),
                VisualApi(),
                dark: dark,
                scale: scale,
                controller: VisualController.new,
              ),
            );
            await tester.runAsync(
              () => precacheImage(
                const AssetImage(FoodImage.asset),
                tester.element(find.byType(MaterialApp)),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(EatMeNavigationBar), findsOneWidget);
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
          },
        );
      }
    }
    for (final state in <(String, Widget, AppController Function())>[
      (
        'guilty-pleasure-active',
        const AppShell(path: '/chef', child: ChefTablePage()),
        GuiltyVisualController.new,
      ),
      (
        'guilty-pleasure-sheet',
        const Scaffold(body: GuiltyPleasureSheet(active: false)),
        VisualController.new,
      ),
    ]) {
      testWidgets('${state.$1} ${dark ? 'dark' : 'light'}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          support.harness(
            RepaintBoundary(key: boundary, child: state.$2),
            VisualApi(),
            dark: dark,
            controller: state.$3,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/screenshots/${state.$1}-${dark ? 'dark' : 'light'}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
  testWidgets(
    'ChefTable renders avatar and keeps the suggestion visible for an unmatched search',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        support.harness(
          const AppShell(path: '/chef', child: ChefTablePage()),
          VisualApi(),
          controller: AvatarVisualController.new,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('chef-profile-avatar-image')),
        findsOneWidget,
      );
      expect(find.text('Suggested by EatMe+'), findsOneWidget);
      expect(find.text('4/4 ingredients at home'), findsOneWidget);
      expect(find.text('Why EatMe+ picked this'), findsNothing);
      expect(find.text('Checking against your profile'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'not-a-recipe');
      await tester.pumpAndSettle();

      expect(find.text('Try another name or category.'), findsOneWidget);
      expect(find.text('Zucchini & spinach pasta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Profile preview prioritizes dietary and medical context', (
    tester,
  ) async {
    await tester.pumpWidget(
      support.harness(
        const ProfilePage(),
        VisualApi(),
        controller: VisualController.new,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Eating style:'), findsOneWidget);
    expect(find.textContaining('Allergies:'), findsOneWidget);
    expect(find.textContaining('Medical dietary settings:'), findsOneWidget);
    expect(find.text('System'), findsNothing);
    expect(find.text('EN'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Existing profile photo can be reframed', (tester) async {
    await tester.pumpWidget(
      support.harness(
        const AppShell(path: '/profile', child: ProfilePage()),
        VisualApi(),
        controller: AvatarVisualController.new,
      ),
    );
    await tester.pumpAndSettle();

    final avatar = find.byType(Image).first;
    await tester.tap(avatar);
    await tester.pumpAndSettle();

    expect(find.text('Choose a new photo'), findsOneWidget);
    expect(find.text('Reframe profile photo'), findsOneWidget);
    expect(find.byType(EatMeNavigationBar), findsOneWidget);
    expect(find.byType(ModalBarrier), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Planner initializes family and keeps equal action heights', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      support.harness(
        const PlannerPage(),
        VisualApi(),
        controller: VisualController.new,
      ),
    );
    await tester.pumpAndSettle();

    final date = find.byKey(const ValueKey('planner-date-action'));
    final diners = find.byKey(const ValueKey('planner-diners-action'));
    final smart = find.byKey(const ValueKey('planner-smart-action'));
    expect(date, findsOneWidget);
    expect(diners, findsOneWidget);
    expect(smart, findsOneWidget);

    final dateTop = tester.getTopLeft(date).dy;
    expect(tester.getTopLeft(diners).dy, dateTop);
    expect(tester.getTopLeft(smart).dy, dateTop);
    expect(tester.getSize(diners).height, tester.getSize(date).height);
    expect(tester.getSize(smart).height, tester.getSize(date).height);
    expect(find.byKey(const ValueKey('planner-diners-avatar')), findsOneWidget);

    await tester.tap(diners);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planner-diners-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('planner-diners-avatar')), findsOneWidget);
    expect(find.byKey(const ValueKey('planner-date-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('planner-smart-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown content does not borrow a demo photograph', (
    tester,
  ) async {
    await tester.pumpWidget(
      support.harness(
        const FoodImage(id: 'private-recipe', width: 100, height: 100),
        VisualApi(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
