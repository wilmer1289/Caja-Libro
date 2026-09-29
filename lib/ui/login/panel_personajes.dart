import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../widgets/aparece.dart';
import '../widgets/fondo_cromo.dart';
import '../widgets/marca.dart';
import 'globo.dart';
import 'personajes.dart';

/// El lado de la marca en el login.
///
/// Antes tenía un titular y un párrafo. Se sacaron: eran la portada genérica
/// de cualquier página de software, competían con los personajes por la
/// atención, y le explicaban la app a alguien que ya la usa todos los días.
/// Ahora los protagonistas son los personajes, y hablan: el globo cambia con
/// lo que el usuario está haciendo.
class PanelPersonajes extends StatelessWidget {
  const PanelPersonajes({
    super.key,
    required this.mirada,
    required this.ojosCerrados,
    required this.frase,
    this.animo = Animo.normal,
    this.reaccion = 0,
    this.compacto = false,
    this.conFondo = true,
  });

  final Offset mirada;
  final bool ojosCerrados;
  final Animo animo;
  final int reaccion;

  /// Lo que dicen en el globo.
  final String frase;

  /// En móvil el panel es una franja arriba.
  final bool compacto;

  /// Sin fondo, para poder desvanecer sólo el contenido: durante la
  /// transición al entrar, el verde tiene que quedarse opaco.
  final bool conFondo;

  @override
  Widget build(BuildContext context) {
    final personajes = Personajes(
      mirada: mirada,
      ojosCerrados: ojosCerrados,
      animo: animo,
      reaccion: reaccion,
      conArco: true,
      margenInferior: compacto ? 6 : 10,
    );

    final contenido = compacto
        ? Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: _Compacto(personajes: personajes, frase: frase),
          )
        : Stack(
            children: [
              const Positioned.fill(child: _Adornos()),
              Padding(
                padding: const EdgeInsets.fromLTRB(44, 42, 44, 40),
                child: _Amplio(personajes: personajes, frase: frase),
              ),
            ],
          );

    if (!conFondo) return contenido;
    return FondoCromo(child: contenido);
  }
}

/// Escritorio: marca chica arriba y personajes al centro con el globo encima.
///
/// Al pie había un "Funciona sin internet". Se sacó: es verdad, pero es
/// información para quien evalúa la app, no para quien entra a trabajar.
class _Amplio extends StatelessWidget {
  const _Amplio({required this.personajes, required this.frase});

  final Personajes personajes;
  final String frase;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Aparece(child: MarcaMiCaja(grande: true)),
        Expanded(
          child: Aparece(
            retraso: const Duration(milliseconds: 120),
            desplazamiento: 24,
            duracion: const Duration(milliseconds: 600),
            child: LayoutBuilder(
              builder: (context, medidas) {
                // Los personajes ocupan lo que su ancho les permite, y ese
                // bloque se centra en el espacio libre. Apoyados abajo, en un
                // panel alto quedaba un vacío enorme encima de ellos.
                final alto = math.min(
                  medidas.maxHeight,
                  (medidas.maxWidth - 36) / 194 * 106 +
                      24 +
                      personajes.margenInferior,
                );
                final tamano = Size(medidas.maxWidth, alto);
                // El globo sale de la cabeza del personaje morado. Se calcula
                // con el mismo encuadre que usa el pintor, así la punta cae
                // justo encima de él en cualquier tamaño de ventana.
                final cabeza = Personajes.ubicar(
                  tamano,
                  const Offset(60, 22),
                  margenInferior: personajes.margenInferior,
                  conArco: true,
                );
                const cola = 30.0;

                return Center(
                  child: SizedBox.fromSize(
                    size: tamano,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: personajes),
                        Positioned(
                          left: cabeza.dx - cola,
                          bottom: tamano.height - cabeza.dy + 10,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: tamano.width - (cabeza.dx - cola),
                            ),
                            child: GloboDialogo(texto: frase, cola: cola),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // El mismo aire abajo que arriba: los personajes quedan al centro
        // del panel, no apoyados en el borde.
        const SizedBox(height: 56),
      ],
    );
  }
}

/// Móvil: marca y globo en la misma fila, personajes debajo. El globo va
/// arriba a la derecha con la punta hacia abajo, hacia ellos: en la franja
/// no hay lugar para ponerlo sobre una cabeza sin tapar la marca.
class _Compacto extends StatelessWidget {
  const _Compacto({required this.personajes, required this.frase});

  final Personajes personajes;
  final String frase;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Aparece(child: MarcaMiCaja(conBajada: false)),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.topRight,
                child: Aparece(
                  retraso: const Duration(milliseconds: 150),
                  child: GloboDialogo(texto: frase, cola: 34),
                ),
              ),
            ),
          ],
        ),
        Expanded(child: personajes),
      ],
    );
  }
}

/// Los adornos del panel en escritorio, como en la referencia: una grilla de
/// puntos arriba a la derecha, una línea naranja que dibuja un gran arco, y
/// dos lunas cálidas asomando por los bordes de abajo.
///
/// Van con el contenido y no con el fondo: al entrar, se desvanecen junto con
/// los personajes y el panel queda liso para convertirse en la barra lateral.
class _Adornos extends StatelessWidget {
  const _Adornos();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, medidas) {
          final alto = medidas.maxHeight;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _ArcoNaranja()),
              ),
              Positioned(
                left: -118,
                top: alto * 0.40,
                child: CirculoAdorno(
                  tamano: 220,
                  color: Tokens.marca.withValues(alpha: 0.20),
                ),
              ),
              Positioned(
                right: -150,
                bottom: -170,
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Tokens.marca.withValues(alpha: 0.34),
                        Tokens.marca.withValues(alpha: 0.10),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 64,
                right: 48,
                child: GrillaPuntos(
                  columnas: 4,
                  filas: 3,
                  paso: 24,
                  color: Color(0x33FFFFFF),
                  radio: 2,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Un trazo fino naranja: el borde de una circunferencia enorme de la que se
/// ve sólo un cuarto, que baja desde el borde izquierdo y se apaga.
class _ArcoNaranja extends CustomPainter {
  const _ArcoNaranja();

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width * 0.62, size.height * 0.78);
    final radio = size.width * 0.78;
    final rect = Rect.fromCircle(center: centro, radius: radio);

    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: Alignment(
          centro.dx / size.width * 2 - 1,
          centro.dy / size.height * 2 - 1,
        ),
        startAngle: math.pi,
        endAngle: math.pi * 1.5,
        colors: [
          Tokens.marca.withValues(alpha: 0.85),
          Tokens.marca.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawArc(rect, math.pi * 1.05, math.pi * 0.33, false, pincel);
  }

  @override
  bool shouldRepaint(_ArcoNaranja anterior) => false;
}
