import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EatMeStrings {
  EatMeStrings(this.values);
  final Map<String, String> values;
  String text(String key, [Map<String, Object> variables = const {}]) {
    var value = values[key] ?? values['unknown_error'] ?? key;
    for (final entry in variables.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return value;
  }

  static const delegate = _EatMeStringsDelegate();
}

class _EatMeStringsDelegate extends LocalizationsDelegate<EatMeStrings> {
  const _EatMeStringsDelegate();
  @override
  bool isSupported(Locale locale) =>
      const {'en', 'it', 'es', 'fr', 'de', 'zh'}.contains(locale.languageCode);
  @override
  Future<EatMeStrings> load(Locale locale) async {
    final canonical = Map<String, String>.from(
      jsonDecode(await rootBundle.loadString('assets/l10n/en.json')) as Map,
    );
    final tag = locale.languageCode == 'zh' ? 'zh-Hans' : locale.languageCode;
    if (tag != 'en') {
      canonical.addAll(
        Map<String, String>.from(
          jsonDecode(await rootBundle.loadString('assets/l10n/$tag.json'))
              as Map,
        ),
      );
    }
    return EatMeStrings(canonical);
  }

  @override
  bool shouldReload(_EatMeStringsDelegate old) => false;
}

extension EatMeLocalization on BuildContext {
  String t(String key, [Map<String, Object> variables = const {}]) =>
      Localizations.of<EatMeStrings>(this, EatMeStrings)!.text(key, variables);
  String get language => Localizations.localeOf(this).languageCode;
}
