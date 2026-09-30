import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/enums.dart';
import '../../dominio/jornada.dart';
import '../../dominio/mayor.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/resumen.dart';
import '../../dominio/series.dart';
import '../../estado/estado_caja.dart';
import '../historial/acciones_movimiento.dart';
import '../login/personajes.dart';
import '../negocio/negocio_pagina.dart';
import '../registro/registro_hoja.dart';
import '../shell/secciones.dart';
import '../widgets/al_entrar.dart';
import '../widgets/aparece.dart';
import '../widgets/distintivo.dart';
import '../widgets/esqueleto.dart';
import '../widgets/fila_movimiento.dart';
import '../widgets/tarjeta_cuenta.dart';
import '../widgets/tarjeta_saldo.dart';

/// Lo primero que se ve al entrar (§3.2): cuánto hay, cuánto entró y salió
/// este mes, cómo viene el saldo y en qué se está yendo la plata.
class DashboardPagina extends StatelessWidget {
  const DashboardPagina({super.key, this.onIrA});

  /// Para saltar a otra sección desde acá ("Ver todo", tocar una cuenta).
  /// Recibe el índice de la sección.
  final ValueChanged<int>? onIrA;

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();

    if (estado.cargando) return const _Cargando();
    if (estado.vacio &&
        estado.negocio.saldoInicialCaja == 0 &&
        estado.negocio.saldoInicialBanco == 0) {
      return _Bienvenida(onIrA: onIrA);
    }

    final resumen = estado.resumen;
    final recientes = estado.movimientos.take(6).toList();

    return LayoutBuilder(
      builder: (context, medidas) {
        final amplio = medidas.maxWidth >= 760;
        final separacion = amplio ? 20.0 : 14.0;

        // Cada bloque entra un poco después del anterior: la pantalla se arma
        // de arriba hacia abajo en vez de aparecer toda de golpe.
        return ListView(
          padding: EdgeInsets.all(amplio ? 28 : 16),
          children: [
            if (estado.faltaPerfil) ...[
              const Aparece(child: _FaltaPerfil()),
              SizedBox(height: separacion),
            ],
            Aparece(
              child: _CajaDelDia(
                caja: estado.cajaAbierta,
                faltaContar: estado.fondo == null,
                onIr: onIrA == null ? null : () => onIrA!(Seccion.iArqueo),
              ),
            ),
            SizedBox(height: separacion),
            Aparece(
              retraso: const Duration(milliseconds: 40),
              child: _Indicadores(resumen: resumen, amplio: amplio),
            ),
            SizedBox(height: separacion),
            Aparece(
              retraso: const Duration(milliseconds: 80),
              child: _Cuentas(resumen: resumen, amplio: amplio, onIrA: onIrA),
            ),
            SizedBox(height: separacion),
            Aparece(
              retraso: const Duration(milliseconds: 160),
              child: amplio
                  ? const IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 3, child: _GraficoSaldo()),
                          SizedBox(width: 20),
                          Expanded(flex: 2, child: _GraficoCategorias()),
                        ],
                      ),
                    )
                  : const Column(
                      children: [
                        _GraficoSaldo(),
                        SizedBox(height: 14),
                        _GraficoCategorias(),
                      ],
                    ),
            ),
            SizedBox(height: separacion),
            Aparece(
              retraso: const Duration(milliseconds: 240),
              child: _Recientes(
                movimientos: recientes,
                recienRegistrado: estado.recienRegistrado,
                onVerTodo: onIrA == null
                    ? null
                    : () => onIrA!(Seccion.iHistorial),
              ),
            ),
            // Aire para que los botones flotantes del celular no tapen la
            // última fila.
            SizedBox(height: amplio ? 8 : 120),
          ],
        );
      },
    );
  }
}

