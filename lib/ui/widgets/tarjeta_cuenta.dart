import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import 'elevable.dart';
import 'tarjeta_saldo.dart';

/// Una cuenta en una línea: ícono en su círculo durazno, nombre, bajada y el
/// saldo a la derecha. Se puede tocar.
///
/// La usan el resumen (para ir a "Caja y bancos") y la misma "Caja y bancos"
/// (para filtrar el libro por esa cuenta).
class TarjetaCuenta extends StatelessWidget {
  const TarjetaCuenta({
    super.key,
    required this.icono,
    required this.titulo,
    required this.bajada,
    required this.centavos,
    this.onTap,
    this.elegida = false,
    this.conFlecha = true,
  });

  final IconData icono;
  final String titulo;
  final String bajada;
  final int centavos;
  final VoidCallback? onTap;

  /// Con borde naranja: es el filtro que está puesto.
  final bool elegida;

  final bool conFlecha;

  @override
  Widget build(BuildContext context) {
    final tarjeta = TarjetaClara(
      resaltada: elegida,
      clip: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: elegida ? Tokens.marca : Tokens.marcaSuave,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icono,
                    size: 22,
                    color: elegida ? Colors.white : Tokens.marca,
                  ),
                ),
                const SizedBox(width: 14),
                // 3 a 2: el nombre y la bajada se llevan más lugar que el
                // monto, que casi siempre es corto. A partes iguales, la
                // bajada se cortaba con "…" teniendo espacio de sobra.
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Tokens.texto,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bajada,
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
                const SizedBox(width: 12),
                // Flexible + FittedBox: el monto se achica si no entra, en vez
                // de empujar al nombre hasta dejarlo una letra por renglón.
                Flexible(
                  flex: 2,
                  // Align ocupa todo el lugar que le toca y deja el monto
                  // pegado a la derecha, donde se leen los números.
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: centavos / 100),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, valor, _) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          Formato.soles(valor),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: centavos < 0 ? Tokens.salio : Tokens.texto,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (conFlecha && onTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: Tokens.texto2,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return onTap == null ? tarjeta : Elevable(child: tarjeta);
  }
}
