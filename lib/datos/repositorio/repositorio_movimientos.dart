import 'package:uuid/uuid.dart';

import '../../dominio/almacen.dart';
import '../../dominio/banco.dart';
import '../../dominio/boleta.dart';
import '../../dominio/categoria.dart';
import '../../dominio/cierre_mes.dart';
import '../../dominio/efectivo.dart';
import '../../dominio/enums.dart';
import '../../dominio/fondo.dart';
import '../../dominio/igv.dart';
import '../../dominio/importe.dart';
import '../../dominio/jornada.dart';
import '../../dominio/kardex.dart';
import '../../dominio/mercaderia.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/negocio.dart';
import '../../dominio/reglas_mercaderia.dart';
import '../local/categoria_dao.dart';
import '../local/cierre_dao.dart';
import '../local/fondo_dao.dart';
import '../local/jornada_dao.dart';
import '../local/kardex_dao.dart';
import '../local/mercaderia_dao.dart';
import '../local/movimiento_dao.dart';
import '../local/negocio_dao.dart';
import '../remoto/fuente_remota.dart';
import '../remoto/fuente_remota_nula.dart';

/// La pieza clave de la arquitectura (§2.4): las pantallas nunca hablan con
/// SQLite ni con Firebase, siempre pasan por aquí.
///
/// Regla de oro del offline-first: **lo local manda**. Toda escritura se
/// confirma contra SQLite y recién después se intenta la nube. Si no hay
/// internet, no pasa nada: el movimiento ya está guardado y queda pendiente.
///
/// Las reglas viven aquí una sola vez. Lo que toca la base está en métodos
/// chicos (`guardarNuevo`, `guardarCambio`, `leerCierres`…) que la demo web
/// reemplaza por listas en memoria: así la demo se porta igual que la app.
class RepositorioMovimientos {
  RepositorioMovimientos({
    MovimientoDao? dao,
    NegocioDao? negocioDao,
    CategoriaDao? categoriaDao,
    JornadaDao? jornadaDao,
    FondoDao? fondoDao,
    MercaderiaDao? mercaderiaDao,
    KardexDao? kardexDao,
    CierreDao? cierreDao,
    FuenteRemota? remoto,
  }) : _dao = dao ?? MovimientoDao(),
       _negocioDao = negocioDao ?? NegocioDao(),
       _categoriaDao = categoriaDao ?? CategoriaDao(),
       _jornadaDao = jornadaDao ?? JornadaDao(),
       _fondoDao = fondoDao ?? FondoDao(),
       _mercaderiaDao = mercaderiaDao ?? MercaderiaDao(database: dao?.database),
       _kardexDao = kardexDao ?? KardexDao(database: dao?.database),
       _cierreDao = cierreDao ?? CierreDao(database: dao?.database),
       _remoto = remoto ?? const FuenteRemotaNula();

  final MovimientoDao _dao;
  final NegocioDao _negocioDao;
  final CategoriaDao _categoriaDao;
  final JornadaDao _jornadaDao;
  final FondoDao _fondoDao;
  final FuenteRemota _remoto;
  final MercaderiaDao _mercaderiaDao;
  final KardexDao _kardexDao;
  final CierreDao _cierreDao;

  static const _uuid = Uuid();

  /// La base guarda las horas al milisegundo: redondeada así, la que queda
  /// en memoria es la misma que se leería después.
  static DateTime _alMilisegundo(DateTime d) =>
      DateTime.fromMillisecondsSinceEpoch(d.millisecondsSinceEpoch);

  static String? _limpio(String? texto) =>
      texto == null || texto.trim().isEmpty ? null : texto.trim();

  // --- Productos ---

  /// Todos los productos, también los desactivados.
  Future<List<Mercaderia>> leerMercaderias() => _mercaderiaDao.listar();
  Future<Mercaderia?> mercaderiaPorId(String id) => _mercaderiaDao.porId(id);

  /// Un producto nuevo con sólo su nombre y lo demás de fábrica: código
  /// sugerido, en unidades y de tipo mercadería. Es lo que usa el botón "+"
  /// del registro.
  Future<Mercaderia> agregarMercaderia(String nombre) =>
      guardarProducto(nombre: nombre);

  /// Crea un producto (sin `id`) o cambia uno que ya existe (con `id`).
  ///
  /// Sin código, se le sugiere el siguiente libre (P001, P002…); al editar
  /// conserva el que tenía. El nombre y el código no se repiten, y la unidad
  /// no cambia si el producto ya pasó por el almacén. Sin unidad de la
  /// factura, toma la que corresponde a su unidad (07 → NIU).
  Future<Mercaderia> guardarProducto({
    String? id,
    required String nombre,
    String? codigo,
    String tipoExistencia = '01',
    String unidad = '07',
    int stockMinimo = 0,
    int? precioSugerido,
    bool activo = true,
    String? unidadCompra,
    int? factorCompra,
    String? unidadFactura,
  }) async {
    final existentes = await leerMercaderias();
    Mercaderia? anterior;
    if (id != null) {
      for (final m in existentes) {
        if (m.id == id) anterior = m;
      }
      if (anterior == null) throw ArgumentError('El producto no existe.');
    }
    final escrito = (codigo ?? '').trim();
    final candidato = Mercaderia(
      id: anterior?.id ?? _uuid.v4(),
      nombre: nombre,
      creadoEn: anterior?.creadoEn ?? _alMilisegundo(DateTime.now()),
      codigo: escrito.isNotEmpty
          ? escrito
          : (anterior?.codigo.isNotEmpty ?? false)
          ? anterior!.codigo
          : ReglasMercaderia.codigoSugerido(existentes),
      tipoExistencia: tipoExistencia,
      unidad: unidad,
      stockMinimo: stockMinimo,
      precioSugerido: precioSugerido,
      activo: activo,
      unidadCompra: _limpio(unidadCompra),
      factorCompra: factorCompra,
      unidadFactura: unidadFactura ?? '',
    );
    final limpio = ReglasMercaderia.validarProducto(
      candidato,
      otros: existentes,
      anterior: anterior,
      conMovimientos:
          anterior != null && await productoConMovimientos(anterior.id),
    );
    if (anterior == null) {
      await insertarProducto(limpio);
    } else {
      await actualizarProducto(limpio);
    }
    return limpio;
  }

  /// Guardan el producto ya revisado. La demo web los reemplaza.
  Future<void> insertarProducto(Mercaderia producto) =>
      _mercaderiaDao.insertar(producto);
  Future<void> actualizarProducto(Mercaderia producto) =>
      _mercaderiaDao.actualizar(producto);

  // --- Almacén ---

  /// Las líneas del almacén que cuentan, en el orden del kardex: por día y,
  /// dentro del día, por orden de registro. Las de un movimiento borrado o
  /// anulado no están.
  Future<List<LineaAlmacen>> leerLineasAlmacen() async =>
      StockAlmacen.ordenadas(await _kardexDao.listar());

  /// Las líneas de una compra o una venta. Si se anuló, salen marcadas.
  Future<List<LineaAlmacen>> lineasDeMovimiento(String movimientoId) =>
      _kardexDao.deMovimiento(movimientoId);

