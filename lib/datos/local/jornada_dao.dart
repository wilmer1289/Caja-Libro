import 'package:sqflite/sqflite.dart';

import '../../dominio/jornada.dart';
import '../db/base_datos.dart';
import '../db/esquema.dart';

/// Las cajas: se abren, se cierran y se leen. Un cierre firmado no se
/// corrige; lo único que se le agrega después es el ajuste del faltante o
/// el sobrante, si se lleva al libro.
class JornadaDao {
  /// Sin base, usa la de la app. Las pruebas le pasan una en memoria.
  JornadaDao({this.database});
  final Database? database;

  Future<Database> get _db async =>
      database ?? await BaseDatos.instancia.abrir();

  /// De la más nueva a la más vieja.
  Future<List<Jornada>> listar() async {
    final db = await _db;
    final filas = await db.query(
      Esquema.tablaJornadas,
      orderBy: 'abierta_en DESC, numero DESC',
    );
    return filas.map(Jornada.desdeMapa).toList();
  }

  /// Guarda una caja nueva con el número que le toca. Falla si ya hay una
  /// abierta: dos cajas a la vez se repartirían los mismos movimientos.
  Future<Jornada> abrir(Jornada Function(int numero) crear) async {
    final db = await _db;
    return db.transaction((txn) async {
      final abiertas = Sqflite.firstIntValue(
        await txn.rawQuery(
          'SELECT COUNT(*) FROM ${Esquema.tablaJornadas} '
          'WHERE cerrada_en IS NULL',
        ),
      );
      if ((abiertas ?? 0) > 0) {
        throw ArgumentError('Ya hay una caja abierta: ciérrala primero.');
      }
      final ultimo = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT MAX(numero) FROM ${Esquema.tablaJornadas}'),
      );
      final caja = crear((ultimo ?? 0) + 1);
      await txn.insert(
        Esquema.tablaJornadas,
        caja.aMapa(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return caja;
    });
  }

  /// Guarda el cierre (o el ajuste) de una caja que ya existe.
  Future<void> actualizar(Jornada caja) async {
    final db = await _db;
    await db.update(
      Esquema.tablaJornadas,
      caja.aMapa(),
      where: 'id = ?',
      whereArgs: [caja.id],
    );
  }
}
