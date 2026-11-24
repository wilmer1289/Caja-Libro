import 'kardex.dart';
import 'libro_diario.dart'
    show CuentaDiario, LineaDiario, EtapaAsiento, EtapaTipo;
import 'pcge.dart';
import 'periodo.dart';

export 'libro_diario.dart'
    show CuentaDiario, LineaDiario, EtapaAsiento, EtapaTipo;

/// Resumen del costo de ventas del período, agrupado por cuenta contable.
///
/// Sirve para la hoja CÁLCULOS y para el panel "Costo de ventas del período"
/// en el Libro Diario. Incluye el total por cuenta y el asiento de cierre
/// que llevaría ese costo a su destino (69 contra 20).
class CostoVentasResumen {
  const CostoVentasResumen({
    required this.porCuenta,
    required this.total,
    this.periodo,
    required this.referencia,
    this.desde,
    this.hasta,
  });

  /// Costo de ventas por cuenta (69111, 69121, etc.), en centavos.
  final Map<String, int> porCuenta;

  /// Total del costo de ventas del período, en centavos.
  final int total;

  final Periodo? periodo;
  final DateTime? referencia;
  final DateTime? desde;
  final DateTime? hasta;

  /// Crea el resumen desde un kardex.
  factory CostoVentasResumen.desdeKardex(
    Kardex kardex, {
    required Periodo periodo,
    DateTime? referencia,
  }) {
    final cuentas = kardex.costoDeVentas(periodo, referencia: referencia);
    final total = cuentas.values.fold(0, (s, v) => s + v);
    return CostoVentasResumen(
      porCuenta: cuentas,
      total: total,
      periodo: periodo,
      referencia: referencia,
    );
  }

  factory CostoVentasResumen.enRango(
    Kardex kardex, {
    required DateTime desde,
    required DateTime hasta,
  }) {
    final cuentas = kardex.costoDeVentasEn(desde: desde, hasta: hasta);
    return CostoVentasResumen(
      porCuenta: cuentas,
      total: cuentas.values.fold(0, (s, v) => s + v),
      periodo: null,
      referencia: null,
      desde: desde,
      hasta: hasta,
    );
  }

  /// El asiento de "Costo de ventas del período": cada cuenta 69 contra 20111.
  ///
  /// No se agrega a `libro.asientos` para no duplicar los asientos 2 de cada
  /// venta; se expone aparte para el panel y la hoja CÁLCULOS.
  List<EtapaAsiento> asientosDeCierre({
    required Pcge pcge,
    required String cuentaMercaderias,
  }) {
    if (porCuenta.isEmpty) return const [];

    final lineas = <LineaDiario>[];
    for (final entrada in porCuenta.entries) {
      final cuentaCosto = entrada.key;
      final monto = entrada.value;
      if (monto == 0) continue;
      final costoAlDebe = monto > 0;
      final valor = monto.abs();
      lineas.add(
        LineaDiario(
          cadena: _cadena(pcge, costoAlDebe ? cuentaCosto : cuentaMercaderias),
          debe: costoAlDebe ? valor : 0,
          porQue: costoAlDebe
              ? 'Costo de ventas del período en $cuentaCosto.'
              : 'La mercadería regresa al almacén por una devolución.',
        ),
      );
      lineas.add(
        LineaDiario(
          cadena: _cadena(pcge, costoAlDebe ? cuentaMercaderias : cuentaCosto),
          haber: costoAlDebe ? valor : 0,
          porQue: costoAlDebe
              ? 'La mercadería sale del almacén a su costo promedio.'
              : 'Se revierte el costo de ventas del período en $cuentaCosto.',
        ),
      );
    }

    if (lineas.isEmpty) return const [];

    return [
      EtapaAsiento(
        tipo: EtapaTipo.costoDeVenta,
        glosa: 'Costo de ventas del período',
        lineas: lineas,
      ),
    ];
  }

  static List<CuentaDiario> _cadena(Pcge pcge, String codigo) {
    final cadena = <CuentaDiario>[
      for (final cuenta in pcge.cadena(codigo))
        CuentaDiario(cuenta.codigo, cuenta.nombre),
    ];
    if (cadena.isEmpty || cadena.last.codigo != codigo) {
      cadena.add(CuentaDiario(codigo, pcge.denominacion(codigo)));
    }
    return cadena;
  }

  bool get vacio => porCuenta.isEmpty;
}
