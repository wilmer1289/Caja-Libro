import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../widgets/fondo_cromo.dart';

/// Cuánto mide el panel de la marca para un ancho de ventana dado.
///
/// Está afuera de la clase porque la transición al entrar necesita saber de
/// dónde parte el panel para llevarlo hasta el ancho de la barra lateral.
double anchoPanelLogin(double anchoVentana) =>
    (anchoVentana * 0.45).clamp(380.0, 660.0);

/// Login para la computadora del local.
///
/// A pantalla completa y partido en dos, no una tarjetita al medio: en un
/// monitor de 1920px una tarjeta de 640 se ve perdida, que es justo lo que
/// pasaba antes.
///
/// Este archivo es sólo disposición. El panel y el formulario llegan armados
/// desde `LoginPagina`, así que no hay nada de lógica duplicada con la versión
/// de móvil.
class LoginEscritorio extends StatelessWidget {
  const LoginEscritorio({
    super.key,
    required this.panel,
    required this.formulario,
  });

  final Widget panel;
  final Widget formulario;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;

    // El panel crece con la ventana pero con tope: en un monitor ultra ancho,
    // un lado de marca de 900px sería todo marca y nada de app.
    final anchoPanel = anchoPanelLogin(ancho);

    return Scaffold(
      backgroundColor: Tokens.fondo,
      body: Row(
        children: [
          SizedBox(width: anchoPanel, child: panel),
          Expanded(
            child: Stack(
              children: [
                // Del lado claro, los mismos adornos que del oscuro pero en
                // durazno: lunas asomando por las esquinas y una grilla de
                // puntos. Unen las dos mitades sin repetir el grafito.
                const Positioned(
                  top: -190,
                  right: -150,
                  child: CirculoAdorno(tamano: 400, color: Color(0xFFFBEADC)),
                ),
                const Positioned(
                  bottom: -150,
                  right: -110,
                  child: CirculoAdorno(tamano: 300, color: Color(0xFFFAEFE5)),
                ),
                Positioned(
                  bottom: 40,
                  right: 64,
                  child: GrillaPuntos(
                    columnas: 4,
                    filas: 4,
                    paso: 22,
                    radio: 2,
                    color: Tokens.marca.withValues(alpha: 0.16),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 40,
                    ),
                    child: ConstrainedBox(
                      // El formulario no se estira con la ventana: pasada
                      // cierta medida, una línea larga se vuelve incómoda.
                      constraints: const BoxConstraints(maxWidth: 452),
                      child: formulario,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
