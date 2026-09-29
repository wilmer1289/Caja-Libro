import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// Login para el celular: la marca arriba y el formulario abajo.
///
/// El panel ocupa una fracción del alto y no una medida fija, porque entre un
/// celular chico y uno grande hay bastante diferencia. Cuando sube el teclado
/// el panel se encoge para que el botón de entrar no quede tapado.
///
/// Este archivo es sólo disposición: el panel y el formulario llegan armados
/// desde `LoginPagina`.
class LoginMovil extends StatelessWidget {
  const LoginMovil({super.key, required this.panel, required this.formulario});

  final Widget panel;
  final Widget formulario;

  @override
  Widget build(BuildContext context) {
    final medidas = MediaQuery.of(context);
    final tecladoArriba = medidas.viewInsets.bottom > 0;

    final altoPanel = tecladoArriba
        ? 0.0
        : (medidas.size.height * 0.30).clamp(180.0, 280.0);

    return Scaffold(
      backgroundColor: Tokens.fondo,
      // El panel llega hasta el borde superior, por debajo de la barra de
      // estado: se ve mejor que dejar una franja blanca arriba.
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: altoPanel,
            child: altoPanel == 0
                ? null
                : ClipRect(child: SafeArea(bottom: false, child: panel)),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: formulario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
