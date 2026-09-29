import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// El fondo grafito de la marca: el degradado con una luz cálida abajo y una
/// trama de puntos casi invisible. Ninguna se nota sola; juntas le sacan lo
/// plano al gris.
///
/// Lo usan el panel del login y la barra lateral. Que sea exactamente el mismo
/// es lo que permite que, al entrar, el panel se transforme en la barra sin
/// que se note el cambio: el fondo nunca salta.
class FondoCromo extends StatelessWidget {
  const FondoCromo({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Tokens.degradadoCromo),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Un resplandor naranja muy bajo, abajo a la izquierda: el mismo
          // tono de la marca, como si la luz viniera de los personajes.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-1, 1),
                radius: 1.1,
                colors: [
                  Tokens.marca.withValues(alpha: 0.10),
                  Tokens.marca.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          const CustomPaint(painter: _Trama()),
          ?child,
        ],
      ),
    );
  }
}

/// Puntos muy tenues que se apagan hacia abajo: textura, no dibujo.
class _Trama extends CustomPainter {
  const _Trama();

  static const _paso = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint();
    for (var y = _paso / 2; y < size.height; y += _paso) {
      final alfa = 0.035 * (1 - y / size.height);
      if (alfa <= 0.004) break;
      pincel.color = Colors.white.withValues(alpha: alfa);
      for (var x = _paso / 2; x < size.width; x += _paso) {
        canvas.drawCircle(Offset(x, y), 1, pincel);
      }
    }
  }

  @override
  bool shouldRepaint(_Trama anterior) => false;
}

/// Una grilla chica de puntos, como la de las esquinas de la referencia.
///
/// A diferencia de la trama del fondo, esta sí se ve: es un adorno puntual,
/// no una textura.
class GrillaPuntos extends StatelessWidget {
  const GrillaPuntos({
    super.key,
    this.columnas = 5,
    this.filas = 3,
    this.paso = 18,
    this.color = const Color(0x2EFFFFFF),
    this.radio = 1.6,
  });

  final int columnas;
  final int filas;
  final double paso;
  final Color color;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (columnas - 1) * paso + radio * 2,
      height: (filas - 1) * paso + radio * 2,
      child: CustomPaint(
        painter: _PintorGrilla(columnas, filas, paso, color, radio),
      ),
    );
  }
}

class _PintorGrilla extends CustomPainter {
  const _PintorGrilla(
    this.columnas,
    this.filas,
    this.paso,
    this.color,
    this.radio,
  );

  final int columnas;
  final int filas;
  final double paso;
  final Color color;
  final double radio;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()..color = color;
    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        canvas.drawCircle(
          Offset(radio + c * paso, radio + f * paso),
          radio,
          pincel,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PintorGrilla a) =>
      a.columnas != columnas ||
      a.filas != filas ||
      a.paso != paso ||
      a.color != color ||
      a.radio != radio;
}

/// Un círculo lleno, de adorno. Los de las esquinas del login y de la barra.
class CirculoAdorno extends StatelessWidget {
  const CirculoAdorno({super.key, required this.tamano, required this.color});

  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
