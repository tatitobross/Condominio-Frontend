import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

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
      // HttpRequest.request treats a useful 422 validation response as a
      // network exception. Using load-end lets us read Laravel's real message.
      final result = await _request(path, method: method, body: body);
      final text = result.responseText ?? '';
      final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      final status = result.status ?? 0;
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

  Future<html.HttpRequest> _request(String path, {required String method, Map<String, dynamic>? body}) {
    final request = html.HttpRequest();
    final done = Completer<html.HttpRequest>();
    request.open(method, '$apiBaseUrl$path');
    request.setRequestHeader('Accept', 'application/json');
    request.setRequestHeader('Authorization', 'Bearer $token');
    if (body != null) request.setRequestHeader('Content-Type', 'application/json');
    request.onLoadEnd.listen((_) { if (!done.isCompleted) done.complete(request); });
    request.onError.listen((_) { if (!done.isCompleted) done.completeError(TimeoutException('No se pudo conectar con Laravel.')); });
    request.send(body == null ? null : jsonEncode(body));
    return done.future.timeout(const Duration(seconds: 15));
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
