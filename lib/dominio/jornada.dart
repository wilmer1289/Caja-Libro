import 'dart:convert';

import '../core/formato.dart';
import 'efectivo.dart';
import 'enums.dart';
import 'movimiento.dart';

/// Cómo arrancó una caja.
enum InicioCaja {
  /// La primera caja: se puso el monto con que empezaba.
  primera,

  /// Con lo mismo con que cerró la caja anterior.
  continua,

  /// En cero: lo de la caja anterior se guardó aparte.
  desdeCero,

  /// Con otro monto: se guardó aparte una parte (o se agregó plata).
  otroMonto,

  /// Un arqueo hecho con la versión anterior de la app, que comparaba lo
  /// contado con el saldo de todo el libro y no con lo de una caja.
  libro;

  static InicioCaja desdeBd(String valor) =>
      InicioCaja.values.firstWhere((e) => e.name == valor);
}

/// Una caja: desde que se abre con un monto hasta que se cierra contando la
/// plata. Casi siempre es un día; puede ser un turno, o varios días si nadie
/// la cerró.
///
/// Mientras está abierta, cada movimiento en efectivo que se registra entra
/// solo en ella, y no se toca desde acá: lo que dice la caja es lo que dice el
/// libro. Al cerrarla se cuenta lo que hay, se compara con lo que debería
/// haber y queda un acta: con cuánto empezó, cuánto entró y salió, con cuánto
/// terminó.
class Jornada {
  const Jornada({
    required this.id,
    required this.numero,
    required this.abiertaEn,
    required this.apertura,
    required this.inicio,
    required this.responsable,
    required this.usuario,
    this.conteoApertura,
    this.anterior = 0,
    this.negocio = '',
    this.documento = '',
    this.cerradaEn,
    this.entradas = 0,
    this.salidas = 0,
    this.operaciones = 0,
    this.conteoCierre,
    this.supervisor = '',
    this.observacion = '',
    this.ajusteId,
  });

  final String id;

  /// "Caja N° 12": correlativo, para nombrar el acta.
  final int numero;

  final DateTime abiertaEn;

  /// Con cuánto empezó, en centavos.
  final int apertura;

  /// Los billetes y monedas con que empezó, si se contaron. Con esto la app
  /// puede decir cuántos de cada uno debería haber al cerrar.
  final Conteo? conteoApertura;

  final InicioCaja inicio;

  /// Con cuánto cerró la caja anterior. Lo que no pasó a esta se guardó
  /// aparte.
  final int anterior;

  /// Quién está a cargo: firma el acta.
  final String responsable;

  /// Quién estaba usando la app.
  final String usuario;

  /// Razón social y RUC al abrir: el acta tiene que seguir diciendo lo mismo
  /// aunque después cambien los datos del negocio.
  final String negocio;
  final String documento;

  // --- El cierre ---

  final DateTime? cerradaEn;

  /// Lo que entró y salió en efectivo mientras estuvo abierta. En una caja
  /// abierta son los de este momento; al cerrarla quedan fijos.
  final int entradas;
  final int salidas;

  /// Cuántos movimientos en efectivo tuvo.
  final int operaciones;

  /// Lo que se contó al cerrar, billete por billete.
  final Conteo? conteoCierre;

  /// Quién presenció el conteo, si alguien lo hizo.
  final String supervisor;
  final String observacion;

  /// El movimiento con que se llevó al libro el faltante o el sobrante. No
  /// cuenta como parte de ninguna caja: la plata ya faltaba (o sobraba) en
  /// el cajón.
  final String? ajusteId;

  bool get abierta => cerradaEn == null;

  /// Lo que tendría que haber en el cajón.
  int get esperado => apertura + entradas - salidas;

  int get contado => conteoCierre?.total ?? 0;

  /// Positiva si sobra plata, negativa si falta. Cero mientras está abierta.
  int get diferencia => abierta ? 0 : contado - esperado;

