import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/almacen.dart';
import '../../dominio/importe.dart';
import '../../dominio/mercaderia.dart';
import '../../estado/estado_caja.dart';

/// Registro del saldo inicial o corrección posterior por medio de un ajuste.
/// El saldo inicial queda bloqueado después de la primera carga.
class InventarioInicialDialogo extends StatefulWidget {
  const InventarioInicialDialogo({super.key, required this.producto});

  final Mercaderia producto;

  static Future<void> abrir(BuildContext context, Mercaderia producto) =>
      showDialog<void>(
        context: context,
        barrierColor: Tokens.cromo.withValues(alpha: .38),
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
            child: InventarioInicialDialogo(producto: producto),
          ),
        ),
      );

  @override
  State<InventarioInicialDialogo> createState() =>
      _InventarioInicialDialogoState();
}

class _InventarioInicialDialogoState extends State<InventarioInicialDialogo> {
  final _cantidad = TextEditingController();
  final _costoUnitario = TextEditingController();
  bool _guardando = false;
  bool _intento = false;
  String? _error;

  EstadoCaja get _estado => context.read<EstadoCaja>();

  bool get _esInicial => !_estado.tieneMovimientosAlmacen(widget.producto.id);

  int get _stockActual => _estado.stockDe(widget.producto.id);

  @override
  void initState() {
    super.initState();
    final estado = context.read<EstadoCaja>();
    final esInicial = !estado.tieneMovimientosAlmacen(widget.producto.id);
    final stock = estado.stockDe(widget.producto.id);
    _cantidad.text = esInicial ? '' : Cantidad.texto(stock);
    final saldo = estado.kardex.saldo(widget.producto.id);
    if (saldo.cantidad > 0) {
      _costoUnitario.text = saldo.costoUnitario.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _cantidad.dispose();
    _costoUnitario.dispose();
    super.dispose();
  }

  String? get _errorCantidad {
    if (!_intento) return null;
    final cantidad = Cantidad.leer(_cantidad.text);
    if (cantidad == null) return 'Escribe una cantidad válida.';
    if (_esInicial && cantidad <= 0) {
      return 'El inventario inicial debe ser mayor que cero.';
    }
    if (widget.producto.cantidadesEnteras && !Cantidad.esEntera(cantidad)) {
      return 'La unidad ${widget.producto.abreviaturaUnidad} no admite decimales.';
    }
    return null;
  }

  String? get _errorCosto {
    if (!_intento) return null;
    final cantidad = Cantidad.leer(_cantidad.text);
    if (cantidad == null) return null;
    final delta = cantidad - _stockActual;
    final necesitaCosto = _esInicial || (delta > 0 && _stockActual == 0);
    if (!necesitaCosto) return null;
    final costo = Importe.leer(_costoUnitario.text);
    if (costo == null || costo <= 0) {
      return 'Escribe un costo unitario mayor que cero.';
    }
    return null;
  }

  int? _costoTotal(int cantidad, int costoUnitario) {
    final total =
        (BigInt.from(cantidad) * BigInt.from(costoUnitario) +
            BigInt.from(Cantidad.escala ~/ 2)) ~/
        BigInt.from(Cantidad.escala);
    if (total <= BigInt.zero || total > BigInt.from(Importe.maximoCentavos)) {
      return null;
    }
    return total.toInt();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _intento = true;
      _error = null;
    });
    if (_errorCantidad != null || _errorCosto != null) return;

    final cantidadObjetivo = Cantidad.leer(_cantidad.text)!;
    final actual = _stockActual;
    final delta = cantidadObjetivo - actual;

    if (!_esInicial && delta == 0) {
      setState(
        () => _error = 'El conteo coincide con el stock actual; no hay ajuste que registrar.',
      );
      return;
    }

    final necesitaCosto = _esInicial || (delta > 0 && actual == 0);
    final costoUnitario = necesitaCosto
        ? Importe.leer(_costoUnitario.text)!
        : null;
    final costoTotal = necesitaCosto
        ? _costoTotal(_esInicial ? cantidadObjetivo : delta, costoUnitario!)
        : null;
    if (necesitaCosto && costoTotal == null) {
      setState(() => _error = 'El costo total supera el límite permitido.');
      return;
    }

    setState(() => _guardando = true);
    try {
      await _estado.registrarEnAlmacen(
        operacion: _esInicial
            ? OperacionAlmacen.saldoInicial
            : OperacionAlmacen.ajuste,
        mercaderiaId: widget.producto.id,
        fecha: DateTime.now(),
        cantidad: _esInicial ? cantidadObjetivo : delta.abs(),
        entrada: _esInicial ? null : delta > 0,
        costoTotal: costoTotal,
        glosa: _esInicial ? '' : 'Corrección del conteo de inventario',
      );
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar el inventario. $e');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _campo({
    required String etiqueta,
    required TextEditingController controller,
    String? ayuda,
    String? error,
    String? prefijo,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        errorText: error,
        prefixText: prefijo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esInicial = _esInicial;
    final stock = _stockActual;
    final saldo = context.watch<EstadoCaja>().kardex.saldo(widget.producto.id);
    final cantidadObjetivo = Cantidad.leer(_cantidad.text);
    final delta = cantidadObjetivo == null ? null : cantidadObjetivo - stock;
    final necesitaCosto =
        esInicial || (delta != null && delta > 0 && stock == 0);

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
                  Icons.inventory_2_outlined,
                  color: Tokens.marcaOscura,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    esInicial ? 'Inventario inicial' : 'Corregir inventario',
                    style: const TextStyle(
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
                  Text(
                    widget.producto.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Tokens.texto,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!esInicial)
                    Text(
                      'Stock registrado: ${Cantidad.texto(stock)} ${widget.producto.abreviaturaUnidad} · Valor: ${Formato.soles(saldo.costo / 100)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Tokens.texto2,
                      ),
                    )
                  else
                    const Text(
                      'Este producto todavía no tiene movimientos. El saldo inicial se registra una sola vez y después queda bloqueado.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Tokens.texto2,
                      ),
                    ),
                  const SizedBox(height: 18),
                  _campo(
                    etiqueta:
                        'Cantidad contada (${widget.producto.abreviaturaUnidad})',
                    controller: _cantidad,
                    error: _errorCantidad,
                    ayuda: esInicial
                        ? 'Cantidad con la que empieza el inventario.'
                        : 'Escribe el conteo real. Se registrará solo la diferencia como ajuste.',
                  ),
                  if (necesitaCosto) ...[
                    const SizedBox(height: 14),
                    _campo(
                      etiqueta: 'Costo unitario',
                      controller: _costoUnitario,
                      prefijo: 'S/ ',
                      error: _errorCosto,
                      ayuda: esInicial
                          ? 'Costo por cada ${widget.producto.abreviaturaUnidad}.'
                          : 'El producto no tiene stock; indica el costo del sobrante.',
                    ),
                  ] else if (!esInicial && delta != null && delta > 0) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'El sobrante se valorará automáticamente al costo promedio del kardex.',
                      style: TextStyle(fontSize: 12, color: Tokens.texto2),
                    ),
                  ],
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
                  onPressed: _guardando ? null : _guardar,
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
                  label: Text(
                    esInicial ? 'Guardar saldo inicial' : 'Registrar ajuste',
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
