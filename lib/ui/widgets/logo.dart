import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// El logo: el personaje naranja del login sobre una baldosa crema.
///
/// Reemplaza al "MC" de relleno. Usar un personaje como logo ata la marca con
/// lo primero que se ve al abrir la app: es la misma cara en los dos lados.
class LogoMiCaja extends StatelessWidget {
  const LogoMiCaja({super.key, this.tamano = 38});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: tamano,
      child: const CustomPaint(painter: _PintorLogo()),
    );
  }
}

class _PintorLogo extends CustomPainter {
  const _PintorLogo();

  @override
  void paint(Canvas canvas, Size size) {
    // Todo se dibuja en una baldosa de 40×40 y se escala al tamaño pedido.
    canvas.scale(size.width / 40);

    final baldosa = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 40, 40),
      const Radius.circular(11),
    );
    canvas.drawRRect(
      baldosa,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBF7EF), Tokens.escenario],
        ).createShader(const Rect.fromLTWH(0, 0, 40, 40)),
    );

    // La media luna naranja, apoyada un poco por debajo del centro.
    final cuerpo = Path()
      ..moveTo(7, 30)
      ..arcToPoint(const Offset(33, 30), radius: const Radius.circular(13))
      ..close();
    canvas.drawPath(cuerpo, Paint()..color = Tokens.marca);

    const ojos = Color(0xFF3A1602);
    final pincelOjos = Paint()..color = ojos;
    canvas.drawCircle(const Offset(16.2, 24), 1.7, pincelOjos);
    canvas.drawCircle(const Offset(23.8, 24), 1.7, pincelOjos);

    final sonrisa = Path()
      ..moveTo(17.2, 27)
      ..quadraticBezierTo(20, 29.4, 22.8, 27);
    canvas.drawPath(
      sonrisa,
      Paint()
        ..color = ojos
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PintorLogo anterior) => false;
}
