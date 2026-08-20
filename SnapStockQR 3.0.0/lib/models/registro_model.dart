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

  List<String> get listaFotos =>
      fotoPaths.split(',').where((s) => s.isNotEmpty).toList();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'nombre': nombre,
      'fecha': fecha,
      'observaciones': observaciones,
      'categoria': categoria,
      'foto_paths':
          fotoPaths, // CORREGIDO: Coincide exactamente con la columna de Supabase
    };
  }

  factory Registro.fromMap(Map<String, dynamic> map) {
    return Registro(
      id: map['id'],
      uuid: map['uuid'] ?? const Uuid().v4(),
      nombre: map['nombre'],
      fecha: map['fecha'],
      observaciones: map['observaciones'],
      categoria: map['categoria'],
      // Buscamos en todas las variantes posibles por compatibilidad
      fotoPaths: map['foto_paths'] ?? map['foto_path'] ?? map['fotoPath'] ?? "",
    );
  }
}
