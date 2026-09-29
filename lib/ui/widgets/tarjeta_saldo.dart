import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';

/// El número grande. El saldo pesa más que todo lo demás por tamaño, color y
/// espacio (§5, jerarquía visual).
///
/// Cuando el saldo sube, la tarjeta da un pulso: es la recompensa de haber
/// registrado una venta, y se ve sin tener que estar mirando el número.
class TarjetaSaldo extends StatefulWidget {
  const TarjetaSaldo({
    super.key,
    required this.titulo,
    required this.centavos,
    this.color,
    this.icono,
    this.insignia,
    this.destacada = false,
    this.oscura = false,
    this.distintivo,
  });

  final String titulo;
  final int centavos;
  final Color? color;

  /// Ícono chico antes del título.
  final IconData? icono;

  /// Ícono en un círculo de color arriba a la derecha, como en "Entró este
  /// mes": se reconoce la tarjeta sin leerla.
  final IconData? insignia;

  final bool destacada;

  /// Variante grafito, para el saldo principal. Es la tarjeta que ancla la
  /// pantalla: la primera que se lee.
  final bool oscura;

  /// Etiqueta de contexto bajo el monto ("3 ingresos", "Sin egresos").
  final Widget? distintivo;

  @override
  State<TarjetaSaldo> createState() => _TarjetaSaldoState();
}

class _TarjetaSaldoState extends State<TarjetaSaldo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(TarjetaSaldo anterior) {
    super.didUpdateWidget(anterior);
    // Sólo cuando sube: que el saldo baje no es para festejar.
    if (widget.centavos > anterior.centavos) _pulso.forward(from: 0);
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oscura = widget.oscura;
    final tono = oscura ? Colors.white : (widget.color ?? Tokens.texto);
    final colorTitulo = oscura ? Tokens.cromoTexto2 : Tokens.texto2;
    final insignia = widget.insignia;

    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (widget.icono != null) ...[
              Icon(
                widget.icono,
                size: 16,
                color: oscura ? colorTitulo : (widget.color ?? colorTitulo),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                widget.titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: oscura ? Tokens.cromoTexto : colorTitulo,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: widget.destacada ? 14 : 12),
        // Los números animan al cambiar (§5, microinteracciones): tras
        // registrar un movimiento el saldo sube contando, no salta de golpe.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.centavos / 100),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, valor, _) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formato.soles(valor),
              style: TextStyle(
                fontSize: widget.destacada ? 36 : 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: tono,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        if (widget.distintivo != null) ...[
          SizedBox(height: widget.destacada ? 16 : 12),
          widget.distintivo!,
        ],
      ],
    );

    final contenido = Padding(
      padding: EdgeInsets.all(widget.destacada ? 24 : 20),
      child: insignia == null
          ? textos
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: textos),
                const SizedBox(width: 10),
                _Insignia(icono: insignia, color: widget.color ?? Tokens.marca),
              ],
            ),
    );

    return AnimatedBuilder(
      animation: _pulso,
      builder: (context, hijo) {
        // El pulso crece rápido y se apaga: un latido, no un parpadeo.
        final t = _pulso.value;
        final fuerza = t == 0 ? 0.0 : (t < 0.2 ? t / 0.2 : 1 - (t - 0.2) / 0.8);
        return Transform.scale(
          scale: 1 + 0.012 * fuerza,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tokens.radioGrande),
              boxShadow: fuerza <= 0
                  ? const []
                  : [
                      BoxShadow(
                        color: Tokens.marca.withValues(alpha: 0.30 * fuerza),
                        blurRadius: 24,
                        spreadRadius: 2 * fuerza,
                      ),
                    ],
            ),
            child: hijo,
          ),
        );
      },
      child: oscura
          ? _Oscura(child: contenido)
          : TarjetaClara(child: contenido),
    );
  }
}

/// La tarjeta blanca de la app: borde fino, esquinas amplias y una sombra
/// apenas visible. Es la misma en todas las pantallas.
class TarjetaClara extends StatelessWidget {
  const TarjetaClara({
    super.key,
    required this.child,
    this.resaltada = false,
    this.clip = false,
  });

  final Widget child;

  /// Con borde naranja: la tarjeta elegida, cuando funciona como filtro.
  final bool resaltada;

  /// Recorta lo de adentro a las esquinas redondeadas (para un InkWell o una
  /// lista con fondos propios).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: Tokens.superficie,
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        border: Border.all(
          color: resaltada ? Tokens.marca : Tokens.borde,
          width: resaltada ? 1.5 : 1,
        ),
        boxShadow: Tokens.sombraTarjeta,
      ),
      child: child,
    );
  }
}

class _Insignia extends StatelessWidget {
  const _Insignia({required this.icono, required this.color});

  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icono, size: 22, color: color),
    );
  }
}

/// La versión grafito, con los detalles que la hacen ver de tarjeta y no de
/// rectángulo: dos lunas naranjas en la esquina, como en la referencia, y un
/// filo de luz arriba.
class _Oscura extends StatelessWidget {
  const _Oscura({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: Tokens.degradadoCromo,
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        boxShadow: [
          BoxShadow(
            color: Tokens.cromo.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -64,
            child: _Luna(
              tamano: 170,
              colores: [
                Tokens.marca.withValues(alpha: 0.30),
                Tokens.marca.withValues(alpha: 0.12),
              ],
            ),
          ),
          Positioned(
            right: -80,
            bottom: -110,
            child: _Luna(
              tamano: 210,
              colores: [
                Tokens.marca.withValues(alpha: 0.55),
                Tokens.marca.withValues(alpha: 0.18),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Luna extends StatelessWidget {
  const _Luna({required this.tamano, required this.colores});

  final double tamano;
  final List<Color> colores;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colores,
        ),
      ),
    );
  }
}