  /// Si el producto pasó alguna vez por el almacén.
  Future<bool> productoConMovimientos(String mercaderiaId) =>
      _kardexDao.hayDeProducto(mercaderiaId);

  /// Guarda una línea suelta con el siguiente número del almacén.
  Future<LineaAlmacen> insertarLineaSuelta(
    LineaAlmacen Function(int numero) construir, {
    required DateTime creadoEn,
  }) => _kardexDao.insertar(construir, creadoEn: creadoEn);

  /// Lo que entra o sale del almacén sin pasar por caja: el saldo inicial de
  /// un producto, una merma, un desmedro, una devolución o un ajuste por
  /// conteo. Las compras y las ventas van por [registrar], con su plata.
  ///
  /// - `entrada` sólo hace falta en el ajuste: si sobra (true) o falta.
  /// - `costoTotal` va en el saldo inicial (obligatorio) y en un sobrante de
  ///   un producto que ese día no tenía stock. En lo demás lo pone el kardex.
  /// - `origenId` es la línea que se devuelve, en las devoluciones.
  /// - `glosa` es el motivo, obligatorio en mermas, desmedros y ajustes.
  Future<LineaAlmacen> registrarEnAlmacen({
    required OperacionAlmacen operacion,
    required String mercaderiaId,
    required DateTime fecha,
    required int cantidad,
    bool? entrada,
    int? costoTotal,
    String? origenId,
    Comprobante? comprobante,
    String glosa = '',
    String? registradoPor,
    bool permitirDesactivado = false,
  }) async {
    if (operacion.vaPorCaja) {
      throw ArgumentError(
        'Las compras y las ventas se registran en "Entró" y "Salió", '
        'para que quede también su plata.',
      );
    }
    final producto = await mercaderiaPorId(mercaderiaId);
    if (producto == null) {
      throw ArgumentError('El producto elegido no existe.');
    }
    if (!producto.activo && !permitirDesactivado) {
      throw ArgumentError(
        '${producto.nombre} está desactivado: actívalo para usarlo.',
      );
    }
    ReglasMercaderia.validarCantidad(producto, cantidad);
    await validarFecha(fecha);

    final sentido = operacion.sentido ?? entrada;
    if (sentido == null) {
      throw ArgumentError('Elige si el ajuste suma (sobra) o resta (falta).');
    }
    if (entrada != null && entrada != sentido) {
      throw ArgumentError(
        'Una ${operacion.etiqueta.toLowerCase()} siempre '
        '${sentido ? 'entra' : 'sale'} del almacén.',
      );
    }

    final lineas = await leerLineasAlmacen();
    final sobrante = operacion == OperacionAlmacen.ajuste && sentido;
    // Un sobrante entra al costo promedio; si ese día no había stock, no
    // hay promedio y hay que escribir su costo.
    final sinStock =
        sobrante && StockAlmacen.saldo(lineas, mercaderiaId, al: fecha) <= 0;
    final llevaCosto = operacion == OperacionAlmacen.saldoInicial || sinStock;
    if (costoTotal != null && !llevaCosto) {
      throw ArgumentError(
        sobrante
            ? 'Un sobrante entra al costo promedio del kardex: no se escribe.'
            : 'El costo de esta operación lo calcula el kardex: no se escribe.',
      );
    }
    if (llevaCosto && costoTotal == null) {
      throw ArgumentError(
        operacion == OperacionAlmacen.saldoInicial
            ? 'Escribe cuánto costó el inventario inicial.'
            : '${producto.nombre} no tenía stock ese día: escribe cuánto '
                  'cuesta lo que sobró.',
      );
    }
    if (costoTotal != null &&
        (costoTotal <= 0 || costoTotal > Importe.maximoCentavos)) {
      throw ArgumentError('El costo tiene que ser mayor que cero.');
    }

    final doc = comprobante?.limpio;
    final problemaDoc = doc?.problema;
    if (problemaDoc != null) throw ArgumentError(problemaDoc);

    final motivo = operacion.pideMotivo
        ? ReglasMercaderia.validarMotivo(glosa)
        : glosa.trim();
    if (motivo.length > ReglasMercaderia.largoMotivo) {
      throw ArgumentError(
        'La nota va en ${ReglasMercaderia.largoMotivo} caracteres o menos.',
      );
    }

    if (operacion == OperacionAlmacen.saldoInicial &&
        await productoConMovimientos(mercaderiaId)) {
      throw ArgumentError(
        '${producto.nombre} ya tiene movimientos en el almacén: el saldo '
        'inicial va antes de todo. Si contaste mal, corrígelo con un ajuste.',
      );
    }
    if (origenId != null && !operacion.esDevolucion) {
      throw ArgumentError('Solo una devolución apunta a otra operación.');
    }
    if (operacion.esDevolucion) {
      _validarDevolucion(
        operacion: operacion,
        producto: producto,
        fecha: fecha,
        cantidad: cantidad,
        origenId: origenId,
        lineas: lineas,
      );
    }

    final tope = lineas.fold(0, (t, l) => l.numero > t ? l.numero : t);
    final id = _uuid.v4();
    final ahora = _alMilisegundo(DateTime.now());
    LineaAlmacen construir(int numero) => LineaAlmacen(
      id: id,
      mercaderiaId: mercaderiaId,
      fecha: fecha,
      numero: numero,
      operacion: operacion,
      entrada: sentido,
      cantidad: cantidad,
      costoTotal: costoTotal,
      origenId: origenId,
      docTipo: doc?.tipo,
      docSerie: doc?.serie,
      docNumero: doc?.numero,
      glosa: motivo,
      registradoPor: _limpio(registradoPor),
    );

    final nueva = construir(tope + 1);
    if (!sentido) {
      final falta = StockAlmacen.faltante(lineas, [nueva]);
      if (falta != null) {
        throw ArgumentError(_mensajeFaltante(producto, falta, fecha));
      }
    }
    _revisarConKardex([...lineas, nueva]);

    final guardada = await insertarLineaSuelta(construir, creadoEn: ahora);
    if (operacion == OperacionAlmacen.saldoInicial) {
      final negocio = await leerNegocio();
      final dia = DateTime(fecha.year, fecha.month, fecha.day);
      final desde = negocio.kardexDesde;
      if (desde == null || dia.isBefore(desde)) {
        await guardarNegocio(negocio.copiarCon(kardexDesde: dia));
      }
    }
    return guardada;
  }

