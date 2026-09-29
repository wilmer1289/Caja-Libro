import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/resumen.dart';
import '../widgets/fondo_cromo.dart';
import '../widgets/logo.dart';
import '../widgets/marca.dart';
import 'secciones.dart';

/// Barra lateral de escritorio: marca arriba, secciones al medio y el estado
/// del mes al pie.
///
/// Se puede plegar hasta dejar sólo los íconos: en una laptop de 1366px los
/// 248 de la barra son espacio que le falta a la tabla del formato o al libro
/// mayor. Plegada sigue sirviendo para navegar —cada ícono dice su nombre al
/// pasar el mouse—, sólo deja de ocupar lugar.
class BarraLateral extends StatelessWidget {
  const BarraLateral({
    super.key,
    required this.seleccionada,
    required this.onSeleccionar,
    required this.resumen,
    this.plegada = false,
    this.enMenu = false,
  });

  final int seleccionada;
  final ValueChanged<int> onSeleccionar;
  final Resumen resumen;
  final bool plegada;

  /// Dentro del menú que sale por la derecha en el celular: ocupa todo el
  /// ancho del menú, sin sombra propia, y deja lugar a la barra de estado.
  final bool enMenu;

  /// Ancho del menú del celular.
  static const anchoMenu = 290.0;

  static const ancho = 248.0;
  static const anchoPlegada = 84.0;

