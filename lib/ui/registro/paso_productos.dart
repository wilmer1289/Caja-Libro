import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/mercaderia.dart';
import '../../dominio/tablas_sunat.dart';
import 'linea_producto.dart';

/// Paso de líneas de productos para compras y ventas.
///
/// La pantalla edita borradores; el coordinador del registro valida el
/// cuadre, el stock y los datos del comprobante antes de permitir continuar.
class PasoProductos extends StatelessWidget {
  const PasoProductos({
    super.key,
    required this.compra,
    required this.venta,
    required this.esServicio,
    required this.sinIgv,
    required this.exportacion,
    required this.lineas,
    required this.productos,
    required this.fecha,
    required this.montoCentavos,
    required this.sumaLineas,
    required this.montoCalculado,
    required this.cuadra,
    required this.intento,
    required this.error,
    required this.tipoComprobante,
    required this.serieComprobante,
    required this.numeroComprobante,
    required this.errorComprobante,
    required this.stockDisponible,
    required this.ultimaFecha,
    required this.costoDeSalida,
    required this.onAgregarLinea,
    required this.onQuitarLinea,
    required this.onCambioLinea,
    required this.onSeleccionarProducto,
    required this.onServicio,
    required this.onSinIgv,
    required this.onExportacion,
    required this.onUsarMonto,
    required this.onTipoComprobante,
    required this.onSerieComprobante,
    required this.onNumeroComprobante,
  });

  final bool compra;
  final bool venta;
  final bool esServicio;
  final bool sinIgv;
  final bool exportacion;
  final List<LineaProductoBorrador> lineas;
  final List<Mercaderia> productos;
  final DateTime fecha;
  final int? montoCentavos;
  final int sumaLineas;
  final int montoCalculado;
  final bool cuadra;
  final bool intento;
  final String? error;
  final String tipoComprobante;
  final TextEditingController serieComprobante;
  final TextEditingController numeroComprobante;
  final String? errorComprobante;
  final int Function(String id) stockDisponible;
  final DateTime? Function(String id) ultimaFecha;
  final int? Function(String id, int cantidad) costoDeSalida;
  final VoidCallback onAgregarLinea;
  final ValueChanged<int> onQuitarLinea;
  final ValueChanged<int> onCambioLinea;
  final void Function(int indice, String? id) onSeleccionarProducto;
  final ValueChanged<bool> onServicio;
  final ValueChanged<bool> onSinIgv;
  final ValueChanged<bool> onExportacion;
  final VoidCallback onUsarMonto;
  final ValueChanged<String?> onTipoComprobante;
  final ValueChanged<String> onSerieComprobante;
  final ValueChanged<String> onNumeroComprobante;

