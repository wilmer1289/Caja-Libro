import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/formato.dart';
import '../core/saludo.dart';
import '../core/tema.dart';
import '../dominio/boleta.dart';
import '../dominio/enums.dart';
import '../dominio/negocio.dart';
import '../estado/estado_caja.dart';
import 'arqueo/arqueo_pagina.dart';
import 'dashboard/dashboard_pagina.dart';
import 'formatos/formatos_pagina.dart';
import 'historial/acciones_movimiento.dart';
import 'historial/historial_pagina.dart';
import 'mayor/mayor_pagina.dart';
import 'registro/registro_hoja.dart';
import 'reportes/reportes_pagina.dart';
import 'shell/barra_lateral.dart';
import 'shell/encabezado.dart';
import 'negocio/negocio_pagina.dart';
import 'shell/secciones.dart';

/// Ancho a partir del cual se usa la disposición de escritorio.
const _anchoEscritorio = 900.0;

/// El armazón de la app: las secciones del §3 y los dos botones de registro.
///
/// En la computadora: barra lateral oscura y los botones "Entró" / "Salió" en
/// el encabezado. En el celular: el menú de secciones sale por la derecha
/// desde el botón del encabezado, y los botones flotan abajo. Las dos
/// cumplen lo mismo del §4.1 —dos botones directos, siempre a la vista—, cada
/// una donde queda natural en su plataforma.
class Inicio extends StatefulWidget {
  const Inicio({super.key, required this.usuario, required this.onSalir});

  final String usuario;
  final VoidCallback onSalir;

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  int _seccion = Seccion.iResumen;

  /// La barra lateral plegada a sólo íconos. Se recuerda mientras la app
  /// está abierta: quien la plegó para ganar espacio no quiere que vuelva a
  /// abrirse cada vez que cambia de sección.
  bool _barraPlegada = false;

  void _alternarBarra() => setState(() => _barraPlegada = !_barraPlegada);

  /// El armazón del celular, para abrir y cerrar el menú de la derecha.
  final _armazon = GlobalKey<ScaffoldState>();

  /// La página ya bajó un poco: el encabezado muestra su línea de abajo.
  bool _desplazado = false;

  void _irA(int seccion) => setState(() {
    _seccion = seccion;
    _desplazado = false;
  });

  /// Escucha sólo el desplazamiento vertical de la página misma (profundidad
  /// cero): las tablas que se deslizan de costado no cuentan.
  bool _alDesplazar(ScrollNotification aviso) {
    if (aviso.depth != 0 || aviso.metrics.axis != Axis.vertical) return false;
    final bajo = aviso.metrics.pixels > 4;
    if (bajo != _desplazado) setState(() => _desplazado = bajo);
    return false;
  }

