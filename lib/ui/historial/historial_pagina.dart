import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/tema.dart';
import '../../dominio/movimiento.dart';
import '../../estado/estado_caja.dart';
import '../widgets/aparece.dart';
import '../widgets/esqueleto.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/fila_movimiento.dart';
import 'acciones_movimiento.dart';
import 'barra_filtros.dart';

/// Todo lo registrado, con búsqueda y filtros a la vista (§4.4).
class HistorialPagina extends StatelessWidget {
  const HistorialPagina({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();

    if (estado.cargando) return const EsqueletoLista();

    if (estado.vacio) {
      return const EstadoVacio(
        icono: Icons.receipt_long_outlined,
        titulo: 'Aún no registraste nada',
        mensaje: 'Cuando anotes tu primer movimiento, lo vas a ver acá.',
      );
    }

    final filtrados = estado.historial;

    return LayoutBuilder(
      builder: (context, medidas) {
        final amplio = medidas.maxWidth >= 760;
        final margen = amplio ? 28.0 : 16.0;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(margen, margen, margen, 0),
              sliver: SliverToBoxAdapter(
                child: Aparece(
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(amplio ? 20 : 14),
                      child: const BarraFiltros(),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(margen + 4, 18, margen, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      estado.hayFiltrosActivos
                          ? 'Resultados'
                          : 'Todos los movimientos',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Tokens.texto,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      filtrados.length == 1
                          ? '1 movimiento'
                          : '${filtrados.length} movimientos',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Tokens.texto2,
                      ),
                    ),
                    const Spacer(),
                    if (estado.hayFiltrosActivos)
                      TextButton.icon(
                        onPressed: estado.limpiarFiltros,
                        icon: const Icon(
                          Icons.filter_alt_off_outlined,
                          size: 18,
                        ),
                        label: const Text('Quitar filtros'),
                      ),
                  ],
                ),
              ),
            ),
            if (filtrados.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EstadoVacio(
                  buscando: true,
                  icono: Icons.search_off_rounded,
                  titulo: 'Nada con esos filtros',
                  mensaje:
                      'Prueba con otras fechas o quita alguno de los filtros.',
                  accion: OutlinedButton(
                    onPressed: estado.limpiarFiltros,
                    child: const Text('Quitar filtros'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  margen,
                  0,
                  margen,
                  // Aire para que los botones flotantes del celular no tapen
                  // la última fila.
                  amplio ? margen : 120,
                ),
                sliver: SliverToBoxAdapter(
                  child: Aparece(
                    retraso: const Duration(milliseconds: 80),
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < filtrados.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                            _FilaDeslizable(
                              key: ValueKey(filtrados[i].id),
                              movimiento: filtrados[i],
                              resaltar:
                                  filtrados[i].id == estado.recienRegistrado,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Una fila del historial. Tocarla, o tocar su "⋮", abre la miniventana con
/// sus papeles: el recibo y la boleta, para verlos, imprimirlos o
/// descargarlos.
///
/// Antes se podía deslizar para eliminar. Se sacó: en un libro contable un
/// movimiento no se borra; si se anotó mal, se corrige con otro.
class _FilaDeslizable extends StatelessWidget {
  const _FilaDeslizable({
    super.key,
    required this.movimiento,
    this.resaltar = false,
  });

  final Movimiento movimiento;
  final bool resaltar;

  @override
  Widget build(BuildContext context) {
    return FilaMovimiento(
      movimiento: movimiento,
      resaltar: resaltar,
      onTap: () => AccionesMovimiento.abrir(context, movimiento),
      accion: IconButton(
        tooltip: 'Recibo y boleta',
        icon: const Icon(Icons.more_vert_rounded, size: 20),
        onPressed: () => AccionesMovimiento.abrir(context, movimiento),
      ),
    );
  }
}
