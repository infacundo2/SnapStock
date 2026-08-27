import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/registro_model.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'SNAPSTOCK_API_URL',
    defaultValue: 'https://api.jahmantencion.cl/api',
  );
  static const Duration _shortTimeout = Duration(seconds: 15);
  static const Duration _uploadTimeout = Duration(seconds: 60);
  static final http.Client _client = http.Client();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(migrateWithBackup: true),
  );

  static Future<bool> hasActiveSession() async {
    try {
      final token = await _secureStorage.read(key: 'authToken');
      final expiresText = await _secureStorage.read(key: 'tokenExpiresAt');
      final expiresAt =
          expiresText == null ? null : DateTime.tryParse(expiresText);
      final active = token != null &&
          token.isNotEmpty &&
          expiresAt != null &&
          expiresAt.isAfter(
            DateTime.now().toUtc().add(const Duration(minutes: 1)),
          );
      if (!active) await clearSession();
      return active;
    } catch (_) {
      await _resetSecureSession();
      return false;
    }
  }

  static Future<void> saveSession(Map<String, dynamic> response) async {
    final token = response['token']?.toString();
    final expiresAt = response['expiresAt']?.toString();
    final userName = response['nombre']?.toString();
    final userType = _asInt(response['tipo']);
    if (token == null ||
        token.isEmpty ||
        expiresAt == null ||
        userName == null) {
      throw const ApiException('El servidor devolvió una sesión incompleta.');
    }

    final prefs = await SharedPreferences.getInstance();
    try {
      await _secureStorage.write(key: 'authToken', value: token);
      await _secureStorage.write(key: 'tokenExpiresAt', value: expiresAt);
    } catch (_) {
      await _resetSecureSession();
      throw const ApiException(
          'No fue posible guardar la sesión de forma segura.');
    }
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('userType', userType);
    await prefs.setString('userName', userName);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _secureStorage.delete(key: 'authToken');
      await _secureStorage.delete(key: 'tokenExpiresAt');
    } catch (_) {
      await _resetSecureSession();
    }
    await prefs.remove('isLoggedIn');
    await prefs.remove('userType');
    await prefs.remove('userName');
  }

  static Future<List<Registro>> obtenerTodos() async {
    final response = await _send(
      () async => _client
          .get(
            Uri.parse('$baseUrl/Registros'),
            headers: await _authorizedHeaders(),
          )
          .timeout(_shortTimeout),
      action: 'cargar el inventario',
    );
    _requireSuccess(response);
    final data = _decodeList(response);
    return data
        .map((item) => Registro.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  static Future<String> guardar(
    Registro registro,
    List<File> fotosNuevas,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/Registros/guardar'),
      );
      request.headers.addAll(await _authorizedHeaders());
      request.fields.addAll({
        'uuid': registro.uuid,
        'nombre': registro.nombre,
        'fecha': registro.fecha,
        'observaciones': registro.observaciones,
        'categoria': registro.categoria,
        'foto_paths': registro.fotoPaths,
      });

      for (final foto in fotosNuevas) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'fotos',
            foto.path,
            contentType: _imageContentType(foto.path),
          ),
        );
      }

      final streamed = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamed);
      _requireSuccess(response);
      final body = _decodeObject(response);
      return body['paths']?.toString() ?? registro.fotoPaths;
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No hay conexión con el servidor.');
    } on TimeoutException {
      throw const ApiException(
        'La carga está tardando demasiado. Revise la conexión e inténtelo nuevamente.',
      );
    } catch (_) {
      throw const ApiException('No fue posible guardar el registro.');
    }
  }

  static http.MediaType _imageContentType(String path) {
    final extension =
        path.split(RegExp(r'[/\\]')).last.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => http.MediaType('image', 'jpeg'),
      'png' => http.MediaType('image', 'png'),
      'webp' => http.MediaType('image', 'webp'),
      _ => http.MediaType('application', 'octet-stream'),
    };
  }

  static Future<bool> eliminar(String uuid) async {
    final response = await _send(
      () async => _client
          .delete(
            Uri.parse('$baseUrl/Registros/eliminar/$uuid'),
            headers: await _authorizedHeaders(),
          )
          .timeout(_shortTimeout),
      action: 'eliminar el registro',
    );
    _requireSuccess(response);
    return true;
  }

  static Future<Registro?> buscarPorUuid(String uuid) async {
    final response = await _send(
      () async => _client
          .get(
            Uri.parse('$baseUrl/Registros/$uuid'),
            headers: await _authorizedHeaders(),
          )
          .timeout(_shortTimeout),
      action: 'buscar el registro',
    );
    if (response.statusCode == 404) return null;
    _requireSuccess(response);
    return Registro.fromMap(_decodeObject(response));
  }

  static Future<Map<String, dynamic>?> login(
    String nombre,
    String password,
  ) async {
    final response = await _send(
      () => _client.post(
        Uri.parse('$baseUrl/Registros/login'),
        body: {'nombre': nombre, 'password': password},
      ).timeout(_shortTimeout),
      action: 'iniciar sesión',
    );
    if (response.statusCode == 401) return null;
    _requireSuccess(response);
    return _decodeObject(response);
  }

  static Future<List<dynamic>> obtenerUsuarios() async {
    final response = await _send(
      () async => _client
          .get(
            Uri.parse('$baseUrl/Registros/usuarios'),
            headers: await _authorizedHeaders(),
          )
          .timeout(_shortTimeout),
      action: 'cargar los usuarios',
    );
    _requireSuccess(response);
    return _decodeList(response);
  }

  static Future<bool> crearUsuario(
    String nombre,
    String password,
    int tipo,
  ) async {
    final response = await _send(
      () async => _client.post(
        Uri.parse('$baseUrl/Registros/usuarios/crear'),
        headers: await _authorizedHeaders(),
        body: {
          'nombre': nombre,
          'password': password,
          'tipo': tipo.toString(),
        },
      ).timeout(_shortTimeout),
      action: 'crear el usuario',
    );
    _requireSuccess(response);
    return true;
  }

  static Future<bool> eliminarUsuario(int id) async {
    final response = await _send(
      () async => _client
          .delete(
            Uri.parse('$baseUrl/Registros/usuarios/$id'),
            headers: await _authorizedHeaders(),
          )
          .timeout(_shortTimeout),
      action: 'eliminar el usuario',
    );
    _requireSuccess(response);
    return true;
  }

  static Future<List<String>> obtenerCategorias() async {
    final response = await _send(
      () async => _client
          .get(
            Uri.parse('$baseUrl/Registros/categorias'),
            headers: await _authorizedHeaders(),
          )
          .timeout(_shortTimeout),
      action: 'cargar las categorías',
    );
    _requireSuccess(response);
    final data = _decodeList(response);
    return data.map((item) => item.toString()).toList();
  }

  static Future<Map<String, String>> _authorizedHeaders() async {
    String? token;
    try {
      token = await _secureStorage.read(key: 'authToken');
    } catch (_) {
      await _resetSecureSession();
    }
    if (token == null || token.isEmpty) {
      throw const ApiException('La sesión ha vencido.', statusCode: 401);
    }
    return {'Authorization': 'Bearer $token'};
  }

  static Future<void> _resetSecureSession() async {
    try {
      await _secureStorage.deleteAll();
    } catch (_) {
      // Android puede rechazar la primera limpieza si quedó una clave antigua inválida.
    }
  }

  static Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required String action,
  }) async {
    try {
      return await request();
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No hay conexión con el servidor.');
    } on TimeoutException {
      throw ApiException(
        'El servidor tardó demasiado en responder al intentar $action.',
      );
    } on HttpException {
      throw ApiException('No fue posible $action.');
    } catch (_) {
      throw ApiException('No fue posible $action.');
    }
  }

  static void _requireSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401) {
      throw const ApiException('La sesión ha vencido.', statusCode: 401);
    }
    if (response.statusCode == 403) {
      throw const ApiException(
        'No tiene permisos para realizar esta acción.',
        statusCode: 403,
      );
    }
    if (response.statusCode == 429) {
      throw const ApiException(
        'Demasiados intentos. Espere un minuto.',
        statusCode: 429,
      );
    }
    throw ApiException(
      _responseMessage(response),
      statusCode: response.statusCode,
    );
  }

  static String _responseMessage(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) {
        return value['message']?.toString() ??
            value['title']?.toString() ??
            'El servidor rechazó la operación.';
      }
    } catch (_) {
      // La respuesta no es JSON; se usa un mensaje neutro.
    }
    return 'El servidor rechazó la operación.';
  }

  static Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {
      // Se transforma en un error estable para la interfaz.
    }
    throw const ApiException('El servidor devolvió una respuesta no válida.');
  }

  static List<dynamic> _decodeList(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is List<dynamic>) return value;
    } catch (_) {
      // Se transforma en un error estable para la interfaz.
    }
    throw const ApiException('El servidor devolvió una lista no válida.');
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 1;
  }
}
