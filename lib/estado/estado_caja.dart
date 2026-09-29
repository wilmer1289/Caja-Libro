// Se importa material (y no foundation) sólo por DateTimeRange, que es el
// tipo que devuelve showDateRangePicker; evita traducir el rango en cada pantalla.
import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../datos/repositorio/repositorio_movimientos.dart';
import '../dominio/categoria.dart';
import '../dominio/efectivo.dart';
import '../dominio/enums.dart';
import '../dominio/jornada.dart';
import '../dominio/mayor.dart';
import '../dominio/movimiento.dart';
import '../dominio/negocio.dart';
import '../dominio/resumen.dart';

/// El estado de la app: qué mostrar en cada momento.
///
/// Mantiene la lista completa en memoria y deriva de ahí saldos, filtros y
/// gráficos. Para el volumen de una bodega es más simple y más rápido que
/// ir a SQLite en cada pantalla, y deja toda la lógica de vista en un solo sitio.
class EstadoCaja extends ChangeNotifier {
  EstadoCaja(this._repo);

  final RepositorioMovimientos _repo;

  List<Movimiento> _movimientos = const [];
  List<Jornada> _jornadas = const [];
  Negocio _negocio = Negocio.vacio;
  bool _cargando = true;
  String? _error;

  // --- Filtros del historial (§4.4) ---
  Tipo? filtroTipo;
  String? filtroCategoriaId;
  MedioPago? filtroMedio;
  DateTimeRange? filtroRango;
  String filtroTexto = '';

  /// Rango de montos, en centavos; un extremo null = sin límite.
  ({int? min, int? max})? filtroMonto;
  String? filtroMontoEtiqueta;

  /// Cómo se nombra el filtro de fecha en su botón: "Este mes" si vino de un
  /// período rápido; null si fue un rango a medida, y ahí se muestran las
  /// fechas.
  String? filtroRangoEtiqueta;

  // --- Valores recordados (§5, "valores por defecto") ---
  MedioPago ultimoMedio = MedioPago.efectivo;

  /// Si el último movimiento se registró con recibo: quien lo usa para todo
  /// no tiene que activarlo cada vez.
  bool reciboPorDefecto = false;
  String? ultimaCategoriaIngreso;
  String? ultimaCategoriaEgreso;

  /// El último movimiento registrado. La fila que le corresponde hace un
  /// destello verde al aparecer, para que se vea dónde quedó lo que acaba de
  /// anotarse en vez de tener que buscarlo en la lista.
  String? recienRegistrado;

  bool get cargando => _cargando;
  String? get error => _error;
  List<Movimiento> get movimientos => _movimientos;

  /// Datos que pertenecen a la apertura configurada y ya ocurrieron.
  List<Movimiento> get movimientosVigentes {
    final hoy = DateTime.now();
    final manana = DateTime(hoy.year, hoy.month, hoy.day + 1);
    final apertura = _negocio.inicioPeriodo;
    return _movimientos
        .where(
          (m) =>
              !m.eliminado &&
              m.fecha.isBefore(manana) &&
              (apertura == null || !m.fecha.isBefore(apertura)),
        )
        .toList();
  }

  bool get vacio => !_cargando && _movimientos.isEmpty;

  /// Los datos del negocio y los saldos con que abre el período.
  Negocio get negocio => _negocio;

  // --- La caja del día ---

  /// Los movimientos con que se llevaron al libro faltantes y sobrantes: no
  /// cuentan dentro de ninguna caja.
  Set<String> get _ajustes => {
    for (final j in _jornadas)
      if (j.ajusteId != null) j.ajusteId!,
  };

  Jornada _enVivo(Jornada caja) =>
      caja.abierta ? caja.conTotales(movimientosDeCaja(caja)) : caja;

  /// Las cajas, de la más nueva a la más vieja. La abierta va con lo que
  /// entró y salió hasta este momento.
  List<Jornada> get cajas => [for (final j in _jornadas) _enVivo(j)];

