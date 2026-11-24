import 'package:uuid/uuid.dart';

import '../../dominio/almacen.dart';
import '../../dominio/categoria.dart';
import '../../dominio/cierre_mes.dart';
import '../../dominio/efectivo.dart';
import '../../dominio/enums.dart';
import '../../dominio/fondo.dart';
import '../../dominio/importe.dart';
import '../../dominio/jornada.dart';
import '../../dominio/mercaderia.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/negocio.dart';
import '../../dominio/reglas_mercaderia.dart';
import 'repositorio_movimientos.dart';

/// La versión de "Mi Caja" que corre en la web (§2.4 dice que las pantallas
/// nunca hablan con SQLite ni con Firebase directo, y en el navegador no hay
/// ni lo uno ni lo otro).
///
/// Todo vive en listas en memoria que arrancan vacías, como el primer día de
/// un negocio que recién empieza: sin datos del negocio, sin movimientos, sin
/// cajas, sin productos y con el efectivo sin contar. Sirve para que alguien
/// pruebe la app desde un link sin instalar nada, y para que Wilmer muestre
/// el avance sin exponer su base real. Al recargar la página se vuelve a
/// empezar de cero: nada de lo que se escriba acá queda guardado en ningún
/// lado.
///
/// Las reglas (bancarización, boleta desde S/ 700, stock, meses cerrados…)
/// son las de [RepositorioMovimientos]: aquí sólo se reemplaza dónde se
/// guarda, para que la demostración se comporte igual que la app real.
class RepositorioDemo extends RepositorioMovimientos {
  RepositorioDemo() : super();

  static const _uuid = Uuid();

  Negocio _negocio = Negocio.vacio;
  final List<Movimiento> _movimientos = [];
  final List<Categoria> _categoriasPropias = [];
  final List<Jornada> _cajas = [];
  FondoNegocio? _fondo;
  final List<Mercaderia> _mercaderias = [];
  final List<LineaAlmacen> _lineas = [];
  final List<CierreMes> _cierres = [];

  // --- Productos ---

  @override
  Future<List<Mercaderia>> leerMercaderias() async => List.of(_mercaderias)
    ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

  @override
  Future<Mercaderia?> mercaderiaPorId(String id) async {
    for (final m in _mercaderias) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  Future<void> insertarProducto(Mercaderia producto) async {
    // La misma barrera que el índice único de SQLite.
    ReglasMercaderia.validarProducto(producto, otros: _mercaderias);
    _mercaderias.add(producto);
  }

  @override
  Future<void> actualizarProducto(Mercaderia producto) async {
    final i = _mercaderias.indexWhere((m) => m.id == producto.id);
    if (i == -1) throw ArgumentError('El producto no existe.');
    _mercaderias[i] = producto;
  }

  // --- Almacén ---

  int get _proximoNumeroAlmacen =>
      _lineas.fold(0, (t, l) => l.numero > t ? l.numero : t) + 1;

  @override
  Future<List<LineaAlmacen>> leerLineasAlmacen() async {
    final vigentes = {
      for (final m in _movimientos)
        if (!m.eliminado && !m.anulado) m.id,
    };
    return StockAlmacen.ordenadas(
      _lineas.where(
        (l) => l.movimientoId == null || vigentes.contains(l.movimientoId),
      ),
    );
  }

  @override
  Future<List<LineaAlmacen>> lineasDeMovimiento(String movimientoId) async {
    final anulado = _movimientos.any((m) => m.id == movimientoId && m.anulado);
    return [
      for (final l in _lineas)
        if (l.movimientoId == movimientoId)
          anulado ? LineasAlmacen.anulada(l) : l,
    ];
  }

  @override
  Future<bool> productoConMovimientos(String mercaderiaId) async =>
      _lineas.any((l) => l.mercaderiaId == mercaderiaId);

  @override
  Future<LineaAlmacen> insertarLineaSuelta(
    LineaAlmacen Function(int numero) construir, {
    required DateTime creadoEn,
  }) async {
    final linea = construir(_proximoNumeroAlmacen);
    _lineas.add(linea);
    return linea;
  }

  // --- Meses cerrados ---

  @override
  Future<List<CierreMes>> leerCierres() async => List.of(_cierres);

  @override
  Future<void> insertarCierre(CierreMes cierre) async {
    if (_cierres.any((c) => c.clave == cierre.clave)) {
      throw ArgumentError('Ese mes ya está cerrado.');
    }
    _cierres.add(cierre);
  }

  // --- Negocio ---

  @override
  Future<Negocio> leerNegocio() async => _negocio;

  @override
  Future<void> guardarNegocio(Negocio negocio) async => _negocio = negocio;

  // --- Categorías propias ---

  @override
  Future<List<Categoria>> leerCategoriasPropias() async =>
      List.of(_categoriasPropias);

  @override
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
    _categoriasPropias.add(categoria);
    return categoria;
  }

