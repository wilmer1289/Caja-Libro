import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/jornada.dart';
import '../../estado/estado_caja.dart';
import '../widgets/tarjeta_saldo.dart';
import 'acta_vista.dart';

/// Las cajas de hoy, de la semana, del mes o todas: cuánto entró y salió en
/// efectivo, cuánto faltó o sobró al contar, cuánto se guardó aparte, y cada
/// caja con su acta.
class ResumenCajasPanel extends StatefulWidget {
  const ResumenCajasPanel({super.key});

  @override
  State<ResumenCajasPanel> createState() => _ResumenCajasPanelState();
}

class _ResumenCajasPanelState extends State<ResumenCajasPanel> {
  PeriodoCajas _periodo = PeriodoCajas.semana;

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final r = estado.resumenCajas(_periodo);

    return TarjetaClara(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tus cajas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Tokens.texto,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: r.vacio
                      ? null
                      : () => ResumenCajasHoja.abrir(context, r),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Imprimir'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: _Periodos(
              elegido: _periodo,
              onElegir: (p) => setState(() => _periodo = p),
            ),
          ),
          if (r.vacio)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
              child: Text(
                _periodo == PeriodoCajas.todo
                    ? 'Todavía no abriste ninguna caja.'
                    : 'No hay cajas en este período.',
                style: const TextStyle(fontSize: 13, color: Tokens.texto2),
              ),
            )
          else ...[
            _Cifras(resumen: r),
            const SizedBox(height: 8),
            for (final c in r.cajas) _FilaCaja(caja: c),
          ],
        ],
      ),
    );
  }
}

/// Hoy, semana, mes o todas, en una sola pieza: la opción elegida se
/// levanta como una tarjetita blanca sobre el fondo.
class _Periodos extends StatelessWidget {
  const _Periodos({required this.elegido, required this.onElegir});

  final PeriodoCajas elegido;
  final ValueChanged<PeriodoCajas> onElegir;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
      ),
      child: Row(
        children: [
          for (final p in PeriodoCajas.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: p == elegido,
                label: p.etiqueta,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onElegir(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p == elegido
                          ? Tokens.superficie
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(Tokens.radio - 3),
                      boxShadow: p == elegido ? Tokens.sombraTarjeta : const [],
                    ),
                    child: Text(
                      p.corta,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: p == elegido
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: p == elegido ? Tokens.texto : Tokens.texto2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cifras extends StatelessWidget {
  const _Cifras({required this.resumen});

  final ResumenCajas resumen;

  @override
  Widget build(BuildContext context) {
    final r = resumen;
    final diferencias = r.diferencias;

    Widget cifra(
      String rotulo,
      String valor, {
      Color color = Tokens.texto,
      IconData? icono,
    }) => Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icono != null) ...[
                Icon(icono, size: 13, color: color),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Tokens.texto2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );

    String soles(int c) => Formato.soles(c / 100);

    final cifras = [
      cifra(
        'Entró en efectivo',
        soles(r.entradas),
        color: Tokens.entro,
        icono: Icons.arrow_upward_rounded,
      ),
      cifra(
        'Salió en efectivo',
        soles(r.salidas),
        color: Tokens.salio,
        icono: Icons.arrow_downward_rounded,
      ),
      cifra('Quedó (entró − salió)', soles(r.neto)),
      cifra(
        diferencias < 0
            ? 'Faltó al contar'
            : diferencias > 0
            ? 'Sobró al contar'
            : 'Al contar',
        diferencias == 0 ? 'Cuadró' : soles(diferencias.abs()),
        color: diferencias < 0
            ? Tokens.salio
            : diferencias > 0
            ? Tokens.marcaOscura
            : Tokens.entro,
      ),
      cifra('Guardado aparte', soles(r.apartado)),
      cifra('Cajas', '${r.cajas.length} · ${r.operaciones} mov.'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, medidas) {
          final columnas = medidas.maxWidth >= 520 ? 3 : 2;
          final ancho = (medidas.maxWidth - 8 * (columnas - 1)) / columnas;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in cifras) SizedBox(width: ancho, child: c),
            ],
          );
        },
      ),
    );
  }
}

class _FilaCaja extends StatelessWidget {
  const _FilaCaja({required this.caja});

  final Jornada caja;

  @override
  Widget build(BuildContext context) {
    final c = caja;
    final color = c.abierta
        ? Tokens.entro
        : c.cuadra
        ? Tokens.entro
        : c.hayFaltante
        ? Tokens.salio
        : Tokens.marcaOscura;
    final fin = c.cerradaEn;
    // "Hoy", "Ayer" o "25 sep": una fecha entera no entra junto a las horas.
    final relativa = Formato.fechaRelativa(c.abiertaEn);
    final dia = relativa.contains('/') ? Formato.diaMes(c.abiertaEn) : relativa;

    return InkWell(
      onTap: c.abierta ? null : () => ActaCierre.abrir(context, c),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 11, 14, 11),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Tokens.borde)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Tokens.fondo,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Tokens.borde),
              ),
              child: Text(
                '${c.numero}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Tokens.texto,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$dia · ${Formato.hora(c.abiertaEn)}'
                    '${fin == null ? '' : ' – ${Formato.hora(fin)}'}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Tokens.texto,
                    ),
                  ),
                  Text(
                    c.abierta
                        ? 'Empezó con ${Formato.soles(c.apertura / 100)} · '
                              'debería haber ${Formato.soles(c.esperado / 100)}'
                        : '${Formato.soles(c.apertura / 100)} → '
                              '${Formato.soles(c.contado / 100)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Tokens.texto2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                c.estadoTexto,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            SizedBox(
              width: 24,
              child: c.abierta
                  ? null
                  : const Icon(
                      Icons.chevron_right_rounded,
                      color: Tokens.texto2,
                      size: 20,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
