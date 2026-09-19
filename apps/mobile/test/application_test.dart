import 'premium_fonts.dart';

import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatme/core/api.dart';
import 'package:eatme/core/entitlements.dart';
import 'package:eatme/core/guilty_pleasure.dart';
import 'package:eatme/core/localization.dart';
import 'package:eatme/core/models.dart';
import 'package:eatme/core/state.dart';
import 'package:eatme/design_system/theme.dart';
import 'package:eatme/design_system/widgets.dart';
import 'package:eatme/main.dart';
import 'package:eatme/features/chef_table/chef_table.dart';
import 'package:eatme/features/organize/shopping.dart';
import 'package:eatme/features/organize/household.dart';
import 'package:eatme/features/organize/recipe_library.dart';
import 'package:eatme/features/organize/guilty_pleasure.dart';

const uid = '00000000-0000-4000-8000-000000000001';
const home = '00000000-0000-4000-8000-000000000002';

class TestStrings extends LocalizationsDelegate<EatMeStrings> {
  const TestStrings();
  @override
  bool isSupported(Locale locale) =>
      ['en', 'it', 'es', 'fr', 'de', 'zh'].contains(locale.languageCode);
  @override
  Future<EatMeStrings> load(Locale locale) {
    final values = Map<String, String>.from(
      jsonDecode(File('assets/l10n/en.json').readAsStringSync()) as Map,
    );
    final tag = locale.languageCode == 'zh' ? 'zh-Hans' : locale.languageCode;
    if (tag != 'en') {
      values.addAll(
        Map<String, String>.from(
          jsonDecode(File('assets/l10n/$tag.json').readAsStringSync()) as Map,
        ),
      );
    }
    return SynchronousFuture(EatMeStrings(values));
  }

  @override
  bool shouldReload(TestStrings old) => false;
}

class TestApi extends EatMeApi {
  TestApi() {
    localUserId = uid;
    localToken = 'test-only-session';
  }
  final calls = <Json>[];
  bool connected = true;
  Json item = {
    'id': 'line',
    'label': 'Tomatoes',
    'quantity': '300',
    'unit': 'g',
    'version': 1,
    'checked': false,
  };
  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    calls.add({
      'method': method,
      'path': path,
      'body': body,
      'key': operationKey,
    });
    if (!connected) throw const ApiFailure('network_error', offline: true);
    if (path == '/profile') return {'household_id': home, 'user_id': uid};
    if (path == '/shopping' && method == 'GET') {
      return {
        'items': item.isEmpty ? [] : [item],
      };
    }
    if (path == '/shopping' && body?['action'] == 'check') {
      item = {...item, 'checked': body!['checked'], 'version': 2};
      return {'updated': true};
    }
    if (path == '/shopping' && body?['action'] == 'purchase') {
      item = {};
      return {'purchased': true};
    }
    if (path == '/households') {
      return {
        'current_id': home,
        'items': [
          {'id': home, 'name': 'Our kitchen', 'role': 'owner'},
        ],
        'members': [
          {
            'user_id': uid,
            'name': 'Alex',
            'role': 'owner',
            'share_constraints': 0,
          },
          {
            'user_id': 'other',
            'name': 'Sam',
            'role': 'member',
            'share_constraints': 0,
          },
        ],
        'consent_version': 'household-constraints-1',
      };
    }
    if (path == '/recipes') return {'items': []};
    return {'items': []};
  }
}

class TestController extends AppController {
  @override
  AppState build() => const AppState(
    stage: Stage.ready,
    profile: {
      'user_id': uid,
      'household_id': home,
      'name': 'Alex',
      'settings': {'timezone': 'Europe/Rome'},
    },
    foods: [
      Food(
        id: 'tomato',
        name: {'en': 'Tomatoes', 'it': 'Pomodori'},
        unit: 'g',
        group: 'vegetable',
      ),
    ],
  );
  @override
  Future<void> refresh({String? mode}) async {}
}

