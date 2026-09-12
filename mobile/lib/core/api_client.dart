import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  Future<dynamic> delete(String path, [Object? body]) =>
      _send('DELETE', path, body);

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

    final message = (json is Map && json['message'] is String)
        ? json['message'] as String
        : 'La requête a échoué ($status).';

    throw ApiException(status, message);
  }

  void close() => _http.close();
}
