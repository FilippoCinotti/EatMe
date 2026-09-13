import 'premium_fonts.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatme/core/models.dart';
import 'package:eatme/core/state.dart';
import 'package:eatme/design_system/widgets.dart';
import 'package:eatme/features/chef_table/chef_table.dart';
import 'package:eatme/features/fridge/fridge.dart';
import 'package:eatme/features/healthy_food/healthy_food.dart';
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

class VisualApi extends support.TestApi {
  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    if (method == 'GET' && path.startsWith('/recipes/')) {
      return {'favorite': false};
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
      ('healthy-food', '/healthy-food', const HealthyFoodPage()),
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
            expect(find.byType(NavigationDestination), findsNWidgets(4));
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
  }
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
