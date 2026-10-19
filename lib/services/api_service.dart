import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
}

class Api {
  Api(this.token);
  final String token;

  Future<dynamic> call(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    try {
      final result = await _request(path, method: method, body: body);
      final text = result.body;
      final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      final status = result.statusCode;
      if (status < 200 || status >= 300) throw ApiException(errorText(decoded));
      return decoded;
    } on TimeoutException {
      throw ApiException('No se pudo conectar con Laravel en $apiBaseUrl.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('La respuesta del servidor no es válida.');
    }
  }

  Future<http.Response> _request(String path, {required String method, Map<String, dynamic>? body}) async {
    final request = http.Request(method, Uri.parse('$apiBaseUrl$path'));
    request.headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer $token', if (body != null) 'Content-Type': 'application/json'});
    request.body = body == null ? '' : jsonEncode(body);
    return http.Response.fromStream(await request.send().timeout(const Duration(seconds: 15)));
  }
}

String errorText(dynamic response) {
  if (response is Map) {
    if (response['message'] != null) return response['message'].toString();
    final errors = response['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
  }
  return 'No se pudo completar la operación.';
}
