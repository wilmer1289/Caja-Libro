import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../login/personajes.dart';

/// Primera vez en una pantalla: en vez de una lista en blanco, una invitación
/// concreta a hacer algo (§5, estados vacíos).
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.accion,
    this.buscando = false,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  /// En vez del ícono, los personajes mirando de un lado a otro. Se usa
  /// cuando una búsqueda no encontró nada: dice lo mismo, pero acompaña.
  final bool buscando;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (buscando)
              const SizedBox(height: 150, width: 260, child: _Buscando())
            else
              Icon(icono, size: 44, color: Tokens.bordeFuerte),
            const SizedBox(height: 14),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Tokens.texto,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Tokens.texto2),
            ),
            if (accion != null) ...[const SizedBox(height: 18), accion!],
          ],
        ),
      ),
    );
  }
}

/// Los personajes mirando a los costados, como buscando algo.
class _Buscando extends StatefulWidget {
  const _Buscando();

  @override
  State<_Buscando> createState() => _BuscandoState();
}

class _BuscandoState extends State<_Buscando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Personajes(
          mirada: Offset(-1 + t * 2, 0.2),
          ojosCerrados: false,
          margenInferior: 8,
        );
      },
    );
  }
}
