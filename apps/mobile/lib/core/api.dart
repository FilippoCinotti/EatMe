import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'offline.dart';

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
    Json result;
    try {
      result = await api.request(method, path, body: body, operationKey: _key);
    } on ApiFailure catch (error) {
      if (!error.offline || !api.canQueue(method, path, body)) rethrow;
      await api.enqueue(method, path, body, _key!);
      result = {'queued': true};
    }
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
  bool offline = false;
  bool syncing = false;
  Future<void> _queueWrite = Future.value();
  OfflineStore? get cache => userId == null ? null : OfflineStore(userId!);
  bool cacheable(String path) => !path.startsWith('/privacy') && !path.startsWith('/admin') && !path.startsWith('/products') && !path.startsWith('/entitlements') && path != '/health';
  bool canQueue(String method, String path, Json body) =>
      (path == '/shopping' && ['add', 'edit', 'check', 'delete'].contains(body['action'])) ||
      (path == '/plans' && body['action'] == 'save') ||
      (path.startsWith('/inventory/') && method == 'PATCH');

  Future<void> enqueue(String method, String path, Json body, String key) async {
    final current = cache;
    if (current == null) throw const ApiFailure('unauthorized');
    final operation = _queueWrite.then((_) async {
      final pending = await current.pending();
      if (pending.any((e) => e['key'] == key)) return;
      if (pending.length >= 50) throw const ApiFailure('offline_queue_full');
      final profile = await current.read('/profile');
      pending.add({'method': method, 'path': path, 'body': body, 'key': key, 'household_id': profile?['household_id'], 'status': 'pending'});
      await current.savePending(pending);
    });
    _queueWrite = operation.catchError((Object _) {});
    await operation;
  }

  Future<void> sync() async {
    if (syncing || cache == null) return;
    syncing = true;
    try {
      await _queueWrite;
      final current = cache!;
      final profile = await request('GET', '/profile', allowCache: false);
      final pending = await current.pending();
      while (pending.isNotEmpty) {
        final item = pending.first;
        if (item['household_id'] != profile['household_id']) {
          item['status'] = 'household_changed';
          await current.savePending(pending); break;
        }
        try {
          await request(item['method'] as String, item['path'] as String,
            body: Map<String, dynamic>.from(item['body'] as Map), operationKey: item['key'] as String, allowCache: false);
          pending.removeAt(0);
          await current.savePending(pending);
        } on ApiFailure catch (error) {
          if (error.offline) break;
          item['status'] = error.code;
          await current.savePending(pending); break;
        }
      }
    } on ApiFailure { /* Keep the encrypted outbox for the next explicit retry. */ }
    finally { syncing = false; }
  }
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
    bool allowCache = true,
  }) async {
    try {
      final result = await dio.request<dynamic>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Idempotency-Key': ?operationKey,
          },
        ),
      );
      final value = Map<String, dynamic>.from(result.data as Map);
      offline = false;
      if (method == 'GET' && cacheable(path)) await cache?.cache(path, value);
      return value;
    } on DioException catch (error) {
      if (error.response == null && method == 'GET' && allowCache && cacheable(path)) {
        final saved = await cache?.read(path);
        if (saved != null) { offline = true; return saved; }
      }
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
    if (development || !oauthEnabled) {
      throw const ApiFailure('oauth_not_configured');
    }
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
    await cache?.clear();
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
