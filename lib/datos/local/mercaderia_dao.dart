import 'package:sqflite/sqflite.dart';

import '../../dominio/mercaderia.dart';
import '../db/base_datos.dart';
import '../db/esquema.dart';

class MercaderiaDao {
  MercaderiaDao({this.database});
  final Database? database;
  Future<Database> get _db async =>
      database ?? await BaseDatos.instancia.abrir();

  Future<List<Mercaderia>> listar() async {
    final db = await _db;
    final filas = await db.query(
      Esquema.tablaMercaderias,
      orderBy: 'nombre_clave',
    );
    return filas.map(Mercaderia.desdeMapa).toList();
  }

  Future<Mercaderia?> porId(String id) async {
    final db = await _db;
    final filas = await db.query(
      Esquema.tablaMercaderias,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return filas.isEmpty ? null : Mercaderia.desdeMapa(filas.single);
  }

  Future<void> insertar(Mercaderia mercaderia) async {
    final db = await _db;
    await db.insert(Esquema.tablaMercaderias, mercaderia.aMapa());
  }

  /// Cambia los datos de un producto. El id y la fecha de creación no se
  /// tocan.
  Future<void> actualizar(Mercaderia mercaderia) async {
    final db = await _db;
    await db.update(
      Esquema.tablaMercaderias,
      mercaderia.aMapa()
        ..remove('id')
        ..remove('creado_en'),
      where: 'id = ?',
      whereArgs: [mercaderia.id],
    );
  }
}
