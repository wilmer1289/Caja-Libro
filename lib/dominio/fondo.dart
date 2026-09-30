import 'dart:convert';

import '../core/formato.dart';
import 'efectivo.dart';
import 'jornada.dart';

/// El efectivo del negocio: toda la plata que tiene, contada una vez billete
/// por billete antes de abrir la primera caja.
///
/// Es de donde sale lo que se pone en la caja cada día. Una vez guardado no
/// se toca, salvo para corregirlo si se contó mal: desde acá la app sigue
/// sola cuánto hay en la caja y cuánto quedó guardado aparte.
class FondoNegocio {
  const FondoNegocio({
    required this.conteo,
    required this.contadoEn,
    required this.usuario,
    this.corregidoEn,
    this.corregidoPor = '',
  });

  /// Los billetes y monedas que se contaron.
  final Conteo conteo;

  /// Cuándo se contó. Las cajas abiertas desde este momento son las que lo
  /// van repartiendo.
  final DateTime contadoEn;

  /// Quién lo contó.
  final String usuario;

  /// Si se corrigió, cuándo y quién. El momento del conteo no cambia: se
  /// arregla lo que se contó, no cuándo.
  final DateTime? corregidoEn;
  final String corregidoPor;

  int get total => conteo.total;

  bool get corregido => corregidoEn != null;

  FondoNegocio corregir(
    Conteo conteo, {
    required String usuario,
    required DateTime en,
  }) => FondoNegocio(
    conteo: conteo,
    contadoEn: contadoEn,
    usuario: this.usuario,
    corregidoEn: en,
    corregidoPor: usuario,
  );

  /// Por qué no se puede guardar este conteo, o null si se puede.
  ///
  /// Se cuenta con la caja cerrada: con una abierta, la plata se está
  /// moviendo mientras se cuenta. Y lo que quedó en la última caja es parte
  /// del efectivo del negocio, así que el total no puede ser menos que eso.
  static String? problemaCon(
    Conteo conteo,
    List<Jornada> cajas, {
    DateTime? contadoEn,
  }) {
    if (conteo.cantidades.values.any((n) => n < 0)) {
      return 'Hay una cantidad negativa en el conteo.';
    }
    if (contadoEn == null && cajas.any((c) => c.abierta)) {
      return 'Cierra la caja antes de contar el efectivo del negocio.';
    }
    final previa = _ultimaCerradaAntes(contadoEn ?? DateTime.now(), cajas);
    if (previa != null && conteo.total < previa.cierre) {
      return 'La caja N° ${previa.numero} cerró con '
          '${Formato.soles(previa.cierre / 100)}: esa plata también es del '
          'negocio. Cuéntala junto con el resto.';
    }
    return null;
  }

  /// La última caja que ya estaba cerrada en ese momento: lo que había en el
  /// cajón cuando se contó.
  static Jornada? _ultimaCerradaAntes(DateTime momento, List<Jornada> cajas) {
    Jornada? previa;
    for (final c in cajas) {
      final cerrada = c.cerradaEn;
      if (cerrada == null || cerrada.isAfter(momento)) continue;
      if (previa == null || c.abiertaEn.isAfter(previa.abiertaEn)) previa = c;
    }
    return previa;
  }

  Map<String, Object?> aMapa() => {
    'id': 1,
    'conteo': jsonEncode(conteo.aJson()),
    'contado_en': contadoEn.millisecondsSinceEpoch,
    'usuario': usuario,
    'corregido_en': corregidoEn?.millisecondsSinceEpoch,
    'corregido_por': corregidoPor,
  };

  factory FondoNegocio.desdeMapa(Map<String, Object?> m) {
    DateTime fecha(Object? v) => DateTime.fromMillisecondsSinceEpoch(v! as int);
    return FondoNegocio(
      conteo: Conteo.desdeJson(
        jsonDecode(m['conteo']! as String) as Map<String, dynamic>,
      ),
      contadoEn: fecha(m['contado_en']),
      usuario: (m['usuario'] as String?) ?? '',
      corregidoEn: m['corregido_en'] == null ? null : fecha(m['corregido_en']),
      corregidoPor: (m['corregido_por'] as String?) ?? '',
    );
  }
}

/// Dónde está ahora el efectivo del negocio: en la caja o guardado aparte.
///
/// No se guarda: sale de repasar, desde que se contó el efectivo, cómo se
/// abrió cada caja. Al abrir, lo que se pone en la caja sale de lo que había
/// —lo que dejó la caja anterior más lo guardado— y lo que no se pone queda
/// guardado. Mientras la caja está abierta, lo que entra y sale en efectivo
/// cambia lo que hay en ella; lo guardado no se toca. Por eso una corrección
/// del conteo se refleja sola en todo lo que vino después.
class EfectivoNegocio {
  const EfectivoNegocio._({
    required this.fondo,
    required this.guardado,
    required this.enCaja,
    this.caja,
  });

  final FondoNegocio fondo;

  /// Lo que no está en la caja.
  final int guardado;

  /// Lo que hay en la caja: lo que debería haber si está abierta, o lo que
  /// se contó al cerrarla.
  final int enCaja;

  /// La caja donde está [enCaja], si hubo alguna.
  final Jornada? caja;

  /// Todo el efectivo del negocio.
  int get total => guardado + enCaja;

  /// Lo que se puede poner en la caja que se abra: todo lo que hay.
  int get disponible => total;

  /// [cajas] en cualquier orden; la abierta, con lo que entró y salió hasta
  /// ahora.
  static EfectivoNegocio de(FondoNegocio fondo, List<Jornada> cajas) {
    final ordenadas = [...cajas]
      ..sort((a, b) => a.abiertaEn.compareTo(b.abiertaEn));

    Jornada? caja = FondoNegocio._ultimaCerradaAntes(fondo.contadoEn, cajas);
    var enCaja = caja?.cierre ?? 0;
    // Nunca negativo: un conteo menor que lo del cajón no se deja guardar,
    // pero si llegara igual, falta plata y no hay de dónde sacarla.
    var guardado = fondo.total - enCaja;
    if (guardado < 0) guardado = 0;

    for (final c in ordenadas) {
      if (c.abiertaEn.isBefore(fondo.contadoEn)) continue;
      final habia = guardado + enCaja;
      // Si se abrió con más de lo que había, lo de más entró de afuera: lo
      // guardado queda en cero y la plata nueva pasa a ser del negocio.
      guardado = c.apertura <= habia ? habia - c.apertura : 0;
      enCaja = c.abierta ? c.esperado : c.cierre;
      caja = c;
    }
    return EfectivoNegocio._(
      fondo: fondo,
      guardado: guardado,
      enCaja: enCaja,
      caja: caja,
    );
  }
}
