import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/almacen.dart';
import '../../estado/estado_caja.dart';
import 'devolucion_dialogo.dart';
import 'operacion_dialogo.dart';

/// Historial de movimientos del almacén que no se registran por Caja.
class OperacionesPestana extends StatelessWidget {
  const OperacionesPestana({super.key});

  Future<void> _nuevaOperacion(BuildContext context) async {
    final tipo = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Nueva operación'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 0),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.trending_down_rounded),
              title: Text('Merma o desmedro'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 1),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.assignment_return_outlined),
              title: Text('Devolución'),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (tipo == 0) {
      await OperacionDialogo.abrir(context);
      return;
    }
    if (!context.mounted) return;
    if (tipo == 1) await DevolucionDialogo.abrir(context);
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final lineas =
        estado.lineasAlmacen
            .where((l) => !l.operacion.vaPorCaja && !l.anulada)
            .toList()
          ..sort((a, b) {
            final fecha = b.fecha.compareTo(a.fecha);
            return fecha != 0 ? fecha : b.numero.compareTo(a.numero);
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boton = FilledButton.icon(
                onPressed: () => _nuevaOperacion(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nueva operación'),
              );
              return constraints.maxWidth < 500
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Operaciones',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Tokens.texto,
                          ),
                        ),
                        const SizedBox(height: 10),
                        boton,
                      ],
                    )
                  : Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Operaciones',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Tokens.texto,
                            ),
                          ),
                        ),
                        boton,
                      ],
                    );
            },
          ),
        ),
        const Divider(height: 1, color: Tokens.borde),
        Expanded(
          child: lineas.isEmpty
              ? const _SinOperaciones()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: lineas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final linea = lineas[index];
                    final producto = estado.producto(linea.mercaderiaId);
                    final costo = estado.kardex.costoDe(linea.id);
                    return _TarjetaOperacion(
                      titulo: linea.operacion.etiqueta,
                      producto: producto?.nombre ?? linea.mercaderiaId,
                      codigo: producto?.codigo ?? linea.mercaderiaId,
                      cantidad: Cantidad.texto(linea.cantidad),
                      unidad: producto?.abreviaturaUnidad ?? '',
                      costo: costo,
                      fecha: linea.fecha,
                      motivo: linea.glosa,
                      registradoPor: linea.registradoPor,
                      entra: linea.entrada,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TarjetaOperacion extends StatelessWidget {
  const _TarjetaOperacion({
    required this.titulo,
    required this.producto,
    required this.codigo,
    required this.cantidad,
    required this.unidad,
    required this.costo,
    required this.fecha,
    required this.motivo,
    required this.registradoPor,
    required this.entra,
  });

  final String titulo, producto, codigo, cantidad, unidad, motivo;
  final int costo;
  final DateTime fecha;
  final String? registradoPor;
  final bool entra;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Tokens.superficie,
      border: Border.all(color: Tokens.borde),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Tokens.marcaSuave,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            entra
                ? Icons.assignment_return_rounded
                : Icons.trending_down_rounded,
            color: entra ? Tokens.entro : Tokens.salio,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Tokens.texto,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$codigo · $producto',
                style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 3,
                children: [
                  Text(
                    '${entra ? '+' : '−'}$cantidad $unidad',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: entra ? Tokens.entro : Tokens.salio,
                    ),
                  ),
                  Text(
                    Formato.soles(costo / 100),
                    style: const TextStyle(fontSize: 12, color: Tokens.texto),
                  ),
                  Text(
                    Formato.fecha(fecha),
                    style: const TextStyle(fontSize: 12, color: Tokens.texto2),
                  ),
                ],
              ),
              if (motivo.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  motivo,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Tokens.texto,
                  ),
                ),
              ],
              if (registradoPor != null && registradoPor!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Registrado por $registradoPor',
                  style: const TextStyle(fontSize: 11, color: Tokens.texto2),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _SinOperaciones extends StatelessWidget {
  const _SinOperaciones();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_outlined, size: 38, color: Tokens.texto2),
          const SizedBox(height: 12),
          const Text(
            'Todavía no hay operaciones',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Tokens.texto,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Aquí aparecerán las mermas, desmedros, devoluciones y ajustes registrados.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Tokens.texto2,
            ),
          ),
        ],
      ),
    ),
  );
}