  @override
  void initState() {
    super.initState();
    // La primera carga se dispara después del primer frame para que la
    // pantalla aparezca con su esqueleto en vez de quedarse en blanco.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EstadoCaja>().cargar();
    });
  }

  Widget get _pagina => switch (_seccion) {
    Seccion.iResumen => DashboardPagina(
      onIrA: (i) => setState(() => _seccion = i),
    ),
    Seccion.iArqueo => ArqueoPagina(usuario: widget.usuario),
    Seccion.iCajaYBancos => const MayorPagina(),
    Seccion.iHistorial => const HistorialPagina(),
    Seccion.iReportes => const ReportesPagina(),
    _ => const FormatosPagina(),
  };

  /// El Resumen no se titula "Resumen": saluda. Es lo primero que se ve al
  /// entrar y es donde más se nota que la app habla con alguien.
  (String, String) get _textosEncabezado {
    final seccion = Seccion.todas[_seccion];
    if (_seccion != Seccion.iResumen) return (seccion.etiqueta, seccion.bajada);

    final mes = Formato.mes(DateTime.now());
    return ('${Saludo.porHora()}, ${widget.usuario}', 'Así va tu caja en $mes');
  }

  Future<void> _registrar(Tipo tipo) async {
    final mensajero = ScaffoldMessenger.of(context);
    final guardado = await RegistroHoja.abrir(context, tipo);
    if (guardado == null) return;

    // En el celular, un golpecito: confirma que se guardó sin tener que mirar.
    HapticFeedback.mediumImpact();

    // Feedback visible en cada acción (§5): se confirma y se ofrece ir a verlo.
    mensajero
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: tipo == Tipo.entro ? Tokens.entroVivo : Tokens.salioVivo,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  [
                    tipo == Tipo.entro
                        ? 'Listo, la entrada quedó anotada'
                        : 'Listo, la salida quedó anotada',
                    if (guardado.numeroBoleta != null)
                      'Boleta ${Boleta(negocio: Negocio.vacio, movimiento: guardado).numero}',
                    if (guardado.numeroRecibo != null)
                      'Recibo N° ${guardado.numeroRecibo.toString().padLeft(6, '0')}',
                  ].join('  ·  '),
                ),
              ),
            ],
          ),
          // "Ver" abre sus papeles si tiene alguno; si no, el historial.
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () =>
                guardado.numeroBoleta != null || guardado.numeroRecibo != null
                ? AccionesMovimiento.abrir(context, guardado)
                : _irA(Seccion.iHistorial),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    if (estado.error != null && !estado.cargando) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 16),
                Text(estado.error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: estado.cargar,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final esEscritorio = MediaQuery.sizeOf(context).width >= _anchoEscritorio;
    final (titulo, bajada) = _textosEncabezado;

    // Al cambiar de sección la página entra con un fundido corto. Sin esto el
    // cambio es un salto seco, y es de las cosas que hacen sentir fría a una
    // interfaz aunque nadie sepa decir por qué.
    final pagina = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (hijo, animacion) => FadeTransition(
        opacity: animacion,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(animacion),
          child: hijo,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_seccion),
        child: NotificationListener<ScrollNotification>(
          onNotification: _alDesplazar,
          child: _pagina,
        ),
      ),
    );

    if (esEscritorio) {
      final anchoBarra = _barraPlegada
          ? BarraLateral.anchoPlegada
          : BarraLateral.ancho;
      // Poco lugar para el encabezado: ventana chica o texto de Windows
      // agrandado. Los botones y el usuario se compactan.
      final estrecho = MediaQuery.sizeOf(context).width - anchoBarra < 860;

      // Ctrl+B pliega y despliega la barra, como en los editores: quien la
      // usa seguido no tiene que ir a buscar el botón con el mouse.
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyB, control: true):
              _alternarBarra,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                Row(
                  children: [
                    BarraLateral(
                      seleccionada: _seccion,
                      onSeleccionar: _irA,
                      resumen: estado.resumen,
                      plegada: _barraPlegada,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Encabezado(
                            titulo: titulo,
                            bajada: bajada,
                            usuario: widget.usuario,
                            onSalir: widget.onSalir,
                            onPerfil: () => NegocioPagina.abrir(context),
                            estrecho: estrecho,
                            elevado: _desplazado,
                            acciones: [
                              _BotonRegistro(
                                tipo: Tipo.entro,
                                compacto: estrecho,
                                onPressed: () => _registrar(Tipo.entro),
                              ),
                              const SizedBox(width: 10),
                              _BotonRegistro(
                                tipo: Tipo.salio,
                                compacto: estrecho,
                                onPressed: () => _registrar(Tipo.salio),
                              ),
                              const SizedBox(width: 10),
                              const _BotonSync(),
                            ],
                          ),
                          Expanded(child: pagina),
                        ],
                      ),
                    ),
                  ],
                ),
                // El botón va montado sobre el borde de la barra y se mueve
                // con ella: siempre queda en el mismo lugar respecto del menú.
                AnimatedPositioned(
                  duration: BarraLateral.duracion,
                  curve: BarraLateral.curva,
                  left: anchoBarra - BotonPlegar.tamano / 2,
                  top: 40,
                  child: BotonPlegar(
                    plegada: _barraPlegada,
                    onTap: _alternarBarra,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: _armazon,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Encabezado(
              titulo: titulo,
              bajada: bajada,
              usuario: widget.usuario,
              onSalir: widget.onSalir,
              onPerfil: () => NegocioPagina.abrir(context),
              compacto: true,
              acciones: const [_BotonSync()],
              alFinal: _BotonMenu(
                onTap: () => _armazon.currentState?.openEndDrawer(),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: pagina),
          ],
        ),
      ),
      // Las secciones salen por la derecha, del lado del pulgar. Con seis
      // secciones, una barra abajo quedaba apretada y con nombres cortados.
      endDrawer: Drawer(
        width: BarraLateral.anchoMenu,
        clipBehavior: Clip.antiAlias,
        backgroundColor: Tokens.cromo,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
        ),
        child: BarraLateral(
          seleccionada: _seccion,
          resumen: estado.resumen,
          enMenu: true,
          onSeleccionar: (i) {
            _armazon.currentState?.closeEndDrawer();
            _irA(i);
          },
        ),
      ),
      floatingActionButton: _BotonesFlotantes(onRegistrar: _registrar),
    );
  }
}

