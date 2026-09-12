/// A failed API call, carrying the HTTP status and the server's message.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// The request never reached the server (no connection, DNS failure, timeout).
class NetworkException implements Exception {
  NetworkException([this.message = 'Impossible de contacter le serveur.']);

  final String message;

  @override
  String toString() => message;
}
