import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:eatme/core/localization.dart';
import 'package:eatme/design_system/theme.dart';
import 'package:eatme/design_system/widgets.dart';

class SplashStringsDelegate extends LocalizationsDelegate<EatMeStrings> {
  const SplashStringsDelegate();

  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<EatMeStrings> load(Locale locale) =>
      SynchronousFuture(EatMeStrings({'eatme': 'EatMe+'}));
  @override
  bool shouldReload(SplashStringsDelegate old) => false;
}

Widget harness(
  Widget child, {
  Brightness brightness = Brightness.light,
  LocalizationsDelegate<EatMeStrings> stringsDelegate = EatMeStrings.delegate,
}) => MaterialApp(
  theme: Tokens.theme(brightness),
  locale: const Locale('it'),
  supportedLocales: const [Locale('it'), Locale('en')],
  localizationsDelegates: [
    stringsDelegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

void main() {
  testWidgets('display typography is reserved for titles and wordmark', (
    tester,
  ) async {
    final theme = Tokens.theme(Brightness.light);
    expect(theme.textTheme.displaySmall?.fontFamily, 'EatMeDisplay');
    expect(theme.textTheme.headlineMedium?.fontFamily, 'EatMeDisplay');
    expect(theme.textTheme.labelLarge?.fontFamily, 'EatMeDisplay');
    expect(theme.textTheme.titleLarge?.fontFamily, 'EatMeSans');
    expect(theme.textTheme.bodyLarge?.fontFamily, 'EatMeSans');

    expect(EatMeWordmark.fontFamily, 'EatMeDisplay');
    expect(EatMeWordmark.plusScale, lessThan(1));
  });

  testWidgets('loading splash uses the two-leaf brand mark', (tester) async {
    await tester.pumpWidget(
      harness(
        const EatMeLoadingSplash(label: 'Caricamento'),
        stringsDelegate: const SplashStringsDelegate(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(EatMeBrandMark), findsNWidgets(2));
    expect(find.byType(EatMeWordmark), findsOneWidget);
    expect(find.bySemanticsLabel('Caricamento'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy action prevents duplicate consumption submissions', (
    tester,
  ) async {
    final pending = Completer<void>();
    int submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: Tokens.theme(Brightness.light),
        home: Scaffold(
          body: AsyncAction(
            key: const ValueKey('confirm-action'),
            label: 'Conferma',
            action: () {
              submissions++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-action')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-action')));
    await tester.pump();
    expect(submissions, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets('empty state supports large text in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: const PageBody(
                children: [
                  EmptyMessage(
                    title: 'Un po’ di spazio per iniziare.',
                    body: 'Aggiungi gli alimenti che hai in casa.',
                  ),
                ],
              ),
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