/// Aviso de que falta el perfil del negocio.
///
/// No bloquea nada: se puede registrar igual. Pero sin RUC, razón social y
/// saldo inicial no hay Formato 1.1 posible, y eso conviene saberlo antes de
/// tener tres meses cargados.
class _FaltaPerfil extends StatelessWidget {
  const _FaltaPerfil();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tokens.marcaSuave,
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        border: Border.all(color: Tokens.marca.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Tokens.marca.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 19,
              color: Tokens.marca,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Falta completar los datos de tu negocio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Tokens.texto,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tu RUC, tu nombre y el saldo con que abriste. Sin eso no se '
                  'puede emitir el Formato 1.1.',
                  style: TextStyle(fontSize: 12.5, color: Tokens.texto2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => NegocioPagina.abrir(context),
            style: FilledButton.styleFrom(
              backgroundColor: Tokens.marca,
              foregroundColor: Colors.white,
            ),
            child: const Text('Completar'),
          ),
        ],
      ),
    );
  }
}

/// Una franja con el estado de la caja del día: abierta, con lo que debería
/// haber, o cerrada, con el botón para abrirla. Es lo primero que se hace al
/// llegar, así que va arriba de todo.
class _CajaDelDia extends StatelessWidget {
  const _CajaDelDia({required this.caja, required this.faltaContar, this.onIr});

  final Jornada? caja;

  /// Todavía no se contó el efectivo del negocio: es lo primero.
  final bool faltaContar;
  final VoidCallback? onIr;

  @override
  Widget build(BuildContext context) {
    final c = caja;
    final abierta = c != null;
    final color = abierta ? Tokens.entro : Tokens.texto2;

    return Material(
      color: Tokens.superficie,
      borderRadius: BorderRadius.circular(Tokens.radioGrande),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        onTap: onIr,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radioGrande),
            border: Border.all(color: Tokens.borde),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  abierta ? Icons.lock_open_rounded : Icons.lock_rounded,
                  size: 19,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      abierta
                          ? 'Caja N° ${c.numero} abierta desde las '
                                '${Formato.hora(c.abiertaEn)}'
                          : 'La caja está cerrada',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Tokens.texto,
                      ),
                    ),
                    Text(
                      abierta
                          ? 'Debería haber ${Formato.soles(c.esperado / 100)} '
                                'en efectivo'
                          : faltaContar
                          ? 'Primero cuenta el efectivo del negocio y ábrela'
                          : 'Ábrela para registrar en efectivo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Tokens.texto2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (abierta)
                const Icon(Icons.chevron_right_rounded, color: Tokens.texto2)
              else
                FilledButton(
                  onPressed: onIr,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Abrir caja'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "3 ingresos", "1 ingreso", o el texto de vacío.
String _contar(int n, String singular, String plural, String ninguno) {
  if (n == 0) return ninguno;
  return n == 1 ? '1 $singular' : '$n $plural';
}

class _Indicadores extends StatelessWidget {
  const _Indicadores({required this.resumen, required this.amplio});

  final Resumen resumen;
  final bool amplio;

  @override
  Widget build(BuildContext context) {
    final total = resumen.saldoTotal;

    final saldo = TarjetaSaldo(
      titulo: 'Lo que tienes ahora',
      centavos: total,
      destacada: true,
      oscura: true,
      distintivo: Distintivo(
        sobreOscuro: true,
        icono: Icons.account_balance_wallet_outlined,
        texto: total > 0
            ? 'Entre caja y banco'
            : total == 0
            ? 'Todavía sin saldo'
            : 'En negativo',
        color: total >= 0 ? Tokens.marca : Tokens.salioVivo,
      ),
    );

    final entro = TarjetaSaldo(
      titulo: 'Entró este mes',
      centavos: resumen.entroMes,
      color: Tokens.entro,
      icono: Icons.arrow_upward_rounded,
      // En el celular las dos tarjetas van lado a lado y no hay lugar para
      // la insignia: le robaría el ancho al monto.
      insignia: amplio ? Icons.arrow_upward_rounded : null,
      distintivo: Distintivo(
        texto: _contar(
          resumen.cantidadEntroMes,
          'ingreso',
          'ingresos',
          'Sin ingresos',
        ),
        color: resumen.cantidadEntroMes == 0 ? Tokens.texto2 : Tokens.entro,
      ),
    );

    final salio = TarjetaSaldo(
      titulo: 'Salió este mes',
      centavos: resumen.salioMes,
      color: Tokens.salio,
      icono: Icons.arrow_downward_rounded,
      insignia: amplio ? Icons.arrow_downward_rounded : null,
      distintivo: Distintivo(
        texto: _contar(
          resumen.cantidadSalioMes,
          'egreso',
          'egresos',
          'Sin egresos',
        ),
        color: resumen.cantidadSalioMes == 0 ? Tokens.texto2 : Tokens.salio,
      ),
    );

    if (amplio) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: saldo),
            const SizedBox(width: 20),
            Expanded(flex: 4, child: entro),
            const SizedBox(width: 20),
            Expanded(flex: 4, child: salio),
          ],
        ),
      );
    }

    // En celular no se igualan las alturas con IntrinsicHeight: mide el monto
    // antes de achicarlo para que entre, y en una tarjeta angosta eso dejaba
    // las dos tarjetas altísimas y medio vacías.
    return Column(
      children: [
        saldo,
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: entro),
            const SizedBox(width: 14),
            Expanded(child: salio),
          ],
        ),
      ],
    );
  }
}

