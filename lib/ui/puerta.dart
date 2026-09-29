import 'package:flutter/material.dart';

import '../datos/auth/autenticador.dart';
import '../datos/auth/autenticador_local.dart';
import 'inicio.dart';
import 'login/login_escritorio.dart';
import 'login/login_pagina.dart';
import 'login/panel_personajes.dart';
import 'widgets/fondo_cromo.dart';
import 'login/personajes.dart';
import 'shell/barra_lateral.dart';

/// Decide qué se ve al abrir la app: el login o el libro de caja.
///
/// La sesión vive sólo en memoria mientras la app está abierta. Cuando se
/// conecte Firebase Auth, acá se preguntará si ya hay sesión guardada y se
/// cambiará el autenticador; lo de abajo no cambia.
class Puerta extends StatefulWidget {
  const Puerta({super.key, this.autenticador = const AutenticadorLocal()});

  final Autenticador autenticador;

  @override
  State<Puerta> createState() => _PuertaState();
}

class _PuertaState extends State<Puerta> with SingleTickerProviderStateMixin {
  /// Quién está adentro. Null mientras nadie entró.
  String? _usuario;

  /// El paso del login a la app. En escritorio, el panel verde se angosta
  /// hasta quedar del ancho de la barra lateral: es el mismo verde, así que
  /// parece que se transformó y no que una pantalla reemplazó a la otra.
  late final AnimationController _paso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  bool _conTransicion = false;

  @override
  void dispose() {
    _paso.dispose();
    super.dispose();
  }

  void _entrar(String nombre) {
    final esEscritorio =
        MediaQuery.sizeOf(context).width >= anchoEscritorioLogin;

    setState(() {
      _usuario = nombre;
      _conTransicion = esEscritorio;
    });

    if (esEscritorio) {
      _paso.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _conTransicion = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = _usuario;

    if (usuario == null) {
      return LoginPagina(autenticador: widget.autenticador, onEntrar: _entrar);
    }

    final app = Inicio(
      usuario: usuario,
      onSalir: () => setState(() => _usuario = null),
    );

    if (!_conTransicion) return app;

    return Stack(
      children: [
        // La app ya se está armando debajo: cuando el panel termina de
        // encogerse, sus animaciones de entrada ya corrieron.
        app,
        AnimatedBuilder(
          animation: _paso,
          builder: (context, _) => _PanelQueSeEncoge(avance: _paso.value),
        ),
      ],
    );
  }
}

/// El panel del login mientras se convierte en la barra lateral.
class _PanelQueSeEncoge extends StatelessWidget {
  const _PanelQueSeEncoge({required this.avance});

  final double avance;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeInOutCubic.transform(avance);
    final ancho = MediaQuery.sizeOf(context).width;

    // Los personajes y la marca se van antes que el panel: primero se vacía,
    // después se encoge del todo.
    final opacidadContenido = (1 - avance * 2.2).clamp(0.0, 1.0);

    // Y al final el panel entero se desvanece sobre la barra lateral, que ya
    // está debajo con el mismo fondo: lo único que aparece son sus opciones.
    final opacidadPanel = avance < 0.82
        ? 1.0
        : (1 - (avance - 0.82) / 0.18).clamp(0.0, 1.0);

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: _interpolar(anchoPanelLogin(ancho), BarraLateral.ancho, t),
      child: IgnorePointer(
        child: Opacity(
          opacity: opacidadPanel,
          child: ClipRect(
            // El fondo va aparte y siempre opaco: si se desvaneciera junto
            // con el contenido, se vería la app a través del verde.
            child: FondoCromo(
              child: Opacity(
                opacity: opacidadContenido,
                child: const PanelPersonajes(
                  mirada: Offset.zero,
                  ojosCerrados: false,
                  animo: Animo.feliz,
                  frase: '¡Vamos!',
                  conFondo: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _interpolar(double a, double b, double t) => a + (b - a) * t;
