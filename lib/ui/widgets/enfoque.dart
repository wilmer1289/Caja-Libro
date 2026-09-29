import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// Un anillo de luz suave alrededor del campo que tiene el foco.
///
/// El borde verde ya dice dónde estás escribiendo; el anillo lo dice sin que
/// haya que mirar de cerca. Es un detalle chico, y justamente de esos está
/// hecha una interfaz que se siente cuidada.
class Enfoque extends StatefulWidget {
  const Enfoque({
    super.key,
    required this.child,
    this.color = Tokens.marca,
    this.activo = true,
  });

  final Widget child;
  final Color color;

  /// Apagado cuando el campo muestra un error: el mensaje va debajo del
  /// campo, y el anillo lo encerraría junto con él.
  final bool activo;

  @override
  State<Enfoque> createState() => _EnfoqueState();
}

class _EnfoqueState extends State<Enfoque> {
  bool _foco = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Este Focus sólo escucha: no se lleva el foco ni entra en el orden de
      // tabulación. `hasFocus` es verdadero si el campo de adentro lo tiene.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (valor) => setState(() => _foco = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tokens.radio),
          boxShadow: _foco && widget.activo
              ? Tokens.brilloFoco(widget.color)
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}