class _Cuentas extends StatelessWidget {
  const _Cuentas({required this.resumen, required this.amplio, this.onIrA});

  final Resumen resumen;
  final bool amplio;
  final ValueChanged<int>? onIrA;

  @override
  Widget build(BuildContext context) {
    /// Lleva a "Caja y bancos" con esa cuenta ya elegida: tocar "Caja" y
    /// caer en el total obligaría a buscar el efectivo de nuevo.
    VoidCallback? ir(Bolsillo bolsillo) {
      final onIrA = this.onIrA;
      if (onIrA == null) return null;
      return () {
        context.read<EstadoCaja>().verBolsillo(bolsillo);
        onIrA(Seccion.iCajaYBancos);
      };
    }

    final caja = TarjetaCuenta(
      icono: Icons.payments_outlined,
      titulo: Cuenta.caja.etiqueta,
      bajada: 'Billetes y monedas en el negocio',
      centavos: resumen.saldoCaja,
      onTap: ir(Bolsillo.caja),
    );
    final banco = TarjetaCuenta(
      icono: Icons.account_balance_outlined,
      titulo: Cuenta.banco.etiqueta,
      bajada: 'Yape, Plin, transferencia y más',
      centavos: resumen.saldoBanco,
      onTap: ir(Bolsillo.banco),
    );

    if (amplio) {
      return Row(
        children: [
          Expanded(child: caja),
          const SizedBox(width: 20),
          Expanded(child: banco),
        ],
      );
    }
    return Column(children: [caja, const SizedBox(height: 10), banco]);
  }
}

/// Título y bajada de una tarjeta de contenido.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.titulo, this.bajada, this.accion});

  final String titulo;
  final String? bajada;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Tokens.texto,
                ),
              ),
              if (bajada != null) ...[
                const SizedBox(height: 3),
                Text(
                  bajada!,
                  style: const TextStyle(fontSize: 13, color: Tokens.texto2),
                ),
              ],
            ],
          ),
        ),
        ?accion,
      ],
    );
  }
}

class _GraficoSaldo extends StatelessWidget {
  const _GraficoSaldo();

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final puntos = Series.saldoDiario(
      estado.movimientosVigentes,
      saldoInicial:
          estado.negocio.saldoInicialCaja + estado.negocio.saldoInicialBanco,
      inicioPeriodo: estado.negocio.inicioPeriodo,
    );
    final ultimo = puntos.length - 1;
    final escala = _Escala.de([for (final p in puntos) p.centavos / 100]);

