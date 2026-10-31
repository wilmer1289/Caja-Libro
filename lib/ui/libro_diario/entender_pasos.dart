import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// Ayuda desplegable "Cómo se arma un asiento": los 4 pasos de la exposición
/// y las 3 etapas de una operación. El "por qué" de cada línea lo muestra cada
/// asiento al desplegar una operación.
class EntenderPasos extends StatelessWidget {
  const EntenderPasos({super.key});

  static const _pasos = [
    ('Identifica', '¿Qué pasó? ¿Qué entró y qué salió?'),
    ('Elige las cuentas', 'Búscalas en el plan contable (PCGE 2026).'),
    (
      'Debe y Haber',
      'Lo que entra va al Debe y lo que sale, al Haber. Los gastos van al '
          'Debe; las ventas y el IGV que cobras, al Haber.',
    ),
    ('Cuadra', 'Suma las dos columnas: tienen que dar lo mismo.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.school_outlined, color: Tokens.marca),
        title: const Text(
          'Cómo se arma un asiento',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('Los 4 pasos y las 3 etapas de cada operación.'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _pasos.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Tokens.marcaSuave,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Tokens.marcaOscura,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${_pasos[i].$1}. ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Tokens.texto,
                            ),
                          ),
                          TextSpan(
                            text: _pasos[i].$2,
                            style: const TextStyle(color: Tokens.texto2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
          const Text(
            'Cada operación lleva hasta 3 asientos con el mismo número: el '
            'reconocimiento (el hecho, con su IGV), el destino (variación de '
            'inventarios en una compra, costo de venta en una venta o destino '
            'del gasto) y el pago o el cobro.',
            style: TextStyle(height: 1.4, color: Tokens.texto2),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toca una operación: cada línea dice por qué esa cuenta va en el '
            'Debe o en el Haber.',
            style: TextStyle(
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: Tokens.texto,
            ),
          ),
        ],
      ),
    );
  }
}
