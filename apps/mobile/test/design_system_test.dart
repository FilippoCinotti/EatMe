import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:eatme/core/localization.dart';
import 'package:eatme/design_system/theme.dart';
import 'package:eatme/design_system/widgets.dart';

Widget harness(Widget child,{Brightness brightness=Brightness.light}) => MaterialApp(
  theme:Tokens.theme(brightness),locale:const Locale('it'),supportedLocales:const [Locale('it'),Locale('en')],
  localizationsDelegates:const [EatMeStrings.delegate,GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
  home:Scaffold(body:child),
);

void main() {
  testWidgets('busy action prevents duplicate consumption submissions',(tester) async {
    final pending=Completer<void>();int submissions=0;
    await tester.pumpWidget(harness(AsyncAction(label:'Conferma',action:(){submissions++;return pending.future;})));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));await tester.pump();
    await tester.tap(find.byType(FilledButton));await tester.pump();
    expect(submissions,1);
    pending.complete();await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });
  for(final brightness in Brightness.values) {
    testWidgets('empty state supports large text in ${brightness.name}',(tester) async {
      tester.view.physicalSize=const Size(360,800);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(harness(Builder(builder:(context)=>MediaQuery(
        data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(1.8)),
        child:const PageBody(children:[EmptyMessage(title:'Un po’ di spazio per iniziare.',body:'Aggiungi gli alimenti che hai in casa.')]),
      )),brightness:brightness));
      await tester.pumpAndSettle();expect(tester.takeException(),isNull);
    });
  }
}