  void _validarDevolucion({
    required OperacionAlmacen operacion,
    required Mercaderia producto,
    required DateTime fecha,
    required int cantidad,
    required String? origenId,
    required List<LineaAlmacen> lineas,
  }) {
    final recibida = operacion == OperacionAlmacen.devolucionRecibida;
    if (origenId == null) {
      throw ArgumentError(
        recibida
            ? 'Elige la venta que el cliente devuelve.'
            : 'Elige la compra que se devuelve al proveedor.',
      );
    }
    LineaAlmacen? origen;
    for (final l in lineas) {
      if (l.id == origenId) origen = l;
    }
    if (origen == null || origen.mercaderiaId != producto.id) {
      throw ArgumentError('La operación que se devuelve no existe.');
    }
    final esperada = recibida
        ? OperacionAlmacen.venta
        : OperacionAlmacen.compra;
    if (origen.operacion != esperada) {
      throw ArgumentError(
        recibida
            ? 'Un cliente devuelve sobre una venta.'
            : 'Al proveedor se le devuelve sobre una compra.',
      );
    }
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    final diaOrigen = DateTime(
      origen.fecha.year,
      origen.fecha.month,
      origen.fecha.day,
    );
    if (dia.isBefore(diaOrigen)) {
      throw ArgumentError(
        'La devolución no puede ser anterior a la operación que devuelve.',
      );
    }
    final devuelto = lineas
        .where((l) => l.origenId == origen!.id)
        .fold(0, (t, l) => t + l.cantidad);
    final quedan = origen.cantidad - devuelto;
    if (cantidad > quedan) {
      throw ArgumentError(
        'De esa operación quedan ${Cantidad.texto(quedan)} '
        '${producto.abreviaturaUnidad} por devolver.',
      );
    }
  }

  /// La última barrera: el motor del kardex (P1) recalcula todo con la
  /// operación nueva. Si no puede —una devolución al proveedor que deja el
  /// costo en negativo, un sobrante sin costo—, no se guarda.
  static void _revisarConKardex(List<LineaAlmacen> lineas) {
    try {
      Kardex.de(lineas);
    } on StateError catch (e) {
      final detalle = e.message;
      if (detalle.contains('devolución')) {
        throw ArgumentError(
          'Esa devolución no cuadra con lo que queda en el kardex: al costo '
          'de su operación, el saldo quedaría en negativo.',
        );
      }
      throw ArgumentError('El kardex no acepta esta operación: $detalle');
    }
  }

  String _mensajeFaltante(Mercaderia p, Faltante falta, DateTime fecha) =>
      'No hay suficiente ${p.nombre}: al ${_fechaCorta(fecha)} pueden salir '
      '${Cantidad.texto(falta.disponible)} ${p.abreviaturaUnidad}.';

