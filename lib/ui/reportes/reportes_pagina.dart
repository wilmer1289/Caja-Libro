import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/series.dart';
import '../../estado/estado_caja.dart';
import '../widgets/al_entrar.dart';
import '../widgets/aparece.dart';
import '../widgets/esqueleto.dart';
import '../widgets/estado_vacio.dart';

/// Reportes del §4.5: cuánto entró y salió mes a mes, en gráfico y en tabla.
///
/// La exportación a PDF y Excel todavía no está: se anuncia como pendiente en
/// vez de ofrecer un botón que no hace nada.
class ReportesPagina extends StatelessWidget {
  const ReportesPagina({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();

    if (estado.cargando) return const EsqueletoLista();

    if (estado.vacio) {
      return const EstadoVacio(
        icono: Icons.insert_chart_outlined_rounded,
        titulo: 'Todavía no hay nada que reportar',
        mensaje:
            'Los reportes se arman solos con lo que vayas registrando. '
            'Empieza por anotar un movimiento.',
      );
    }

    final meses = Series.porMes(estado.movimientosVigentes);
    final claves = meses.keys.toList();
    final maximo = meses.values.fold<int>(
      0,
      (mayor, m) => [mayor, m.entro, m.salio].reduce((a, b) => a > b ? a : b),
    );

    return LayoutBuilder(
      builder: (context, medidas) {
        final amplio = medidas.maxWidth >= 760;
        final margen = amplio ? 28.0 : 16.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            margen,
            margen,
            margen,
            amplio ? margen : 120,
          ),
          children: [
            Aparece(
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 22, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mes a mes',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Tokens.texto,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Cuánto entró y cuánto salió',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Tokens.texto2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _PuntoLeyenda(color: Tokens.entro, texto: 'Entró'),
                          SizedBox(width: 14),
                          _PuntoLeyenda(color: Tokens.salio, texto: 'Salió'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 220,
                        child: _Barras(
                          meses: meses,
                          claves: claves,
                          maximo: maximo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Aparece(
              retraso: const Duration(milliseconds: 90),
              child: _Tabla(meses: meses, claves: claves, amplio: amplio),
            ),
            const SizedBox(height: 20),
            const Aparece(
              retraso: Duration(milliseconds: 160),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(Icons.download_outlined, color: Tokens.texto2),
                  title: Text('Exportar a PDF o Excel'),
                  subtitle: Text('En construcción'),
                  enabled: false,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Barras extends StatelessWidget {
  const _Barras({
    required this.meses,
    required this.claves,
    required this.maximo,
  });

  final Map<DateTime, ({int entro, int salio})> meses;
  final List<DateTime> claves;
  final int maximo;

  @override
  Widget build(BuildContext context) {
    return AlEntrar(
      constructor: (context, listo) => BarChart(
        BarChartData(
          // El techo se calcula con los datos reales y se le deja 15% de aire
          // para que la barra más alta no toque el borde.
          maxY: maximo == 0 ? 10 : (maximo / 100) * 1.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Tokens.borde, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (valor, meta) {
                  final i = valor.round();
                  if (i < 0 || i >= claves.length) {
                    return const SizedBox.shrink();
                  }
                  final esActual = i == claves.length - 1;
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      Formato.mesCorto(claves[i]),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: esActual
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: esActual ? Tokens.texto : Tokens.texto2,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < claves.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: listo ? meses[claves[i]]!.entro / 100 : 0,
                    color: Tokens.entro,
                    width: 12,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  BarChartRodData(
                    toY: listo ? meses[claves[i]]!.salio / 100 : 0,
                    color: Tokens.salio,
                    width: 12,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

/// La tabla del histórico. En escritorio van las cuatro columnas; en celular
/// no entran, así que entró y salió pasan abajo del mes.
class _Tabla extends StatelessWidget {
  const _Tabla({
    required this.meses,
    required this.claves,
    required this.amplio,
  });

  final Map<DateTime, ({int entro, int salio})> meses;
  final List<DateTime> claves;
  final bool amplio;

  static const _estiloCabecera = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: Tokens.texto2,
  );

  @override
  Widget build(BuildContext context) {
    // El mes más reciente primero: es el que se mira.
    final orden = claves.reversed.toList();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Text(
              'Histórico de meses',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Tokens.texto,
              ),
            ),
          ),
          Container(
            color: Tokens.fondo,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text('MES', style: _estiloCabecera),
                ),
                if (amplio) ...[
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'ENTRÓ',
                      textAlign: TextAlign.right,
                      style: _estiloCabecera,
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'SALIÓ',
                      textAlign: TextAlign.right,
                      style: _estiloCabecera,
                    ),
                  ),
                ],
                const Expanded(
                  flex: 2,
                  child: Text(
                    'BALANCE',
                    textAlign: TextAlign.right,
                    style: _estiloCabecera,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < orden.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _FilaMes(
              mes: orden[i],
              valores: meses[orden[i]]!,
              actual: i == 0,
              amplio: amplio,
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaMes extends StatelessWidget {
  const _FilaMes({
    required this.mes,
    required this.valores,
    required this.actual,
    required this.amplio,
  });

  final DateTime mes;
  final ({int entro, int salio}) valores;
  final bool actual;
  final bool amplio;

  @override
  Widget build(BuildContext context) {
    final balance = valores.entro - valores.salio;
    final sinMovimiento = valores.entro == 0 && valores.salio == 0;

    // Un mes vacío se atenúa entero: los ceros no compiten con los meses que
    // sí tuvieron movimiento.
    final tenue = sinMovimiento ? Tokens.texto2 : null;

    final monto = TextStyle(
      fontSize: 13.5,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: tenue,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formato.capitalizar(Formato.mes(mes)),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: actual ? FontWeight.w700 : FontWeight.w500,
                    color: tenue ?? Tokens.texto,
                  ),
                ),
                if (!amplio && !sinMovimiento)
                  Text(
                    '↑ ${Formato.soles(valores.entro / 100)}   '
                    '↓ ${Formato.soles(valores.salio / 100)}',
                    style: const TextStyle(fontSize: 12, color: Tokens.texto2),
                  ),
              ],
            ),
          ),
          if (amplio) ...[
            Expanded(
              flex: 2,
              child: Text(
                Formato.soles(valores.entro / 100),
                textAlign: TextAlign.right,
                style: monto.copyWith(
                  color: tenue ?? (valores.entro > 0 ? Tokens.entro : null),
                  fontWeight: valores.entro > 0 ? FontWeight.w600 : null,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                Formato.soles(valores.salio / 100),
                textAlign: TextAlign.right,
                style: monto.copyWith(
                  color: tenue ?? (valores.salio > 0 ? Tokens.salio : null),
                  fontWeight: valores.salio > 0 ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
          Expanded(
            flex: 2,
            child: Text(
              '${balance > 0 ? '+' : ''}${Formato.soles(balance / 100)}',
              textAlign: TextAlign.right,
              style: monto.copyWith(
                fontWeight: FontWeight.w700,
                color: tenue ?? (balance >= 0 ? Tokens.entro : Tokens.salio),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PuntoLeyenda extends StatelessWidget {
  const _PuntoLeyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 12, color: Tokens.texto2)),
      ],
    );
  }
}
