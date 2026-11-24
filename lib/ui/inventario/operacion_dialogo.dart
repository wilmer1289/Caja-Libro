import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/almacen.dart';
import '../../dominio/mercaderia.dart';
import '../../estado/estado_caja.dart';

/// Registra una merma o un desmedro usando las reglas y el costo del kardex.
class OperacionDialogo extends StatefulWidget {
  const OperacionDialogo({super.key});

  static Future<void> abrir(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Tokens.cromo.withValues(alpha: .38),
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
        child: const OperacionDialogo(),
      ),
    ),
  );

  @override
  State<OperacionDialogo> createState() => _OperacionDialogoState();
}

class _OperacionDialogoState extends State<OperacionDialogo> {
  final _cantidad = TextEditingController();
  final _motivo = TextEditingController();
  OperacionAlmacen _operacion = OperacionAlmacen.merma;
  String? _productoId;
  DateTime _fecha = DateTime.now();
  bool _intento = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _cantidad.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Mercaderia? _producto(List<Mercaderia> productos) {
    for (final producto in productos) {
      if (producto.id == _productoId) return producto;
    }
    return null;
  }

  String? get _errorCantidad {
    if (!_intento) return null;
    final cantidad = Cantidad.leer(_cantidad.text);
    if (cantidad == null || cantidad == 0) {
      return 'Escribe una cantidad válida.';
    }
    return null;
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime(ahora.year + 1, 12, 31),
    );
    if (elegida != null && mounted) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _intento = true;
      _error = null;
    });
    final estado = context.read<EstadoCaja>();
    final producto = _producto(estado.productosActivos);
    final cantidad = Cantidad.leer(_cantidad.text);
    if (producto == null || cantidad == null || cantidad <= 0) return;
    if (producto.cantidadesEnteras && !Cantidad.esEntera(cantidad)) {
      setState(
        () => _error =
            'La unidad ${producto.abreviaturaUnidad} no admite decimales.',
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await estado.registrarEnAlmacen(
        operacion: _operacion,
        mercaderiaId: producto.id,
        fecha: _fecha,
        cantidad: cantidad,
        glosa: _motivo.text,
      );
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo registrar la operación. $e');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productos = context.watch<EstadoCaja>().productosActivos;
    final seleccionado = _producto(productos);
    final saldo = seleccionado == null
        ? null
        : context.watch<EstadoCaja>().kardex.saldo(seleccionado.id);

    return Material(
      color: Tokens.superficie,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: Tokens.marcaOscura),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Nueva operación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Tokens.texto,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _guardando
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Tokens.borde),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<OperacionAlmacen>(
                    initialValue: _operacion,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de operación',
                    ),
                    items:
                        const [
                              OperacionAlmacen.merma,
                              OperacionAlmacen.desmedro,
                            ]
                            .map(
                              (o) => DropdownMenuItem(
                                value: o,
                                child: Text(o.etiqueta),
                              ),
                            )
                            .toList(),
                    onChanged: _guardando
                        ? null
                        : (v) => setState(() => _operacion = v ?? _operacion),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _productoId,
                    decoration: InputDecoration(
                      labelText: 'Producto',
                      errorText: _intento && seleccionado == null
                          ? 'Elige un producto.'
                          : null,
                    ),
                    items: productos
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              '${p.codigo} · ${p.nombre}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _guardando
                        ? null
                        : (v) => setState(() => _productoId = v),
                  ),
                  if (seleccionado != null && saldo != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Disponible: ${Cantidad.texto(saldo.cantidad)} ${seleccionado.abreviaturaUnidad} · ${Formato.soles(saldo.costo / 100)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Tokens.texto2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _cantidad,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: seleccionado == null
                          ? 'Cantidad'
                          : 'Cantidad (${seleccionado.abreviaturaUnidad})',
                      errorText: _errorCantidad,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _motivo,
                    maxLength: 200,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Motivo',
                      hintText: 'Describe brevemente qué ocurrió',
                    ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: _guardando ? null : _elegirFecha,
                    icon: const Icon(Icons.calendar_today_outlined, size: 17),
                    label: Text('Fecha: ${Formato.fecha(_fecha)}'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _operacion == OperacionAlmacen.merma
                        ? 'La salida se valorará al costo promedio. Conserva el informe técnico que sustenta la merma.'
                        : 'La salida se valorará al costo promedio. Recuerda sustentar y comunicar la destrucción según corresponda.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Tokens.texto2,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Tokens.salio,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Tokens.borde),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                const Spacer(),
                OutlinedButton(
                  onPressed: _guardando
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _guardando || productos.isEmpty ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Registrar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
