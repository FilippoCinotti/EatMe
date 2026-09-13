import 'dart:io';
import 'package:flutter/services.dart';

Future<void> loadEatMeFonts() async {
  for (final family in ['EatMeDisplay', 'EatMeSans']) {
    final loader = FontLoader(family);
    for (final weight in ['Regular']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/$family-$weight.ttf').readAsBytesSync(),
          ),
        ),
      );
    }
    await loader.load();
  }
}
