import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatme/core/api.dart';
import 'package:eatme/core/models.dart';
import 'package:eatme/core/state.dart';

class BootstrapApi extends EatMeApi {
  BootstrapApi() {
    localToken = 'local-test-token';
    localUserId = 'account-a';
  }

  bool connected = false;

  @override
  Future<void> restore() async {}

  @override
  Future<void> sync() async {}

  @override
  Future<Json?> cachedRecommendations(String mode, String slot) async => snapshot;

  Json? snapshot;
  bool failRecommendations = false;

  @override
  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
    bool allowCache = true,
  }) async {
    if (!connected || path == '/notifications') {
      // A headless widget test has no native notification plugin.
      throw const ApiFailure('network_error', offline: true);
    }
    if (path == '/config') return {'auth_mode': 'development'};
    if (path == '/profile') {
      return {
        'user_id': localUserId,
        'household_id': 'household-a',
        'onboarded': true,
      };
    }
    if (path == '/catalog') {
      return {'foods': <Json>[], 'diets': <Json>[], 'allergens': <String>[]};
    }
    if (path.startsWith('/recommendations') && failRecommendations) {
      throw const ApiFailure('service_unavailable');
    }
    return {'items': <Json>[]};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('startup restores recommendations and retains them when refresh fails', () async {
    final api = BootstrapApi()..connected = true..failRecommendations = true;
    api.snapshot = {
      'contextual': <Json>[],
      'items': [{
        'recipe': {'id': 'cached-recipe', 'title': {'en': 'Cached recipe'}, 'minutes': 15, 'servings': 2, 'ingredients': <Json>[], 'steps': {'en': ['Cook.']}},
        'available_count': 0, 'ingredient_count': 0, 'use_soon_food_ids': <String>[], 'warnings': <Json>[],
      }],
    };
    final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);
    await container.read(appProvider.notifier).restore();
    expect(container.read(appProvider).stage, Stage.ready);
    expect(container.read(appProvider).recommendations.single.recipe.id, 'cached-recipe');
    expect(container.read(appProvider).error, 'service_unavailable');
  });

  test('transport failures and server failures have actionable codes', () {
    final options = RequestOptions(path: '/config');
    DioException failure(DioExceptionType type, {int? status}) => DioException(
      requestOptions: options,
      type: type,
      response: status == null
          ? null
          : Response<dynamic>(requestOptions: options, statusCode: status),
    );

    expect(
      apiFailureCode(failure(DioExceptionType.connectionTimeout)),
      'connection_timeout',
    );
    expect(
      apiFailureCode(failure(DioExceptionType.badCertificate)),
      'secure_connection_failed',
    );
    expect(
      apiFailureCode(failure(DioExceptionType.badResponse, status: 503)),
      'service_unavailable',
    );
    expect(
      apiFailureCode(failure(DioExceptionType.badResponse, status: 401)),
      'unauthorized',
    );
    expect(
      isRetryableReadFailure(
        failure(DioExceptionType.badResponse, status: 503),
      ),
      isTrue,
    );
    expect(
      isRetryableReadFailure(
        failure(DioExceptionType.badResponse, status: 401),
      ),
      isFalse,
    );
    expect(
      isRetryableReadFailure(failure(DioExceptionType.badCertificate)),
      isFalse,
    );
  });

  test('GET retries twice then uses the encrypted account snapshot', () async {
    final api = EatMeApi()
      ..localToken = 'local-test-token'
      ..localUserId = 'account-a';
    var connected = true;
    var attempts = 0;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          attempts++;
          if (!connected) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {'auth_mode': 'development'},
            ),
          );
        },
      ),
    );

    await api.request('GET', '/config');
    connected = false;
    final snapshot = await api.request('GET', '/config');
    expect(snapshot['auth_mode'], 'development');
    expect(snapshot['_offline'], isTrue);
    expect(api.offline, isTrue);
    expect(attempts, 4);
  });

  test(
    'mutation is attempted once and is never automatically replayed',
    () async {
      final api = EatMeApi()
        ..localToken = 'local-test-token'
        ..localUserId = 'account-a';
      var attempts = 0;
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            attempts++;
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );

      await expectLater(
        api.request('POST', '/shopping', body: {'action': 'add'}),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.code,
            'code',
            'network_error',
          ),
        ),
      );
      expect(attempts, 1);
    },
  );

  test(
    'failed startup retains authentication and restores usable session',
    () async {
      final api = BootstrapApi();
      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final app = container.read(appProvider.notifier);

      await app.restore();
      expect(container.read(appProvider).stage, Stage.failed);
      expect(api.localToken, 'local-test-token');

      api.connected = true;
      await app.restore();
      expect(container.read(appProvider).stage, Stage.ready);

      api.connected = false;
      await app.restore();
      final offline = container.read(appProvider);
      expect(offline.stage, Stage.ready);
      expect(offline.offline, isTrue);
      expect(offline.profile['user_id'], 'account-a');
      expect(api.localToken, 'local-test-token');

      // Never reuse account A's in-memory profile for account B.
      api.localUserId = 'account-b';
      await app.restore();
      expect(container.read(appProvider).stage, Stage.failed);
    },
  );
}
