import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/efectivo.dart';
import '../../dominio/enums.dart';
import '../widgets/conteo_editor.dart';

/// Paso de efectivo. Se anotan manualmente los billetes y monedas entregados
/// y, si corresponde, los que se devolvieron como vuelto.
class PasoEfectivo extends StatelessWidget {
  const PasoEfectivo({
    super.key,
    required this.tipo,
    required this.monto,
    required this.entregado,
    required this.vuelto,
    required this.onEntregado,
    required this.onVuelto,
    this.error,
  });

  final Tipo tipo;

  /// El monto del movimiento, en centavos.
  final int monto;
  final Conteo entregado;
  final Conteo vuelto;
  final ValueChanged<Conteo> onEntregado;
  final ValueChanged<Conteo> onVuelto;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final entro = tipo == Tipo.entro;
    final vueltoEsperado = entregado.total - monto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Resumen(
          datos: [
            ('Monto', monto, Tokens.texto),
            (entro ? 'Pagó con' : 'Entregaste', entregado.total, Tokens.texto),
            (
              'Vuelto registrado',
              vuelto.total,
              vuelto.total > 0 ? Tokens.marcaOscura : Tokens.texto2,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          entro ? '¿Con cuánto pagó el cliente?' : '¿Con cuánto pagaste?',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Tokens.texto,
          ),
        ),
        const SizedBox(height: 10),
        ConteoEditor(conteo: entregado, onCambiar: onEntregado),
        if (vueltoEsperado > 0) ...[
          const SizedBox(height: 22),
          Text(
            entro ? 'Vuelto que le diste' : 'Vuelto que te dieron',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Tokens.texto,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Debe sumar ${Formato.soles(vueltoEsperado / 100)}. '
            'Registra los billetes y monedas del vuelto.',
            style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
          ),
          const SizedBox(height: 8),
          ConteoEditor(conteo: vuelto, onCambiar: onVuelto),
        ],
        if (error != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 17,
                color: Tokens.salio,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  error!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Tokens.salio,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.datos});

  final List<(String, int, Color)> datos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
      ),
      child: Row(
        children: [
          for (var i = 0; i < datos.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Tokens.borde,
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    datos[i].$1,
                    style: const TextStyle(fontSize: 12, color: Tokens.texto2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formato.soles(datos[i].$2 / 100),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: datos[i].$3,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
