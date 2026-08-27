import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/registro_model.dart';

class DbHelper {
  static Future<Database> _openDB() async {
    return openDatabase(
      join(await getDatabasesPath(), 'catalogo.db'),
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE registros(
            id INTEGER,
            uuid TEXT NOT NULL UNIQUE,
            nombre TEXT NOT NULL,
            fecha TEXT NOT NULL,
            observaciones TEXT NOT NULL DEFAULT '',
            categoria TEXT NOT NULL DEFAULT 'General',
            foto_paths TEXT NOT NULL DEFAULT ''
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE registros ADD COLUMN uuid TEXT');
        }
        if (oldVersion < 3) {
          try {
            await db.execute(
              'ALTER TABLE registros ADD COLUMN foto_paths TEXT',
            );
            await db.execute('UPDATE registros SET foto_paths = fotoPath');
          } catch (_) {
            // La columna puede existir en instalaciones que ya migraron.
          }
        }
        if (oldVersion < 4) {
          await db.execute(
            'DELETE FROM registros WHERE rowid NOT IN '
            '(SELECT MAX(rowid) FROM registros GROUP BY uuid)',
          );
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS '
            'idx_registros_uuid ON registros(uuid)',
          );
        }
      },
    );
  }

  static Future<int> guardar(Registro registro) async {
    final db = await _openDB();
    return db.insert(
      'registros',
      registro.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Registro>> obtenerTodos() async {
    final db = await _openDB();
    final maps = await db.query('registros', orderBy: 'id DESC');
    return maps.map(Registro.fromMap).toList(growable: false);
  }

  static Future<void> reemplazarTodos(List<Registro> registros) async {
    final db = await _openDB();
    await db.transaction((txn) async {
      await txn.delete('registros');
      for (final registro in registros) {
        await txn.insert(
          'registros',
          registro.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<int> eliminarPorUuid(String uuid) async {
    final db = await _openDB();
    return db.delete('registros', where: 'uuid = ?', whereArgs: [uuid]);
  }
}
