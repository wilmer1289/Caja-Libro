import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/almacen.dart';
import '../../estado/estado_caja.dart';

/// Devuelve mercadería vinculándola a la línea original de compra o venta.
class DevolucionDialogo extends StatefulWidget {
  const DevolucionDialogo({super.key});

  static Future<void> abrir(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Tokens.cromo.withValues(alpha: .38),
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: const DevolucionDialogo(),
      ),
    ),
  );

  @override
  State<DevolucionDialogo> createState() => _DevolucionDialogoState();
}

class _DevolucionDialogoState extends State<DevolucionDialogo> {
  final _cantidad = TextEditingController();
  OperacionAlmacen _operacion = OperacionAlmacen.devolucionRecibida;
  String? _origenId;
  DateTime _fecha = DateTime.now();
  bool _intento = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  bool get _esDevolucionCliente =>
      _operacion == OperacionAlmacen.devolucionRecibida;

  List<LineaAlmacen> _origenes(EstadoCaja estado) {
    final tipoOrigen = _esDevolucionCliente
        ? OperacionAlmacen.venta
        : OperacionAlmacen.compra;
    final lineas =
        estado.lineasAlmacen
            .where((l) => !l.anulada && l.operacion == tipoOrigen)
            .where((l) => estado.producto(l.mercaderiaId) != null)
            .where((l) => _pendiente(estado, l) > 0)
            .toList()
          ..sort((a, b) {
            final fecha = b.fecha.compareTo(a.fecha);
            return fecha != 0 ? fecha : b.numero.compareTo(a.numero);
          });
    return lineas;
  }

  int _pendiente(EstadoCaja estado, LineaAlmacen origen) {
    final devuelto = estado.lineasAlmacen
        .where((l) => !l.anulada && l.origenId == origen.id)
        .fold<int>(0, (total, l) => total + l.cantidad);
    return origen.cantidad - devuelto;
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

  Future<void> _guardar(LineaAlmacen? origen) async {
    if (_guardando) return;
    setState(() {
      _intento = true;
      _error = null;
    });
    final cantidad = Cantidad.leer(_cantidad.text);
    if (origen == null || cantidad == null || cantidad <= 0) return;
    final estado = context.read<EstadoCaja>();
    final producto = estado.producto(origen.mercaderiaId);
    if (producto == null) {
      setState(
        () => _error =
            'El producto de la operación original ya no está disponible.',
      );
      return;
    }
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
        mercaderiaId: origen.mercaderiaId,
        fecha: _fecha,
        cantidad: cantidad,
        origenId: origen.id,
      );
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo registrar la devolución. $e');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _etiquetaOrigen(EstadoCaja estado, LineaAlmacen linea) {
    final producto = estado.producto(linea.mercaderiaId);
    final documento = linea.comprobante?.texto;
    final nombreDoc = documento == null || documento.isEmpty
        ? 'Operación ${linea.numero}'
        : documento;
    return '${Formato.fecha(linea.fecha)} · $nombreDoc · '
        '${producto?.nombre ?? linea.mercaderiaId} · quedan '
        '${Cantidad.texto(_pendiente(estado, linea))} '
        '${producto?.abreviaturaUnidad ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final origenes = _origenes(estado);
    final origen = origenes.where((l) => l.id == _origenId).firstOrNull;
    final producto = origen == null
        ? null
        : estado.producto(origen.mercaderiaId);
    final pendiente = origen == null ? null : _pendiente(estado, origen);

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
                const Icon(
                  Icons.assignment_return_outlined,
                  color: Tokens.marcaOscura,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Registrar devolución',
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
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de devolución',
                    ),
                    items:
                        const [
                              OperacionAlmacen.devolucionRecibida,
                              OperacionAlmacen.devolucionEntregada,
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
                        : (v) => setState(() {
                            _operacion = v ?? _operacion;
                            _origenId = null;
                            _cantidad.clear();
                          }),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _origenId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _esDevolucionCliente
                          ? 'Venta original'
                          : 'Compra original',
                      errorText: _intento && origen == null
                          ? origenes.isEmpty
                                ? 'No hay operaciones disponibles para devolver.'
                                : 'Elige la operación original.'
                          : null,
                    ),
                    items: origenes
                        .map(
                          (l) => DropdownMenuItem(
                            value: l.id,
                            child: Text(
                              _etiquetaOrigen(estado, l),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _guardando
                        ? null
                        : (id) => setState(() {
                            _origenId = id;
                            _cantidad.clear();
                          }),
                  ),
                  if (origen != null &&
                      producto != null &&
                      pendiente != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${producto.codigo} · ${producto.nombre}\nCantidad disponible para devolver: ${Cantidad.texto(pendiente)} ${producto.abreviaturaUnidad}',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Tokens.texto2,
                      ),
                    ),
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
                        labelText: 'Cantidad (${producto.abreviaturaUnidad})',
                        errorText:
                            _intento &&
                                (Cantidad.leer(_cantidad.text) == null ||
                                    Cantidad.leer(_cantidad.text) == 0)
                            ? 'Escribe una cantidad mayor que cero.'
                            : null,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _guardando ? null : _elegirFecha,
                    icon: const Icon(Icons.calendar_today_outlined, size: 17),
                    label: Text('Fecha: ${Formato.fecha(_fecha)}'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _esDevolucionCliente
                        ? 'La mercadería vuelve al costo con que salió en esa venta. La devolución del dinero se registra en otra etapa.'
                        : 'La mercadería sale al costo de esa compra. El pago al proveedor se registra en otra etapa.',
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
                  onPressed: _guardando || origenes.isEmpty
                      ? null
                      : () => _guardar(origen),
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
