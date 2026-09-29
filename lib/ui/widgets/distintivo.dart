import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// Una etiqueta chica con un punto de color: "3 ingresos", "Sin egresos".
///
/// Siempre lleva texto. El color acompaña, pero lo que se lee es la palabra
/// (§5, "No solo color").
class Distintivo extends StatelessWidget {
  const Distintivo({
    super.key,
    required this.texto,
    required this.color,
    this.sobreOscuro = false,
    this.icono,
  });

  final String texto;
  final Color color;

  /// Sobre la tarjeta oscura el fondo del distintivo tiene que ser más claro
  /// para que no se pierda.
  final bool sobreOscuro;

  /// En vez del punto, un ícono: la billetera de "Entre caja y banco".
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final icono = this.icono;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icono == null ? 10 : 11,
        vertical: icono == null ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: sobreOscuro ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: sobreOscuro
            ? Border.all(color: color.withValues(alpha: 0.28))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null)
            Icon(icono, size: 15, color: color)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          SizedBox(width: icono == null ? 6 : 7),
          // Flexible: en una tarjeta angosta de celular el texto se corta con
          // "…" en vez de desbordar la pastilla.
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sobreOscuro ? _aclarar(color) : color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sobre grafito, el texto va en el mismo tono pero más claro: el color
  /// puro se empasta con el fondo.
  static Color _aclarar(Color c) => Color.lerp(c, Colors.white, 0.35)!;
}

/// Un número chico con su etiqueta, para las tarjetas: "Entró S/ 90.00".
class DatoChico extends StatelessWidget {
  const DatoChico({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.color = Tokens.texto,
  });

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$etiqueta ',
            style: const TextStyle(color: Tokens.texto2),
          ),
          TextSpan(
            text: valor,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 12,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