/// El botón del menú en el celular: abre las secciones por la derecha.
class _BotonMenu extends StatelessWidget {
  const _BotonMenu({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconButton(
        tooltip: 'Secciones',
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: Tokens.cromo,
          foregroundColor: Colors.white,
          fixedSize: const Size(42, 42),
        ),
        icon: const Icon(Icons.menu_rounded, size: 22),
      ),
    );
  }
}

/// Botón de registro para el encabezado de escritorio.
class _BotonRegistro extends StatelessWidget {
  const _BotonRegistro({
    required this.tipo,
    required this.onPressed,
    this.compacto = false,
  });

  final Tipo tipo;
  final VoidCallback onPressed;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final entro = tipo == Tipo.entro;

    final color = entro ? Tokens.entro : Tokens.salio;

    return FilledButton.icon(
      onPressed: onPressed,
      style:
          FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            minimumSize: compacto ? const Size(96, 46) : const Size(116, 50),
            padding: EdgeInsets.symmetric(horizontal: compacto ? 16 : 24),
            elevation: 0,
            textStyle: const TextStyle(
              fontFamily: Tokens.tipografia,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ).copyWith(
            // Un brillo del mismo color al pasar el mouse: el botón se enciende
            // en vez de sólo oscurecerse.
            elevation: WidgetStateProperty.resolveWith(
              (e) => e.contains(WidgetState.hovered) ? 6 : 0,
            ),
            shadowColor: WidgetStatePropertyAll(color.withValues(alpha: 0.45)),
          ),
      icon: Icon(
        entro ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        size: 19,
      ),
      label: Text(tipo.etiqueta),
    );
  }
}

/// Los dos botones flotantes del celular.
///
/// Dos y no uno: el usuario dice de entrada si entró o salió plata (§4.1). Un
/// solo botón "+" obligaría a elegir el signo dentro del formulario.
class _BotonesFlotantes extends StatelessWidget {
  const _BotonesFlotantes({required this.onRegistrar});

  final Future<void> Function(Tipo) onRegistrar;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'salio',
          onPressed: () => onRegistrar(Tipo.salio),
          backgroundColor: Tokens.salio,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.arrow_downward_rounded),
          label: const Text('Salió'),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: 'entro',
          onPressed: () => onRegistrar(Tipo.entro),
          backgroundColor: Tokens.entro,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.arrow_upward_rounded),
          label: const Text('Entró'),
        ),
      ],
    );
  }
}

class _BotonSync extends StatelessWidget {
  const _BotonSync();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Respaldar en la nube',
      icon: const Icon(
        Icons.cloud_off_outlined,
        color: Tokens.texto2,
        size: 22,
      ),
      onPressed: () async {
        final mensajero = ScaffoldMessenger.of(context);
        final estado = context.read<EstadoCaja>();
        try {
          final respaldado = await estado.sincronizar();
          if (!mensajero.mounted) return;
          // Sin Firebase conectado esto siempre cae acá, y está bien: la app
          // sirve igual. El mensaje evita que parezca que algo falló.
          mensajero.showSnackBar(
            SnackBar(
              content: Text(
                respaldado
                    ? 'Sincronización completada.'
                    : 'Tus datos están guardados en este equipo. El respaldo en la '
                          'nube todavía no está activado.',
              ),
            ),
          );
        } catch (e) {
          if (mensajero.mounted) {
            mensajero.showSnackBar(
              SnackBar(content: Text('No se pudo sincronizar. $e')),
            );
          }
        }
      },
    );
  }
}
