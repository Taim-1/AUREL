import 'package:dio/dio.dart';

import 'aurel_account_service.dart';

class CatalogTokenException implements Exception {
  const CatalogTokenException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CatalogTokenService {
  CatalogTokenService({
    required this.account,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 10),
                responseType: ResponseType.json,
              ),
            );

  final AurelAccountService account;
  final Dio _dio;
  final Map<String, _CachedProviderToken> _cache = {};

  bool get canRequestTokens => account.isConfigured && account.isSignedIn;

  Future<String> tokenFor(String provider) async {
    final key = provider.trim().toLowerCase();
    if (!{'spotify', 'apple_music', 'soundcloud', 'openverse'}.contains(key)) {
      throw const CatalogTokenException(
        'This catalogue connection is unavailable.',
      );
    }

    final user = account.currentUser;
    if (user == null) {
      throw const CatalogTokenException(
        'Sign in to AUREL to enable additional catalogue results.',
      );
    }

    final cached = _cache[key];
    if (cached != null &&
        cached.expiresAt.isAfter(
          DateTime.now().add(const Duration(minutes: 2)),
        )) {
      return cached.value;
    }

    final projectId = account.firebaseProjectId;
    if (projectId == null || projectId.isEmpty) {
      throw const CatalogTokenException(
        'This catalogue connection is not configured yet.',
      );
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const CatalogTokenException(
        'AUREL could not verify your account. Sign in again.',
      );
    }

    final endpoint = Uri.https(
      'us-central1-$projectId.cloudfunctions.net',
      '/catalogTokens',
      {'provider': key},
    );

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        endpoint.toString(),
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        ),
      );
      final body = response.data;
      final token = (body?['token'] ?? '').toString().trim();
      if (token.isEmpty) {
        throw const CatalogTokenException(
          'Additional catalogue authentication is currently unavailable.',
        );
      }

      final expiryValue = body?['expiresAt'];
      final expiry = expiryValue == null
          ? DateTime.now().add(const Duration(minutes: 20))
          : DateTime.tryParse(expiryValue.toString()) ??
              DateTime.now().add(const Duration(minutes: 20));
      _cache[key] = _CachedProviderToken(token, expiry);
      return token;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401) {
        throw const CatalogTokenException(
          'Your AUREL session expired. Sign in again to continue.',
        );
      }
      if (status == 404 || status == 503) {
        throw const CatalogTokenException(
          'This catalogue connection is not configured yet.',
        );
      }
      if (status == 429) {
        throw const CatalogTokenException(
          'Music services are busy. Please try again shortly.',
        );
      }
      throw const CatalogTokenException(
        'Could not connect to the AUREL catalogue gateway.',
      );
    }
  }

  void clear() => _cache.clear();
}

class _CachedProviderToken {
  const _CachedProviderToken(this.value, this.expiresAt);

  final String value;
  final DateTime expiresAt;
}
