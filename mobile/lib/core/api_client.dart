import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_exception.dart';

/// Thin JSON wrapper around `package:http`.
///
/// Injects the bearer token, decodes JSON bodies, turns non-2xx responses into
/// [ApiException] (using the backend's `{"message": ...}` shape), and connection
/// failures into [NetworkException]. A 401 additionally fires [onUnauthorized]
/// so the app can drop back to the login screen.
class ApiClient {
  ApiClient({
    required String? Function() tokenProvider,
    required this.onUnauthorized,
    http.Client? httpClient,
  }) : _tokenProvider = tokenProvider,
       _http = httpClient ?? http.Client();

  final String? Function() _tokenProvider;
  final void Function() onUnauthorized;
  final http.Client _http;

  static const _timeout = Duration(seconds: 15);

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body);

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);

  Future<dynamic> delete(String path, [Object? body]) =>
      _send('DELETE', path, body);

  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body);

  /// Uploads one file as multipart/form-data under [field] — for the few
  /// endpoints that take a photo (see BillsRepository.uploadBillPhoto).
  Future<dynamic> postFile(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
    );
    request.headers.addAll(authHeaders);
    request.headers['Accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes(field, bytes, filename: filename),
    );

    http.Response response;
    try {
      // Photos can take a while on a slow connection.
      final streamed = await _http
          .send(request)
          .timeout(const Duration(seconds: 60));
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw NetworkException('Le serveur met trop de temps à répondre.');
    } on http.ClientException {
      throw NetworkException();
    }

    return _decode(response);
  }

  /// The bearer header, for loading a protected image with
  /// Image.network(headers: ...) — the bill photo, which is never public.
  Map<String, String> get authHeaders {
    final token = _tokenProvider();
    return token == null ? const {} : {'Authorization': 'Bearer $token'};
  }

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final request = http.Request(method, uri);

    request.headers['Accept'] = 'application/json';

    final token = _tokenProvider();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    http.Response response;
    try {
      final streamed = await _http.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw NetworkException('Le serveur met trop de temps à répondre.');
    } on http.ClientException {
      throw NetworkException();
    }

    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final status = response.statusCode;

    dynamic json;
    if (response.body.isNotEmpty) {
      try {
        json = jsonDecode(response.body);
      } on FormatException {
        json = null;
      }
    }

    if (status >= 200 && status < 300) {
      return json;
    }

    if (status == 401) {
      onUnauthorized();
    }

    throw ApiException(status, errorMessage(status, json));
  }

  /// What to tell the user about a failed request: the first field error
  /// of a validation failure (the top-level message is a generic
  /// "Validation failed."), the server's own message otherwise, and plain
  /// words instead of a status code for a server error or rate limit.
  @visibleForTesting
  static String errorMessage(int status, dynamic json) {
    if (status >= 500) {
      return 'Le service est momentanément indisponible. Réessayez dans un instant.';
    }
    if (status == 429) {
      return 'Trop de tentatives. Réessayez dans une minute.';
    }
    if (json is Map) {
      final errors = json['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map && first['message'] is String) {
          return first['message'] as String;
        }
      }
      if (json['message'] is String) return json['message'] as String;
    }
    return 'La requête a échoué. Réessayez.';
  }

  void close() => _http.close();
}
