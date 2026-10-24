import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'models.dart';
import 'reminders.dart';

import 'package:flutter/services.dart';

import 'guilty_pleasure.dart';

enum Stage { loading, login, onboarding, ready, failed }

Locale localeFromTag(String value) => value == 'zh-Hans'
    ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')
    : Locale(value);

class AppState {
  const AppState({
    this.stage = Stage.loading,
    this.profile = const {},
    this.foods = const [],
    this.diets = const [],
    this.allergens = const [],
    this.intolerances = const [],
    this.sensitivities = const [],
    this.medicalAwareness = const [],
    this.ethicalPreferences = const [],
    this.inventory = const [],
    this.leftovers = const [],
    this.recommendations = const [],
    this.contextual = const [],
    this.theme = ThemeMode.system,
    this.locale,
    this.error,
    this.offline = false,
    this.isDemo = false,
    this.mode = 'for_you',
    this.guiltyPleasure,
  });
  final Stage stage;
  final Json profile;
  final List<Food> foods;
  final List<Diet> diets;
  final List<String> allergens;
  final List<String> intolerances;
  final List<String> sensitivities;
  final List<String> medicalAwareness;
  final List<String> ethicalPreferences;
  final List<Batch> inventory;
  final List<Json> leftovers;
  final List<Recommendation> recommendations;
  final List<Json> contextual;
  final ThemeMode theme;
  final Locale? locale;
  final String? error;
  final bool offline, isDemo;
  final String mode;
  final GuiltyPleasureContext? guiltyPleasure;
  bool get guiltyPleasureActive =>
      guiltyPleasure?.activeAt(DateTime.now()) == true;
  AppState copy({
    Stage? stage,
    Json? profile,
    List<Food>? foods,
    List<Diet>? diets,
    List<String>? allergens,
    List<String>? intolerances,
    List<String>? sensitivities,
    List<String>? medicalAwareness,
    List<String>? ethicalPreferences,
    List<Batch>? inventory,
    List<Json>? leftovers,
    List<Recommendation>? recommendations,
    List<Json>? contextual,
    ThemeMode? theme,
    Locale? locale,
    String? error,
    bool? offline,
    bool? isDemo,
    String? mode,
    GuiltyPleasureContext? guiltyPleasure,
    bool clearGuiltyPleasure = false,
  }) => AppState(
    stage: stage ?? this.stage,
    profile: profile ?? this.profile,
    foods: foods ?? this.foods,
    diets: diets ?? this.diets,
    allergens: allergens ?? this.allergens,
    intolerances: intolerances ?? this.intolerances,
    sensitivities: sensitivities ?? this.sensitivities,
    medicalAwareness: medicalAwareness ?? this.medicalAwareness,
    ethicalPreferences: ethicalPreferences ?? this.ethicalPreferences,
    inventory: inventory ?? this.inventory,
    leftovers: leftovers ?? this.leftovers,
    recommendations: recommendations ?? this.recommendations,
    contextual: contextual ?? this.contextual,
    theme: theme ?? this.theme,
    locale: locale ?? this.locale,
    error: error,
    offline: offline ?? this.offline,
    isDemo: isDemo ?? this.isDemo,
    mode: mode ?? this.mode,
    guiltyPleasure: clearGuiltyPleasure
        ? null
        : guiltyPleasure ?? this.guiltyPleasure,
  );
}