  // --- Movimientos ---

  @override
  Future<List<Movimiento>> listar({Cuenta? cuenta}) async => [
    for (final m in _movimientos)
      if (!m.eliminado && !m.anulado && (cuenta == null || m.cuenta == cuenta))
        m,
  ]..sort((a, b) => b.fecha.compareTo(a.fecha));

  @override
  Future<List<Movimiento>> listarAnulados() async => [
    for (final m in _movimientos)
      if (m.anulado && !m.eliminado) m,
  ]..sort((a, b) => b.fecha.compareTo(a.fecha));

  @override
  Future<Movimiento?> movimientoPorId(String id) async {
    for (final m in _movimientos) {
      if (m.id == id) return m;
    }
    return null;
  }

  int get _proximoNumero =>
      _movimientos.fold(0, (t, m) => m.numero > t ? m.numero : t) + 1;

  int _proximoRecibo(Tipo tipo) =>
      _movimientos
          .where((m) => m.tipo == tipo)
          .fold(0, (t, m) => (m.numeroRecibo ?? 0) > t ? m.numeroRecibo! : t) +
      1;

  int get _proximaBoleta =>
      _movimientos.fold(
        0,
        (t, m) => (m.numeroBoleta ?? 0) > t ? m.numeroBoleta! : t,
      ) +
      1;

  /// Igual que en SQLite: cuenta también lo borrado y lo anulado.
  int _siguienteComprobante(String tipoDoc, String serie) =>
      _movimientos
          .where(
            (m) =>
                m.tipo == Tipo.entro &&
                m.docTipo == tipoDoc &&
                m.docSerie == serie,
          )
          .fold(0, (t, m) {
            final n = int.tryParse(m.docNumero ?? '') ?? 0;
            return n > t ? n : t;
          }) +
      1;

  @override
  Future<Movimiento> guardarNuevo(MovimientoPorGuardar listo) async {
    var nuevo = listo.construir(
      _proximoNumero,
      listo.conRecibo ? _proximoRecibo(listo.tipo) : null,
      listo.conBoleta ? _proximaBoleta : null,
    );
    final doc = nuevo.comprobante;
    if (listo.productos.numerarComprobante && doc != null) {
      nuevo = nuevo.copiarCon(
        comprobante: Comprobante(
          tipo: doc.tipo,
          serie: doc.serie,
          numero: '${_siguienteComprobante(doc.tipo, doc.serie)}',
        ),
      );
    }
    final lineas = listo.lineasDe(nuevo, _proximoNumeroAlmacen);
    _movimientos.add(nuevo);
    _lineas.addAll(lineas);
    return nuevo;
  }

  @override
  Future<Movimiento> guardarCorreccion(
    Movimiento anulado,
    MovimientoPorGuardar listo,
  ) async {
    final actual = await movimientoPorId(anulado.id);
    if (actual == null || actual.anulado) {
      throw ArgumentError('Ese movimiento ya se había anulado.');
    }
    final nuevo = await guardarNuevo(listo);
    _reemplazar(anulado.copiarCon(reemplazadoPor: nuevo.id));
    return nuevo;
  }

