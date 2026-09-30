import 'package:sqflite/sqflite.dart';

import '../../dominio/fondo.dart';
import '../db/base_datos.dart';
import '../db/esquema.dart';

/// Lee y escribe el efectivo del negocio: la única fila de su tabla.
class FondoDao {
  /// Sin base, usa la de la app. Las pruebas le pasan una en memoria.
  FondoDao({this.database});
  final Database? database;

  Future<Database> get _db async =>
      database ?? await BaseDatos.instancia.abrir();

  /// Null mientras no se contó.
  Future<FondoNegocio?> leer() async {
    final db = await _db;
    final filas = await db.query(Esquema.tablaFondo, where: 'id = 1', limit: 1);
    return filas.isEmpty ? null : FondoNegocio.desdeMapa(filas.first);
  }

  /// Con id fijo, insertar con reemplazo sirve para el conteo y para la
  /// corrección.
  Future<void> guardar(FondoNegocio fondo) async {
    final db = await _db;
    await db.insert(
      Esquema.tablaFondo,
      fondo.aMapa(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
