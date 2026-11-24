import 'package:flutter/material.dart';

import '../../core/tema.dart';
import 'conteo_pestana.dart';
import 'cerrar_mes.dart';
import 'kardex_pestana.dart';
import 'operaciones_pestana.dart';
import 'productos_seccion.dart';

/// Secciones del inventario. La visibilidad se define aquí para que más
/// adelante pueda limitarse por rol sin duplicar menús ni navegación.
class OpcionInventario {
  const OpcionInventario({
    required this.id,
    required this.etiqueta,
    required this.icono,
    this.rolesPermitidos = const [],
  });

  final String id;
  final String etiqueta;
  final IconData icono;

  /// Vacío significa visible para todos. Los roles se conectarán cuando exista
  /// la administración de permisos.
  final List<String> rolesPermitidos;

  bool visiblePara(String? rol) =>
      rolesPermitidos.isEmpty || (rol != null && rolesPermitidos.contains(rol));

  static const todas = <OpcionInventario>[
    OpcionInventario(
      id: 'productos',
      etiqueta: 'Productos',
      icono: Icons.inventory_2_outlined,
    ),
    OpcionInventario(
      id: 'kardex',
      etiqueta: 'Kardex',
      icono: Icons.receipt_long_outlined,
    ),
    OpcionInventario(
      id: 'operaciones',
      etiqueta: 'Operaciones',
      icono: Icons.swap_horiz_rounded,
    ),
    OpcionInventario(
      id: 'conteo',
      etiqueta: 'Conteo',
      icono: Icons.fact_check_outlined,
    ),
  ];
}

/// Ventana independiente del inventario. Al cerrarla, la sección de Mi Caja
/// que estaba debajo permanece seleccionada.
class InventarioVentana extends StatefulWidget {
  const InventarioVentana({super.key, this.seccion = 'productos'});

  /// La sección con que se abre: 'productos', 'kardex', 'operaciones' o
  /// 'conteo'. Formatos de Mi Caja la abre en el kardex.
  final String seccion;

  static Future<void> abrir(
    BuildContext context, {
    String seccion = 'productos',
  }) {
    final pantalla = MediaQuery.sizeOf(context);
    final movil = pantalla.width < 700;
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Tokens.cromo.withValues(alpha: .48),
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.all(movil ? 7 : 24),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Tokens.fondo,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 1180,
            maxHeight: (pantalla.height - (movil ? 14 : 48)).clamp(
              360.0,
              900.0,
            ),
          ),
          child: InventarioVentana(seccion: seccion),
        ),
      ),
    );
  }

  @override
  State<InventarioVentana> createState() => _InventarioVentanaState();
}

class _InventarioVentanaState extends State<InventarioVentana> {
  late String _seccion = widget.seccion;

