import 'package:sqflite/sqflite.dart';

import '../../dominio/almacen.dart';
import '../db/base_datos.dart';
import '../db/esquema.dart';

/// Acceso crudo a la tabla del kardex. No calcula costos ni decide nada: eso
/// es del kardex (P1) y del repositorio.
class KardexDao {
  /// Sin base, usa la de la app. Las pruebas le pasan una en memoria.
  KardexDao({this.database});
  final Database? database;
  Future<Database> get _db async =>
      database ?? await BaseDatos.instancia.abrir();

  /// Cada línea con la marca `anulada` de su movimiento. Las sueltas
  /// (merma, ajuste, saldo inicial…) no tienen movimiento y nunca lo están.
  static const _consulta =
      'SELECT k.*, '
      'CASE WHEN m.anulado_en IS NOT NULL THEN 1 ELSE 0 END AS anulada '
      'FROM ${Esquema.tablaKardex} AS k '
      'LEFT JOIN ${Esquema.tablaMovimientos} AS m ON m.id = k.movimiento_id';

  /// Una línea cuenta si es suelta o si su movimiento sigue vigente. Las de
  /// un movimiento borrado o anulado no cuentan; las de un borrado vuelven
  /// si se deshace el borrado.
  static const _vigente =
      'k.movimiento_id IS NULL OR '
      '(m.eliminado_en IS NULL AND m.anulado_en IS NULL)';

  /// Las líneas que cuentan, en el orden en que se anotaron.
  Future<List<LineaAlmacen>> listar() async {
    final db = await _db;
    final filas = await db.rawQuery(
      '$_consulta WHERE $_vigente ORDER BY k.fecha, k.numero',
    );
    return filas.map(LineasAlmacen.desdeMapa).toList();
  }

  /// Las de un movimiento, aunque esté anulado: salen marcadas.
  Future<List<LineaAlmacen>> deMovimiento(String movimientoId) async {
    final db = await _db;
    final filas = await db.rawQuery(
      '$_consulta WHERE k.movimiento_id = ? ORDER BY k.numero',
      [movimientoId],
    );
    return filas.map(LineasAlmacen.desdeMapa).toList();
  }

  /// Si el producto pasó alguna vez por el almacén, aunque sea en un
  /// movimiento que después se borró o se anuló.
  Future<bool> hayDeProducto(String mercaderiaId) async {
    final db = await _db;
    final filas = await db.query(
      Esquema.tablaKardex,
      columns: ['id'],
      where: 'mercaderia_id = ?',
      whereArgs: [mercaderiaId],
      limit: 1,
    );
    return filas.isNotEmpty;
  }

  /// Guarda varias líneas seguidas, numeradas desde el siguiente libre.
  /// Recibe la transacción de quien llama: así el movimiento y sus líneas
  /// entran juntos o no entra nada.
  Future<List<LineaAlmacen>> insertarEn(
    DatabaseExecutor ejecutor,
    List<LineaAlmacen> Function(int primerNumero) construir, {
    required DateTime creadoEn,
  }) async {
    final tope = await ejecutor.rawQuery(
      'SELECT MAX(numero) AS tope FROM ${Esquema.tablaKardex}',
    );
    final lineas = construir(((tope.first['tope'] as int?) ?? 0) + 1);
    for (final linea in lineas) {
      await ejecutor.insert(
        Esquema.tablaKardex,
        linea.aMapa(creadoEn: creadoEn),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
    return lineas;
  }

  /// Una línea suelta, en su propia transacción.
  Future<LineaAlmacen> insertar(
    LineaAlmacen Function(int numero) construir, {
    required DateTime creadoEn,
  }) async {
    final db = await _db;
    return db.transaction(
      (txn) async => (await insertarEn(
        txn,
        (n) => [construir(n)],
        creadoEn: creadoEn,
      )).single,
    );
  }
}
