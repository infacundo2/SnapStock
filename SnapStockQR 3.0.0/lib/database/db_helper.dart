import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/registro_model.dart';

class DbHelper {
  static Future<Database> _openDB() async {
    return openDatabase(
      join(await getDatabasesPath(), 'catalogo.db'),
      onCreate: (db, version) {
        // Estructura oficial v3: foto_paths (plural y con guion bajo)
        return db.execute(
          "CREATE TABLE registros(id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT, nombre TEXT, fecha TEXT, observaciones TEXT, categoria TEXT, foto_paths TEXT)",
        );
      },
      version: 3, // SUBIMOS A LA VERSIÓN 3 PARA RENOMBRAR LA COLUMNA
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE registros ADD COLUMN uuid TEXT");
        }
        if (oldVersion < 3) {
          // Migración segura: Agregamos la nueva columna y pasamos los datos si existían
          try {
            await db.execute(
              "ALTER TABLE registros ADD COLUMN foto_paths TEXT",
            );
            // Intentamos copiar los datos de la columna vieja a la nueva si existe
            await db.execute("UPDATE registros SET foto_paths = fotoPath");
          } catch (e) {
            debugPrint(">>> [DB] Aviso de migración: $e");
          }
        }
      },
    );
  }

  static Future<int> insertar(Registro registro) async {
    final db = await _openDB();
    return db.insert('registros', registro.toMap());
  }

  static Future<List<Registro>> obtenerTodos() async {
    final db = await _openDB();
    final List<Map<String, dynamic>> maps = await db.query(
      'registros',
      orderBy: "id DESC",
    );
    return List.generate(maps.length, (i) => Registro.fromMap(maps[i]));
  }

  static Future<int> actualizar(Registro registro) async {
    final db = await _openDB();
    return await db.update(
      'registros',
      registro.toMap(),
      where: 'id = ?',
      whereArgs: [registro.id],
    );
  }

  static Future<int> eliminar(int id) async {
    final db = await _openDB();
    return await db.delete('registros', where: 'id = ?', whereArgs: [id]);
  }
}
