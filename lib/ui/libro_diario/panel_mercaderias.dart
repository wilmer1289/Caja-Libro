import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/inventario.dart';

/// El panel de mercaderías: por cada tipo, lo comprado (sin IGV), el costo de
/// lo vendido y el saldo. Es la base del asiento 2 y del inventario.
class PanelMercaderias extends StatelessWidget {
  const PanelMercaderias({
    super.key,
    required this.inventario,
    required this.hasta,
  });

  final InventarioMercaderias inventario;

  /// Hasta qué día llega la cuenta: es acumulada, no del período.
  final DateTime hasta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tokens.superficie,
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        border: Border.all(color: Tokens.borde),
        boxShadow: Tokens.sombraTarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 18, color: Tokens.texto2),
              SizedBox(width: 8),
              Text(
                'Mercaderías',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Tokens.texto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Acumulado hasta el ${Formato.fecha(hasta)}',
            style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
          ),
          const SizedBox(height: 12),
          if (inventario.vacio)
            const Text(
              'Todavía no hay compras ni ventas con tipo de mercadería.',
              style: TextStyle(fontSize: 13, color: Tokens.texto2),
            )
          else
            for (var i = 0; i < inventario.tipos.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              _FilaTipo(saldo: inventario.tipos[i]),
            ],
        ],
      ),
    );
  }
}

class _FilaTipo extends StatelessWidget {
  const _FilaTipo({required this.saldo});

  final SaldoMercaderia saldo;

  @override
  Widget build(BuildContext context) {
    final negativo = saldo.saldo < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                saldo.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Tokens.texto,
                ),
              ),
            ),
            Text(
              Formato.soles(saldo.saldo / 100),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: negativo ? Tokens.salio : Tokens.texto,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: _Cifra('Comprado', saldo.comprado)),
            Expanded(child: _Cifra('Costo vendido', saldo.costoVendido)),
            const Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Saldo',
                  style: TextStyle(fontSize: 11.5, color: Tokens.texto2),
                ),
              ),
            ),
          ],
        ),
        if (negativo) ...[
          const SizedBox(height: 6),
          const Text(
            'Saldo negativo: se vendió más de lo comprado en la app.',
            style: TextStyle(fontSize: 11.5, color: Tokens.salio),
          ),
        ],
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.rotulo, this.centavos);

  final String rotulo;
  final int centavos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: const TextStyle(fontSize: 11.5, color: Tokens.texto2),
        ),
        Text(
          Formato.soles(centavos / 100),
          style: const TextStyle(
            fontSize: 12.5,
            color: Tokens.texto,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
