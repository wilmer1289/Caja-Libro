import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/almacen.dart';

/// Fila compartida por los conteos periódicos y anuales.
class FilaConteo extends StatelessWidget {
  const FilaConteo({
    super.key,
    required this.producto,
    required this.codigo,
    required this.unidad,
    required this.stock,
    required this.valor,
    required this.cantidad,
    required this.costoSobrante,
    required this.diferencia,
    required this.diferenciaValor,
    required this.onCambiar,
  });

  final String producto, codigo, unidad;
  final int stock, valor;
  final TextEditingController cantidad;
  final TextEditingController? costoSobrante;
  final int? diferencia, diferenciaValor;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Tokens.superficie,
      border: Border.all(color: Tokens.borde),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$codigo · $producto',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Tokens.texto,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sistema: ${Cantidad.texto(stock)} $unidad · ${Formato.soles(valor / 100)}',
          style: const TextStyle(fontSize: 12, color: Tokens.texto2),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 165,
              child: TextField(
                controller: cantidad,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => onCambiar(),
                decoration: InputDecoration(
                  labelText: 'Contado ($unidad)',
                  isDense: true,
                ),
              ),
            ),
            if (diferencia != null)
              Text(
                '${diferencia! > 0
                    ? 'Sobra'
                    : diferencia! < 0
                    ? 'Falta'
                    : 'Cuadra'}: '
                '${Cantidad.texto(diferencia!.abs())} $unidad · '
                '${diferenciaValor == null ? '—' : Formato.soles(diferenciaValor!.abs() / 100)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: diferencia == 0
                      ? Tokens.texto2
                      : diferencia! > 0
                      ? Tokens.entro
                      : Tokens.salio,
                ),
              ),
            if (costoSobrante != null)
              SizedBox(
                width: 190,
                child: TextField(
                  controller: costoSobrante,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) => onCambiar(),
                  decoration: const InputDecoration(
                    labelText: 'Costo unitario del sobrante',
                    prefixText: 'S/ ',
                    isDense: true,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