  bool get cuadra => diferencia == 0;
  bool get hayFaltante => diferencia < 0;
  bool get haySobrante => diferencia > 0;

  /// Lo que quedó de la caja anterior y no se puso en esta: se guardó aparte.
  /// Negativo si se agregó plata de afuera. La primera caja no tiene de dónde
  /// guardar.
  int get apartado => switch (inicio) {
    InicioCaja.primera || InicioCaja.libro => 0,
    _ => anterior - apertura,
  };

  /// Con cuánto terminó: lo contado.
  int get cierre => contado;

  /// Cómo empezó, dicho para el acta.
  String get descripcionInicio {
    String soles(int c) => Formato.soles(c / 100);
    return switch (inicio) {
      InicioCaja.primera => 'Primera caja',
      InicioCaja.continua => 'Con lo que dejó la caja anterior',
      InicioCaja.desdeCero =>
        anterior > 0
            ? 'Desde cero; se guardaron aparte ${soles(anterior)}'
            : 'Desde cero',
      InicioCaja.otroMonto =>
        apartado > 0
            ? 'Con otro monto; se guardaron aparte ${soles(apartado)}'
            : apartado < 0
            ? 'Con otro monto; se agregaron ${soles(-apartado)}'
            : 'Con otro monto',
      InicioCaja.libro =>
        'Arqueo contra el saldo del libro (versión anterior de la app)',
    };
  }

  /// "Cuadra", "Faltan S/ 4.50", "Sobran S/ 1.00", o "Abierta".
  String get estadoTexto {
    if (abierta) return 'Abierta';
    if (cuadra) return 'Cuadra';
    return hayFaltante
        ? 'Faltan ${Formato.soles(-diferencia / 100)}'
        : 'Sobran ${Formato.soles(diferencia / 100)}';
  }

  /// Si un movimiento cae dentro de esta caja: en efectivo, registrado entre
  /// la apertura y el cierre, y sin ser el ajuste de un cierre.
  ///
  /// Manda cuándo se registró y no la fecha que se le puso: la plata entra al
  /// cajón cuando se cobra, aunque la venta se anote con la fecha de ayer.
  bool incluye(Movimiento m, {Set<String> ajustes = const {}}) {
    if (m.eliminado || m.medio != MedioPago.efectivo) return false;
    if (ajustes.contains(m.id)) return false;
    if (m.creadoEn.isBefore(abiertaEn)) return false;
    final hasta = cerradaEn;
    return hasta == null || m.creadoEn.isBefore(hasta);
  }

  /// Los movimientos de esta caja, del primero al último.
  List<Movimiento> movimientosDe(
    List<Movimiento> todos, {
    Set<String> ajustes = const {},
  }) =>
      todos.where((m) => incluye(m, ajustes: ajustes)).toList()
        ..sort((a, b) => a.creadoEn.compareTo(b.creadoEn));

  /// La misma caja con lo que entró y salió según estos movimientos.
  Jornada conTotales(List<Movimiento> movimientos) {
    var entradas = 0;
    var salidas = 0;
    for (final m in movimientos) {
      if (m.tipo == Tipo.entro) {
        entradas += m.centavos;
      } else {
        salidas += m.centavos;
      }
    }
    return _copiar(
      entradas: entradas,
      salidas: salidas,
      operaciones: movimientos.length,
    );
  }

  /// La caja cerrada con lo contado. Los totales quedan fijos desde acá.
  Jornada cerrar({
    required DateTime cerradaEn,
    required List<Movimiento> movimientos,
    required Conteo conteo,
    String supervisor = '',
    String observacion = '',
  }) {
    final conTotales = this.conTotales(movimientos);
    return conTotales._copiar(
      cerradaEn: cerradaEn,
      conteoCierre: conteo,
      supervisor: supervisor.trim(),
      observacion: observacion.trim(),
    );
  }

  Jornada conAjuste(String movimientoId) => _copiar(ajusteId: movimientoId);