  @override
  Widget build(BuildContext context) {
    final mostrarLineas = !(venta && esServicio);
    final monto = montoCentavos;
    final desajuste = monto != null && !cuadra;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Tokens.marcaSuave,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: Tokens.marcaOscura,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Productos',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Tokens.texto,
                    ),
                  ),
                  Text(
                    'Agrega los productos y las cantidades de esta operación.',
                    style: TextStyle(fontSize: 12.5, color: Tokens.texto2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (venta) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: ChoiceChip(
              label: const Text('No es mercadería'),
              selected: esServicio,
              onSelected: onServicio,
            ),
          ),
          const SizedBox(height: 10),
          if (esServicio)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Tokens.fondo,
                borderRadius: BorderRadius.circular(Tokens.radio),
                border: Border.all(color: Tokens.borde),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 18,
                    color: Tokens.texto2,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Es un servicio: no descuenta productos del inventario ni requiere costo de kardex.',
                      style: TextStyle(fontSize: 12, color: Tokens.texto2),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (compra) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: sinIgv,
            onChanged: (v) => onSinIgv(v ?? false),
            title: const Text(
              'Esta compra no tiene IGV',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'El importe de las líneas será también el monto de la compra.',
              style: TextStyle(fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 8),
          _ComprobanteProveedor(
            tipo: tipoComprobante,
            serie: serieComprobante,
            numero: numeroComprobante,
            error: errorComprobante,
            onTipo: onTipoComprobante,
            onSerie: onSerieComprobante,
            onNumero: onNumeroComprobante,
          ),
          const SizedBox(height: 14),
        ],
        if (venta && !esServicio) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: exportacion,
            onChanged: (v) => onExportacion(v ?? false),
            title: const Text(
              'Venta de exportación',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'No lleva IGV. Se registra en la cuenta 70111 y se numera como factura F001.',
              style: TextStyle(fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (mostrarLineas) ...[
          for (var i = 0; i < lineas.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            LineaProducto(
              key: ValueKey('linea-producto-$i-${lineas[i].mercaderiaId}'),
              indice: i,
              borrador: lineas[i],
              productos: productos,
              compra: compra,
              fecha: fecha,
              stockDisponible: stockDisponible,
              ultimaFecha: ultimaFecha,
              costoDeSalida: costoDeSalida,
              onCambio: () => onCambioLinea(i),
              onSeleccionar: (id) => onSeleccionarProducto(i, id),
              onQuitar: () => onQuitarLinea(i),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAgregarLinea,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar producto'),
            ),
          ),
          if (lineas.isEmpty && intento)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Agrega al menos un producto para continuar.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Tokens.salio,
                ),
              ),
            ),
          if (lineas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Tokens.fondo,
                borderRadius: BorderRadius.circular(Tokens.radio),
                border: Border.all(
                  color: desajuste
                      ? Tokens.salio.withValues(alpha: .35)
                      : Tokens.borde,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Suma neta de las líneas',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Tokens.texto2,
                          ),
                        ),
                      ),
                      Text(
                        Formato.soles(sumaLineas / 100),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Tokens.texto,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Monto que corresponde',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Tokens.texto2,
                          ),
                        ),
                      ),
                      Text(
                        Formato.soles(montoCalculado / 100),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Tokens.texto,
                        ),
                      ),
                    ],
                  ),
                  if (desajuste) ...[
                    const SizedBox(height: 9),
                    Text(
                      'El monto actual es ${Formato.soles(monto / 100)}. '
                      'Las líneas no cuadran con ese monto.',
                      style: const TextStyle(fontSize: 12, color: Tokens.salio),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonal(
                        onPressed: onUsarMonto,
                        child: Text(
                          'Usar ${Formato.soles(montoCalculado / 100)} como monto',
                        ),
                      ),
                    ),
                  ] else if (monto != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Tokens.entro,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Las líneas cuadran con el monto.',
                            style: TextStyle(fontSize: 12, color: Tokens.entro),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Tokens.salioSuave,
              borderRadius: BorderRadius.circular(Tokens.radio),
              border: Border.all(color: Tokens.salio.withValues(alpha: .25)),
            ),
            child: Text(
              error!,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Tokens.salio,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ComprobanteProveedor extends StatelessWidget {
  const _ComprobanteProveedor({
    required this.tipo,
    required this.serie,
    required this.numero,
    required this.error,
    required this.onTipo,
    required this.onSerie,
    required this.onNumero,
  });

  final String tipo;
  final TextEditingController serie;
  final TextEditingController numero;
  final String? error;
  final ValueChanged<String?> onTipo;
  final ValueChanged<String> onSerie;
  final ValueChanged<String> onNumero;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Comprobante del proveedor (opcional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Tokens.texto,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: tipo,
          isExpanded: true,
          menuMaxHeight: 320,
          decoration: const InputDecoration(
            labelText: 'Tipo de comprobante',
            isDense: true,
          ),
          items: [
            for (final doc in TablasSunat.comprobantes)
              DropdownMenuItem(
                value: doc.codigo,
                child: Text(
                  '${doc.codigo} · ${doc.descripcion}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onTipo,
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: serie,
                textCapitalization: TextCapitalization.characters,
                onChanged: onSerie,
                decoration: const InputDecoration(
                  labelText: 'Serie',
                  hintText: 'F001',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: numero,
                keyboardType: TextInputType.number,
                onChanged: onNumero,
                decoration: const InputDecoration(
                  labelText: 'Número',
                  hintText: '123',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: const TextStyle(fontSize: 12, color: Tokens.salio),
            ),
          ),
      ],
    );
  }
}
