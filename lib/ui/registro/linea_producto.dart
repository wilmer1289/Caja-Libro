import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/almacen.dart';
import '../../dominio/importe.dart';
import '../../dominio/mercaderia.dart';
import '../inventario/producto_dialogo.dart';

/// Borrador editable de una línea del paso Productos.
///
/// Los importes se guardan en centavos y las cantidades en milésimas, igual
/// que el kardex. En una venta, [valor] es el precio unitario; en una compra,
/// es el importe bruto de la línea antes del descuento.
class LineaProductoBorrador {
  LineaProductoBorrador({
    this.mercaderiaId,
    String cantidad = '1',
    String valor = '',
    String descuento = '0',
    this.enUnidadDeCompra = false,
    this.importeOriginal,
    this.conservarImporte = false,
    this.autoImporte = false,
  }) : cantidad = TextEditingController(text: cantidad),
       valor = TextEditingController(text: valor),
       descuento = TextEditingController(text: descuento);

  String? mercaderiaId;
  final TextEditingController cantidad;
  final TextEditingController valor;
  final TextEditingController descuento;
  bool enUnidadDeCompra;
  int? importeOriginal;
  bool conservarImporte;
  bool autoImporte;

  int? get cantidadMil => Cantidad.leer(cantidad.text);
  int? get valorCentavos => Importe.leer(valor.text);
  int? get descuentoCentavos =>
      descuento.text.trim().isEmpty ? 0 : Importe.leer(descuento.text);

  int? importeNeto({required bool compra}) {
    final descuento = descuentoCentavos;
    if (descuento == null) return null;
    if (!compra && conservarImporte && importeOriginal != null) {
      return importeOriginal;
    }
    final bruto = compra
        ? valorCentavos
        : _importeVenta(valorCentavos, cantidadMil);
    if (bruto == null || bruto <= 0 || descuento > bruto) return null;
    return bruto - descuento;
  }

  LineaNueva? aLinea({required bool compra}) {
    final id = mercaderiaId;
    final cantidad = cantidadMil;
    final importe = importeNeto(compra: compra);
    final descuento = descuentoCentavos;
    if (id == null ||
        cantidad == null ||
        importe == null ||
        descuento == null) {
      return null;
    }
    return LineaNueva(
      mercaderiaId: id,
      cantidad: cantidad,
      importe: importe,
      descuento: descuento,
      enUnidadDeCompra: compra && enUnidadDeCompra,
    );
  }

  void dispose() {
    cantidad.dispose();
    valor.dispose();
    descuento.dispose();
  }

  static int? _importeVenta(int? precioCentavos, int? cantidadMil) {
    if (precioCentavos == null || cantidadMil == null) return null;
    if (precioCentavos <= 0 || cantidadMil <= 0) return null;
    final bruto =
        (BigInt.from(precioCentavos) * BigInt.from(cantidadMil) +
            BigInt.from(Cantidad.escala ~/ 2)) ~/
        BigInt.from(Cantidad.escala);
    if (bruto > BigInt.from(Importe.maximoCentavos)) return null;
    return bruto.toInt();
  }
}

/// Una fila editable de compra o venta.
class LineaProducto extends StatelessWidget {
  const LineaProducto({
    super.key,
    required this.indice,
    required this.borrador,
    required this.productos,
    required this.compra,
    required this.fecha,
    required this.stockDisponible,
    required this.ultimaFecha,
    required this.costoDeSalida,
    required this.onCambio,
    required this.onSeleccionar,
    required this.onQuitar,
  });

  final int indice;
  final LineaProductoBorrador borrador;
  final List<Mercaderia> productos;
  final bool compra;
  final DateTime fecha;
  final int Function(String id) stockDisponible;
  final DateTime? Function(String id) ultimaFecha;
  final int? Function(String id, int cantidad) costoDeSalida;
  final VoidCallback onCambio;
  final ValueChanged<String?> onSeleccionar;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final producto = productos
        .where((p) => p.id == borrador.mercaderiaId)
        .firstOrNull;
    final cantidad = borrador.cantidadMil;
    final descuento = borrador.descuentoCentavos ?? 0;
    final importe = borrador.importeNeto(compra: compra);
    final cantidadStock = producto == null || cantidad == null
        ? null
        : compra && borrador.enUnidadDeCompra
        ? producto.aStock(cantidad)
        : cantidad;
    final disponible = !compra && producto != null
        ? stockDisponible(producto.id)
        : null;
    final costo = !compra && producto != null && cantidadStock != null
        ? costoDeSalida(producto.id, cantidadStock)
        : null;
    final ultima = producto == null ? null : ultimaFecha(producto.id);
    final fechaAnterior =
        ultima != null &&
        DateUtils.dateOnly(fecha).isBefore(DateUtils.dateOnly(ultima));
    final faltaStock =
        !compra &&
        disponible != null &&
        cantidadStock != null &&
        cantidadStock > disponible;