  /// La caja abierta ahora, si hay una.
  Jornada? get cajaAbierta {
    for (final j in _jornadas) {
      if (j.abierta) return _enVivo(j);
    }
    return null;
  }

  Jornada? get ultimaCajaCerrada {
    for (final j in _jornadas) {
      if (!j.abierta) return j;
    }
    return null;
  }

  /// Los movimientos en efectivo de una caja, del primero al último.
  List<Movimiento> movimientosDeCaja(Jornada caja) =>
      caja.movimientosDe(_movimientos, ajustes: _ajustes);

  /// Cuántos billetes y monedas de cada uno debería haber en una caja.
  EstimadoCaja? estimadoDe(Jornada caja) =>
      EstimadoCaja.de(caja, movimientosDeCaja(caja));

  ResumenCajas resumenCajas(PeriodoCajas periodo) =>
      ResumenCajas.de(cajas, periodo);

  /// Falta configurar el perfil: sin él no se puede emitir el Formato 1.1.
  bool get faltaPerfil => !_negocio.completo;

  Resumen get resumen => Resumen.de(
    _movimientos,
    saldoInicialCaja: _negocio.saldoInicialCaja,
    saldoInicialBanco: _negocio.saldoInicialBanco,
    inicioPeriodo: _negocio.inicioPeriodo,
  );

  /// Caja y bancos juntos, con el desglose por medio y los saldos renglón
  /// a renglón.
  LibroMayor get mayor => LibroMayor.armar(_movimientos, negocio: _negocio);

  /// Qué parte de la plata se mira en "Caja y bancos". Vive acá y no en la
  /// pantalla para que tocar "Caja (efectivo)" en el resumen lleve directo al
  /// efectivo, y para que el filtro siga puesto al volver a la sección.
  Bolsillo bolsillo = Bolsillo.todo;

  void verBolsillo(Bolsillo nuevo) {
    if (nuevo == bolsillo) return;
    bolsillo = nuevo;
    notifyListeners();
  }

  /// El historial ya filtrado. Un solo lugar donde se aplican los filtros,
  /// para que la lista y el contador de resultados nunca se contradigan.
  List<Movimiento> get historial {
    final texto = filtroTexto.trim().toLowerCase();

    return _movimientos.where((m) {
      if (filtroTipo != null && m.tipo != filtroTipo) return false;
      if (filtroCategoriaId != null && m.categoriaId != filtroCategoriaId) {
        return false;
      }
      if (filtroMedio != null && m.medio != filtroMedio) return false;

      final monto = filtroMonto;
      if (monto != null) {
        if (monto.min != null && m.centavos < monto.min!) return false;
        if (monto.max != null && m.centavos > monto.max!) return false;
      }

      final rango = filtroRango;
      if (rango != null) {
        if (m.fecha.isBefore(rango.start)) return false;
        // `end` lo da el date picker a las 00:00, así que el último día
        // quedaría fuera si comparamos directo.
        final finExclusivo = DateTime(
          rango.end.year,
          rango.end.month,
          rango.end.day + 1,
        );
        if (!m.fecha.isBefore(finExclusivo)) return false;
      }

      if (texto.isNotEmpty) {
        final enConcepto = m.concepto.toLowerCase().contains(texto);
        final enContraparte = (m.contraparte ?? '').toLowerCase().contains(
          texto,
        );
        if (!enConcepto && !enContraparte) return false;
      }

      return true;
    }).toList();
  }

  bool get hayFiltrosActivos =>
      filtroTipo != null ||
      filtroCategoriaId != null ||
      filtroMedio != null ||
      filtroRango != null ||
      filtroMonto != null ||
      filtroTexto.trim().isNotEmpty;

  void limpiarFiltros() {
    filtroTipo = null;
    filtroCategoriaId = null;
    filtroMedio = null;
    filtroRango = null;
    filtroRangoEtiqueta = null;
    filtroMonto = null;
    filtroMontoEtiqueta = null;
    filtroTexto = '';
    notifyListeners();
  }

