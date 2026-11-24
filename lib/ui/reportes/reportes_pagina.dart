import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/almacen.dart' show Cantidad;
import '../../dominio/kardex.dart';
import '../../dominio/mercaderia.dart';
import '../../dominio/periodo.dart';
import '../../dominio/series.dart';
import '../../estado/estado_caja.dart';
import '../widgets/al_entrar.dart';
import '../widgets/aparece.dart';
import '../widgets/esqueleto.dart';
import '../widgets/estado_vacio.dart';

/// Reportes del §4.5: cuánto entró y salió mes a mes, en gráfico y en tabla.
///
/// Incluye reportes de inventario: valor total, margen por producto y productos
/// sin movimiento.
class ReportesPagina extends StatelessWidget {
  const ReportesPagina({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();

    if (estado.cargando) return const EsqueletoLista();

    final kardex = estado.kardex;
    final productos = estado.productosActivos;
    if (estado.vacio && productos.isEmpty && kardex.productos.isEmpty) {
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

    // Datos de inventario
    final valorTotal = kardex.valorTotal();
    final margenPorProducto = <String, int>{};
    final productosSinMovimiento = <Mercaderia>[];

    for (final p in productos) {
      final ventas = kardex
          .filas(p.id, periodo: Periodo.mes)
          .any((fila) => fila.linea.operacion == OperacionAlmacen.venta);
      if (ventas) {
        final margen = kardex.margenPorProducto(p.id, Periodo.mes);
        margenPorProducto[p.id] = margen;
      }
      if (kardex.filas(p.id, periodo: Periodo.mes).isEmpty) {
        productosSinMovimiento.add(p);
      }
    }

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
            // --- Mes a mes ---
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

            // --- Inventario ---
            const SizedBox(height: 32),
            Aparece(
              retraso: const Duration(milliseconds: 200),
              child: _InventarioReportes(
                valorTotal: valorTotal,
                margenPorProducto: margenPorProducto,
                productosSinMovimiento: productosSinMovimiento,
                productos: productos,
                kardex: kardex,
                amplio: amplio,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InventarioReportes extends StatelessWidget {
  const _InventarioReportes({
    required this.valorTotal,
    required this.margenPorProducto,
    required this.productosSinMovimiento,
    required this.productos,
    required this.kardex,
    required this.amplio,
  });

  final int valorTotal;
  final Map<String, int> margenPorProducto;
  final List<Mercaderia> productosSinMovimiento;
  final List<Mercaderia> productos;
  final Kardex kardex;
  final bool amplio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Valor total del inventario
        _TarjetaReporte(
          icono: Icons.account_balance_wallet_outlined,
          titulo: 'Valor del inventario',
          subtitulo: Formato.soles(valorTotal / 100),
          color: Tokens.entro,
          anchoCompleto: true,
        ),
        const SizedBox(height: 16),
        // Margen por producto
        if (margenPorProducto.isNotEmpty) ...[
          _TarjetaReporte(
            icono: Icons.trending_up_outlined,
            titulo: 'Margen por producto',
            subtitulo: '${margenPorProducto.length} productos con ventas',
            color: Tokens.cromo,
            anchoCompleto: true,
            accion: _DetalleMargen(
              margenPorProducto: margenPorProducto,
              productos: productos,
              kardex: kardex,
              amplio: amplio,
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Productos sin movimiento
        if (productosSinMovimiento.isNotEmpty) ...[
          _TarjetaReporte(
            icono: Icons.inventory_outlined,
            titulo: 'Productos sin movimiento',
            subtitulo:
                '${productosSinMovimiento.length} de ${productos.length}',
            color: Tokens.salio,
            anchoCompleto: true,
            accion: _DetalleSinMovimiento(
              productos: productosSinMovimiento,
              amplio: amplio,
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Stock actual
        if (productos.isNotEmpty) ...[
          _TarjetaReporte(
            icono: Icons.warehouse_outlined,
            titulo: 'Stock actual',
            subtitulo: '${productos.length} productos activos',
            color: Tokens.texto2,
            anchoCompleto: true,
            accion: _DetalleStock(
              productos: productos,
              kardex: kardex,
              amplio: amplio,
            ),
          ),
        ],
      ],
    );
  }
}

class _TarjetaReporte extends StatelessWidget {
  const _TarjetaReporte({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    this.anchoCompleto = false,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color color;
  final bool anchoCompleto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.08),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Icon(icono, size: 24, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitulo,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Tokens.texto2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (accion != null) ...[const Divider(height: 1), accion!],
        ],
      ),
    );
  }
}

class _DetalleMargen extends StatelessWidget {
  const _DetalleMargen({
    required this.margenPorProducto,
    required this.productos,
    required this.kardex,
    required this.amplio,
  });

  final Map<String, int> margenPorProducto;
  final List<Mercaderia> productos;
  final Kardex kardex;
  final bool amplio;

  @override
  Widget build(BuildContext context) {
    // Ordenar por margen descendente
    final ordenados = margenPorProducto.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (amplio)
            Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text('PRODUCTO', style: _estiloCabecera),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'VENTAS',
                    style: _estiloCabecera,
                    textAlign: TextAlign.right,
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'COSTO',
                    style: _estiloCabecera,
                    textAlign: TextAlign.right,
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'MARGEN',
                    style: _estiloCabecera,
                    textAlign: TextAlign.right,
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'MARGEN %',
                    style: _estiloCabecera,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
          const SizedBox(height: 8),
          for (var i = 0; i < ordenados.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            _FilaMargen(
              entrada: ordenados[i],
              productos: productos,
              kardex: kardex,
              amplio: amplio,
            ),
          ],
        ],
      ),
    );
  }

  static const _estiloCabecera = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: Tokens.texto2,
  );
}

class _FilaMargen extends StatelessWidget {
  const _FilaMargen({
    required this.entrada,
    required this.productos,
    required this.kardex,
    required this.amplio,
  });

  final MapEntry<String, int> entrada;
  final List<Mercaderia> productos;
  final Kardex kardex;
  final bool amplio;

  @override
  Widget build(BuildContext context) {
    final producto = productos.firstWhere((p) => p.id == entrada.key);
    final margen = entrada.value;
    final ventas = kardex
        .filas(producto.id, periodo: Periodo.mes)
        .where((f) => f.linea.operacion == OperacionAlmacen.venta)
        .fold<int>(0, (s, f) => s + (f.linea.importe ?? 0));
    final costo = ventas - margen;
    final margenPct = ventas > 0 ? (margen / ventas * 100) : 0.0;

    final montoStyle = TextStyle(
      fontSize: 13,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: Tokens.texto,
    );

    if (amplio) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              producto.nombre,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              Formato.soles(ventas / 100),
              textAlign: TextAlign.right,
              style: montoStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              Formato.soles(costo / 100),
              textAlign: TextAlign.right,
              style: montoStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              Formato.soles(margen / 100),
              textAlign: TextAlign.right,
              style: montoStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: margen >= 0 ? Tokens.entro : Tokens.salio,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${margenPct.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: montoStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: margen >= 0 ? Tokens.entro : Tokens.salio,
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  producto.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                Formato.soles(margen / 100),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: margen >= 0 ? Tokens.entro : Tokens.salio,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ventas: ${Formato.soles(ventas / 100)}  •  Costo: ${Formato.soles(costo / 100)}  •  Margen: ${margenPct.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 12, color: Tokens.texto2),
          ),
        ],
      );
    }
  }
}