    Widget campoNumero({
      required String etiqueta,
      required TextEditingController controller,
      String? prefijo,
      String? sufijo,
      required ValueChanged<String> alCambiar,
    }) => TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: alCambiar,
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixText: prefijo,
        suffixText: sufijo,
        isDense: true,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Tokens.superficie,
        borderRadius: BorderRadius.circular(Tokens.radio + 2),
        border: Border.all(color: Tokens.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Producto ${indice + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Tokens.texto,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Quitar producto',
                visualDensity: VisualDensity.compact,
                onPressed: onQuitar,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('producto-$indice-${borrador.mercaderiaId}'),
                  initialValue: borrador.mercaderiaId,
                  isExpanded: true,
                  menuMaxHeight: 300,
                  decoration: const InputDecoration(
                    labelText: 'Producto',
                    hintText: 'Elige un producto',
                    isDense: true,
                  ),
                  items: [
                    for (final p in productos)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(p.nombre, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: onSeleccionar,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Agregar producto',
                onPressed: () async {
                  final nuevo = await ProductoDialogo.abrir(context);
                  if (context.mounted && nuevo != null) {
                    onSeleccionar(nuevo.id);
                  }
                },
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (producto != null) ...[
            LayoutBuilder(
              builder: (context, medidas) {
                final estrecho = medidas.maxWidth < 480;
                final cantidadWidget = campoNumero(
                  etiqueta: 'Cantidad',
                  controller: borrador.cantidad,
                  sufijo:
                      producto.abreviaturaUnidadCompra ==
                              producto.abreviaturaUnidad ||
                          !compra
                      ? producto.abreviaturaUnidad
                      : producto.abreviaturaUnidadCompra,
                  alCambiar: (_) {
                    borrador.conservarImporte = false;
                    onCambio();
                  },
                );
                final valorWidget = campoNumero(
                  etiqueta: compra
                      ? 'Importe de la línea'
                      : 'Precio por unidad',
                  controller: borrador.valor,
                  prefijo: 'S/ ',
                  alCambiar: (_) {
                    borrador.conservarImporte = false;
                    if (compra) borrador.autoImporte = false;
                    onCambio();
                  },
                );
                final descuentoWidget = campoNumero(
                  etiqueta: 'Descuento',
                  controller: borrador.descuento,
                  prefijo: 'S/ ',
                  alCambiar: (_) {
                    borrador.conservarImporte = false;
                    if (compra) borrador.autoImporte = false;
                    onCambio();
                  },
                );
                final campos = [cantidadWidget, valorWidget, descuentoWidget];
                if (estrecho) {
                  return Column(
                    children: [
                      for (var i = 0; i < campos.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        campos[i],
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < campos.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: campos[i]),
                    ],
                  ],
                );
              },
            ),
            if (compra &&
                producto.tieneUnidadDeCompra &&
                cantidadStock != null) ...[
              const SizedBox(height: 7),
              Text(
                'El inventario recibirá ${Cantidad.texto(cantidadStock)} '
                '${producto.abreviaturaUnidad}.',
                style: const TextStyle(fontSize: 12, color: Tokens.texto2),
              ),
            ],
            if (importe != null) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Importe neto de la línea',
                      style: TextStyle(fontSize: 12, color: Tokens.texto2),
                    ),
                  ),
                  Text(
                    Formato.soles(importe / 100),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Tokens.texto,
                    ),
                  ),
                ],
              ),
            ],
            if (compra &&
                importe != null &&
                cantidadStock != null &&
                cantidadStock > 0) ...[
              const SizedBox(height: 5),
              Text(
                'Costo unitario resultante: ${Formato.soles((importe * Cantidad.escala / cantidadStock) / 100)} por ${producto.abreviaturaUnidad}.',
                style: const TextStyle(fontSize: 12, color: Tokens.texto2),
              ),
            ],
            if (!compra && disponible != null) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Stock disponible',
                      style: TextStyle(fontSize: 12, color: Tokens.texto2),
                    ),
                  ),
                  Text(
                    '${Cantidad.texto(disponible)} ${producto.abreviaturaUnidad}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: faltaStock ? Tokens.salio : Tokens.texto,
                    ),
                  ),
                ],
              ),
              if (faltaStock)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'No hay suficiente ${producto.nombre}: hay '
                    '${Cantidad.texto(disponible)} ${producto.abreviaturaUnidad}.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Tokens.salio,
                    ),
                  ),
                ),
              if (costo != null && !faltaStock)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'Costo ${Formato.soles(costo / 100)}, lo calcula el kardex.',
                    style: const TextStyle(fontSize: 12, color: Tokens.texto2),
                  ),
                ),
            ],
            if (fechaAnterior) ...[
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E5),
                  borderRadius: BorderRadius.circular(Tokens.radio),
                  border: Border.all(color: const Color(0xFFF0DCB4)),
                ),
                child: Text(
                  'La fecha es anterior al último movimiento de ${producto.nombre} '
                  '(${Formato.fecha(ultima)}). Puede cambiar el costo de las operaciones posteriores.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF6B520F),
                  ),
                ),
              ),
            ],
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Selecciona un producto para ingresar su cantidad e importe.',
                style: TextStyle(fontSize: 12, color: Tokens.texto2),
              ),
            ),
          if (descuento > 0 && importe != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Descuento aplicado: ${Formato.soles(descuento / 100)}.',
                style: const TextStyle(fontSize: 11, color: Tokens.texto2),
              ),
            ),
        ],
      ),
    );
  }
}