  void aplicarFiltro({
    Tipo? tipo,
    String? categoriaId,
    MedioPago? medio,
    DateTimeRange? rango,
    String? rangoEtiqueta,
    String? texto,
    ({int? min, int? max})? monto,
    String? montoEtiqueta,
    bool limpiarMonto = false,
    bool limpiarTipo = false,
    bool limpiarCategoria = false,
    bool limpiarMedio = false,
    bool limpiarRango = false,
  }) {
    if (limpiarTipo) {
      filtroTipo = null;
    } else if (tipo != null) {
      filtroTipo = tipo;
    }
    if (limpiarCategoria) {
      filtroCategoriaId = null;
    } else if (categoriaId != null) {
      filtroCategoriaId = categoriaId;
    }
    if (limpiarMedio) {
      filtroMedio = null;
    } else if (medio != null) {
      filtroMedio = medio;
    }
    if (limpiarRango) {
      filtroRango = null;
      filtroRangoEtiqueta = null;
    } else if (rango != null) {
      filtroRango = rango;
      filtroRangoEtiqueta = rangoEtiqueta;
    }
    if (texto != null) filtroTexto = texto;
    if (limpiarMonto) {
      filtroMonto = null;
      filtroMontoEtiqueta = null;
    } else if (monto != null) {
      filtroMonto = monto;
      filtroMontoEtiqueta = montoEtiqueta;
    }
    notifyListeners();
  }

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      // Las categorías propias primero: los movimientos que las usan tienen
      // que encontrarlas al dibujarse.
      Categoria.registrarPropias(await _repo.leerCategoriasPropias());
      _movimientos = await _repo.listar();
      _negocio = await _repo.leerNegocio();
      _jornadas = await _repo.leerJornadas();
    } catch (e) {
      _error = 'No pudimos abrir tus datos. $e';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> guardarNegocio(Negocio negocio) async {
    await _repo.guardarNegocio(negocio);
    _negocio = negocio;
    notifyListeners();
  }

  /// Deja un nombre como responsable de caja de aquí en adelante.
  Future<void> usarTesorero(String nombre) async {
    final limpio = nombre.trim();
    if (limpio == _negocio.tesorero) return;
    await guardarNegocio(_negocio.copiarCon(tesorero: limpio));
  }

  /// Le da recibo a un movimiento que se guardó sin él.
  Future<Movimiento> emitirRecibo(
    Movimiento movimiento, {
    required String tesorero,
  }) async {
    final conRecibo = await _repo.emitirRecibo(movimiento, tesorero: tesorero);
    _movimientos = [
      for (final m in _movimientos) m.id == conRecibo.id ? conRecibo : m,
    ];
    notifyListeners();
    return conRecibo;
  }

  Future<Jornada> abrirCaja({
    required int apertura,
    required InicioCaja inicio,
    required String responsable,
    required String usuario,
    Conteo? conteo,
    int anterior = 0,
  }) async {
    final caja = await _repo.abrirCaja(
      apertura: apertura,
      inicio: inicio,
      responsable: responsable,
      usuario: usuario,
      conteo: conteo,
      anterior: anterior,
    );
    _jornadas = [caja, ..._jornadas];
    notifyListeners();
    return caja;
  }

  /// Cierra la caja abierta con lo que se contó. Los totales quedan fijos.
  Future<Jornada> cerrarCaja({
    required Conteo conteo,
    String supervisor = '',
    String observacion = '',
  }) async {
    final abierta = _jornadas.where((j) => j.abierta).firstOrNull;
    if (abierta == null) throw ArgumentError('No hay ninguna caja abierta.');
    final cerrada = abierta.cerrar(
      cerradaEn: DateTime.now(),
      movimientos: movimientosDeCaja(abierta),
      conteo: conteo,
      supervisor: supervisor,
      observacion: observacion,
    );
    await _repo.guardarCierre(cerrada);
    _reemplazarCaja(cerrada);
    return cerrada;
  }

  /// Lleva al libro el faltante o el sobrante de una caja cerrada.
  ///
  /// Un faltante sale como gasto (659 Otros gastos de gestión) y un sobrante
  /// entra como ingreso (7599 Otros ingresos de gestión): así el libro vuelve
  /// a decir lo mismo que el cajón. No pasa por [registrar] para no cambiar
  /// lo que el formulario recuerda del último movimiento.
  Future<Jornada> llevarDiferenciaAlLibro(Jornada caja) async {
    if (caja.abierta || caja.cuadra || caja.ajusteId != null) return caja;
    final faltante = caja.hayFaltante;
    final ajuste = await _repo.registrar(
      tipo: faltante ? Tipo.salio : Tipo.entro,
      centavos: caja.diferencia.abs(),
      categoriaId: faltante
          ? Categoria.otrosEgresos.id
          : Categoria.otrosIngresos.id,
      concepto:
          '${faltante ? 'Faltante' : 'Sobrante'} de la caja '
          'N° ${caja.numero} (cierre del ${Formato.fecha(caja.cerradaEn!)})',
      cuentaAsociada: faltante ? '659' : '7599',
      medio: MedioPago.efectivo,
      fecha: DateTime.now(),
    );
    _movimientos = [ajuste, ..._movimientos]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final conAjuste = caja.conAjuste(ajuste.id);
    await _repo.guardarAjuste(conAjuste);
    _reemplazarCaja(conAjuste);
    return conAjuste;
  }

  void _reemplazarCaja(Jornada caja) {
    _jornadas = [for (final j in _jornadas) j.id == caja.id ? caja : j];
    notifyListeners();
  }

  /// Agrega una categoría propia y la deja disponible en toda la app.
  Future<Categoria> agregarCategoria({
    required String etiqueta,
    required Tipo tipo,
    required String cuenta,
    bool afectoIgv = false,
  }) async {
    final nueva = await _repo.agregarCategoria(
      etiqueta: etiqueta,
      tipo: tipo,
      cuenta: cuenta,
      afectoIgv: afectoIgv,
    );
    Categoria.registrarPropias([...Categoria.propias, nueva]);
    notifyListeners();
    return nueva;
  }

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
    bool conRecibo = false,
    String? tesorero,
    DetalleEfectivo? detalleEfectivo,
  }) async {
    final nuevo = await _repo.registrar(
      tipo: tipo,
      centavos: centavos,
      categoriaId: categoriaId,
      concepto: concepto,
      medio: medio,
      fecha: fecha,
      contraparte: contraparte,
      documentoContraparte: documentoContraparte,
      numeroTransaccion: numeroTransaccion,
      cuentaAsociada: cuentaAsociada,
      conIgv: conIgv,
      conRecibo: conRecibo,
      tesorero: tesorero,
      detalleEfectivo: detalleEfectivo,
    );

    ultimoMedio = medio;
    reciboPorDefecto = conRecibo;
    if (tipo == Tipo.entro) {
      ultimaCategoriaIngreso = categoriaId;
    } else {
      ultimaCategoriaEgreso = categoriaId;
    }

    recienRegistrado = nuevo.id;
    _movimientos = [nuevo, ..._movimientos]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    notifyListeners();
    return nuevo;
  }

  Future<void> eliminar(Movimiento m) async {
    await _repo.eliminar(m);
    _movimientos = _movimientos.where((x) => x.id != m.id).toList();
    notifyListeners();
  }

  Future<void> deshacerEliminacion(Movimiento m) async {
    final restaurado = await _repo.restaurar(m);
    _movimientos = [restaurado, ..._movimientos.where((x) => x.id != m.id)]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    notifyListeners();
  }

  Future<bool> sincronizar() async {
    final huboSync = await _repo.sincronizar();
    if (huboSync) await cargar();
    return huboSync;
  }
}
