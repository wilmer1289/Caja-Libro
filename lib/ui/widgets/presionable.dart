import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Hace que lo que envuelve se hunda un poco al presionarlo y vuelva con un
/// rebote de resorte al soltarlo (§5, "botones que responden al tacto").
///
/// El rebote es física de resorte y no una curva de duración fija: por eso se
/// siente vivo en vez de mecánico. Es lo que más separa a una interfaz que
/// "funciona" de una que se siente cuidada.
///
/// Usa un `Listener` y no un detector de gestos, así no le roba el toque al
/// botón de adentro: el botón sigue haciendo lo suyo, esto sólo lo anima.
class Presionable extends StatefulWidget {
  const Presionable({super.key, required this.child, this.escala = 0.965});

  final Widget child;

  /// Cuánto se achica presionado. Poco: más de un 5% ya se ve como un error.
  final double escala;

  @override
  State<Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<Presionable>
    with SingleTickerProviderStateMixin {
  /// Sin límites, para que el resorte pueda pasarse un poquito de largo al
  /// volver: ese pasarse es el rebote.
  late final AnimationController _ctrl = AnimationController.unbounded(
    vsync: this,
  );

  static const _resorte = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 17,
  );

  void _hundir() => _ctrl.animateTo(
    1,
    duration: const Duration(milliseconds: 90),
    curve: Curves.easeOut,
  );

  void _soltar() => _ctrl.animateWith(
    SpringSimulation(_resorte, _ctrl.value, 0, _ctrl.velocity),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return Listener(
      onPointerDown: (_) => _hundir(),
      onPointerUp: (_) => _soltar(),
      onPointerCancel: (_) => _soltar(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, hijo) => Transform.scale(
          scale: 1 - (1 - widget.escala) * _ctrl.value,
          child: hijo,
        ),
        child: widget.child,
      ),
    );
  }
}
