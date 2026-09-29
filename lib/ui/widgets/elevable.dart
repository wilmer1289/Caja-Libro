import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// Levanta una tarjeta un par de píxeles cuando el cursor pasa por encima.
///
/// Sólo para lo que **se puede tocar**. Levantar una tarjeta que no hace nada
/// promete algo que no va a pasar, y eso molesta más que no tener el efecto.
class Elevable extends StatefulWidget {
  const Elevable({super.key, required this.child});

  final Widget child;

  @override
  State<Elevable> createState() => _ElevableState();
}

class _ElevableState extends State<Elevable> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _encima ? -3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tokens.radioGrande),
          boxShadow: _encima ? Tokens.sombraFlotante : const [],
        ),
        child: widget.child,
      ),
    );
  }
}
