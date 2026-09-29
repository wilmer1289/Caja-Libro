import 'package:sqflite/sqflite.dart';

import '../../dominio/categoria.dart';
import '../db/base_datos.dart';
import '../db/esquema.dart';

/// Las categorías que el usuario agregó con el "+" del formulario.
class CategoriaDao {
  /// Sin base, usa la de la app. Las pruebas le pasan una en memoria.
  CategoriaDao({this.database});
  final Database? database;

  Future<Database> get _db async =>
      database ?? await BaseDatos.instancia.abrir();

  Future<List<Categoria>> listar() async {
    final db = await _db;
    final filas = await db.query(
      Esquema.tablaCategorias,
      orderBy: 'creado_en ASC',
    );
    return filas.map(Categoria.desdeMapa).toList();
  }

  Future<void> guardar(Categoria categoria) async {
    final db = await _db;
    await db.insert(Esquema.tablaCategorias, {
      ...categoria.aMapa(),
      'creado_en': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }
}