  @override
  Future<void> guardarCambio(Movimiento movimiento) async =>
      _reemplazar(movimiento);

  @override
  Future<Movimiento> emitirRecibo(
    Movimiento movimiento, {
    required String tesorero,
  }) async {
    if (movimiento.numeroRecibo != null) return movimiento;
    final conRecibo = movimiento.copiarCon(
      numeroRecibo: _proximoRecibo(movimiento.tipo),
      tesorero: tesorero.trim(),
      actualizadoEn: DateTime.now(),
    );
    _reemplazar(conRecibo);
    return conRecibo;
  }

  void _reemplazar(Movimiento m) {
    final i = _movimientos.indexWhere((x) => x.id == m.id);
    if (i == -1) {
      _movimientos.add(m);
    } else {
      _movimientos[i] = m;
    }
  }

  @override
  Future<bool> sincronizar() async => false;

  // --- Caja del día ---

  @override
  Future<FondoNegocio?> leerFondo() async => _fondo;

  @override
  Future<FondoNegocio> contarFondo({
    required Conteo conteo,
    required String usuario,
  }) async {
    if (_fondo != null) {
      throw ArgumentError(
        'El efectivo del negocio ya se contó. Si contaste mal, corrígelo.',
      );
    }
    final problema = FondoNegocio.problemaCon(conteo, _cajas);
    if (problema != null) throw ArgumentError(problema);
    return _fondo = FondoNegocio(
      conteo: conteo,
      contadoEn: DateTime.now(),
      usuario: usuario,
    );
  }

  @override
  Future<FondoNegocio> corregirFondo({
    required Conteo conteo,
    required String usuario,
  }) async {
    final actual = _fondo;
    if (actual == null) {
      throw ArgumentError('Todavía no se contó el efectivo del negocio.');
    }
    final problema = FondoNegocio.problemaCon(
      conteo,
      _cajas,
      contadoEn: actual.contadoEn,
    );
    if (problema != null) throw ArgumentError(problema);
    return _fondo = actual.corregir(
      conteo,
      usuario: usuario,
      en: DateTime.now(),
    );
  }

  @override
  Future<List<Jornada>> leerJornadas() async => List.of(_cajas.reversed);

  @override
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
    if (_fondo == null) {
      throw ArgumentError(
        'Primero cuenta el efectivo del negocio: de ahí sale lo de la caja.',
      );
    }
    if (_cajas.any((c) => c.abierta)) {
      throw ArgumentError('Ya hay una caja abierta: ciérrala primero.');
    }
    final numero = _cajas.fold(0, (t, c) => c.numero > t ? c.numero : t) + 1;
    final caja = Jornada(
      id: _uuid.v4(),
      numero: numero,
      abiertaEn: DateTime.now(),
      apertura: apertura,
      conteoApertura: conteo,
      inicio: inicio,
      anterior: anterior,
      responsable: responsable.trim(),
      usuario: usuario,
      negocio: _negocio.razonSocial,
      documento: _negocio.documento,
    );
    _cajas.add(caja);
    return caja;
  }

  @override
  Future<void> guardarCierre(Jornada caja) async {
    if (caja.abierta || caja.conteoCierre == null) {
      throw ArgumentError('Para cerrar la caja hay que contar la plata.');
    }
    _reemplazarCaja(caja);
  }

  @override
  Future<void> guardarAjuste(Jornada caja) async => _reemplazarCaja(caja);

  void _reemplazarCaja(Jornada caja) {
    final i = _cajas.indexWhere((c) => c.id == caja.id);
    if (i == -1) {
      _cajas.add(caja);
    } else {
      _cajas[i] = caja;
    }
  }
}