  Jornada _copiar({
    DateTime? cerradaEn,
    int? entradas,
    int? salidas,
    int? operaciones,
    Conteo? conteoCierre,
    String? supervisor,
    String? observacion,
    String? ajusteId,
  }) => Jornada(
    id: id,
    numero: numero,
    abiertaEn: abiertaEn,
    apertura: apertura,
    inicio: inicio,
    responsable: responsable,
    usuario: usuario,
    conteoApertura: conteoApertura,
    anterior: anterior,
    negocio: negocio,
    documento: documento,
    cerradaEn: cerradaEn ?? this.cerradaEn,
    entradas: entradas ?? this.entradas,
    salidas: salidas ?? this.salidas,
    operaciones: operaciones ?? this.operaciones,
    conteoCierre: conteoCierre ?? this.conteoCierre,
    supervisor: supervisor ?? this.supervisor,
    observacion: observacion ?? this.observacion,
    ajusteId: ajusteId ?? this.ajusteId,
  );

  static String? _conteoATexto(Conteo? c) =>
      c == null ? null : jsonEncode(c.aJson());

  static Conteo? _conteoDesde(Object? texto) {
    if (texto is! String || texto.trim().isEmpty) return null;
    return Conteo.desdeJson(jsonDecode(texto) as Map<String, dynamic>);
  }

  Map<String, Object?> aMapa() => {
    'id': id,
    'numero': numero,
    'abierta_en': abiertaEn.millisecondsSinceEpoch,
    'apertura': apertura,
    'conteo_apertura': _conteoATexto(conteoApertura),
    'inicio': inicio.name,
    'anterior': anterior,
    'responsable': responsable,
    'usuario': usuario,
    'negocio': negocio,
    'documento': documento,
    'cerrada_en': cerradaEn?.millisecondsSinceEpoch,
    'entradas': entradas,
    'salidas': salidas,
    'operaciones': operaciones,
    'conteo_cierre': _conteoATexto(conteoCierre),
    'supervisor': supervisor,
    'observacion': observacion,
    'ajuste_id': ajusteId,
  };

  factory Jornada.desdeMapa(Map<String, Object?> m) {
    DateTime fecha(Object? v) => DateTime.fromMillisecondsSinceEpoch(v! as int);
    return Jornada(
      id: m['id']! as String,
      numero: (m['numero'] as int?) ?? 0,
      abiertaEn: fecha(m['abierta_en']),
      apertura: m['apertura']! as int,
      conteoApertura: _conteoDesde(m['conteo_apertura']),
      inicio: InicioCaja.desdeBd(m['inicio']! as String),
      anterior: (m['anterior'] as int?) ?? 0,
      responsable: (m['responsable'] as String?) ?? '',
      usuario: (m['usuario'] as String?) ?? '',
      negocio: (m['negocio'] as String?) ?? '',
      documento: (m['documento'] as String?) ?? '',
      cerradaEn: m['cerrada_en'] == null ? null : fecha(m['cerrada_en']),
      entradas: (m['entradas'] as int?) ?? 0,
      salidas: (m['salidas'] as int?) ?? 0,
      operaciones: (m['operaciones'] as int?) ?? 0,
      conteoCierre: _conteoDesde(m['conteo_cierre']),
      supervisor: (m['supervisor'] as String?) ?? '',
      observacion: (m['observacion'] as String?) ?? '',
      ajusteId: m['ajuste_id'] as String?,
    );
  }
}

/// Cuántos billetes y monedas de cada uno debería haber en una caja: los
/// que se contaron al abrir, más lo que entró y menos lo que salió, con el
/// detalle que se anotó en cada cobro y cada pago.
///
/// Es una ayuda para contar, no la base del cierre: si la caja se abrió
/// escribiendo un monto sin contar billetes, o hubo movimientos sin detalle,
/// la cuenta por denominación ya no es exacta, y lo dice.
class EstimadoCaja {
  const EstimadoCaja({required this.conteo, required this.sinDetalle});

