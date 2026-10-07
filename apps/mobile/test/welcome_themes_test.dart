import 'dart:io';
import 'dart:ui' as ui;

import 'package:eatme/features/auth/login.dart';
import 'package:eatme/features/auth/welcome/landing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'application_test.dart' as support;
import 'premium_fonts.dart';

void main() {
  setUpAll(loadEatMeFonts);

  for (final dark in [false, true]) {
    testWidgets('approved Italian welcome ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      var action = '';
      await tester.pumpWidget(
        support.harness(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 44, bottom: 34)),
              child: RepaintBoundary(
                key: boundary,
                child: WelcomeLanding(
                  onStart: () => action = 'register',
                  onLogin: () => action = 'login',
                ),
              ),
            ),
          ),
          support.TestApi(),
          language: 'it',
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      final start = find.byKey(const ValueKey('welcome-start'));
      final login = find.byKey(const ValueKey('welcome-login'));
      expect(tester.getBottomRight(login).dy, lessThan(810));
      expect(
        find.text('Ricette su misura per te,\ncon quello che hai già.'),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        final renderObject =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        // Warm the first off-screen raster. Without this, Flutter's Linux test
        // renderer can omit the first button's foreground layer in the PNG.
        final warmup = await renderObject.toImage(pixelRatio: 2);
        warmup.dispose();
        final image = await renderObject.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File(
          'build/screenshots/welcome-approved-${dark ? 'dark' : 'light'}.png',
        );
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(start);
      expect(action, 'register');
      await tester.tap(login);
      expect(action, 'login');
    });
  }

  for (final language in ['en', 'it', 'es', 'fr', 'de', 'zh']) {
    testWidgets('small welcome with large text: $language', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var tapped = false;
      await tester.pumpWidget(
        support.harness(
          WelcomeLanding(onStart: () {}, onLogin: () => tapped = true),
          support.TestApi(),
          language: language,
          scale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final login = find.byKey(const ValueKey('welcome-login'));
      await tester.ensureVisible(login);
      await tester.pumpAndSettle();
      await tester.tap(login);
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('welcome actions enter registration and sign in', (tester) async {
    await tester.pumpWidget(
      support.harness(const LoginPage(), support.TestApi(), language: 'it'),
    );
    await tester.pumpAndSettle();
    final start = find.byKey(const ValueKey('welcome-start'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(find.text('Crea il tuo account'), findsWidgets);
  });
}
