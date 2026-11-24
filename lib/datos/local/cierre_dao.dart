import 'package:sqflite/sqflite.dart';

import '../../dominio/cierre_mes.dart';
import '../db/base_datos.dart';
import '../db/esquema.dart';

/// Acceso crudo a la tabla de meses cerrados.
class CierreDao {
  /// Sin base, usa la de la app. Las pruebas le pasan una en memoria.
  CierreDao({this.database});
  final Database? database;
  Future<Database> get _db async =>
      database ?? await BaseDatos.instancia.abrir();

  Future<List<CierreMes>> listar() async {
    final db = await _db;
    final filas = await db.query(Esquema.tablaCierres, orderBy: 'anio, mes');
    return filas.map(CierreMes.desdeMapa).toList();
  }

  /// La llave (año, mes) no deja cerrar dos veces el mismo mes.
  Future<void> insertar(CierreMes cierre) async {
    final db = await _db;
    await db.insert(
      Esquema.tablaCierres,
      cierre.aMapa(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }
}
