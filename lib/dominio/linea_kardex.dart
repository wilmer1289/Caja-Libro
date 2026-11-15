/// Contrato de entrada del motor. P2 puede reexportarlo desde almacen.dart.
enum OperacionAlmacen {
  venta('01'),
  compra('02'),
  devolucionRecibida('05'),
  devolucionEntregada('06'),
  merma('13'),
  desmedro('14'),
  saldoInicial('16'),
  ajuste('99');

  const OperacionAlmacen(this.codigo);
  final String codigo;
}

/// Cantidades en milésimas, importes netos y costos en centavos.
class LineaAlmacen {
  const LineaAlmacen({
    required this.id,
    required this.mercaderiaId,
    required this.fecha,
    required this.numero,
    required this.operacion,
    required this.entrada,
    required this.cantidad,
    this.costoTotal,
    this.importe,
    this.descuento = 0,
    this.movimientoId,
    this.origenId,
    this.docTipo,
    this.docSerie,
    this.docNumero,
    this.cuentaCosto,
    this.registradoPor,
    this.glosa = '',
    this.anulada = false,
    this.gastoCompraAsignado = 0,
  });

  final String id, mercaderiaId, glosa;
  final DateTime fecha;
  final int numero, cantidad, descuento;
  final OperacionAlmacen operacion;
  final bool entrada, anulada;
  final int? costoTotal, importe;
  final String? movimientoId, origenId, docTipo, docSerie, docNumero;
  final String? cuentaCosto, registradoPor;

  /// Parte del flete u otro gasto asignada por P2 a esta línea de compra.
  final int gastoCompraAsignado;
}
