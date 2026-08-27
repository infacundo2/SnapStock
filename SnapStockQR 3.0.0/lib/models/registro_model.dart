import 'package:uuid/uuid.dart';

class Registro {
  int? id;
  String uuid;
  String nombre;
  String fecha;
  String observaciones;
  String categoria;
  String fotoPaths; // Rutas de las fotos separadas por comas

  Registro({
    this.id,
    String? uuid,
    required this.nombre,
    required this.fecha,
    required this.observaciones,
    required this.categoria,
    required this.fotoPaths,
  }) : uuid = uuid ?? const Uuid().v4();

  List<String> get listaFotos => fotoPaths
      .split(',')
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty)
      .toSet()
      .toList(growable: false);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'nombre': nombre,
      'fecha': fecha,
      'observaciones': observaciones,
      'categoria': categoria,
      'foto_paths': fotoPaths,
    };
  }

  factory Registro.fromMap(Map<String, dynamic> map) {
    return Registro(
      id: _asInt(map['id']),
      uuid: map['uuid']?.toString().trim().isNotEmpty == true
          ? map['uuid'].toString()
          : const Uuid().v4(),
      nombre: map['nombre']?.toString() ?? '',
      fecha: map['fecha']?.toString() ?? '',
      observaciones: map['observaciones']?.toString() ?? '',
      categoria: map['categoria']?.toString() ?? 'General',
      fotoPaths:
          (map['foto_paths'] ?? map['foto_path'] ?? map['fotoPath'] ?? '')
              .toString(),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
