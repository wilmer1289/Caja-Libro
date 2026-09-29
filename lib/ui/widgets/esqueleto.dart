import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// Carga con "esqueleto" gris con la forma del contenido, no un spinner suelto
/// (§5, estados de carga): la pantalla no da un salto cuando llegan los datos.
class Esqueleto extends StatefulWidget {
  const Esqueleto({
    super.key,
    required this.ancho,
    required this.alto,
    this.radio = 8,
  });

  final double ancho;
  final double alto;
  final double radio;

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_ctrl),
      child: Container(
        width: widget.ancho,
        height: widget.alto,
        decoration: BoxDecoration(
          color: Tokens.borde,
          borderRadius: BorderRadius.circular(widget.radio),
        ),
      ),
    );
  }
}

/// Esqueleto con la forma de una lista de movimientos.
class EsqueletoLista extends StatelessWidget {
  const EsqueletoLista({super.key, this.filas = 6});

  final int filas;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: filas,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Esqueleto(ancho: 40, alto: 40, radio: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Esqueleto(ancho: 160, alto: 12),
                  SizedBox(height: 8),
                  Esqueleto(ancho: 110, alto: 10),
                ],
              ),
            ),
            SizedBox(width: 12),
            Esqueleto(ancho: 70, alto: 14),
          ],
        ),
      ),
    );
  }
}