final apiProvider = Provider<EatMeApi>((ref) => EatMeApi());
final appProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends Notifier<AppState> {
  EatMeApi get api => ref.read(apiProvider);
  @override
  AppState build() => const AppState();

  Future<void> restore() async {
    try {
      await api.restore();
      final theme = await EatMeApi.secure.read(key: 'eatme.theme');
      final locale = await EatMeApi.secure.read(key: 'eatme.locale');
      final pleasure = GuiltyPleasureContext.restore(
        await EatMeApi.secure.read(key: _guiltyPleasureKey('scope')),
        await EatMeApi.secure.read(key: _guiltyPleasureKey('expires_at')),
        DateTime.now(),
      );
      if (pleasure == null) await _clearGuiltyPleasureStorage();
      state = state.copy(
        theme: ThemeMode.values.firstWhere(
          (t) => t.name == theme,
          orElse: () => ThemeMode.system,
        ),
        locale: locale == null ? null : localeFromTag(locale),
        mode: pleasure == null ? 'for_you' : 'guilty_pleasure',
        guiltyPleasure: pleasure,
        clearGuiltyPleasure: pleasure == null,
      );
      if (api.token == null) {
        state = state.copy(stage: Stage.login);
        return;
      }
      await api.sync();
      await hydrate();
    } on ApiFailure catch (error) {
      if (error.code == 'unauthorized') {
        await api.clearSession();
        state = state.copy(stage: Stage.login);
      } else {
        state = state.copy(stage: Stage.failed, error: error.code);
      }
    } catch (_) {
      state = state.copy(stage: Stage.failed, error: 'unknown_error');
    }
  }

  Future<void> hydrate() async {
    final responses = await Future.wait<Json>([
      api.request('GET', '/config'),
      api.request('GET', '/profile'),
      api.request('GET', '/catalog'),
    ]);
    final config = responses[0];
    if ((config['auth_mode'] == 'development') != EatMeApi.development) {
      throw const ApiFailure('auth_mode_mismatch');
    }
    final profile = responses[1], catalog = responses[2];
    final switchedUser =
        state.profile['user_id'] != profile['user_id'] ||
        state.profile['household_id'] != profile['household_id'];
    state = state.copy(
      profile: profile,
      isDemo: catalog['is_demo'] == true,
      inventory: switchedUser ? const [] : null,
      leftovers: switchedUser ? const [] : null,
      recommendations: switchedUser ? const [] : null,
      contextual: switchedUser ? const [] : null,
      foods: (catalog['foods'] as List)
          .map((f) => Food.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList(),
      diets: (catalog['diets'] as List)
          .map((d) => Diet.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
      allergens: List<String>.from(catalog['allergens'] as List),
      intolerances: List<String>.from(
        catalog['intolerances'] as List? ?? const [],
      ),
      sensitivities: List<String>.from(
        catalog['sensitivities'] as List? ?? const [],
      ),
      medicalAwareness: List<String>.from(
        catalog['medical_awareness'] as List? ?? const [],
      ),
      ethicalPreferences: List<String>.from(
        catalog['ethical_preferences'] as List? ?? const [],
      ),
      stage: profile['onboarded'] == true ? Stage.ready : Stage.onboarding,
    );
    if (state.stage == Stage.ready) await refresh();
    state = state.copy(offline: api.offline);
  }

  Future<void> refresh({String? mode, bool recommendationsOnly = false}) async {
    if (state.guiltyPleasure != null && !state.guiltyPleasureActive) {
      await _clearGuiltyPleasureStorage();
      state = state.copy(mode: 'for_you', clearGuiltyPleasure: true);
    }
    final chosenMode = mode ?? state.mode;
    try {
      final requests = await Future.wait<Json>([
        if (!recommendationsOnly) api.request('GET', '/inventory'),
        if (!recommendationsOnly) api.request('GET', '/leftovers'),
        api.request(
          'GET',
          '/recommendations?mode=$chosenMode&slot=${mealSlotAt(DateTime.now())}',
        ),
      ]);
      var index = 0;
      if (!recommendationsOnly) {
        final inventory = requests[index++];
        final meals = requests[index++];
        await api.cacheInventory(inventory);
        state = state.copy(
          inventory: (inventory['items'] as List)
              .map((b) => Batch.fromJson(Map<String, dynamic>.from(b as Map)))
              .toList(),
          leftovers: (meals['items'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList(),
        );
      }
      final recommendations = requests[index];
      state = state.copy(
        mode: chosenMode,
        contextual: (recommendations['contextual'] as List? ?? const []).map((r) => Map<String, dynamic>.from(r as Map)).toList(),
        recommendations: (recommendations['items'] as List)
            .map(
              (r) =>
                  Recommendation.fromJson(Map<String, dynamic>.from(r as Map)),
            )
            .toList(),
      );
      state = state.copy(offline: api.offline);
      if (!api.offline && !recommendationsOnly) unawaited(updateReminders());
    } on ApiFailure catch (error) {
      if (error.code == 'unauthorized' ||
          error.code == 'account_deletion_pending') {
        await api.clearSession();
        state = AppState(
          stage: Stage.login,
          theme: state.theme,
          locale: state.locale,
        );
        return;
      }
      if (error.offline) {
        final cached = await api.cachedInventory();
        state = state.copy(
          offline: true,
          error: error.code,
          inventory: cached == null
              ? state.inventory
              : (cached['items'] as List)
                    .map(
                      (b) =>
                          Batch.fromJson(Map<String, dynamic>.from(b as Map)),
                    )
                    .toList(),
          recommendations: const [], contextual: const [],
        );
      } else {
        state = state.copy(error: error.code, recommendations: const []);
      }
    }
  }

  Future<void> updateReminders() async {
    try {
      final notification = await api.request(
        'GET',
        '/notifications',
        allowCache: false,
      );
      final preferences = Map<String, dynamic>.from(
        notification['preferences'] as Map? ?? {},
      );
      if (preferences['enabled'] != true) {
        await Reminders.clear();
        return;
      }
      final plans = await api.request('GET', '/plans', allowCache: false);
      final settings = state.profile['settings'] as Map;
      await Reminders.schedule(
        preferences,
        state.inventory,
        (plans['items'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList(),
        settings['timezone'] as String,
        state.locale?.languageCode ?? 'en',
      );
    } on ApiFailure {
      // Existing device reminders remain available when the API cannot refresh them.
    } on MissingPluginException {
      // Headless tests have no native notification service.
    } on PlatformException {
      // A denied device capability must not prevent inventory access.
    }
  }

  Future<void> setTheme(ThemeMode value) async {
    state = state.copy(theme: value);
    await EatMeApi.secure.write(key: 'eatme.theme', value: value.name);
  }

  Future<void> setLocale(String value) async {
    state = state.copy(locale: localeFromTag(value));
    await EatMeApi.secure.write(key: 'eatme.locale', value: value);
  }

  Future<void> enableGuiltyPleasure(String scope) async {
    final expiresAt = guiltyPleasureExpiry(scope, DateTime.now());
    final value = GuiltyPleasureContext(scope: scope, expiresAt: expiresAt);
    await EatMeApi.secure.write(key: _guiltyPleasureKey('scope'), value: scope);
    await EatMeApi.secure.write(
      key: _guiltyPleasureKey('expires_at'),
      value: expiresAt.toIso8601String(),
    );
    state = state.copy(mode: 'guilty_pleasure', guiltyPleasure: value);
    await refresh(mode: 'guilty_pleasure', recommendationsOnly: true);
  }

  Future<void> setRecommendationMode(String value) async {
    if (value != 'guilty_pleasure') {
      await _clearGuiltyPleasureStorage();
      state = state.copy(clearGuiltyPleasure: true);
    }
    await refresh(mode: value, recommendationsOnly: true);
  }

  Future<void> disableGuiltyPleasure({
    bool refreshRecommendations = true,
  }) async {
    await _clearGuiltyPleasureStorage();
    state = state.copy(mode: 'for_you', clearGuiltyPleasure: true);
    if (refreshRecommendations) {
      await refresh(mode: 'for_you', recommendationsOnly: true);
    }
  }

  Future<void> completeGuiltyPleasureMeal() async {
    if (state.guiltyPleasure?.scope == 'meal') {
      await disableGuiltyPleasure(refreshRecommendations: false);
    }
  }

  Future<void> _clearGuiltyPleasureStorage() async {
    await EatMeApi.secure.delete(key: _guiltyPleasureKey('scope'));
    await EatMeApi.secure.delete(key: _guiltyPleasureKey('expires_at'));
  }

  String _guiltyPleasureKey(String field) =>
      'eatme.${api.userId ?? 'signed-out'}.guilty_pleasure.$field';

  Future<void> logout() async {
    await api.logout();
    state = AppState(
      stage: Stage.login,
      theme: state.theme,
      locale: state.locale,
    );
  }

  Future<void> deleted() async {
    await api.clearSession();
    state = AppState(
      stage: Stage.login,
      theme: state.theme,
      locale: state.locale,
    );
  }
}
