import 'categoria.dart';
import 'enums.dart';
import 'movimiento.dart';

/// Un punto de la línea de saldo: un día y cuánto había al cerrar ese día.
class PuntoSaldo {
  const PuntoSaldo(this.dia, this.centavos);

  final DateTime dia;
  final int centavos;
}

/// Una porción de la dona: una categoría y cuánto se fue en ella.
class PorcionCategoria {
  const PorcionCategoria(this.categoria, this.centavos);

  final Categoria categoria;
  final int centavos;
}

/// Cálculos que alimentan los gráficos del dashboard y los reportes.
///
/// Viven en el dominio y no en la UI: así el mismo número que sale en el
/// gráfico es el que se exporta al PDF, sin recalcularlo en dos sitios.
class Series {
  /// Saldo acumulado día a día, hacia atrás desde hoy.
  ///
  /// Arranca del saldo actual y va **restando** hacia el pasado en vez de
  /// sumar desde cero: así la línea termina exactamente en el saldo que el
  /// usuario ve arriba, aunque haya movimientos más viejos que la ventana.
  static List<PuntoSaldo> saldoDiario(
    List<Movimiento> movimientos, {
    int dias = 30,
    DateTime? ahora,
    int saldoInicial = 0,
    DateTime? inicioPeriodo,
  }) {
    final hoy = ahora ?? DateTime.now();
    final finDeHoy = DateTime(hoy.year, hoy.month, hoy.day);

    final manana = DateTime(hoy.year, hoy.month, hoy.day + 1);
    final vivos = movimientos
        .where(
          (m) =>
              !m.eliminado &&
              m.fecha.isBefore(manana) &&
              (inicioPeriodo == null || !m.fecha.isBefore(inicioPeriodo)),
        )
        .toList();

    // Cuánto se movió cada día dentro de la ventana.
    final porDia = <DateTime, int>{};
    var saldoActual = saldoInicial;
    for (final m in vivos) {
      saldoActual += m.efectoEnSaldo;
      final dia = DateTime(m.fecha.year, m.fecha.month, m.fecha.day);
      porDia[dia] = (porDia[dia] ?? 0) + m.efectoEnSaldo;
    }

    final puntos = <PuntoSaldo>[];
    var saldo = saldoActual;

    for (var i = 0; i < dias; i++) {
      final dia = DateTime(finDeHoy.year, finDeHoy.month, finDeHoy.day - i);
      if (inicioPeriodo != null &&
          dia.isBefore(
            DateTime(
              inicioPeriodo.year,
              inicioPeriodo.month,
              inicioPeriodo.day,
            ),
          )) {
        break;
      }
      puntos.add(PuntoSaldo(dia, saldo));
      saldo -= porDia[dia] ?? 0;
    }

    return puntos.isEmpty
        ? [PuntoSaldo(finDeHoy, 0)]
        : puntos.reversed.toList();
  }

  /// En qué se fue la plata: egresos agrupados por categoría, de mayor a menor.
  static List<PorcionCategoria> egresosPorCategoria(
    List<Movimiento> movimientos, {
    DateTime? mes,
  }) {
    final referencia = mes ?? DateTime.now();

    final acumulado = <String, int>{};
    for (final m in movimientos) {
      if (m.eliminado || m.tipo != Tipo.salio) continue;
      if (m.fecha.year != referencia.year ||
          m.fecha.month != referencia.month) {
        continue;
      }
      acumulado[m.categoriaId] = (acumulado[m.categoriaId] ?? 0) + m.centavos;
    }

    final porciones =
        acumulado.entries
            .map((e) => PorcionCategoria(Categoria.porId(e.key), e.value))
            .toList()
          ..sort((a, b) => b.centavos.compareTo(a.centavos));

    return porciones;
  }

  /// Totales por mes, para el reporte comparativo (§4.5).
  static Map<DateTime, ({int entro, int salio})> porMes(
    List<Movimiento> movimientos, {
    int meses = 6,
    DateTime? ahora,
  }) {
    final hoy = ahora ?? DateTime.now();
    final resultado = <DateTime, ({int entro, int salio})>{};

    for (var i = meses - 1; i >= 0; i--) {
      final mes = DateTime(hoy.year, hoy.month - i);
      resultado[mes] = (entro: 0, salio: 0);
    }

    for (final m in movimientos) {
      if (m.eliminado) continue;
      final clave = DateTime(m.fecha.year, m.fecha.month);
      final actual = resultado[clave];
      if (actual == null) continue; // fuera de la ventana
      resultado[clave] = m.tipo == Tipo.entro
          ? (entro: actual.entro + m.centavos, salio: actual.salio)
          : (entro: actual.entro, salio: actual.salio + m.centavos);
    }

    return resultado;
  }
}
