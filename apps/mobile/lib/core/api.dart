import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.code, {this.offline = false});
  final String code;
  final bool offline;
  @override
  String toString() => code;
}

class SecureAuthStorage extends LocalStorage {
  const SecureAuthStorage();
  static const storage = FlutterSecureStorage();
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async =>
      await storage.containsKey(key: 'eatme.supabase.session');
  @override
  Future<String?> accessToken() => storage.read(key: 'eatme.supabase.session');
  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(key: 'eatme.supabase.session', value: persistSessionString);
  @override
  Future<void> removePersistedSession() =>
      storage.delete(key: 'eatme.supabase.session');
}

class Mutation {
  String? _fingerprint, _key;
  Future<Json> send(EatMeApi api, String method, String path, Json body) async {
    final fingerprint = jsonEncode([method, path, body]);
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _key = api.newOperation();
    }
    final result = await api.request(
      method,
      path,
      body: body,
      operationKey: _key,
    );
    _fingerprint = _key = null;
    return result;
  }
}

class EatMeApi {
  EatMeApi()
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 20),
          contentType: 'application/json',
        ),
      ) {
    if (kReleaseMode && (development || !baseUrl.startsWith('https://'))) {
      throw StateError('Release builds require HTTPS and Supabase auth.');
    }
  }
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );
  static const development =
      String.fromEnvironment('AUTH_MODE', defaultValue: 'development') ==
      'development';
  static const oauthEnabled = bool.fromEnvironment(
    'OAUTH_ENABLED',
    defaultValue: false,
  );
  static const redirect = 'dev.eatme.app://login-callback';
  static const secure = FlutterSecureStorage();
  final Dio dio;
  String? localToken, localUserId;
  String? get token => development
      ? localToken
      : Supabase.instance.client.auth.currentSession?.accessToken;
  String? get userId =>
      development ? localUserId : Supabase.instance.client.auth.currentUser?.id;

  Future<void> restore() async {
    localToken = await secure.read(key: 'eatme.token');
    localUserId = await secure.read(key: 'eatme.user');
  }

  Future<Json> request(
    String method,
    String path, {
    Json? body,
    String? operationKey,
  }) async {
    try {
      final result = await dio.request<dynamic>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            if (operationKey != null) 'Idempotency-Key': operationKey,
          },
        ),
      );
      return Map<String, dynamic>.from(result.data as Map);
    } on DioException catch (error) {
      final data = error.response?.data;
      final code = data is Map && data['error'] is Map
          ? data['error']['code'] as String?
          : null;
      throw ApiFailure(
        code ??
            (error.response?.statusCode == 401
                ? 'unauthorized'
                : 'network_error'),
        offline: error.response == null,
      );
    }
  }

  // A mutation keeps its key until success. The caller owns it across manual retries.
  String newOperation() => const Uuid().v4();

  Future<bool> login(
    String email,
    String password, {
    required bool register,
  }) async {
    if (development) {
      final result = await request(
        'POST',
        register ? '/auth/register' : '/auth/login',
        body: {'email': email, 'password': password},
      );
      localToken = result['access_token'] as String;
      localUserId = result['user_id'] as String;
      await secure.write(key: 'eatme.token', value: localToken);
      await secure.write(key: 'eatme.user', value: localUserId);
      return true;
    }
    final auth = Supabase.instance.client.auth;
    final result = register
        ? await auth.signUp(
            email: email,
            password: password,
            emailRedirectTo: redirect,
          )
        : await auth.signInWithPassword(email: email, password: password);
    return result.session != null;
  }

  Future<void> oauth(OAuthProvider provider) async {
    if (development || !oauthEnabled)
      throw const ApiFailure('oauth_not_configured');
    await Supabase.instance.client.auth.signInWithOAuth(
      provider,
      redirectTo: redirect,
    );
  }

  Future<void> resetPassword(String email) async {
    if (development) throw const ApiFailure('reset_not_configured');
    await Supabase.instance.client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirect,
    );
  }

  Future<void> logout() async {
    if (development && token != null) {
      await request('POST', '/auth/logout');
    } else if (!development) {
      await Supabase.instance.client.auth.signOut();
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    if (!development && Supabase.instance.client.auth.currentSession != null) {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    }
    localToken = localUserId = null;
    for (final key in ['eatme.token', 'eatme.user', 'eatme.inventory']) {
      await secure.delete(key: key);
    }
  }

  Future<void> cacheInventory(Json inventory) async {
    await secure.write(
      key: 'eatme.inventory',
      value: jsonEncode({
        'user_id': userId,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'data': inventory,
      }),
    );
  }

  Future<Json?> cachedInventory() async {
    final stored = await secure.read(key: 'eatme.inventory');
    if (stored == null) return null;
    final cached = jsonDecode(stored) as Map;
    if (cached['user_id'] != userId) return null;
    return Map<String, dynamic>.from(cached['data'] as Map);
  }
}
