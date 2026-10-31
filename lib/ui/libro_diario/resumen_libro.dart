import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/libro_diario.dart';

/// Lo primero que se mira: cuántas operaciones y asientos hay, cuánto suman el
/// Debe y el Haber, y el sello que dice si cuadra.
class ResumenLibro extends StatelessWidget {
  const ResumenLibro({super.key, required this.libro});

  final LibroDiario libro;

  @override
  Widget build(BuildContext context) {
    final asientos = libro.asientos.fold<int>(0, (s, a) => s + a.etapas.length);
    final sinCosto = libro.asientos.where((a) => a.faltaCosto).length;

    final datos = [
      _Dato('Operaciones', '${libro.asientos.length}'),
      _Dato('Asientos', '$asientos'),
      _Dato('Total Debe', Formato.soles(libro.totalDebe / 100)),
      _Dato('Total Haber', Formato.soles(libro.totalHaber / 100)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tokens.superficie,
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        border: Border.all(color: Tokens.borde),
        boxShadow: Tokens.sombraTarjeta,
      ),
      child: LayoutBuilder(
        builder: (context, medidas) {
          final ancho = medidas.maxWidth >= 600;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Resumen del período',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Tokens.texto,
                      ),
                    ),
                  ),
                  _Sello(cuadra: libro.cuadra, vacio: libro.vacio),
                ],
              ),
              const SizedBox(height: 14),
              if (ancho)
                Row(children: [for (final d in datos) Expanded(child: d)])
              else ...[
                Row(
                  children: [
                    Expanded(child: datos[0]),
                    Expanded(child: datos[1]),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: datos[2]),
                    Expanded(child: datos[3]),
                  ],
                ),
              ],
              if (sinCosto > 0) ...[
                const SizedBox(height: 12),
                Text(
                  sinCosto == 1
                      ? '1 venta sin costo anotado: no tiene asiento 2.'
                      : '$sinCosto ventas sin costo anotado: no tienen asiento 2.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Tokens.marcaOscura,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.rotulo, this.valor);

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: const TextStyle(fontSize: 12, color: Tokens.texto2),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Tokens.texto,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// El sello: "Cuadra" en verde, "No cuadra" en rojo. Sin operaciones no se
/// afirma nada.
class _Sello extends StatelessWidget {
  const _Sello({required this.cuadra, required this.vacio});

  final bool cuadra;
  final bool vacio;

  @override
  Widget build(BuildContext context) {
    if (vacio) return const SizedBox.shrink();
    final color = cuadra ? Tokens.entro : Tokens.salio;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            cuadra ? Icons.verified_rounded : Icons.error_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            cuadra ? 'Cuadra' : 'No cuadra',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
