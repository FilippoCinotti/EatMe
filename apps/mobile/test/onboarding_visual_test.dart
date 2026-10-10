import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:eatme/core/api.dart';
import 'package:eatme/core/localization.dart';
import 'package:eatme/core/models.dart';
import 'package:eatme/core/state.dart';
import 'package:eatme/design_system/theme.dart';
import 'package:eatme/features/onboarding/onboarding.dart';
import 'package:eatme/features/onboarding/onboarding_tag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'premium_fonts.dart';

const dietSlugs = [
  'omnivore',
  'mediterranean',
  'vegetarian',
  'vegan',
  'pescatarian',
  'flexitarian',
  'plant-forward',
  'low-carb',
  'low-fat',
  'high-protein',
  'whole-food',
  'gluten-free',
  'celiac',
  'rad',
];
const dietNames = [
  'Onnivora',
  'Mediterranea',
  'Vegetariana',
  'Vegana',
  'Pescetariana',
  'Flexitariana',
  'A prevalenza vegetale',
  'Low-carb',
  'Low-fat',
  'Proteica',
  'Alimenti poco processati',
  'Senza glutine',
  'Celiachia',
  'RAD',
];
final fixture = AppState(
  stage: Stage.onboarding,
  diets: [
    for (var i = 0; i < dietSlugs.length; i++)
      Diet(
        dietSlugs[i],
        dietSlugs[i],
        {'en': dietNames[i], 'it': dietNames[i]},
        true,
        'active',
        i >= 12,
      ),
  ],
  allergens: const [
    'gluten',
    'crustaceans',
    'eggs',
    'fish',
    'peanut',
    'soy',
    'milk',
    'nuts',
    'wheat',
    'celery',
    'mustard',
    'sesame',
    'sulphites',
    'lupin',
    'molluscs',
    'almond',
    'hazelnut',
    'walnut',
    'cashew',
    'pecan',
    'brazil_nut',
    'pistachio',
    'macadamia',
  ],
  intolerances: const [
    'lactose',
    'fructose',
    'sorbitol',
    'mannitol',
    'xylitol',
    'maltitol',
    'fructans',
    'gos',
  ],
  sensitivities: const ['caffeine', 'alcohol', 'spicy_food', 'histamine'],
  medicalAwareness: const [
    'ibs',
    'diabetes',
    'prediabetes',
    'renal',
    'hypertension',
    'hyperlipidemia',
    'gout',
    'gerd',
    'pku',
    'custom_clinician',
  ],
);

class FixtureController extends AppController {
  @override
  AppState build() => fixture;
  @override
  Future<void> hydrate() async {}
}

class FixtureApi extends EatMeApi {
  Json? saved;
  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    if (method == 'PUT' && path == '/profile') saved = body;
    return {};
  }
}

class FixtureStrings extends LocalizationsDelegate<EatMeStrings> {
  const FixtureStrings();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<EatMeStrings> load(Locale locale) {
    final tag = locale.languageCode == 'zh' ? 'zh-Hans' : locale.languageCode;
    final values = Map<String, String>.from(
      jsonDecode(File('assets/l10n/en.json').readAsStringSync()),
    );
    values.addAll(
      Map<String, String>.from(
        jsonDecode(File('assets/l10n/$tag.json').readAsStringSync()),
      ),
    );
    return SynchronousFuture(EatMeStrings(values));
  }

  @override
  bool shouldReload(FixtureStrings old) => false;
}

