import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/efectivo.dart';
import '../../dominio/enums.dart';
import '../widgets/conteo_editor.dart';

/// El paso del efectivo: con qué billetes se pagó y qué vuelto se dio.
///
/// Todo cobro o pago en efectivo pasa por acá, porque de esto vive el cierre
/// de caja: con cada billete anotado, la app sabe cuántos de cada uno
/// debería haber al contar. Para que no demore, arriba están los montos con
/// que se suele pagar —el exacto, el billete que redondea— a un toque. El
/// vuelto se calcula solo y se sugiere cómo darlo; quien atiende lo cambia si
/// no tiene esas monedas.
class PasoEfectivo extends StatelessWidget {
  const PasoEfectivo({
    super.key,
    required this.tipo,
    required this.monto,
    required this.entregado,
    required this.vuelto,
    required this.onEntregado,
    required this.onVuelto,
    required this.onSugerirVuelto,
    this.error,
  });

  final Tipo tipo;

  /// El monto del movimiento, en centavos.
  final int monto;
  final Conteo entregado;
  final Conteo vuelto;
  final ValueChanged<Conteo> onEntregado;
  final ValueChanged<Conteo> onVuelto;
  final VoidCallback onSugerirVuelto;
  final String? error;

  /// Con qué se suele pagar un monto: justo, o con el billete o la suma
  /// redonda que lo cubre. Para S/ 37.40: exacto, S/ 40, S/ 50 y S/ 100.
  static List<int> pagosRapidos(int monto) {
    if (monto <= 0) return const [];
    int redondear(int paso) => ((monto + paso - 1) ~/ paso) * paso;
    final opciones = <int>{monto};
    for (final paso in const [1000, 2000, 5000, 10000, 20000]) {
      final valor = redondear(paso);
      if (valor > monto) opciones.add(valor);
    }
    final lista = opciones.toList()..sort();
    return lista.take(4).toList();
  }

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
              'Vuelto',
              vueltoEsperado < 0 ? 0 : vueltoEsperado,
              vueltoEsperado < 0 ? Tokens.texto2 : Tokens.marcaOscura,
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final valor in pagosRapidos(monto))
              ChoiceChip(
                label: Text(
                  valor == monto ? 'Exacto' : Formato.soles(valor / 100),
                ),
                avatar: valor == monto
                    ? const Icon(Icons.done_all_rounded, size: 17)
                    : null,
                selected: entregado.total == valor,
                onSelected: (_) => onEntregado(Conteo.sugerir(valor)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'O marca billete por billete:',
          style: TextStyle(
            fontSize: 12.5,
            color: Tokens.texto2.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 8),
        ConteoEditor(conteo: entregado, onCambiar: onEntregado),
        if (vueltoEsperado > 0) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entro ? 'Vuelto que le diste' : 'Vuelto que te dieron',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Tokens.texto,
                      ),
                    ),
                    Text(
                      'Tiene que sumar ${Formato.soles(vueltoEsperado / 100)}. '
                      'Va sugerido; cámbialo si lo diste con otras monedas.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Tokens.texto2,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onSugerirVuelto,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Sugerir'),
              ),
            ],
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
