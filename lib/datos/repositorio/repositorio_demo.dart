import 'package:uuid/uuid.dart';

import '../../dominio/boleta.dart';
import '../../dominio/categoria.dart';
import '../../dominio/efectivo.dart';
import '../../dominio/enums.dart';
import '../../dominio/fondo.dart';
import '../../dominio/igv.dart';
import '../../dominio/importe.dart';
import '../../dominio/jornada.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/negocio.dart';
import 'repositorio_movimientos.dart';

/// La versión de "Mi Caja" que corre en la web (§2.4 dice que las pantallas
/// nunca hablan con SQLite ni con Firebase directo, y en el navegador no hay
/// ni lo uno ni lo otro).
///
/// Todo vive en listas en memoria que arrancan vacías, como el primer día de
/// un negocio que recién empieza: sin datos del negocio, sin movimientos, sin
/// cajas y con el efectivo sin contar. Sirve para que alguien pruebe la app
/// desde un link sin instalar nada, y para que Wilmer muestre el avance sin
/// exponer su base real. Al recargar la página se vuelve a empezar de cero:
/// nada de lo que se escriba acá queda guardado en ningún lado.
///
/// Reimplementa cada método de [RepositorioMovimientos] contra las listas de
/// abajo, con las mismas reglas del repositorio de verdad (bancarización,
/// boleta desde S/ 700, numeración sin huecos): el objetivo es que la
/// demostración se comporte igual que la app real, no una versión recortada.
class RepositorioDemo extends RepositorioMovimientos {
  RepositorioDemo() : super();

  static const _uuid = Uuid();

  Negocio _negocio = Negocio.vacio;
  final List<Movimiento> _movimientos = [];
  final List<Categoria> _categoriasPropias = [];
  final List<Jornada> _cajas = [];
  FondoNegocio? _fondo;

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
      if (!m.eliminado && (cuenta == null || m.cuenta == cuenta)) m,
  ]..sort((a, b) => b.fecha.compareTo(a.fecha));

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

  @override
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
    String? cuentaAsociada,
    bool? conIgv,
    String? rutaFoto,
    bool conRecibo = false,
    String? tesorero,
    DetalleEfectivo? detalleEfectivo,
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
    if (medio == MedioPago.efectivo &&
        centavos >= Movimiento.umbralBancarizacionCentavos) {
      throw ArgumentError(
        'Desde S/ 2,000 no se puede registrar en efectivo: usa banco, Yape, '
        'transferencia, depósito o tarjeta.',
      );
    }
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
    if (!fecha.isBefore(DateTime(ahora.year, ahora.month, ahora.day + 1))) {
      throw ArgumentError('No se pueden registrar movimientos futuros.');
    }
    if (_negocio.inicioPeriodo != null &&
        fecha.isBefore(_negocio.inicioPeriodo!)) {
      throw ArgumentError('La fecha es anterior a la apertura del negocio.');
    }

    final afecto = conIgv ?? categoria.afectoIgv;
    final igv = afecto ? Igv.desagregar(centavos).igv : 0;

    final nuevo = Movimiento(
      id: _uuid.v4(),
      numero: _proximoNumero,
      tipo: tipo,
      centavos: centavos,
      categoriaId: categoriaId,
      concepto: concepto,
      medio: medio,
      fecha: fecha,
      creadoEn: ahora,
      actualizadoEn: ahora,
      cuentaAsociada: cuentaAsociada ?? categoria.cuentaAsociada,
      igvCentavos: igv,
      contraparte: contraparte,
      documentoContraparte: documentoContraparte,
      numeroTransaccion: numeroTransaccion,
      numeroRecibo: conRecibo ? _proximoRecibo(tipo) : null,
      numeroBoleta: conBoleta ? _proximaBoleta : null,
      tesorero: conRecibo ? tesorero?.trim() : null,
      detalleEfectivo: detalleEfectivo,
      rutaFoto: rutaFoto,
      sync: EstadoSync.local,
    );
    _movimientos.add(nuevo);
    return nuevo;
  }

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

  @override
  Future<Movimiento> editar(Movimiento movimiento) async {
    final actualizado = movimiento.copiarCon(
      actualizadoEn: DateTime.now(),
      sync: EstadoSync.local,
    );
    _reemplazar(actualizado);
    return actualizado;
  }

  @override
  Future<Movimiento> eliminar(Movimiento movimiento) async {
    final borrado = movimiento.copiarCon(
      eliminadoEn: DateTime.now(),
      actualizadoEn: DateTime.now(),
      sync: EstadoSync.local,
    );
    _reemplazar(borrado);
    return borrado;
  }

  @override
  Future<Movimiento> restaurar(Movimiento movimiento) async {
    final restaurado = movimiento.copiarCon(
      eliminadoEn: null,
      actualizadoEn: DateTime.now(),
      sync: EstadoSync.local,
    );
    _reemplazar(restaurado);
    return restaurado;
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
