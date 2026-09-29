import 'package:flutter/material.dart';

import '../../core/tema.dart';
import 'logo.dart';

/// El logo con el nombre, sobre fondo oscuro.
///
/// Va en el panel del login y en la barra lateral: es el mismo objeto en los
/// dos sitios para que la marca no se vaya separando de a poco.
class MarcaMiCaja extends StatelessWidget {
  const MarcaMiCaja({super.key, this.conBajada = true, this.grande = false});

  /// Sin la bajada "Gestión financiera", para espacios chicos.
  final bool conBajada;

  /// Más grande, para el panel del login, donde la marca tiene todo el aire.
  final bool grande;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoMiCaja(tamano: grande ? 50 : 40),
        SizedBox(width: grande ? 14 : 12),
        // Flexible: con el texto del sistema agrandado, la bajada se corta con
        // "…" en vez de desbordar la barra lateral.
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mi Caja',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: grande ? 21 : 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: Tokens.cromoTexto,
                ),
              ),
              if (conBajada)
                Text(
                  'Gestión financiera',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: grande ? 14.5 : 12,
                    color: Tokens.cromoTexto2,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