    // Una etiqueta por semana, como en un calendario: "1 sep", "8 sep"…
    // Con menos días, las que entren sin pisarse.
    final pasoDias = ultimo >= 20 ? 7 : math.max(1, (ultimo / 3).ceil());

    return TarjetaClara(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cabecera(
              titulo: 'Cómo viene tu saldo',
              bajada: ultimo >= 29
                  ? 'Últimos 30 días'
                  : 'Desde que abriste el libro',
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 210,
              child: AlEntrar(
                constructor: (context, listo) => LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: ultimo == 0 ? 1 : ultimo.toDouble(),
                    minY: escala.minimo,
                    maxY: escala.maximo,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: escala.paso,
                      getDrawingHorizontalLine: (_) =>
                          const FlLine(color: Tokens.borde, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: const Border(
                        bottom: BorderSide(color: Tokens.bordeFuerte),
                      ),
                    ),
                    // Al pasar el mouse (o el dedo) se lee el saldo exacto de
                    // ese día: el eje sólo da la idea, el número está acá.
                    lineTouchData: LineTouchData(
                      getTouchedSpotIndicator: (barra, indices) => [
                        for (final _ in indices)
                          TouchedSpotIndicatorData(
                            FlLine(
                              color: Tokens.marca.withValues(alpha: 0.35),
                              strokeWidth: 1.2,
                              dashArray: const [4, 4],
                            ),
                            FlDotData(
                              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                                radius: 5,
                                color: Tokens.marca,
                                strokeWidth: 2.5,
                                strokeColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => Tokens.cromo,
                        tooltipBorderRadius: BorderRadius.circular(10),
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        getTooltipItems: (tocados) => [
                          for (final t in tocados)
                            LineTooltipItem(
                              Formato.soles(puntos[t.x.round()].centavos / 100),
                              const TextStyle(
                                fontFamily: Tokens.tipografia,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      '\n${Formato.diaMes(puntos[t.x.round()].dia)}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Tokens.cromoTexto2,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          interval: escala.paso,
                          getTitlesWidget: (valor, meta) {
                            // fl_chart agrega el mínimo y el máximo exactos
                            // aunque no caigan en el paso: se saltan para que
                            // no se pisen con la etiqueta de al lado.
                            final resto = (valor - escala.minimo) % escala.paso;
                            if (resto > 0.01 && escala.paso - resto > 0.01) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              space: 10,
                              child: Text(
                                Formato.compacto(valor),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Tokens.texto2,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: pasoDias.toDouble(),
                          getTitlesWidget: (valor, meta) {
                            final i = valor.round();
                            if (i < 0 || i >= puntos.length) {
                              return const SizedBox.shrink();
                            }
                            // El último punto sólo lleva etiqueta si cae en
                            // el paso: si no, se pisa con la anterior.
                            if (i % pasoDias != 0) {
                              return const SizedBox.shrink();
                            }
                            // fitInside empuja hacia adentro las etiquetas de
                            // los extremos: centradas sobre el primer y el
                            // último punto, quedaban medio afuera de la tarjeta.
                            return SideTitleWidget(
                              meta: meta,
                              space: 8,
                              fitInside: SideTitleFitInsideData.fromTitleMeta(
                                meta,
                                distanceFromEdge: 0,
                              ),
                              child: Text(
                                Formato.diaMes(puntos[i].dia),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Tokens.texto2,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < puntos.length; i++)
                            FlSpot(
                              i.toDouble(),
                              listo
                                  ? puntos[i].centavos / 100
                                  : math.max(0, escala.minimo),
                            ),
                        ],
                        isCurved: true,
                        curveSmoothness: 0.25,
                        preventCurveOverShooting: true,
                        color: Tokens.marca,
                        barWidth: 2.8,
                        isStrokeCapRound: true,
                        // Un punto sólo al final: marca "hoy" sin ensuciar la
                        // línea con treinta puntitos.
                        dotData: FlDotData(
                          show: true,
                          checkToShowDot: (punto, _) => punto.x == ultimo,
                          getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                            radius: 5,
                            color: Tokens.marca,
                            strokeWidth: 2.5,
                            strokeColor: Colors.white,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Tokens.marca.withValues(alpha: 0.20),
                              Tokens.marca.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 620),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mínimo, máximo y paso del eje de montos, en números redondos: el eje dice
/// "10 mil, 20 mil, 30 mil", no "8,734 · 17,468".
class _Escala {
  const _Escala(this.minimo, this.maximo, this.paso);

  final double minimo;
  final double maximo;
  final double paso;

  factory _Escala.de(List<double> valores) {
    // El cero siempre entra: una línea que arranca a mitad del gráfico
    // exagera cualquier subida o bajada.
    var bajo = 0.0, alto = 0.0;
    for (final v in valores) {
      if (v < bajo) bajo = v;
      if (v > alto) alto = v;
    }
    if (alto - bajo < 1) alto = bajo + 100;

    final paso = _redondo((alto - bajo) / 4);
    final minimo = (bajo / paso).floorToDouble() * paso;
    var maximo = (alto / paso).ceilToDouble() * paso;
    // Un poco de aire arriba: si el máximo cae justo en la última línea, la
    // curva se pega al borde de la tarjeta.
    if (maximo - alto < paso * 0.12) maximo += paso;
    return _Escala(minimo, maximo, paso);
  }

  /// 1, 2, 2.5 o 5 por una potencia de diez.
  static double _redondo(double crudo) {
    final potencia = math
        .pow(10, (math.log(crudo) / math.ln10).floor())
        .toDouble();
    final normal = crudo / potencia;
    final double factor = normal <= 1
        ? 1
        : normal <= 2
        ? 2
        : normal <= 2.5
        ? 2.5
        : normal <= 5
        ? 5
        : 10;
    return factor * potencia;
  }
}

class _GraficoCategorias extends StatelessWidget {
  const _GraficoCategorias();

  /// Paleta de la dona: el naranja de la marca, el grafito y el morado del
  /// personaje primero, como en la referencia. Alternan claro y oscuro para
  /// distinguirse también en escala de grises.
  static const _colores = [
    Tokens.marca,
    Tokens.cromo,
    Color(0xFF6D4AE0),
    Color(0xFFE9B872),
    Tokens.entro,
    Color(0xFFA39C94),
    Tokens.salio,
    Color(0xFFF5C400),
  ];

  @override
  Widget build(BuildContext context) {
    final movimientos = context.watch<EstadoCaja>().movimientosVigentes;
    final porciones = Series.egresosPorCategoria(movimientos);
    final total = porciones.fold<int>(0, (a, p) => a + p.centavos);

    return TarjetaClara(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cabecera(
              titulo: 'En qué se fue la plata',
              bajada: Formato.capitalizar(Formato.mes(DateTime.now())),
            ),
            const SizedBox(height: 16),
            if (total == 0)
              const SizedBox(height: 210, child: _SinEgresos())
            else
              SizedBox(
                height: 210,
                child: Row(
                  children: [
                    SizedBox(
                      width: 184,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AlEntrar(
                            constructor: (context, listo) => PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 58,
                                startDegreeOffset: -90,
                                sections: [
                                  for (var i = 0; i < porciones.length; i++)
                                    PieChartSectionData(
                                      value: porciones[i].centavos.toDouble(),
                                      color: _colores[i % _colores.length],
                                      // El anillo engorda al aparecer.
                                      radius: listo ? 26 : 0,
                                      showTitle: false,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // El total al centro: la dona dice "en qué", el
                          // centro dice "cuánto". El ancho fijo es el del
                          // hueco; sin él, un monto grande tapaba la dona.
                          SizedBox(
                            width: 100,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  child: Text(
                                    Formato.soles(total / 100),
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: Tokens.texto,
                                    ),
                                  ),
                                ),
                                const Text(
                                  'salió',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Tokens.texto2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // La leyenda centrada junto a la dona, no pegada arriba:
                    // con tres o cuatro categorías, arriba quedaba un hueco.
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < porciones.length; i++)
                                _Leyenda(
                                  color: _colores[i % _colores.length],
                                  etiqueta: porciones[i].categoria.etiqueta,
                                  monto: porciones[i].centavos,
                                  porcentaje: porciones[i].centavos / total,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SinEgresos extends StatelessWidget {
  const _SinEgresos();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Tokens.entroSuave,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.savings_outlined,
              color: Tokens.entro,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Este mes todavía no salió plata',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Tokens.texto,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cuando registres un gasto, acá vas a ver en qué se fue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Tokens.texto2),
          ),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({
    required this.color,
    required this.etiqueta,
    required this.monto,
    required this.porcentaje,
  });

  final Color color;
  final String etiqueta;
  final int monto;
  final double porcentaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 11,
            height: 11,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Tokens.texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formato.soles(monto / 100)} · '
                  '${(porcentaje * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Tokens.texto2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Recientes extends StatelessWidget {
  const _Recientes({
    required this.movimientos,
    this.recienRegistrado,
    this.onVerTodo,
  });

  final List<Movimiento> movimientos;
  final String? recienRegistrado;
  final VoidCallback? onVerTodo;

  @override
  Widget build(BuildContext context) {
    return TarjetaClara(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: _Cabecera(
              titulo: 'Movimientos recientes',
              accion: onVerTodo == null
                  ? null
                  : TextButton(
                      onPressed: onVerTodo,
                      child: const Text('Ver todo'),
                    ),
            ),
          ),
          for (var i = 0; i < movimientos.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            FilaMovimiento(
              movimiento: movimientos[i],
              resaltar: movimientos[i].id == recienRegistrado,
              onTap: () => AccionesMovimiento.abrir(context, movimientos[i]),
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Primera vez: en vez de números en cero, los personajes del login dando la
/// bienvenida. Es la misma cara que vio al entrar, y le dice qué hacer.
class _Bienvenida extends StatelessWidget {
  const _Bienvenida({this.onIrA});

  final ValueChanged<int>? onIrA;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Aparece(
            child: TarjetaClara(
              clip: true,
              child: Column(
                children: [
                  Container(
                    height: 170,
                    color: Tokens.escenario,
                    // Miran hacia abajo, hacia el botón.
                    child: const Personajes(
                      mirada: Offset(0, 0.8),
                      ojosCerrados: false,
                      margenInferior: 10,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                    child: Column(
                      children: [
                        const Text(
                          'Aún no registraste nada',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Tokens.texto,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cuando entre o salga plata del negocio, anótalo acá. '
                          'Te toma menos de diez segundos y el saldo se '
                          'calcula solo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Tokens.texto2,
                          ),
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: () => _registrarPrimero(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: Tokens.entro,
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                          ),
                          icon: const Icon(Icons.arrow_upward_rounded),
                          label: const Text('Registrar mi primera venta'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _registrarPrimero(BuildContext context) async {
    // Lleva directo al caso más común de una bodega: una venta.
    final mensajero = ScaffoldMessenger.of(context);
    final guardado = await RegistroHoja.abrir(
      context,
      Tipo.entro,
      onAbrirCaja: onIrA == null ? null : () => onIrA!(Seccion.iArqueo),
    );
    if (guardado != null) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('¡Listo! Tu primera venta quedó anotada')),
      );
    }
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        Esqueleto(ancho: double.infinity, alto: 132, radio: 20),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Esqueleto(ancho: double.infinity, alto: 74, radio: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Esqueleto(ancho: double.infinity, alto: 74, radio: 20),
            ),
          ],
        ),
        SizedBox(height: 16),
        Esqueleto(ancho: double.infinity, alto: 250, radio: 20),
      ],
    );
  }
}
