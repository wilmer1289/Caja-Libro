import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/importe.dart';
import '../../estado/estado_caja.dart';

/// El costo de lo vendido, con el saldo que hay de ese tipo de mercadería.
///
/// El aviso de que el costo supera el saldo no bloquea: puede que la
/// mercadería ya existiera antes de empezar a usar la app. El campo sí es
/// obligatorio cuando la venta lleva un tipo de mercadería.
class CampoCosto extends StatelessWidget {
  const CampoCosto({
    super.key,
    required this.mercaderiaId,
    required this.fecha,
    required this.costo,
    required this.onCambio,
    this.error,
  });

  final String mercaderiaId;
  final DateTime fecha;
  final TextEditingController costo;
  final VoidCallback onCambio;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final saldo = estado.saldoDeMercaderia(mercaderiaId, fecha: fecha);
    final centavos = Importe.leer(costo.text);
    final aviso = centavos == null
        ? null
        : estado.advertenciaDeCosto(mercaderiaId, centavos, fecha: fecha);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Tokens.fondo,
            borderRadius: BorderRadius.circular(Tokens.radio),
            border: Border.all(color: Tokens.borde),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 17,
                color: Tokens.texto2,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saldo disponible',
                  style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
                ),
              ),
              Text(
                Formato.soles(saldo / 100),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Tokens.texto,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('costo-mercaderia'),
          controller: costo,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: 'Costo de lo vendido',
            prefixText: 'S/ ',
            hintText: '0.00',
            errorText: error,
            helperText: 'Lo que te costó lo vendido, sin IGV. No es el precio de venta.',
            helperMaxLines: 2,
          ),
          onChanged: (_) => onCambio(),
        ),
        if (aviso != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E5),
              borderRadius: BorderRadius.circular(Tokens.radio),
              border: Border.all(color: const Color(0xFFF0DCB4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: Color(0xFF8A6A1F),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    aviso,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF6B520F),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
