import 'package:sqflite/sqflite.dart';

import '../../dominio/almacen.dart';
import '../../dominio/enums.dart';
import '../../dominio/movimiento.dart';
import '../db/base_datos.dart';
import '../db/esquema.dart';

/// Acceso crudo a la tabla de movimientos. No decide nada de negocio: eso es
/// trabajo del repositorio.
class MovimientoDao {
  /// Sin base, usa la de la app. Las pruebas le pasan una en memoria.
  MovimientoDao({this.database});
  final Database? database;
  Future<Database> get _db async =>
      database ?? await BaseDatos.instancia.abrir();

  /// El correlativo y la inserción comparten una transacción SQLite: dos
  /// registros al mismo tiempo nunca se llevan el mismo número de operación,
  /// de recibo ni de boleta.
  ///
  /// Con `numerarComprobante`, el movimiento trae el tipo y la serie del
  /// comprobante asignado (F001, B001) y aquí recibe el número siguiente de
  /// esa serie. La emisión oficial ante SUNAT es responsabilidad del
  /// proveedor electrónico integrado.
  ///
  /// `despues` corre dentro de la misma transacción, con el movimiento ya
  /// numerado: ahí se guardan sus líneas del almacén y, al corregir, se anula
  /// el original. Si falla, no queda guardado ni el movimiento.
  Future<Movimiento> insertarNumerado(
    Tipo tipo,
    bool conRecibo,
    Movimiento Function(int numero, int? recibo, int? boleta) construir, {
    bool conBoleta = false,
    bool numerarComprobante = false,
    Future<void> Function(Transaction txn, Movimiento movimiento)? despues,
  }) async {
    final db = await _db;
    return db.transaction((txn) async {
      final operaciones = await txn.rawQuery(
        'SELECT MAX(numero) AS tope FROM ${Esquema.tablaMovimientos}',
      );
      final numero = ((operaciones.first['tope'] as int?) ?? 0) + 1;
      int? recibo;
      if (conRecibo) {
        final recibos = await txn.rawQuery(
          'SELECT MAX(numero_recibo) AS tope FROM ${Esquema.tablaMovimientos} '
          'WHERE tipo = ?',
          [tipo.name],
        );
        recibo = ((recibos.first['tope'] as int?) ?? 0) + 1;
      }
      int? boleta;
      if (conBoleta) {
        final boletas = await txn.rawQuery(
          'SELECT MAX(numero_boleta) AS tope FROM ${Esquema.tablaMovimientos}',
        );
        boleta = ((boletas.first['tope'] as int?) ?? 0) + 1;
      }
      var movimiento = construir(numero, recibo, boleta);
      final doc = movimiento.comprobante;
      if (numerarComprobante && doc != null) {
        final siguiente = await siguienteComprobante(txn, doc.tipo, doc.serie);
        movimiento = movimiento.copiarCon(
          comprobante: Comprobante(
            tipo: doc.tipo,
            serie: doc.serie,
            numero: '$siguiente',
          ),
        );
      }
      await txn.insert(
        Esquema.tablaMovimientos,
        movimiento.aMapa(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      if (despues != null) await despues(txn, movimiento);
      return movimiento;
    });
  }

  /// El siguiente número de una serie que emite la app. Cuenta también lo
  /// borrado y lo anulado: un número de comprobante no se vuelve a usar.
  /// Sólo mira lo que entró (ventas y adelantos): una compra también puede
  /// traer una F001, pero es la serie de su proveedor.
  static Future<int> siguienteComprobante(
    DatabaseExecutor ejecutor,
    String tipoDoc,
    String serie,
  ) async {
    final r = await ejecutor.rawQuery(
      'SELECT MAX(CAST(doc_numero AS INTEGER)) AS tope '
      'FROM ${Esquema.tablaMovimientos} '
      'WHERE tipo = ? AND doc_tipo = ? AND doc_serie = ?',
      [Tipo.entro.name, tipoDoc, serie],
    );
    return ((r.first['tope'] as int?) ?? 0) + 1;
  }

  /// Marca el original como anulado, dentro de la transacción que guarda el
  /// que lo reemplaza. Falla si otro ya lo había anulado.
  static Future<void> anularEn(
    DatabaseExecutor ejecutor,
    Movimiento anulado,
  ) async {
    final cambiadas = await ejecutor.update(
      Esquema.tablaMovimientos,
      anulado.aMapa(),
      where: 'id = ? AND anulado_en IS NULL',
      whereArgs: [anulado.id],
    );
    if (cambiadas != 1) {
      throw ArgumentError('Ese movimiento ya se había anulado.');
    }
  }

  /// Le da recibo a un movimiento que se guardó sin él. El número sale del
  /// talonario de su tipo, en la misma transacción que lo anota.
  Future<Movimiento> asignarRecibo(
    Movimiento movimiento, {
    required String tesorero,
    required DateTime ahora,
  }) async {
    final db = await _db;
    return db.transaction((txn) async {
      final recibos = await txn.rawQuery(
        'SELECT MAX(numero_recibo) AS tope FROM ${Esquema.tablaMovimientos} '
        'WHERE tipo = ?',
        [movimiento.tipo.name],
      );
      final numero = ((recibos.first['tope'] as int?) ?? 0) + 1;
      final conRecibo = movimiento.copiarCon(
        numeroRecibo: numero,
        tesorero: tesorero,
        actualizadoEn: ahora,
        sync: EstadoSync.local,
      );
      await txn.update(
        Esquema.tablaMovimientos,
        conRecibo.aMapa(),
        where: 'id = ? AND numero_recibo IS NULL',
        whereArgs: [movimiento.id],
      );
      return conRecibo;
    });
  }

  /// Por defecto no devuelve los borrados: el borrado lógico existe para la
  /// sincronización, no para que el usuario vea filas fantasma. Tampoco los
  /// anulados, que no cuentan en nada: esos se piden aparte
  /// (`soloAnulados`), para mostrarlos.
  Future<List<Movimiento>> listar({
    Cuenta? cuenta,
    bool incluirEliminados = false,
    bool soloAnulados = false,
  }) async {
    final db = await _db;

    final condiciones = <String>[
      soloAnulados ? 'anulado_en IS NOT NULL' : 'anulado_en IS NULL',
    ];
    final args = <Object?>[];

    if (!incluirEliminados) condiciones.add('eliminado_en IS NULL');
    if (cuenta != null) {
      condiciones.add('cuenta = ?');
      args.add(cuenta.name);
    }

    final filas = await db.query(
      Esquema.tablaMovimientos,
      where: condiciones.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'fecha DESC, creado_en DESC',
    );

    return filas.map(Movimiento.desdeMapa).toList();
  }

  Future<Movimiento?> porId(String id) async {
    final db = await _db;
    final filas = await db.query(
      Esquema.tablaMovimientos,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return filas.isEmpty ? null : Movimiento.desdeMapa(filas.first);
  }

  /// Insert-or-update en una sola llamada: la usa tanto el registro manual
  /// como la bajada de datos de la nube.
  Future<void> guardar(Movimiento m) async {
    final db = await _db;
    await db.insert(
      Esquema.tablaMovimientos,
      m.aMapa(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> guardarVarios(List<Movimiento> movimientos) async {
    final db = await _db;
    final lote = db.batch();
    for (final m in movimientos) {
      lote.insert(
        Esquema.tablaMovimientos,
        m.aMapa(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await lote.commit(noResult: true);
  }

  /// Lo que todavía no llegó a la nube.
  Future<List<Movimiento>> pendientesDeSubir() async {
    final db = await _db;
    final filas = await db.query(
      Esquema.tablaMovimientos,
      where: 'sync != ?',
      whereArgs: [EstadoSync.respaldado.name],
    );
    return filas.map(Movimiento.desdeMapa).toList();
  }

  /// El siguiente N° DE OPER. del formato.
  ///
  /// Cuenta desde el máximo y no desde la cantidad de filas: si se borra un
  /// movimiento, su número no se reutiliza. En un libro contable, dos
  /// operaciones distintas no pueden llevar el mismo número.
  Future<int> proximoNumero() async {
    final db = await _db;
    final r = await db.rawQuery(
      'SELECT MAX(numero) AS tope FROM ${Esquema.tablaMovimientos}',
    );
    return ((r.first['tope'] as int?) ?? 0) + 1;
  }

  /// El siguiente correlativo de recibo, que va por separado para entradas y
  /// para salidas: son dos talonarios distintos.
  Future<int> proximoRecibo(Tipo tipo) async {
    final db = await _db;
    final r = await db.rawQuery(
      'SELECT MAX(numero_recibo) AS tope FROM ${Esquema.tablaMovimientos} '
      'WHERE tipo = ?',
      [tipo.name],
    );
    return ((r.first['tope'] as int?) ?? 0) + 1;
  }

  Future<void> marcarRespaldados(List<Movimiento> enviados) async {
    if (enviados.isEmpty) return;
    final db = await _db;
    final lote = db.batch();
    for (final m in enviados) {
      lote.update(
        Esquema.tablaMovimientos,
        {'sync': EstadoSync.respaldado.name},
        where: 'id = ? AND actualizado_en = ?',
        whereArgs: [m.id, m.actualizadoEn.millisecondsSinceEpoch],
      );
    }
    await lote.commit(noResult: true);
  }
}
