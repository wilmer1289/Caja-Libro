import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// La franja de arriba de todo cuando la app corre en la web.
///
/// Sólo aparece ahí (ver `main.dart`, `kIsWeb`): es la versión que se manda
/// por un link para mostrar el avance. Arranca vacía, como un negocio que
/// recién empieza, y lo que se registre no se guarda: al recargar se vuelve
/// a empezar. Sin este aviso, alguien podría creer que sus datos quedaron.
class BannerDemo extends StatelessWidget {
  const BannerDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Tokens.cromo,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Icon(Icons.visibility_outlined, size: 14, color: Tokens.marca),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 12, color: Tokens.cromoTexto2),
              children: [
                const TextSpan(
                  text: 'Vista de demostración: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Tokens.cromoTexto,
                  ),
                ),
                const TextSpan(
                  text:
                      'empieza vacía y lo que registres se borra al recargar. '
                      'Entra con ',
                ),
                TextSpan(
                  text: 'usuario / usuario123',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Tokens.marca,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