  @override
  Widget build(BuildContext context) {
    final opciones = OpcionInventario.todas
        .where((o) => o.visiblePara(null))
        .toList();
    final seccionVisible = opciones.any((o) => o.id == _seccion)
        ? _seccion
        : (opciones.isEmpty ? '' : opciones.first.id);

    final ancho = MediaQuery.sizeOf(context).width;
    final escritorio = ancho >= 720;

    Widget contenido() {
      return switch (seccionVisible) {
        'productos' => const ProductosSeccion(),
        'kardex' => const KardexPestana(),
        'operaciones' => const OperacionesPestana(),
        'conteo' => const ConteoPestana(),
        _ => const _SeccionPendiente(
          icono: Icons.fact_check_outlined,
          titulo: 'Conteo',
          detalle: 'El conteo físico del inventario se habilitará en la siguiente etapa.',
        ),
      };
    }

    return Material(
      color: Tokens.fondo,
      child: Column(
        children: [
          _CabeceraInventario(onVolver: () => Navigator.of(context).pop()),
          Expanded(
            child: escritorio
                ? Row(
                    children: [
                      SizedBox(
                        width: 188,
                        child: _MenuInventario(
                          opciones: opciones,
                          seleccionada: seccionVisible,
                          vertical: true,
                          onSeleccionar: (id) => setState(() => _seccion = id),
                        ),
                      ),
                      Expanded(child: contenido()),
                    ],
                  )
                : Column(
                    children: [
                      _MenuInventario(
                        opciones: opciones,
                        seleccionada: seccionVisible,
                        vertical: false,
                        onSeleccionar: (id) => setState(() => _seccion = id),
                      ),
                      Expanded(child: contenido()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// El encabezado de la ventana: blanco, con el ícono naranja y una línea
/// naranja fina abajo. Dice «Inventario», así se nota que cambió de lugar.
class _CabeceraInventario extends StatelessWidget {
  const _CabeceraInventario({required this.onVolver});

  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
      decoration: const BoxDecoration(
        color: Tokens.superficie,
        border: Border(bottom: BorderSide(color: Tokens.marca, width: 2)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onVolver,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            label: const Text('Mi Caja'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
          ),
          const SizedBox(width: 14),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Tokens.marca,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Inventario',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Tokens.texto,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (MediaQuery.sizeOf(context).width < 450)
            IconButton(
              tooltip: 'Cerrar mes',
              onPressed: () => CerrarMes.abrir(context),
              icon: const Icon(Icons.lock_clock_outlined),
              color: Tokens.texto,
            )
          else
            OutlinedButton.icon(
              onPressed: () => CerrarMes.abrir(context),
              icon: const Icon(Icons.lock_clock_outlined, size: 17),
              label: const Text('Cerrar mes'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            ),
        ],
      ),
    );
  }
}

/// El menú del inventario, sobre crema arena (el tono del logo): separa el
/// menú del contenido sin oscurecer la ventana. La opción activa va en una
/// pastilla naranja con letra blanca.
class _MenuInventario extends StatelessWidget {
  const _MenuInventario({
    required this.opciones,
    required this.seleccionada,
    required this.vertical,
    required this.onSeleccionar,
  });

  final List<OpcionInventario> opciones;
  final String seleccionada;
  final bool vertical;
  final ValueChanged<String> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    if (!vertical) {
      return Container(
        height: 58,
        decoration: const BoxDecoration(
          color: Tokens.escenario,
          border: Border(bottom: BorderSide(color: Tokens.borde)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              for (final opcion in opciones) ...[
                _OpcionMenu(
                  opcion: opcion,
                  activa: seleccionada == opcion.id,
                  compacta: true,
                  onTap: () => onSeleccionar(opcion.id),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Tokens.escenario,
        border: Border(right: BorderSide(color: Tokens.borde)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 8, 12),
            child: Text(
              'INVENTARIO',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Tokens.texto2,
              ),
            ),
          ),
          for (final opcion in opciones)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _OpcionMenu(
                opcion: opcion,
                activa: seleccionada == opcion.id,
                onTap: () => onSeleccionar(opcion.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpcionMenu extends StatelessWidget {
  const _OpcionMenu({
    required this.opcion,
    required this.activa,
    required this.onTap,
    this.compacta = false,
  });

  final OpcionInventario opcion;
  final bool activa;
  final VoidCallback onTap;

  /// En el celular: una pastilla en la fila de arriba.
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final contenido = Row(
      mainAxisSize: compacta ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Icon(
          opcion.icono,
          size: 19,
          color: activa ? Colors.white : Tokens.texto2,
        ),
        const SizedBox(width: 10),
        Flexible(
          fit: compacta ? FlexFit.loose : FlexFit.tight,
          child: Text(
            opcion.etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
              color: activa ? Colors.white : Tokens.texto,
            ),
          ),
        ),
      ],
    );
    return Material(
      color: activa ? Tokens.marca : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: Tokens.marca.withValues(alpha: .08),
        splashColor: Tokens.marca.withValues(alpha: .12),
        highlightColor: Tokens.marca.withValues(alpha: .06),
        child: Padding(
          padding: compacta
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: contenido,
        ),
      ),
    );
  }
}

class _SeccionPendiente extends StatelessWidget {
  const _SeccionPendiente({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Tokens.marcaSuave,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icono, size: 30, color: Tokens.marcaOscura),
              ),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Tokens.texto,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detalle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Tokens.texto2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