  final Conteo conteo;

  /// Movimientos de la caja que no anotaron sus billetes.
  final int sinDetalle;

  bool get completo => sinDetalle == 0;

  /// Null si la caja no se abrió contando billetes: no hay de dónde partir.
  static EstimadoCaja? de(Jornada caja, List<Movimiento> movimientos) {
    final inicial = caja.conteoApertura;
    if (inicial == null) return null;

    var conteo = inicial;
    var sinDetalle = 0;
    for (final m in movimientos) {
      final d = m.detalleEfectivo;
      if (d == null) {
        sinDetalle++;
        continue;
      }
      // Entra al cajón lo que da el cliente y sale el vuelto; al pagar es al
      // revés.
      conteo = m.tipo == Tipo.entro
          ? conteo + d.entregado - d.vuelto
          : conteo - d.entregado + d.vuelto;
    }
    return EstimadoCaja(conteo: conteo, sinDetalle: sinDetalle);
  }
}

/// Para ver las cajas de un tramo: hoy, esta semana, este mes o todas.
enum PeriodoCajas {
  hoy('Hoy', 'Hoy'),
  semana('Esta semana', 'Semana'),
  mes('Este mes', 'Mes'),
  todo('Todas', 'Todas');

  const PeriodoCajas(this.etiqueta, this.corta);
  final String etiqueta;

  /// Para el selector, donde entran las cuatro en una fila.
  final String corta;

  /// Desde cuándo, o null si no hay límite. La semana empieza el lunes.
  DateTime? desde(DateTime ahora) {
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    return switch (this) {
      PeriodoCajas.hoy => hoy,
      PeriodoCajas.semana => hoy.subtract(Duration(days: hoy.weekday - 1)),
      PeriodoCajas.mes => DateTime(ahora.year, ahora.month),
      PeriodoCajas.todo => null,
    };
  }
}

/// Lo que dicen juntas las cajas de un tramo: cuánto entró y salió en
/// efectivo, cuánto faltó o sobró al contar, y cuánto se guardó aparte.
class ResumenCajas {
  const ResumenCajas._(this.periodo, this.cajas);

  final PeriodoCajas periodo;

  /// De la más nueva a la más vieja. La abierta, si entra, va con sus totales
  /// de este momento.
  final List<Jornada> cajas;

  static ResumenCajas de(
    List<Jornada> todas,
    PeriodoCajas periodo, {
    DateTime? ahora,
  }) {
    final desde = periodo.desde(ahora ?? DateTime.now());
    return ResumenCajas._(periodo, [
      for (final c in todas)
        if (desde == null || !c.abiertaEn.isBefore(desde)) c,
    ]);
  }

  bool get vacio => cajas.isEmpty;

  Iterable<Jornada> get _cerradas => cajas.where((c) => !c.abierta);

  int get entradas => cajas.fold(0, (s, c) => s + c.entradas);
  int get salidas => cajas.fold(0, (s, c) => s + c.salidas);

  /// Lo que dejó el efectivo en el tramo: entró menos salió.
  int get neto => entradas - salidas;

  int get operaciones => cajas.fold(0, (s, c) => s + c.operaciones);

  int get faltantes =>
      _cerradas.where((c) => c.hayFaltante).fold(0, (s, c) => s - c.diferencia);

  int get sobrantes =>
      _cerradas.where((c) => c.haySobrante).fold(0, (s, c) => s + c.diferencia);

  /// Sobrantes menos faltantes: cuánto se desvió el conteo del libro.
  int get diferencias => sobrantes - faltantes;

  /// Lo que se fue guardando aparte al abrir cada caja.
  int get apartado =>
      cajas.where((c) => c.apartado > 0).fold(0, (s, c) => s + c.apartado);

  /// Con cuánto terminó la última caja cerrada del tramo.
  Jornada? get ultimaCerrada => _cerradas.isEmpty ? null : _cerradas.first;
}