Widget harness(
  Widget child,
  TestApi api, {
  bool dark = false,
  String language = 'en',
  double scale = 1,
  List<ui.DisplayFeature> features = const [],
  AppController Function()? controller,
}) => ProviderScope(
  overrides: [
    apiProvider.overrideWithValue(api),
    appProvider.overrideWith(controller ?? TestController.new),
  ],
  child: MaterialApp(
    locale: Locale(language),
    supportedLocales: const [
      Locale('en'),
      Locale('it'),
      Locale('es'),
      Locale('fr'),
      Locale('de'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    ],
    localizationsDelegates: const [
      TestStrings(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: Tokens.theme(dark ? Brightness.dark : Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        displayFeatures: features,
      ),
      child: AdaptiveAppFrame(child: child!),
    ),
    home: child,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadEatMeFonts();
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk == null) return;
    final fonts = Directory('$sdk/bin/cache/artifacts/material_fonts');
    final text = FontLoader('Roboto');
    for (final file in fonts.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.ttf') && file.path.contains('Roboto-'),
    )) {
      text.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await text.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      Future.value(
        ByteData.sublistView(
          File('${fonts.path}/MaterialIcons-Regular.otf').readAsBytesSync(),
        ),
      ),
    );
    await icons.load();
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });
  test('entitlement snapshot keeps safety free and smart planning gated', () {
    final free = EntitlementSnapshot.fromJson({
      'tier': 'free',
      'configured': true,
      'capabilities': {
        'canSeeSafetyWarnings': true,
        'canUseSmartPlanning': false,
      },
      'limits': {'smart_import': 3},
      'usage': {'smart_import': 1},
      'remaining': {'smart_import': 2},
    });
    expect(free.can('canSeeSafetyWarnings'), isTrue);
    expect(free.can(EntitlementCapability.smartPlanning), isFalse);
    expect(free.remainingFor('smart_import'), 2);
  });
  test('Guilty Pleasure expires and scheduled meal scope stays isolated', () {
    final now = DateTime(2026, 9, 19, 19);
    expect(
      GuiltyPleasureContext.restore(
        'meal',
        now.subtract(const Duration(minutes: 1)).toIso8601String(),
        now,
      ),
      isNull,
    );
    final plans = <Json>[
      {
        'data': {
          'preference_overrides': [
            {
              'mode': 'guilty_pleasure',
              'scope': 'meal',
              'date': '2026-09-19',
              'slot': 'dinner',
            },
          ],
        },
      },
    ];
    expect(
      scheduledPreferenceMode(plans, now, slot: 'dinner'),
      'guilty_pleasure',
    );
    expect(scheduledPreferenceMode(plans, now, slot: 'lunch'), 'for_you');
    expect(
      scheduledPreferenceMode(plans, DateTime(2026, 9, 20), slot: 'dinner'),
      'for_you',
    );
  });
  for (final language in ['en', 'it', 'es', 'fr', 'de', 'zh-Hans']) {
    testWidgets('Guilty Pleasure safety copy renders in $language', (
      tester,
    ) async {
      final locale = language == 'zh-Hans' ? 'zh' : language;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showGuiltyPleasureSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
          TestApi(),
          language: locale,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(RadioListTile<String>), findsNWidgets(2));
      expect(find.textContaining('unknown_error'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Plan shopping keeps the Plan destination selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const AppShell(path: '/plan/shopping', child: SizedBox()),
        TestApi(),
      ),
    );
    await tester.pumpAndSettle();
    final navigation = tester.widget<EatMeNavigationBar>(
      find.byType(EatMeNavigationBar),
    );
    expect(navigation.selectedIndex, 2);
    expect(navigation.destinations.map((item) => item.label), [
      'ChefTable',
      'Fridge',
      'Plan',
      'Profile',
    ]);
  });
  testWidgets('shopping check and purchase updates the connected list', (
    tester,
  ) async {
    final api = TestApi();
    await tester.pumpWidget(harness(const ShoppingPage(), api));
    await tester.pumpAndSettle();
    expect(find.text('Tomatoes'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Purchased · add to fridge'));
    await tester.tap(find.text('Purchased · add to fridge'));
    await tester.pumpAndSettle();
    expect(find.text('Everything is in order'), findsOneWidget);
    expect(
      api.calls.where((c) => c['body']?['action'] == 'purchase').length,
      1,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'household view shows consent controls without a health profile',
    (tester) async {
      await tester.pumpWidget(harness(const HouseholdPage(), TestApi()));
      await tester.pumpAndSettle();
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Use my constraints for shared meals'), findsOneWidget);
      expect(find.text('milk'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('recipe editor requires a canonical ingredient before saving', (
    tester,
  ) async {
    await tester.pumpWidget(harness(const RecipeEditorPage(), TestApi()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save private recipe'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save private recipe'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
  test(
    'offline mutation preserves its operation key when synchronized',
    () async {
      final api = TestApi();
      await api.cache!.cache('/profile', {'household_id': home});
      api.connected = false;
      final result = await Mutation().send(api, 'POST', '/shopping', {
        'action': 'add',
        'label': 'Rice',
        'quantity': '1',
      });
      expect(result['queued'], isTrue);
      final pending = await api.cache!.pending();
      final key = pending.single['key'];
      api.connected = true;
      await api.sync();
      expect(await api.cache!.pending(), isEmpty);
      expect(api.calls.last['key'], key);
    },
  );
  test(
    'offline changes stay queued if the current household changes',
    () async {
      final api = TestApi();
      await api.cache!.cache('/profile', {'household_id': 'previous-home'});
      api.connected = false;
      await Mutation().send(api, 'POST', '/shopping', {
        'action': 'add',
        'label': 'Rice',
        'quantity': '1',
      });
      api.connected = true;
      await api.sync();
      expect(
        (await api.cache!.pending()).single['status'],
        'household_changed',
      );
      expect(api.calls.where((c) => c['method'] == 'POST').length, 1);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'navigation avoids a foldable hinge ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(804, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          harness(
            const AppShell(path: '/chef', child: ChefTablePage()),
            TestApi(),
            dark: dark,
            scale: 1.6,
            features: const [
              ui.DisplayFeature(
                bounds: Rect.fromLTWH(390, 0, 24, 844),
                type: ui.DisplayFeatureType.hinge,
                state: ui.DisplayFeatureState.postureFlat,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EatMeNavigationBar), findsOneWidget);
        expect(
          tester.getRect(find.byType(EatMeNavigationBar)).right,
          lessThanOrEqualTo(390),
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'shopping renders at mobile width with large text ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          harness(
            RepaintBoundary(key: boundary, child: const ShoppingPage()),
            TestApi(),
            dark: dark,
            scale: 1.6,
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
          final output = File(
            'build/screenshots/shopping-${dark ? 'dark' : 'light'}.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      },
    );
  }
}
