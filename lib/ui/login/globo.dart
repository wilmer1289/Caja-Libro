import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// El globo de diálogo de los personajes.
///
/// Cuando cambia lo que dicen, el globo nuevo aparece con un pequeño "pop"
/// que sale desde la punta, como si lo acabaran de decir. Y el globo se estira
/// o se encoge suave según el largo de la frase, en vez de saltar de tamaño.
class GloboDialogo extends StatelessWidget {
  const GloboDialogo({super.key, required this.texto, this.cola = 26});

  final String texto;

  /// A qué distancia del borde izquierdo sale la punta del globo.
  final double cola;

  static const _altoCola = 9.0;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FormaGlobo(cola: cola, altoCola: _altoCola),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11 + _altoCola),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (hijo, animacion) => FadeTransition(
              opacity: animacion,
              child: ScaleTransition(
                scale: Tween(begin: 0.85, end: 1.0).animate(animacion),
                alignment: Alignment.bottomLeft,
                child: hijo,
              ),
            ),
            // Mientras se cruzan, el que sale y el que entra se apilan desde
            // abajo a la izquierda: así la frase no brinca de lugar.
            layoutBuilder: (actual, anteriores) => Stack(
              alignment: Alignment.bottomLeft,
              children: [...anteriores, ?actual],
            ),
            child: Text(
              texto,
              key: ValueKey(texto),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Tokens.texto,
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormaGlobo extends CustomPainter {
  const _FormaGlobo({required this.cola, required this.altoCola});

  final double cola;
  final double altoCola;

  @override
  void paint(Canvas canvas, Size size) {
    final cuerpo = Rect.fromLTWH(0, 0, size.width, size.height - altoCola);
    final punta = cola.clamp(18.0, size.width - 18);

    final forma = Path()
      ..addRRect(RRect.fromRectAndRadius(cuerpo, const Radius.circular(16)))
      ..moveTo(punta - 8, cuerpo.bottom - 1)
      ..quadraticBezierTo(punta - 1, cuerpo.bottom + 2, punta - 3, size.height)
      ..quadraticBezierTo(
        punta + 5,
        cuerpo.bottom + 3,
        punta + 9,
        cuerpo.bottom - 1,
      )
      ..close();

    // Sombra teñida de grafito, no negra pura: sobre el panel se funde.
    canvas.drawShadow(forma, Tokens.cromo, 8, false);
    canvas.drawPath(forma, Paint()..color = const Color(0xFFFFFDF8));
  }

  @override
  bool shouldRepaint(_FormaGlobo anterior) =>
      anterior.cola != cola || anterior.altoCola != altoCola;
}