Widget harness(
  GlobalKey boundary,
  FixtureApi api,
  bool dark,
  double scale,
  String lang,
) => ProviderScope(
  overrides: [
    appProvider.overrideWith(FixtureController.new),
    apiProvider.overrideWithValue(api),
  ],
  child: MaterialApp(
    locale: Locale(lang),
    supportedLocales: const [
      Locale('en'),
      Locale('it'),
      Locale('fr'),
      Locale('de'),
      Locale('es'),
      Locale('zh'),
    ],
    localizationsDelegates: const [
      FixtureStrings(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: Tokens.theme(dark ? Brightness.dark : Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
      ),
      child: child!,
    ),
    home: RepaintBoundary(key: boundary, child: const OnboardingPage()),
  ),
);

Finder get mainScroll => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    maxScrolls: 60,
    scrollable: mainScroll,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadEatMeFonts();
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
      await loader.load();
    }
  });
  for (final dark in [false, true]) {
    for (final small in [false, true]) {
      testWidgets(
        'six steps ${dark ? "dark" : "light"}, ${small ? "320 large text" : "390 screenshots"}',
        (tester) async {
          tester.view.physicalSize = small
              ? const Size(320, 568)
              : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          final api = FixtureApi();
          await tester.pumpWidget(
            harness(boundary, api, dark, small ? 2 : 1, 'it'),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byType(TextField),
            180,
            scrollable: mainScroll,
          );
          await tester.enterText(find.byType(TextField).first, 'Filippo');
          await tapVisible(tester, find.byType(CheckboxListTile));
          for (var step = 0; step < 6; step++) {
            if (step == 1 || step == 4) {
              final slug = step == 1 ? 'omnivore' : 'celiac';
              await tapVisible(
                tester,
                find.byKey(ValueKey('onboarding-diet-$slug')),
              );
              expect(
                tester
                    .widget<OnboardingTag>(
                      find.byKey(ValueKey('onboarding-diet-$slug')),
                    )
                    .selected,
                isTrue,
              );
            }
            if (step == 2 || step == 3) {
              final tag = find.byKey(
                ValueKey(
                  step == 2
                      ? 'onboarding-allergen-gluten'
                      : 'onboarding-intolerance-lactose',
                ),
              );
              await tapVisible(tester, tag);
              expect(tester.widget<OnboardingTag>(tag).selected, isTrue);
              await tapVisible(tester, tag);
              expect(tester.widget<OnboardingTag>(tag).selected, isFalse);
              await tapVisible(tester, tag);
            }
            if (step >= 2 && step <= 4) {
              final consents = find.byType(CheckboxListTile);
              await tester.scrollUntilVisible(
                consents,
                180,
                maxScrolls: 60,
                scrollable: mainScroll,
              );
              expect(
                tester.widget<CheckboxListTile>(consents.first).value,
                isFalse,
              );
              await tapVisible(tester, consents.first);
            }
            if (step == 5) {
              await tapVisible(
                tester,
                find.byKey(const ValueKey('onboarding-timing-window')),
              );
            }
            expect(tester.takeException(), isNull);
            if (!small) {
              for (var pass = 0; pass < 4; pass++) {
                final extra = tester
                    .state<ScrollableState>(mainScroll)
                    .position
                    .maxScrollExtent;
                if (extra <= 0) break;
                tester.view.physicalSize = Size(
                  390,
                  tester.view.physicalSize.height + extra + 2,
                );
                await tester.pumpAndSettle();
              }
              await tester.drag(find.byType(ListView), const Offset(0, 2000));
              await tester.pumpAndSettle();
              await tester.runAsync(() async {
                final render =
                    boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final warmup = await render.toImage(pixelRatio: 2);
                warmup.dispose();
                final image = await render.toImage(pixelRatio: 2);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final output = File(
                  'build/screenshots/onboarding-${dark ? "dark" : "light"}-${step + 1}.png',
                );
                await output.parent.create(recursive: true);
                await output.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
              tester.view.physicalSize = const Size(390, 844);
              await tester.pumpAndSettle();
            }
            if (step < 5) {
              await tapVisible(
                tester,
                find.byKey(const ValueKey('onboarding-continue')),
              );
            }
          }
          final strings = await const FixtureStrings().load(const Locale('it'));
          await tapVisible(tester, find.text(strings.text('start_eatme')));
          expect(api.saved?['name'], 'Filippo');
          expect(api.saved?['adult_confirmed'], true);
          expect(api.saved?['health_consent_version'], 'nutrition-profile-1');
          expect(api.saved?['medical_consent_version'], 'medical-nutrition-1');
          expect(
            (api.saved?['diets'] as List).any((d) => d['diet_id'] == 'celiac'),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final lang in ['en', 'es', 'fr', 'de', 'zh']) {
    for (final dark in [false, true]) {
      testWidgets('all steps, 320px and 200% text: $lang $dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          harness(GlobalKey(), FixtureApi(), dark, 2, lang),
        );
        await tester.pumpAndSettle();
        final strings = await const FixtureStrings().load(Locale(lang));
        for (var step = 0; step < 6; step++) {
          expect(
            find.text(
              strings.text('step_count', {'current': step + 1, 'total': 6}),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if (step < 5) {
            await tapVisible(
              tester,
              find.byKey(const ValueKey('onboarding-continue')),
            );
          }
        }
      });
    }
  }

  for (final dark in [false, true]) {
    testWidgets('keyboard and back preserve data: $dark', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        harness(GlobalKey(), FixtureApi(), dark, 2, 'it'),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextField),
        180,
        scrollable: mainScroll,
      );
      await tester.enterText(find.byType(TextField).first, 'Filippo');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('onboarding-continue')),
      );
      expect(tester.testTextInput.isVisible, isFalse);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      final diet = find.byKey(const ValueKey('onboarding-diet-omnivore'));
      await tapVisible(tester, diet);
      final strings = await const FixtureStrings().load(const Locale('it'));
      await tester.tap(find.byTooltip(strings.text('back')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextField),
        180,
        scrollable: mainScroll,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Filippo',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('onboarding-continue')),
      );
      await tester.scrollUntilVisible(diet, 180, scrollable: mainScroll);
      expect(tester.widget<OnboardingTag>(diet).selected, isTrue);
      expect(tester.takeException(), isNull);
    });
    for (final health in [false, true]) {
      testWidgets(
        'mandatory validation ${health ? "health consent" : "adult"}: $dark',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final api = FixtureApi();
          await tester.pumpWidget(harness(GlobalKey(), api, dark, 1, 'it'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byType(TextField),
            180,
            scrollable: mainScroll,
          );
          await tester.enterText(find.byType(TextField).first, 'Filippo');
          if (health) await tapVisible(tester, find.byType(CheckboxListTile));
          for (var step = 0; step < 5; step++) {
            if (health && step == 2) {
              await tapVisible(
                tester,
                find.byKey(const ValueKey('onboarding-allergen-gluten')),
              );
            }
            await tapVisible(
              tester,
              find.byKey(const ValueKey('onboarding-continue')),
            );
          }
          final strings = await const FixtureStrings().load(const Locale('it'));
          await tapVisible(tester, find.text(strings.text('start_eatme')));
          expect(api.saved, isNull);
          expect(
            find.text(
              strings.text(
                health ? 'health_consent_required' : 'invalid_profile',
              ),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
