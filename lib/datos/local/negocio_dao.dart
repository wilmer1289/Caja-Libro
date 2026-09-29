import 'package:sqflite/sqflite.dart';

import '../../dominio/negocio.dart';
import '../db/base_datos.dart';
import '../db/esquema.dart';

/// Lee y escribe la única fila de la tabla del negocio.
class NegocioDao {
  /// Sin base, usa la de la app. Las pruebas le pasan una en memoria.
  NegocioDao({this.database});
  final Database? database;

  Future<Negocio> leer() async {
    final db = database ?? await BaseDatos.instancia.abrir();
    final filas = await db.query(
      Esquema.tablaNegocio,
      where: 'id = 1',
      limit: 1,
    );
    // Mientras nadie llenó el perfil no hay fila: se devuelve el vacío en vez
    // de null, para que la app arranque igual y el perfil se pida después.
    return filas.isEmpty ? Negocio.vacio : Negocio.desdeMapa(filas.first);
  }

  Future<void> guardar(Negocio negocio) async {
    final db = database ?? await BaseDatos.instancia.abrir();
    // `id` siempre es 1, así que insertar con reemplazo hace de alta y de
    // actualización a la vez.
    await db.insert(
      Esquema.tablaNegocio,
      negocio.aMapa(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
