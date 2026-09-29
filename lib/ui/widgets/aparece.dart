import 'package:flutter/material.dart';

/// Hace que un elemento entre subiendo y apareciendo, en vez de estar de golpe.
///
/// Con `retraso` distinto en cada hijo, la pantalla se arma sola de arriba
/// hacia abajo. Es el truco más barato que hay para que una interfaz deje de
/// sentirse fría: no cambia nada del contenido, sólo cómo llega.
class Aparece extends StatefulWidget {
  const Aparece({
    super.key,
    required this.child,
    this.retraso = Duration.zero,
    this.duracion = const Duration(milliseconds: 420),
    this.desplazamiento = 14,
  });

  final Widget child;
  final Duration retraso;
  final Duration duracion;

  /// Cuántos píxeles sube al entrar. Poco a propósito: un salto grande se
  /// siente aparatoso cuando hay varios elementos seguidos.
  final double desplazamiento;

  @override
  State<Aparece> createState() => _ApareceState();
}

class _ApareceState extends State<Aparece> with SingleTickerProviderStateMixin {
  /// El controlador dura retraso + animación, y el retraso se resuelve con un
  /// `Interval` dentro de la curva.
  ///
  /// Se hace así y no con `Future.delayed` porque un temporizador suelto queda
  /// fuera del control del árbol: hay que acordarse de comprobar `mounted`, y
  /// en las pruebas de widgets no avanza como uno espera. Con la curva, el
  /// retraso es parte de la animación y no hay nada más que limpiar.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.retraso + widget.duracion,
  )..forward();

  late final Animation<double> _curva = CurvedAnimation(
    parent: _ctrl,
    curve: Interval(
      widget.retraso.inMilliseconds /
          (widget.retraso + widget.duracion).inMilliseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Con "reducir movimiento" activado no hay desplazamiento ni espera: el
    // contenido simplemente está.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _curva,
      builder: (context, hijo) => Opacity(
        opacity: _curva.value,
        child: Transform.translate(
          offset: Offset(0, widget.desplazamiento * (1 - _curva.value)),
          child: hijo,
        ),
      ),
      child: widget.child,
    );
  }
}