  static String _fechaCorta(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/'
      '${f.month.toString().padLeft(2, '0')}/${f.year}';

  /// Que una fecha se pueda anotar: no en el futuro, ni antes de que empiece
  /// el libro del negocio, ni en un mes cerrado.
  Future<void> validarFecha(DateTime fecha) async {
    final ahora = DateTime.now();
    if (!fecha.isBefore(DateTime(ahora.year, ahora.month, ahora.day + 1))) {
      throw ArgumentError('No se pueden registrar movimientos futuros.');
    }
    final negocio = await leerNegocio();
    if (negocio.inicioPeriodo != null &&
        fecha.isBefore(negocio.inicioPeriodo!)) {
      throw ArgumentError('La fecha es anterior a la apertura del negocio.');
    }
    final cerrado = CierreMes.problemaCon(await leerCierres(), fecha);
    if (cerrado != null) throw ArgumentError(cerrado);
  }

  // --- Meses cerrados ---

  /// Los meses cerrados, del más viejo al más nuevo.
  Future<List<CierreMes>> leerCierres() => _cierreDao.listar();

  /// Guarda el cierre ya revisado. La demo web lo reemplaza.
  Future<void> insertarCierre(CierreMes cierre) => _cierreDao.insertar(cierre);

  /// Cierra un mes que ya terminó. Desde aquí nada se registra con fecha de
  /// ese mes ni de los anteriores, ni en caja ni en el inventario.
  Future<CierreMes> cerrarMes(
    int anio,
    int mes, {
    String cerradoPor = '',
  }) async {
    final ahora = _alMilisegundo(DateTime.now());
    final problema = CierreMes.problemaAlCerrar(
      await leerCierres(),
      anio,
      mes,
      hoy: ahora,
    );
    if (problema != null) throw ArgumentError(problema);
    final cierre = CierreMes(
      anio: anio,
      mes: mes,
      cerradoEn: ahora,
      cerradoPor: cerradoPor.trim(),
    );
    await insertarCierre(cierre);
    return cierre;
  }

  // --- Lo que se guarda con el movimiento ---

  /// Revisa los productos de una compra o una venta y deja listo lo que se
  /// guarda con el movimiento.
  ///
  /// Con líneas: cada producto existe y está activo, y las líneas suman el
  /// valor sin IGV. Sin líneas: las reglas de la v7, con el tipo de
  /// mercadería y el costo escrito. En una venta o un adelanto, además, se
  /// asigna el tipo, la serie y el número de comprobante. El stock lo revisa
  /// [revisarStock].
  Future<ProductosDelMovimiento> prepararProductos({
    required String categoriaId,
    required int baseCentavos,
    required DateTime fecha,
    required List<LineaNueva> lineas,
    required Comprobante? comprobante,
    required bool exportacion,
    required Vinculo vinculo,
    String? documentoCliente,
    String? mercaderiaId,
    int? costoCentavos,
    String? registradoPor,
    String? reemplaza,
  }) async {
    final venta = categoriaId == Categoria.ventas.id;
    if (exportacion && !venta) {
      throw ArgumentError('Solo una venta puede ser de exportación.');
    }
    var doc = comprobante?.limpio;
    var numerar = false;
    if (ReglasMercaderia.emiteComprobante(categoriaId) && doc == null) {
      doc = ReglasMercaderia.comprobanteDeVenta(
        documentoCliente: documentoCliente,
        exportacion: exportacion,
      );
      numerar = true;
    } else if (doc != null) {
      final problemaDoc = doc.problema;
      if (problemaDoc != null) throw ArgumentError(problemaDoc);
      if (ReglasMercaderia.emiteComprobante(categoriaId)) {
        ReglasMercaderia.validarComprobanteDeVenta(
          doc,
          documentoCliente: documentoCliente,
          exportacion: exportacion,
        );
        await _revisarComprobanteLibre(doc);
      }
    }

    if (lineas.isEmpty) {
      if (ReglasMercaderia.exigirLineas &&
          categoriaId == Categoria.mercaderia.id) {
        throw ArgumentError('Agrega al menos un producto a la compra.');
      }
      // Sin líneas, una venta sólo puede ser un servicio. Las ventas de
      // mercadería tienen que pasar por el kardex para validar cantidad y costo.
      final servicio =
          ReglasMercaderia.exigirLineas &&
          venta &&
          mercaderiaId == null &&
          (costoCentavos == null || costoCentavos == 0);
      if (ReglasMercaderia.exigirLineas && venta && !servicio) {
        throw ArgumentError(
          'Las ventas de mercadería requieren productos y cantidades. '
          'Usa "No es mercadería" solamente para servicios.',
        );
      }
      final costo = servicio ? 0 : costoCentavos;
      final tipo = await validarDatosMercaderia(
        categoriaId: categoriaId,
        mercaderiaId: mercaderiaId,
        costoCentavos: costo,
      );
      return ProductosDelMovimiento(
        tipoLegado: tipo,
        costoCentavos: costo,
        nombre: tipo?.nombre,
        comprobante: doc,
        numerarComprobante: numerar,
      );
    }

    if (mercaderiaId != null || costoCentavos != null) {
      throw ArgumentError(
        'Con productos, el tipo y el costo de venta los pone el inventario.',
      );
    }
    final productos = {for (final m in await leerMercaderias()) m.id: m};
    final enStock = ReglasMercaderia.validarLineas(
      categoriaId: categoriaId,
      lineas: lineas,
      baseCentavos: baseCentavos,
      productos: productos,
    );
    if (venta) {
      final todas = await leerLineasAlmacen();
      final existentes = todas
          .where((l) => reemplaza == null || l.movimientoId != reemplaza)
          .toList();
      final motor = Kardex.de(existentes);
      for (final linea in enStock) {
        final producto = productos[linea.mercaderiaId]!;
        final disponible = StockAlmacen.disponible(
          existentes,
          linea.mercaderiaId,
          fecha,
        );
        if (linea.cantidad > disponible) {
          throw ArgumentError(
            'No hay suficiente ${producto.nombre}: hay '
            '${Cantidad.texto(disponible)} ${producto.abreviaturaUnidad}.',
          );
        }
        try {
          // Se consulta el costo para validar que el kardex pueda valorar la
          // salida, pero no se copia al movimiento: el costo oficial se vuelve
          // a leer desde las líneas del kardex y así no queda desactualizado
          // si luego se registra una operación con fecha anterior.
          motor.costoDeSalida(linea.mercaderiaId, linea.cantidad, fecha);
        } on StateError {
          throw ArgumentError(
            'No hay suficiente ${producto.nombre}: hay '
            '${Cantidad.texto(disponible)} ${producto.abreviaturaUnidad}.',
          );
        }
      }
    }
    return ProductosDelMovimiento(
      nombre: ReglasMercaderia.descripcionDe([
        for (final l in lineas) productos[l.mercaderiaId]!.nombre,
      ]),
      comprobante: doc,
      numerarComprobante: numerar,
      lineas: enStock,
      venta: venta,
      exportacion: exportacion,
      vinculo: vinculo,
      registradoPor: _limpio(registradoPor),
      costoCentavos: null,
    );
  }

  /// Un comprobante de venta escrito a mano no puede repetir uno que ya se
  /// emitió, ni siquiera de algo anulado.
  Future<void> _revisarComprobanteLibre(Comprobante doc) async {
    for (final m in [...await listar(), ...await listarAnulados()]) {
      if (m.tipo == Tipo.entro && m.comprobante == doc) {
        throw ArgumentError(
          'Ya hay una venta con el comprobante ${doc.texto}: '
          'los números no se repiten.',
        );
      }
    }
  }

  /// Que nada quede en negativo con las líneas nuevas y, si se corrige
  /// algo, sin las del movimiento que se anula (`reemplaza`). Al final, el
  /// kardex de P1 lo recalcula todo.
  Future<void> revisarStock(
    ProductosDelMovimiento productos, {
    required DateTime fecha,
    String? reemplaza,
  }) async {
    final todas = await leerLineasAlmacen();
    final quitadas = [
      for (final l in todas)
        if (reemplaza != null && l.movimientoId == reemplaza) l,
    ];
    if (productos.lineas.isEmpty && quitadas.isEmpty) return;
    final existentes = [
      for (final l in todas)
        if (reemplaza == null || l.movimientoId != reemplaza) l,
    ];
    final tope = todas.fold(0, (t, l) => l.numero > t ? l.numero : t);
    final nuevas = productos.construir(
      movimientoId: '',
      fecha: fecha,
      comprobante: productos.comprobante,
      primerNumero: tope + 1,
    );
    final falta = StockAlmacen.faltante(
      existentes,
      nuevas,
      tambien: quitadas.map((l) => l.mercaderiaId),
    );
    if (falta != null) {
      final producto = await mercaderiaPorId(falta.mercaderiaId);
      final nombre = producto?.nombre ?? 'Un producto';
      final saleAqui = nuevas.any(
        (l) => !l.entrada && l.mercaderiaId == falta.mercaderiaId,
      );
      throw ArgumentError(
        saleAqui && producto != null
            ? _mensajeFaltante(producto, falta, fecha)
            : 'Así, $nombre se queda sin stock el '
                  '${_fechaCorta(falta.cuando)}: revisa las ventas de '
                  'después.',
      );
    }
    _revisarConKardex([...existentes, ...nuevas]);
  }

  /// Un movimiento con productos en el almacén no se borra: se anula y se
  /// vuelve a registrar, o se corrige con una devolución.
  Future<void> revisarQueSePuedeBorrar(Movimiento movimiento) async {
    if ((await lineasDeMovimiento(movimiento.id)).isNotEmpty) {
      throw ArgumentError(
        'Este movimiento tiene productos en el inventario: no se borra. '
        'Usa "Anular y volver a registrar" o una devolución.',
      );
    }
  }

  Future<Mercaderia?> validarDatosMercaderia({
    required String categoriaId,
    required String? mercaderiaId,
    required int? costoCentavos,
    bool permitirHeredado = false,
  }) async {
    ReglasMercaderia.validar(
      categoriaId: categoriaId,
      mercaderiaId: mercaderiaId,
      costoCentavos: costoCentavos,
      permitirHeredado: permitirHeredado,
    );
    if (mercaderiaId == null) return null;
    final tipo = await mercaderiaPorId(mercaderiaId);
    if (tipo == null) throw ArgumentError('La mercadería elegida no existe.');
    return tipo;
  }

  Future<Movimiento> validarEdicionMercaderia(Movimiento movimiento) async {
    final anteriores = await listar();
    // Con productos en el almacén, lo que mueve el kardex queda fijo: se
    // puede completar el voucher o el detalle, no rehacer la operación.
    if ((await lineasDeMovimiento(movimiento.id)).isNotEmpty) {
      Movimiento? antes;
      for (final m in anteriores) {
        if (m.id == movimiento.id) antes = m;
      }
      bool mismoDia(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      if (antes != null &&
          (antes.tipo != movimiento.tipo ||
              antes.centavos != movimiento.centavos ||
              antes.igvCentavos != movimiento.igvCentavos ||
              antes.categoriaId != movimiento.categoriaId ||
              antes.exportacion != movimiento.exportacion ||
              !mismoDia(antes.fecha, movimiento.fecha))) {
        throw ArgumentError(
          'Este movimiento tiene productos en el inventario: el monto, la '
          'fecha y la categoría ya no se cambian. Usa "Anular y volver a '
          'registrar".',
        );
      }
      return movimiento;
    }
    final heredado = anteriores.any(
      (m) =>
          m.id == movimiento.id &&
          m.categoriaId == movimiento.categoriaId &&
          m.mercaderiaId == null &&
          m.costoCentavos == null &&
          movimiento.mercaderiaId == null &&
          movimiento.costoCentavos == null,
    );
    final tipo = await validarDatosMercaderia(
      categoriaId: movimiento.categoriaId,
      mercaderiaId: movimiento.mercaderiaId,
      costoCentavos: movimiento.costoCentavos,
      permitirHeredado: heredado,
    );
    return movimiento.copiarCon(mercaderiaNombre: tipo?.nombre);
  }

  // --- Efectivo del negocio y cajas ---

  /// El efectivo del negocio, o null si todavía no se contó.
  Future<FondoNegocio?> leerFondo() => _fondoDao.leer();

  /// Guarda el primer conteo del efectivo del negocio. Se hace una vez, con
  /// la caja cerrada; después sólo se corrige.
  Future<FondoNegocio> contarFondo({
    required Conteo conteo,
    required String usuario,
  }) async {
    if (await leerFondo() != null) {
      throw ArgumentError(
        'El efectivo del negocio ya se contó. Si contaste mal, corrígelo.',
      );
    }
    final problema = FondoNegocio.problemaCon(conteo, await leerJornadas());
    if (problema != null) throw ArgumentError(problema);
    final fondo = FondoNegocio(
      conteo: conteo,
      contadoEn: _alMilisegundo(DateTime.now()),
      usuario: usuario,
    );
    await _fondoDao.guardar(fondo);
    return fondo;
  }

  /// Corrige lo que se contó, por si se contó mal. Lo que vino después —lo
  /// guardado en cada apertura— se recalcula solo a partir de este conteo.
  Future<FondoNegocio> corregirFondo({
    required Conteo conteo,
    required String usuario,
  }) async {
    final actual = await leerFondo();
    if (actual == null) {
      throw ArgumentError('Todavía no se contó el efectivo del negocio.');
    }
    final problema = FondoNegocio.problemaCon(
      conteo,
      await leerJornadas(),
      contadoEn: actual.contadoEn,
    );
    if (problema != null) throw ArgumentError(problema);
    final corregido = actual.corregir(
      conteo,
      usuario: usuario,
      en: _alMilisegundo(DateTime.now()),
    );
    await _fondoDao.guardar(corregido);
    return corregido;
  }

  /// Las cajas, de la más nueva a la más vieja.
  Future<List<Jornada>> leerJornadas() => _jornadaDao.listar();

  /// Abre una caja con el monto con que empieza.
  ///
  /// Antes hay que haber contado el efectivo del negocio: lo de la caja sale
  /// de ahí. Si se contaron los billetes, tienen que sumar el monto: es de
  /// donde la app parte para decir, al cerrar, cuántos de cada uno debería
  /// haber.
  Future<Jornada> abrirCaja({
    required int apertura,
    required InicioCaja inicio,
    required String responsable,
    required String usuario,
    Conteo? conteo,
    int anterior = 0,
  }) async {
    if (apertura < 0 || apertura > Importe.maximoCentavos) {
      throw ArgumentError('El monto con que empieza la caja no es válido.');
    }
    if (conteo != null && conteo.total != apertura) {
      throw ArgumentError(
        'Los billetes contados no suman lo que dice el monto de apertura.',
      );
    }
    if (responsable.trim().isEmpty) {
      throw ArgumentError('Escribe quién queda a cargo de la caja.');
    }
    if (await leerFondo() == null) {
      throw ArgumentError(
        'Primero cuenta el efectivo del negocio: de ahí sale lo de la caja.',
      );
    }
    final negocio = await leerNegocio();
    final ahora = DateTime.now();
    return _jornadaDao.abrir(
      (numero) => Jornada(
        id: _uuid.v4(),
        numero: numero,
        abiertaEn: ahora,
        apertura: apertura,
        conteoApertura: conteo,
        inicio: inicio,
        anterior: anterior,
        responsable: responsable.trim(),
        usuario: usuario,
        negocio: negocio.razonSocial,
        documento: negocio.documento,
      ),
    );
  }

  /// Guarda el cierre de una caja: lo contado y los totales, que desde acá
  /// quedan fijos.
  Future<void> guardarCierre(Jornada caja) {
    if (caja.abierta || caja.conteoCierre == null) {
      throw ArgumentError('Para cerrar la caja hay que contar la plata.');
    }
    return _jornadaDao.actualizar(caja);
  }

  /// Anota en la caja el movimiento con que se llevó al libro su faltante o
  /// su sobrante.
  Future<void> guardarAjuste(Jornada caja) => _jornadaDao.actualizar(caja);

  /// Le da recibo a un movimiento guardado sin él, con el responsable de caja
  /// de ese momento.
  Future<Movimiento> emitirRecibo(
    Movimiento movimiento, {
    required String tesorero,
  }) {
    if (movimiento.numeroRecibo != null) return Future.value(movimiento);
    return _dao.asignarRecibo(
      movimiento,
      tesorero: tesorero.trim(),
      ahora: DateTime.now(),
    );
  }

  // --- Categorías y negocio ---

  /// Las categorías que el usuario agregó. Por ahora viven sólo en el
  /// equipo: cuando se conecte la nube, habrá que subirlas junto con los
  /// movimientos que las usan.
  Future<List<Categoria>> leerCategoriasPropias() => _categoriaDao.listar();

  /// Crea una categoría propia con su cuenta del plan contable.
  ///
  /// La cuenta elegida va directo como "cuenta contable asociada" del
  /// formato: es la que el usuario buscó y eligió, y es la que espera ver
  /// impresa. No se inventa una provisión intermedia.
  Future<Categoria> agregarCategoria({
    required String etiqueta,
    required Tipo tipo,
    required String cuenta,
    bool afectoIgv = false,
  }) async {
    final nombre = etiqueta.trim();
    if (nombre.isEmpty) {
      throw ArgumentError('La categoría necesita un nombre.');
    }
    if (cuenta.trim().isEmpty) {
      throw ArgumentError('La categoría necesita su cuenta del plan contable.');
    }
    final repetida = Categoria.de(tipo)
        .any((c) => c.etiqueta.toLowerCase() == nombre.toLowerCase());
    if (repetida) {
      throw ArgumentError('Ya hay una categoría que se llama "$nombre".');
    }

    final categoria = Categoria(
      id: 'propia_${_uuid.v4()}',
      etiqueta: nombre,
      tipo: tipo,
      grupo: GrupoCategoria.propias,
      cuentaAsociada: cuenta.trim(),
      afectoIgv: afectoIgv,
      comun: true,
      propia: true,
    );
    await _categoriaDao.guardar(categoria);
    return categoria;
  }

  Future<Negocio> leerNegocio() => _negocioDao.leer();
  Future<void> guardarNegocio(Negocio negocio) => _negocioDao.guardar(negocio);

  // --- Movimientos ---

  /// Los que cuentan: ni borrados ni anulados.
  Future<List<Movimiento>> listar({Cuenta? cuenta}) =>
      _dao.listar(cuenta: cuenta);

  /// Los anulados, para mostrarlos: no cuentan en nada.
  Future<List<Movimiento>> listarAnulados() => _dao.listar(soloAnulados: true);

  /// Uno cualquiera, aunque esté borrado o anulado.
  Future<Movimiento?> movimientoPorId(String id) => _dao.porId(id);

  /// Registra un movimiento nuevo y devuelve lo que quedó guardado.
  ///
  /// En una venta o un adelanto, la app asigna factura F001 si el cliente
  /// tiene RUC o es una exportación; en los demás casos asigna boleta B001.
  /// La transmisión y autorización electrónica ante SUNAT requiere un PSE/OSE
  /// o servicio autorizado conectado por separado.
  Future<Movimiento> registrar({
    required Tipo tipo,
    required int centavos,
    required String categoriaId,
    required String concepto,
    required MedioPago medio,
    required DateTime fecha,
    String? contraparte,
    String? documentoContraparte,
    String? numeroTransaccion,
    String? bancoTercero,
    Vinculo vinculo = Vinculo.tercero,
    DocumentoPago documentoPago = DocumentoPago.factura,
    Situacion situacion = Situacion.cartera,
    String? cuentaAsociada,
    bool? conIgv,
    String? rutaFoto,
    bool conRecibo = false,
    String? tesorero,
    DetalleEfectivo? detalleEfectivo,
    String? mercaderiaId,
    int? costoCentavos,
    List<LineaNueva> lineas = const [],
    Comprobante? comprobante,
    bool exportacion = false,
    bool sinIgv = false,
    String? registradoPor,
  }) async {
    final listo = await prepararMovimiento(
      tipo: tipo,
      centavos: centavos,
      categoriaId: categoriaId,
      concepto: concepto,
      medio: medio,
      fecha: fecha,
      contraparte: contraparte,
      documentoContraparte: documentoContraparte,
      numeroTransaccion: numeroTransaccion,
      bancoTercero: bancoTercero,
      vinculo: vinculo,
      documentoPago: documentoPago,
      situacion: situacion,
      cuentaAsociada: cuentaAsociada,
      conIgv: conIgv,
      rutaFoto: rutaFoto,
      conRecibo: conRecibo,
      tesorero: tesorero,
      detalleEfectivo: detalleEfectivo,
      mercaderiaId: mercaderiaId,
      costoCentavos: costoCentavos,
      lineas: lineas,
      comprobante: comprobante,
      exportacion: exportacion,
      sinIgv: sinIgv,
      registradoPor: registradoPor,
    );
    return guardarNuevo(listo);
  }

  /// "Anular y volver a registrar": anula el original y registra el nuevo
  /// en una sola operación. El original queda a la vista, marcado como
  /// anulado y con el número del que lo reemplaza; sus líneas dejan de
  /// contar en el kardex.
  ///
  /// Es para errores de tipeo, en un mes abierto. No se anula lo que ya se
  /// cerró (su caja o su mes), ni una venta o compra que tiene devoluciones.
  Future<Movimiento> corregir(
    Movimiento original, {
    required Tipo tipo,
    required int centavos,
    required String categoriaId,
    required String concepto,
    required MedioPago medio,
    required DateTime fecha,
    String? contraparte,
    String? documentoContraparte,
    String? numeroTransaccion,
    String? bancoTercero,
    Vinculo vinculo = Vinculo.tercero,
    DocumentoPago documentoPago = DocumentoPago.factura,
    Situacion situacion = Situacion.cartera,
    String? cuentaAsociada,
    bool? conIgv,
    String? rutaFoto,
    bool conRecibo = false,
    String? tesorero,
    DetalleEfectivo? detalleEfectivo,
    String? mercaderiaId,
    int? costoCentavos,
    List<LineaNueva> lineas = const [],
    Comprobante? comprobante,
    bool exportacion = false,
    bool sinIgv = false,
    String? registradoPor,
  }) async {
    final antes = await movimientoPorId(original.id);
    if (antes == null || antes.eliminado) {
      throw ArgumentError('Ese movimiento no existe.');
    }
    if (antes.anulado) throw ArgumentError('Ese movimiento ya se anuló.');
    final cerrado = CierreMes.problemaCon(await leerCierres(), antes.fecha);
    if (cerrado != null) throw ArgumentError(cerrado);
    final suyas = {for (final l in await lineasDeMovimiento(antes.id)) l.id};
    if (suyas.isNotEmpty &&
        (await leerLineasAlmacen()).any((l) => suyas.contains(l.origenId))) {
      throw ArgumentError(
        'Ese movimiento tiene devoluciones: ya no se anula. Corrígelo con '
        'otra devolución o con un ajuste.',
      );
    }
    for (final caja in await leerJornadas()) {
      if (caja.ajusteId == antes.id) {
        throw ArgumentError(
          'Es el faltante o sobrante de la caja N° ${caja.numero}: no se '
          'anula.',
        );
      }
      if (!caja.abierta && caja.incluye(antes)) {
        throw ArgumentError(
          'Su efectivo ya se contó al cerrar la caja N° ${caja.numero}: no '
          'se anula. Corrígelo con un movimiento nuevo.',
        );
      }
    }

    final listo = await prepararMovimiento(
      tipo: tipo,
      centavos: centavos,
      categoriaId: categoriaId,
      concepto: concepto,
      medio: medio,
      fecha: fecha,
      contraparte: contraparte,
      documentoContraparte: documentoContraparte,
      numeroTransaccion: numeroTransaccion,
      bancoTercero: bancoTercero,
      vinculo: vinculo,
      documentoPago: documentoPago,
      situacion: situacion,
      cuentaAsociada: cuentaAsociada,
      conIgv: conIgv,
      rutaFoto: rutaFoto,
      conRecibo: conRecibo,
      tesorero: tesorero,
      detalleEfectivo: detalleEfectivo,
      mercaderiaId: mercaderiaId,
      costoCentavos: costoCentavos,
      lineas: lineas,
      comprobante: comprobante,
      exportacion: exportacion,
      sinIgv: sinIgv,
      registradoPor: registradoPor,
      reemplaza: antes.id,
    );
    final ahora = _alMilisegundo(DateTime.now());
    return guardarCorreccion(
      antes.copiarCon(
        anuladoEn: ahora,
        actualizadoEn: ahora,
        sync: EstadoSync.local,
      ),
      listo,
    );
  }

  /// Revisa todo lo de un movimiento nuevo y deja listo cómo se arma. Lo
  /// usan [registrar] y [corregir]; `reemplaza` es el id del que se anula.
  Future<MovimientoPorGuardar> prepararMovimiento({
    required Tipo tipo,
    required int centavos,
    required String categoriaId,
    required String concepto,
    required MedioPago medio,
    required DateTime fecha,
    String? contraparte,
    String? documentoContraparte,
    String? numeroTransaccion,
    String? bancoTercero,
    Vinculo vinculo = Vinculo.tercero,
    DocumentoPago documentoPago = DocumentoPago.factura,
    Situacion situacion = Situacion.cartera,
    String? cuentaAsociada,
    bool? conIgv,
    String? rutaFoto,
    bool conRecibo = false,
    String? tesorero,
    DetalleEfectivo? detalleEfectivo,
    String? mercaderiaId,
    int? costoCentavos,
    List<LineaNueva> lineas = const [],
    Comprobante? comprobante,
    bool exportacion = false,
    bool sinIgv = false,
    String? registradoPor,
    String? reemplaza,
  }) async {
    final ahora = DateTime.now();
    final categoria = Categoria.porId(categoriaId);
    if (centavos <= 0 || centavos > Importe.maximoCentavos) {
      throw ArgumentError(
        'El monto debe ser mayor que cero y estar dentro del límite.',
      );
    }
    if (categoria.id != categoriaId || categoria.tipo != tipo) {
      throw ArgumentError('La categoría no corresponde al movimiento.');
    }
    // Ley de Bancarización: desde S/ 2,000 no se paga ni se cobra en
    // efectivo. El formulario ya no deja guardarlo; esto es la segunda
    // barrera, por si algún día llega un movimiento por otro camino.
    if (medio == MedioPago.efectivo &&
        centavos >= Movimiento.umbralBancarizacionCentavos) {
      throw ArgumentError(
        'Desde S/ 2,000 no se puede registrar en efectivo: usa banco, Yape, '
        'transferencia, depósito o tarjeta.',
      );
    }
    // Desde S/ 700 el comprobante de la venta lleva quién compró.
    final conBoleta = Boleta.corresponde(categoria);
    if (conBoleta &&
        Boleta.exigeCliente(centavos) &&
        ((contraparte ?? '').trim().isEmpty ||
            (documentoContraparte ?? '').trim().isEmpty)) {
      throw ArgumentError(
        'Desde S/ 700 la boleta lleva el nombre y el DNI o RUC del cliente.',
      );
    }
    if (detalleEfectivo != null &&
        (medio != MedioPago.efectivo || !detalleEfectivo.cuadraCon(centavos))) {
      throw ArgumentError(
        'Los billetes y el vuelto no cuadran con el monto del movimiento.',
      );
    }
    await validarFecha(fecha);

    // El IGV va incluido en el monto: se desagrega hacia adentro para que el
    // saldo del libro siga siendo la plata que de verdad se movió. Una
    // exportación o una compra sin IGV no lo llevan.
    final afecto = !sinIgv && !exportacion && (conIgv ?? categoria.afectoIgv);
    final igv = afecto ? Igv.desagregar(centavos).igv : 0;
    final autor = _limpio(registradoPor);

    final productos = await prepararProductos(
      categoriaId: categoriaId,
      baseCentavos: centavos - igv,
      fecha: fecha,
      lineas: lineas,
      comprobante: comprobante,
      exportacion: exportacion,
      vinculo: vinculo,
      documentoCliente: documentoContraparte,
      mercaderiaId: mercaderiaId,
      costoCentavos: costoCentavos,
      registradoPor: autor,
      reemplaza: reemplaza,
    );
    await revisarStock(productos, fecha: fecha, reemplaza: reemplaza);
    final mercaderia = productos.tipoLegado;
    final doc = productos.comprobante;

    return MovimientoPorGuardar(
      tipo: tipo,
      conRecibo: conRecibo,
      conBoleta: conBoleta,
      productos: productos,
      construir: (numero, recibo, boleta) => Movimiento(
        id: _uuid.v4(),
        numero: numero,
        tipo: tipo,
        centavos: centavos,
        categoriaId: categoriaId,
        concepto: concepto,
        medio: medio,
        fecha: fecha,
        creadoEn: ahora,
        actualizadoEn: ahora,
        // La cuenta elegida a mano manda; si no, la arma la regla del
        // vínculo y el documento, como en el Excel.
        cuentaAsociada:
            cuentaAsociada ??
            ReglasCuenta.para(
              categoria,
              vinculo: vinculo,
              documento: documentoPago,
              situacion: situacion,
            ),
        igvCentavos: igv,
        contraparte: contraparte,
        documentoContraparte: documentoContraparte,
        numeroTransaccion: numeroTransaccion,
        bancoTercero: bancoTercero,
        vinculo: vinculo,
        documentoPago: documentoPago,
        situacion: situacion,
        numeroRecibo: recibo,
        numeroBoleta: boleta,
        tesorero: conRecibo ? tesorero?.trim() : null,
        detalleEfectivo: detalleEfectivo,
        mercaderiaId: mercaderia?.id,
        mercaderiaNombre: productos.nombre,
        costoCentavos: productos.costoCentavos,
        docTipo: doc?.tipo,
        docSerie: doc?.serie,
        docNumero: doc?.numero,
        exportacion: exportacion,
        registradoPor: autor,
        rutaFoto: rutaFoto,
        sync: EstadoSync.local,
      ),
    );
  }

  /// Guarda un movimiento ya revisado con sus números (de operación, de
  /// recibo, de boleta y de su comprobante) y sus líneas del almacén, todo
  /// en una transacción. La demo web lo reemplaza.
  Future<Movimiento> guardarNuevo(MovimientoPorGuardar listo) =>
      _dao.insertarNumerado(
        listo.tipo,
        listo.conRecibo,
        listo.construir,
        conBoleta: listo.conBoleta,
        numerarComprobante: listo.productos.numerarComprobante,
        despues: listo.productos.lineas.isEmpty
            ? null
            : (txn, m) => _kardexDao.insertarEn(
                txn,
                (primero) => listo.lineasDe(m, primero),
                creadoEn: m.creadoEn,
              ),
      );

  /// Como [guardarNuevo], y en la misma transacción marca el original como
  /// anulado y reemplazado por el nuevo. La demo web lo reemplaza.
  Future<Movimiento> guardarCorreccion(
    Movimiento anulado,
    MovimientoPorGuardar listo,
  ) => _dao.insertarNumerado(
    listo.tipo,
    listo.conRecibo,
    listo.construir,
    conBoleta: listo.conBoleta,
    numerarComprobante: listo.productos.numerarComprobante,
    despues: (txn, m) async {
      if (listo.productos.lineas.isNotEmpty) {
        await _kardexDao.insertarEn(
          txn,
          (primero) => listo.lineasDe(m, primero),
          creadoEn: m.creadoEn,
        );
      }
      await MovimientoDao.anularEn(
        txn,
        anulado.copiarCon(reemplazadoPor: m.id),
      );
    },
  );

  /// Guarda un movimiento que ya existe, tal cual. La demo web lo reemplaza.
  Future<void> guardarCambio(Movimiento movimiento) => _dao.guardar(movimiento);

  /// Cualquier edición vuelve el registro a "pendiente de subir" y le pone
  /// hora nueva, que es lo que después define quién gana el conflicto.
  ///
  /// Un anulado no se toca. En un mes cerrado sólo se completa el voucher
  /// (la foto, el N° de operación, el banco y los datos del otro): lo que
  /// sale en los libros queda como se entregó.
  Future<Movimiento> editar(Movimiento movimiento) async {
    final antes = await movimientoPorId(movimiento.id);
    if (antes != null) {
      if (antes.anulado) {
        throw ArgumentError('Un movimiento anulado ya no se cambia.');
      }
      final cierres = await leerCierres();
      final fechaCerrada = CierreMes.cerrado(cierres, antes.fecha)
          ? antes.fecha
          : CierreMes.cerrado(cierres, movimiento.fecha)
          ? movimiento.fecha
          : null;
      if (fechaCerrada != null && !_soloCambiaElVoucher(antes, movimiento)) {
        throw ArgumentError(
          '${CierreMes.problemaCon(cierres, fechaCerrada)} Solo se puede '
          'completar su voucher.',
        );
      }
    }
    final validado = await validarEdicionMercaderia(movimiento);
    final actualizado = validado.copiarCon(
      actualizadoEn: DateTime.now(),
      sync: EstadoSync.local,
    );
    await guardarCambio(actualizado);
    return actualizado;
  }

  static bool _soloCambiaElVoucher(Movimiento a, Movimiento b) =>
      a.tipo == b.tipo &&
      a.centavos == b.centavos &&
      a.categoriaId == b.categoriaId &&
      a.concepto == b.concepto &&
      a.medio == b.medio &&
      a.fecha.millisecondsSinceEpoch == b.fecha.millisecondsSinceEpoch &&
      a.cuentaAsociada == b.cuentaAsociada &&
      a.igvCentavos == b.igvCentavos &&
      a.vinculo == b.vinculo &&
      a.documentoPago == b.documentoPago &&
      a.situacion == b.situacion &&
      a.mercaderiaId == b.mercaderiaId &&
      a.costoCentavos == b.costoCentavos &&
      a.exportacion == b.exportacion &&
      a.comprobante == b.comprobante;

  /// Borrado lógico. El registro sigue en la tabla con `eliminado_en`, así el
  /// "Deshacer" es inmediato y la nube se entera del borrado igual que de
  /// cualquier otro cambio. Lo anulado, lo de un mes cerrado y lo que tiene
  /// productos no se borra.
  Future<Movimiento> eliminar(Movimiento movimiento) async {
    final antes = await movimientoPorId(movimiento.id) ?? movimiento;
    if (antes.anulado) {
      throw ArgumentError(
        'Un movimiento anulado no se borra: queda a la vista.',
      );
    }
    final cerrado = CierreMes.problemaCon(await leerCierres(), antes.fecha);
    if (cerrado != null) throw ArgumentError(cerrado);
    await revisarQueSePuedeBorrar(antes);
    final ahora = DateTime.now();
    final borrado = movimiento.copiarCon(
      eliminadoEn: ahora,
      actualizadoEn: ahora,
      sync: EstadoSync.local,
    );
    await guardarCambio(borrado);
    return borrado;
  }

  /// El "Deshacer" del §5. Se apoya en que nunca hicimos DELETE de verdad.
  ///
  /// `copiarCon` distingue un null explícito de un campo omitido y conserva
  /// boleta, recibo, billetes y los datos de mercadería.
  Future<Movimiento> restaurar(Movimiento movimiento) async {
    final cerrado = CierreMes.problemaCon(
      await leerCierres(),
      movimiento.fecha,
    );
    if (cerrado != null) throw ArgumentError(cerrado);
    final restaurado = movimiento.copiarCon(
      actualizadoEn: DateTime.now(),
      eliminadoEn: null,
      sync: EstadoSync.local,
    );
    await guardarCambio(restaurado);
    return restaurado;
  }

  /// Sube lo pendiente y baja lo que cambió en la nube.
  ///
  /// Devuelve `false` si no había con qué sincronizar (sin internet, sin
  /// Firebase configurado); eso no es un error, es el caso normal en una bodega.
  Future<bool> sincronizar() async {
    if (!await _remoto.disponible()) return false;

    final pendientes = await _dao.pendientesDeSubir();
    if (pendientes.isNotEmpty) {
      await _remoto.subir(pendientes);
      await _dao.marcarRespaldados(pendientes);
    }

    final remotos = await _remoto.bajar();
    final aGuardar = <Movimiento>[];

    for (final remoto in remotos) {
      final local = await _dao.porId(remoto.id);
      // "El último cambio gana" (§2.3): sólo pisamos lo local si lo de la nube
      // es estrictamente más nuevo. Con fechas iguales se queda lo local, que
      // es lo que el usuario tiene delante.
      if (local == null || remoto.actualizadoEn.isAfter(local.actualizadoEn)) {
        aGuardar.add(remoto.copiarCon(sync: EstadoSync.respaldado));
      }
    }

    await _dao.guardarVarios(aGuardar);
    return true;
  }
}

/// Un movimiento ya revisado, listo para numerarse y guardarse.
class MovimientoPorGuardar {
  const MovimientoPorGuardar({
    required this.tipo,
    required this.conRecibo,
    required this.conBoleta,
    required this.productos,
    required this.construir,
  });

  final Tipo tipo;
  final bool conRecibo;
  final bool conBoleta;
  final ProductosDelMovimiento productos;

  /// Arma el movimiento con sus números, que se sacan al guardar.
  final Movimiento Function(int numero, int? recibo, int? boleta) construir;

  /// Las líneas del almacén del movimiento ya guardado, numeradas desde
  /// `primerNumero`.
  List<LineaAlmacen> lineasDe(Movimiento m, int primerNumero) =>
      productos.construir(
        movimientoId: m.id,
        fecha: m.fecha,
        comprobante: m.comprobante,
        primerNumero: primerNumero,
      );
}

/// Los productos de una compra o una venta, ya revisados: lo que se anota en
/// el movimiento y cómo se arman sus líneas del almacén.
class ProductosDelMovimiento {
  const ProductosDelMovimiento({
    this.tipoLegado,
    this.costoCentavos,
    this.nombre,
    this.comprobante,
    this.numerarComprobante = false,
    this.lineas = const [],
    this.venta = false,
    this.exportacion = false,
    this.vinculo = Vinculo.tercero,
    this.registradoPor,
  });

  /// El tipo de mercadería de la v7, cuando se registra sin líneas.
  final Mercaderia? tipoLegado;
  final int? costoCentavos;

  /// Lo que va en `mercaderiaNombre`: el tipo de la v7 o los productos
  /// ("Ponchos y Mantas"). Con eso la descripción del formato sigue diciendo
  /// "Compra de Ponchos".
  final String? nombre;

  /// El de la compra, o el de la venta. Si `numerarComprobante`, todavía sin
  /// número: lo recibe al guardar.
  final Comprobante? comprobante;
  final bool numerarComprobante;

  /// Ya en la unidad del stock.
  final List<LineaNueva> lineas;
  final bool venta;
  final bool exportacion;
  final Vinculo vinculo;
  final String? registradoPor;

  static const _uuid = Uuid();

  /// Las líneas del almacén, numeradas desde `primerNumero`. Llevan el
  /// comprobante del movimiento; una compra sin comprobante queda con tipo
  /// 00 y sin número.
  List<LineaAlmacen> construir({
    required String movimientoId,
    required DateTime fecha,
    required Comprobante? comprobante,
    required int primerNumero,
  }) {
    final doc = comprobante ?? const Comprobante(tipo: '00');
    return [
      for (var i = 0; i < lineas.length; i++)
        LineaAlmacen(
          id: _uuid.v4(),
          mercaderiaId: lineas[i].mercaderiaId,
          fecha: fecha,
          numero: primerNumero + i,
          operacion: venta ? OperacionAlmacen.venta : OperacionAlmacen.compra,
          entrada: !venta,
          cantidad: lineas[i].cantidad,
          costoTotal: venta ? null : lineas[i].importe,
          importe: lineas[i].importe,
          descuento: lineas[i].descuento,
          movimientoId: movimientoId,
          docTipo: doc.tipo,
          docSerie: doc.serie,
          docNumero: doc.numero,
          cuentaCosto: venta
              ? ReglasMercaderia.cuentaCostoDeVenta(
                  exportacion: exportacion,
                  vinculo: vinculo,
                )
              : null,
          registradoPor: registradoPor,
        ),
    ];
  }
}
