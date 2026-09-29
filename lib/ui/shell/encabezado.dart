import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../widgets/aparece.dart';

/// El encabezado de cada página: título grande, una bajada que dice qué hay
/// acá, y a la derecha las acciones y el usuario.
///
/// La bajada importa más de lo que parece. Sin ella, "Caja" es una palabra
/// suelta; con "El dinero físico que tienes en el negocio" ya se entiende sin
/// que nadie lo explique (§1).
class Encabezado extends StatelessWidget {
  const Encabezado({
    super.key,
    required this.titulo,
    required this.bajada,
    required this.usuario,
    required this.onSalir,
    required this.onPerfil,
    this.acciones = const [],
    this.alFinal,
    this.compacto = false,
    this.estrecho = false,
    this.elevado = false,
  });

  final String titulo;
  final String bajada;
  final String usuario;
  final VoidCallback onSalir;

  /// Abre los datos del negocio.
  final VoidCallback onPerfil;

  /// Botones que van antes del usuario (registrar, sincronizar).
  final List<Widget> acciones;

  /// Lo que va después del usuario, pegado al borde: el botón del menú en
  /// el celular.
  final Widget? alFinal;

  /// En celular: letra más chica y el usuario sólo como inicial.
  final bool compacto;

  /// Escritorio, pero con poco lugar (una ventana chica, o la pantalla con
  /// el texto de Windows al 150%): el título se achica un poco y el usuario
  /// queda sólo con su inicial, para que el título no se corte.
  final bool estrecho;

  /// La página de abajo ya se desplazó: aparece una línea fina y una sombra
  /// apenas visible, para que el contenido no se corte a filo contra el
  /// encabezado. Arriba de todo no hace falta, y sin ella se ve más limpio.
  final bool elevado;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      // En escritorio el encabezado es parte de la página, sobre el mismo
      // blanco cálido: una franja blanca encima partía la pantalla en dos.
      decoration: BoxDecoration(
        color: compacto ? Tokens.superficie : Tokens.fondo,
        border: Border(
          bottom: BorderSide(
            color: elevado && !compacto ? Tokens.borde : Colors.transparent,
          ),
        ),
        boxShadow: elevado && !compacto
            ? const [
                BoxShadow(
                  color: Color(0x0F2A1A0C),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ]
            : const [],
      ),
      padding: EdgeInsets.fromLTRB(
        compacto ? 20 : 32,
        compacto ? 14 : 26,
        compacto ? 12 : 28,
        compacto ? 14 : 16,
      ),
      child: Row(
        children: [
          Expanded(
            // La clave hace que el título entre animado cada vez que cambia
            // de sección, en vez de sólo cambiar de texto.
            child: Aparece(
              key: ValueKey(titulo),
              desplazamiento: 6,
              duracion: const Duration(milliseconds: 280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compacto ? 20 : (estrecho ? 23 : 28),
                      fontWeight: FontWeight.w800,
                      letterSpacing: compacto ? -0.2 : -0.6,
                      color: Tokens.texto,
                    ),
                  ),
                  SizedBox(height: compacto ? 2 : 4),
                  Text(
                    bajada,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compacto ? 12.5 : (estrecho ? 13.5 : 15),
                      color: Tokens.texto2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...acciones,
          SizedBox(width: compacto ? 4 : 12),
          _Usuario(
            nombre: usuario,
            onSalir: onSalir,
            onPerfil: onPerfil,
            compacto: compacto || estrecho,
          ),
          ?alFinal,
        ],
      ),
    );
  }
}

/// El usuario con su inicial. Al tocarlo se abre un menú con "Cerrar sesión":
/// sin esto, una vez adentro no había forma de salir.
class _Usuario extends StatelessWidget {
  const _Usuario({
    required this.nombre,
    required this.onSalir,
    required this.onPerfil,
    required this.compacto,
  });

  final String nombre;
  final VoidCallback onSalir;
  final VoidCallback onPerfil;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final inicial = nombre.isEmpty ? '?' : nombre[0].toUpperCase();

    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.storefront_outlined, size: 18),
          onPressed: onPerfil,
          child: const Text('Datos del negocio'),
        ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout_rounded, size: 18),
          onPressed: onSalir,
          child: const Text('Cerrar sesión'),
        ),
      ],
      builder: (context, menu, _) => InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFECE8E3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Tokens.borde),
                ),
                child: Text(
                  inicial,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Tokens.texto,
                  ),
                ),
              ),
              if (!compacto) ...[
                const SizedBox(width: 10),
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Tokens.texto,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: Tokens.texto,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
