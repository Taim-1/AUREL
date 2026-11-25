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
    if (!{'spotify', 'apple_music', 'soundcloud'}.contains(key)) {
      throw const CatalogTokenException('Unknown music provider.');
    }

    final user = account.currentUser;
    if (user == null) {
      throw CatalogTokenException(
        'Sign in to your AUREL account before using $provider catalog search.',
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
      throw CatalogTokenException(
        '$provider catalog access requires a connected AUREL account.',
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
          'The music provider token service returned an empty token.',
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
      final body = error.response?.data;
      final message = body is Map
          ? (body['message'] ?? body['error']?['message'] ?? '').toString()
          : '';
      if (status == 401) {
        throw const CatalogTokenException(
          'Your AUREL session expired. Sign in again to use this source.',
        );
      }
      if (status == 404 || status == 503) {
        throw CatalogTokenException(
          message.isNotEmpty
              ? message
              : 'This source is not configured on the AUREL server yet.',
        );
      }
      if (status == 429) {
        throw const CatalogTokenException(
          'Music services are busy. Please try again shortly.',
        );
      }
      throw CatalogTokenException(
        message.isNotEmpty
            ? message
            : 'Could not connect to the AUREL music provider gateway.',
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