class _DetalleSinMovimiento extends StatelessWidget {
  const _DetalleSinMovimiento({required this.productos, required this.amplio});

  final List<Mercaderia> productos;
  final bool amplio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Estos productos no tuvieron compras ni ventas en el mes actual:',
            style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < productos.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            _FilaProductoSimple(producto: productos[i]),
          ],
        ],
      ),
    );
  }
}

class _DetalleStock extends StatelessWidget {
  const _DetalleStock({
    required this.productos,
    required this.kardex,
    required this.amplio,
  });

  final List<Mercaderia> productos;
  final Kardex kardex;
  final bool amplio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (amplio)
            Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text('PRODUCTO', style: _estiloCabecera),
                ),
                const Expanded(
                  child: Text(
                    'CANTIDAD',
                    style: _estiloCabecera,
                    textAlign: TextAlign.right,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'VALOR',
                    style: _estiloCabecera,
                    textAlign: TextAlign.right,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'COSTO UNIT.',
                    style: _estiloCabecera,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
          const SizedBox(height: 8),
          for (var i = 0; i < productos.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            _FilaStock(producto: productos[i], kardex: kardex, amplio: amplio),
          ],
        ],
      ),
    );
  }

  static const _estiloCabecera = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: Tokens.texto2,
  );
}

class _FilaStock extends StatelessWidget {
  const _FilaStock({
    required this.producto,
    required this.kardex,
    required this.amplio,
  });

  final Mercaderia producto;
  final Kardex kardex;
  final bool amplio;

  @override
  Widget build(BuildContext context) {
    final saldo = kardex.saldo(producto.id);
    final cantidad = saldo.cantidad;
    final valor = saldo.costo;
    final costoUnitario = saldo.costoUnitario;
    final unidad = producto.abreviaturaUnidad;

    if (amplio) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              producto.nombre,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              '${Cantidad.texto(cantidad)} $unidad',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              Formato.soles(valor / 100),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              costoUnitario > 0 ? Formato.soles(costoUnitario / 100) : '-',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  producto.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                Formato.soles(valor / 100),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Stock: ${Cantidad.texto(cantidad)} $unidad  •  Costo unitario: ${costoUnitario > 0 ? Formato.soles(costoUnitario / 100) : '—'}',
            style: const TextStyle(fontSize: 12, color: Tokens.texto2),
          ),
        ],
      );
    }
  }
}

class _FilaProductoSimple extends StatelessWidget {
  const _FilaProductoSimple({required this.producto});

  final Mercaderia producto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            producto.nombre,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Tokens.salio.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Tokens.salio.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'Sin movimiento',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Tokens.salio,
            ),
          ),
        ),
      ],
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
