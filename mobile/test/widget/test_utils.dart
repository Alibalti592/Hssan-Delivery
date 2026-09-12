import 'dart:convert';

import 'package:http/http.dart' as http;

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// Wraps a list in the backend's `{"items": [...], "meta": {...}}`
/// pagination envelope, matching what PagedResult.fromJson expects.
Map<String, dynamic> pagedBody(
  List<dynamic> items, {
  int page = 1,
  int pages = 1,
}) => {
  'items': items,
  'meta': {'page': page, 'limit': 20, 'total': items.length, 'pages': pages},
};
