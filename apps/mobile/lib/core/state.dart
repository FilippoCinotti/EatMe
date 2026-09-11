import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';
import 'models.dart';

enum Stage { loading, login, onboarding, ready, failed }

class AppState {
  const AppState({
    this.stage = Stage.loading,
    this.profile = const {},
    this.foods = const [],
    this.diets = const [],
    this.allergens = const [],
    this.inventory = const [],
    this.recommendations = const [],
    this.theme = ThemeMode.system,
    this.locale,
    this.error,
    this.offline = false,
    this.mode = 'for_you',
  });
  final Stage stage;
  final Json profile;
  final List<Food> foods;
  final List<Diet> diets;
  final List<String> allergens;
  final List<Batch> inventory;
  final List<Recommendation> recommendations;
  final ThemeMode theme;
  final Locale? locale;
  final String? error;
  final bool offline;
  final String mode;
  AppState copy({
    Stage? stage,
    Json? profile,
    List<Food>? foods,
    List<Diet>? diets,
    List<String>? allergens,
    List<Batch>? inventory,
    List<Recommendation>? recommendations,
    ThemeMode? theme,
    Locale? locale,
    String? error,
    bool? offline,
    String? mode,
  }) => AppState(
    stage: stage ?? this.stage,
    profile: profile ?? this.profile,
    foods: foods ?? this.foods,
    diets: diets ?? this.diets,
    allergens: allergens ?? this.allergens,
    inventory: inventory ?? this.inventory,
    recommendations: recommendations ?? this.recommendations,
    theme: theme ?? this.theme,
    locale: locale ?? this.locale,
    error: error,
    offline: offline ?? this.offline,
    mode: mode ?? this.mode,
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
      state = state.copy(
        theme: ThemeMode.values.firstWhere(
          (t) => t.name == theme,
          orElse: () => ThemeMode.system,
        ),
        locale: locale == null ? null : Locale(locale),
      );
      if (api.token == null) {
        state = state.copy(stage: Stage.login);
        return;
      }
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
    final config = await api.request('GET', '/config');
    if ((config['auth_mode'] == 'development') != EatMeApi.development) {
      throw const ApiFailure('auth_mode_mismatch');
    }
    final responses = await Future.wait([
      api.request('GET', '/profile'),
      api.request('GET', '/catalog'),
    ]);
    final profile = responses[0], catalog = responses[1];
    final switchedUser = state.profile['user_id'] != profile['user_id'];
    state = state.copy(
      profile: profile,
      inventory: switchedUser ? const [] : null,
      recommendations: switchedUser ? const [] : null,
      foods: (catalog['foods'] as List)
          .map((f) => Food.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList(),
      diets: (catalog['diets'] as List)
          .map((d) => Diet.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
      allergens: List<String>.from(catalog['allergens'] as List),
      stage: profile['onboarded'] == true ? Stage.ready : Stage.onboarding,
    );
    if (state.stage == Stage.ready) await refresh();
  }

  Future<void> refresh({String? mode}) async {
    final chosenMode = mode ?? state.mode;
    try {
      final inventory = await api.request('GET', '/inventory');
      await api.cacheInventory(inventory);
      state = state.copy(
        inventory: (inventory['items'] as List)
            .map((b) => Batch.fromJson(Map<String, dynamic>.from(b as Map)))
            .toList(),
        offline: false,
        mode: chosenMode,
      );
      final recommendations = await api.request(
        'GET',
        '/recommendations?mode=$chosenMode',
      );
      state = state.copy(
        recommendations: (recommendations['items'] as List)
            .map(
              (r) =>
                  Recommendation.fromJson(Map<String, dynamic>.from(r as Map)),
            )
            .toList(),
      );
    } on ApiFailure catch (error) {
      if (error.code == 'unauthorized') {
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
          recommendations: const [],
        );
      } else {
        state = state.copy(error: error.code, recommendations: const []);
      }
    }
  }

  Future<void> setTheme(ThemeMode value) async {
    state = state.copy(theme: value);
    await EatMeApi.secure.write(key: 'eatme.theme', value: value.name);
  }

  Future<void> setLocale(String value) async {
    state = state.copy(locale: Locale(value));
    await EatMeApi.secure.write(key: 'eatme.locale', value: value);
  }

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