  /// Cuánto tarda en plegarse o desplegarse. Lo usa también el botón que
  /// acompaña al borde, para moverse junto con ella.
  static const duracion = Duration(milliseconds: 300);
  static const curva = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final bordes = MediaQuery.paddingOf(context);
    return AnimatedContainer(
      duration: duracion,
      curve: curva,
      width: enMenu
          ? anchoMenu
          : plegada
          ? anchoPlegada
          : ancho,
      // La sombra despega la barra del contenido: sin ella, el grafito y el
      // blanco se tocan a filo y la pantalla se ve plana.
      decoration: BoxDecoration(
        boxShadow: enMenu
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 18,
                  offset: Offset(2, 0),
                ),
              ],
      ),
      child: ClipRect(
        child: FondoCromo(
          child: LayoutBuilder(
            builder: (context, medidas) {
              // Se decide por el ancho real y no por `plegada`: a mitad de la
              // animación la barra todavía no tiene lugar para los nombres, y
              // mostrarlos antes de tiempo los haría desbordar.
              final conTextos = medidas.maxWidth > 170;
              // La grilla de puntos va entre las opciones y el estado del
              // mes: si la ventana es baja no hay hueco, y se les encima.
              final conPuntos = conTextos && medidas.maxHeight > 760;
              // Ventana baja: el estado del mes pasa a su anillo compacto.
              final bajita = medidas.maxHeight < 700;

              return Stack(
                children: [
                  // Los adornos de la referencia: una luna cálida asomando
                  // abajo a la izquierda y una grilla de puntos.
                  const Positioned(
                    left: -150,
                    bottom: -150,
                    child: CirculoAdorno(tamano: 270, color: Color(0x1AF97316)),
                  ),
                  if (conPuntos)
                    const Positioned(
                      right: 26,
                      bottom: 214,
                      child: GrillaPuntos(columnas: 4, filas: 2, paso: 16),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      conTextos ? 16 : 14,
                      24 + bordes.top,
                      conTextos ? 16 : 14,
                      16 + bordes.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 44,
                          child: conTextos
                              ? const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: MarcaMiCaja(),
                                  ),
                                )
                              : const Center(child: LogoMiCaja(tamano: 40)),
                        ),
                        SizedBox(height: bajita ? 20 : 34),
                        // Las opciones se desplazan si no entran: con el
                        // texto de Windows agrandado, una ventana baja no
                        // tiene lugar para las seis más el estado del mes.
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < Seccion.todas.length; i++)
                                  _Opcion(
                                    seccion: Seccion.todas[i],
                                    activa: i == seleccionada,
                                    conTexto: conTextos,
                                    onTap: () => onSeleccionar(i),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: conTextos && !bajita
                              ? _EstadoDelMes(resumen: resumen)
                              : _EstadoDelMesMini(resumen: resumen),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// El botón redondo que asoma sobre el borde de la barra y la pliega o la
/// despliega. Va encima del borde y no adentro: así está en el mismo lugar
/// con la barra abierta o cerrada, y no le roba espacio a las opciones.
class BotonPlegar extends StatefulWidget {
  const BotonPlegar({super.key, required this.plegada, required this.onTap});

  final bool plegada;
  final VoidCallback onTap;

  static const tamano = 28.0;

  @override
  State<BotonPlegar> createState() => _BotonPlegarState();
}

class _BotonPlegarState extends State<BotonPlegar> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.plegada
          ? 'Mostrar el menú (Ctrl+B)'
          : 'Ocultar el menú (Ctrl+B)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() => _encima = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: BotonPlegar.tamano,
            height: BotonPlegar.tamano,
            decoration: BoxDecoration(
              color: _encima ? Tokens.marca : Tokens.superficie,
              shape: BoxShape.circle,
              border: Border.all(color: _encima ? Tokens.marca : Tokens.borde),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F2A1A0C),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: AnimatedRotation(
              turns: widget.plegada ? 0.5 : 0,
              duration: BarraLateral.duracion,
              curve: BarraLateral.curva,
              child: Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: _encima ? Colors.white : Tokens.texto,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Opcion extends StatefulWidget {
  const _Opcion({
    required this.seccion,
    required this.activa,
    required this.conTexto,
    required this.onTap,
  });

  final Seccion seccion;
  final bool activa;
  final bool conTexto;
  final VoidCallback onTap;

  @override
  State<_Opcion> createState() => _OpcionState();
}

class _OpcionState extends State<_Opcion> {
  /// El cursor encima también ilumina la opción: en escritorio es la señal de
  /// que eso se puede tocar, y hace que la barra responda al pasar el mouse.
  bool _encima = false;

  static const _textoApagado = Color(0xFFD2CCC5);

  @override
  Widget build(BuildContext context) {
    final activa = widget.activa;

    final fondo = activa
        ? Colors.white.withValues(alpha: 0.08)
        : _encima
        ? Colors.white.withValues(alpha: 0.045)
        : Colors.transparent;

    final icono = Icon(
      activa ? widget.seccion.iconoActivo : widget.seccion.icono,
      size: 21,
      color: activa ? Tokens.marca : _textoApagado,
    );

    final opcion = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 50,
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(Tokens.radio),
            border: Border.all(
              color: activa
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.transparent,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // La rayita naranja de la opción activa: el color no es la
              // única señal de dónde estás (§5).
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 3,
                    height: activa ? 22 : 0,
                    decoration: const BoxDecoration(
                      color: Tokens.marca,
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.conTexto)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      icono,
                      const SizedBox(width: 14),
                      // Expanded + "…": con el texto de Windows agrandado
                      // (125%, 150%) un nombre largo ya no entra en la barra,
                      // y sin esto se desbordaría.
                      Expanded(
                        child: Text(
                          widget.seccion.etiqueta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: activa
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: activa ? Colors.white : _textoApagado,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Center(child: icono),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      // Plegada, el nombre aparece al pasar el mouse: el ícono solo no
      // alcanza para saber a dónde lleva.
      child: widget.conTexto
          ? opcion
          : Tooltip(
              message: widget.seccion.etiqueta,
              preferBelow: false,
              verticalOffset: 0,
              margin: const EdgeInsets.only(left: 90),
              child: opcion,
            ),
    );
  }
}

/// Lo que dice el estado del mes: el título, el detalle y su color.
({String titulo, String detalle, Color color, double? proporcion}) _estado(
  Resumen resumen,
) {
  final proporcion = resumen.proporcionGastada;
  final sinMovimientos =
      resumen.cantidadEntroMes == 0 && resumen.cantidadSalioMes == 0;

  if (sinMovimientos) {
    return (
      titulo: 'Mes sin movimientos',
      detalle: 'Cuando registres algo, acá vas a ver cómo va.',
      color: Tokens.cromoTexto2,
      proporcion: proporcion,
    );
  }
  if (resumen.flujoPositivo) {
    return (
      titulo: 'Flujo positivo',
      detalle: proporcion == null
          ? 'Este mes sólo entró plata.'
          : 'Salió el ${(proporcion * 100).round()}% de lo que entró.',
      color: Tokens.entroVivo,
      proporcion: proporcion,
    );
  }
  return (
    titulo: 'Salió más de lo que entró',
    detalle: proporcion == null
        ? 'Este mes todavía no entró nada.'
        : 'Salió el ${(proporcion * 100).round()}% de lo que entró.',
    color: Tokens.marca,
    proporcion: proporcion,
  );
}

/// La tarjetita del pie. La barra mide qué parte de lo que entró este mes ya
/// salió: si llega al final, se gastó todo lo que entró.
class _EstadoDelMes extends StatelessWidget {
  const _EstadoDelMes({required this.resumen});

  final Resumen resumen;

  @override
  Widget build(BuildContext context) {
    final estado = _estado(resumen);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESTADO DEL MES',
            maxLines: 1,
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w600,
              color: Tokens.cromoTexto2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            Formato.capitalizar(Formato.mes(DateTime.now())),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Tokens.cromoTexto,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (estado.proporcion ?? 0).clamp(0, 1)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, valor, _) => LinearProgressIndicator(
                value: valor,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                color: estado.color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: estado.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  estado.titulo,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Tokens.cromoTexto,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            estado.detalle,
            style: const TextStyle(fontSize: 11.5, color: Tokens.cromoTexto2),
          ),
        ],
      ),
    );
  }
}

/// Con la barra plegada, el estado del mes cabe en un anillo: la misma
/// proporción, dibujada en redondo, y el detalle al pasar el mouse.
class _EstadoDelMesMini extends StatelessWidget {
  const _EstadoDelMesMini({required this.resumen});

  final Resumen resumen;

  @override
  Widget build(BuildContext context) {
    final estado = _estado(resumen);
    final mes = Formato.capitalizar(Formato.mesSolo(DateTime.now()));

    return Tooltip(
      message: '$mes · ${estado.titulo}\n${estado.detalle}',
      preferBelow: false,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: SizedBox.square(
          dimension: 30,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (estado.proporcion ?? 0).clamp(0, 1)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, valor, _) => CircularProgressIndicator(
              value: valor,
              strokeWidth: 3.5,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              color: estado.color,
            ),
          ),
        ),
      ),
    );
  }
}
