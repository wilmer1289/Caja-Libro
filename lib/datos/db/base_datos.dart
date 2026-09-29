import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'esquema.dart';

/// Abre la base local. Android trae SQLite de fábrica; Windows necesita que
/// se inicialice el motor FFI antes del primer `openDatabase`, así que el
/// arranque se resuelve aquí y el resto de la app no se entera de la diferencia.
class BaseDatos {
  BaseDatos._();
  static final BaseDatos instancia = BaseDatos._();

  Database? _db;
  Future<Database>? _abriendo;

  Future<Database> abrir() {
    final abierta = _db;
    if (abierta != null) return Future.value(abierta);
    return _abriendo ??= _abrir().whenComplete(() => _abriendo = null);
  }

  Future<Database> _abrir() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final carpeta = await getApplicationDocumentsDirectory();
    final ruta = p.join(carpeta.path, 'mi_caja.db');

    return _db = await databaseFactory.openDatabase(ruta, options: opciones);
  }

  /// Cómo se crea y cómo se migra la base. Está aparte para que las pruebas
  /// abran una base de versión vieja con exactamente esta migración, y no
  /// con una copia que se podría desincronizar.
  static final opciones = OpenDatabaseOptions(
    version: Esquema.version,
    onCreate: (db, _) async {
      await db.execute(Esquema.crearMovimientos);
      await db.execute(Esquema.crearNegocio);
      await db.execute(Esquema.crearCategorias);
      await db.execute(Esquema.crearJornadas);
      for (final indice in Esquema.indices) {
        await db.execute(indice);
      }
    },
    onUpgrade: (db, desde, hasta) async {
      // Migrar y no recrear: el usuario ya tiene movimientos anotados y
      // borrar la base para "empezar limpio" sería perderle la plata.
      if (desde < 2) {
        for (final paso in Esquema.migracionV2) {
          await db.execute(paso);
        }
      }
      // v3 sólo agrega una tabla: lo que ya estaba no se toca.
      if (desde < 3) await db.execute(Esquema.crearCategorias);
      if (desde < 4) {
        for (final paso in Esquema.migracionV4) {
          await db.execute(paso);
        }
      }
      if (desde < 5) {
        for (final paso in Esquema.migracionV5) {
          await db.execute(paso);
        }
      }
    },
  );

  Future<void> cerrar() async {
    await _db?.close();
    _db = null;
  }
}
