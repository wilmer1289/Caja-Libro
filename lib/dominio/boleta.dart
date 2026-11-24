import 'almacen.dart';
import 'categoria.dart';
import 'enums.dart';
import 'igv.dart';
import 'mercaderia.dart';
import 'monto_en_letras.dart';
import 'movimiento.dart';
import 'negocio.dart';
import 'recibo.dart';
import 'reglas_mercaderia.dart';
import 'tablas_sunat.dart';

/// Una línea del comprobante: cantidad, unidad, descripción y valores.
class ItemComprobante {
  const ItemComprobante({
    required this.cantidad,
    required this.unidad,
    required this.descripcion,
    required this.valorVenta,
    this.descuento = 0,
    this.codigo = '',
  });

  /// En milésimas (ver `Cantidad`).
  final int cantidad;

  /// El código de la factura electrónica (catálogo 03): NIU, KGM, ZZ…
  final String unidad;
  final String descripcion;
  final String codigo;

  /// Valor de venta de la línea, sin IGV y con el descuento ya restado.
  final int valorVenta;

  /// El descuento de la línea, sin IGV.
  final int descuento;

  /// En soles por unidad, sin IGV y antes del descuento.
  double get valorUnitario => cantidad == 0
      ? 0
      : (valorVenta + descuento) / 100 / (cantidad / Cantidad.escala);

  /// Las líneas de una venta guardada, con los datos de cada producto.
  static List<ItemComprobante> de(
    Iterable<LineaAlmacen> lineas,
    Mercaderia? Function(String id) producto,
  ) => [
    for (final l in lineas)
      _item(
        producto(l.mercaderiaId),
        l.mercaderiaId,
        l.cantidad,
        l.importe ?? 0,
        l.descuento,
      ),
  ];

  /// Las líneas de una venta que todavía no se guarda, para verla antes.
  static List<ItemComprobante> deNuevas(
    Iterable<LineaNueva> lineas,
    Mercaderia? Function(String id) producto,
  ) => [
    for (final l in lineas)
      _item(
        producto(l.mercaderiaId),
        l.mercaderiaId,
        l.cantidad,
        l.importe,
        l.descuento,
      ),
  ];

  static ItemComprobante _item(
    Mercaderia? p,
    String id,
    int cantidad,
    int importe,
    int descuento,
  ) => ItemComprobante(
    cantidad: cantidad,
    unidad: p?.codigoUnidadFactura ?? TablasSunat.unidadFacturaSuelta,
    descripcion: p?.nombre ?? id,
    codigo: p?.codigo ?? '',
    valorVenta: importe,
    descuento: descuento,
  );
}

/// El comprobante de una venta o de un adelanto de cliente.
///
/// Desde el inventario es la **factura electrónica** (01, serie F001) si el
/// cliente tiene RUC o es una exportación, o la **boleta de venta
/// electrónica** (03, serie B001) en los demás casos. La app la numera sola
/// al guardar. Todavía no se envía a SUNAT: eso llega con su API, cuando el
/// proyecto esté terminado.
///
/// Las ventas de antes del inventario se emitieron como boleta de control
/// interno, sin comprobante electrónico: esas se siguen mostrando así, con
/// su número de siempre.
class Boleta {
  const Boleta({
    required this.negocio,
    required this.movimiento,
    this.items = const [],
  });

  final Negocio negocio;
  final Movimiento movimiento;

  /// Los productos de la venta. Sin ellos, el comprobante lleva una sola
  /// línea con la descripción del movimiento (un servicio, o una venta de
  /// antes del inventario).
  final List<ItemComprobante> items;

  /// Desde este monto, el comprobante lleva el nombre y el documento del
  /// cliente. Por debajo es opcional y sale "Clientes varios".
  static const umbralIdentificacionCentavos = 70000; // S/ 700.00

  /// La serie de la boleta de control interno de antes del inventario.
  static const serie = 'B001';

  /// Qué movimientos llevan comprobante.
  static bool corresponde(Categoria categoria) =>
      categoria.tipo == Tipo.entro &&
      (categoria.id == Categoria.ventas.id ||
          categoria.id == Categoria.anticipos.id);

  static bool exigeCliente(int centavos) =>
      centavos >= umbralIdentificacionCentavos;

  /// Una venta de antes del inventario: ya se emitió como boleta interna.
  bool get deControlInterno =>
      movimiento.comprobante == null &&
      movimiento.numeroBoleta != null &&
      movimiento.numero > 0;

  bool get electronica => !deControlInterno;

  /// El comprobante electrónico: el guardado o, antes de guardar, el que le
  /// tocará según el documento del cliente.
  Comprobante get _electronico {
    final guardado = movimiento.comprobante;
    if (guardado != null) return guardado;
    try {
      return ReglasMercaderia.comprobanteDeVenta(
        documentoCliente: movimiento.documentoContraparte,
        exportacion: movimiento.exportacion,
      );
    } on ArgumentError {
      return const Comprobante(
        tipo: TablasSunat.boleta,
        serie: ReglasMercaderia.serieBoleta,
      );
    }
  }

  bool get esFactura => electronica && _electronico.tipo == TablasSunat.factura;

  /// "Factura electrónica", "Boleta de venta electrónica" o "Boleta de venta".
  String get nombre => !electronica
      ? 'Boleta de venta'
      : esFactura
      ? 'Factura electrónica'
      : 'Boleta de venta electrónica';

  /// Lo que va en el recuadro del documento.
  String get titulo => !electronica
      ? 'BOLETA DE VENTA'
      : esFactura
      ? 'FACTURA ELECTRÓNICA'
      : 'BOLETA DE VENTA ELECTRÓNICA';

  String? get subtitulo => electronica ? null : 'DE CONTROL INTERNO';

  /// Si ya tiene número (se asigna al guardar).
  bool get numerado => electronica
      ? (movimiento.docNumero ?? '').isNotEmpty
      : movimiento.numeroBoleta != null;

  /// "F001-00000012", con ceros como en un talonario de verdad.
  String get numero {
    if (!electronica) {
      return '$serie-'
          '${(movimiento.numeroBoleta ?? 0).toString().padLeft(8, '0')}';
    }
    final doc = _electronico;
    final correlativo = int.tryParse(doc.numero)?.toString() ?? doc.numero;
    return '${doc.serie}-${correlativo.padLeft(8, '0')}';
  }

  /// Como va en el recuadro: "F001 - 00000012".
  String get numeroImpreso => numero.replaceFirst('-', ' - ');

  String get cliente {
    final nombre = (movimiento.contraparte ?? '').trim();
    return nombre.isEmpty ? 'Clientes varios' : nombre;
  }

  String get documentoCliente => (movimiento.documentoContraparte ?? '').trim();

  /// "RUC" con 11 dígitos, "DNI" con 8.
  String get tipoDocumento => documentoCliente.length == 11 ? 'RUC' : 'DNI';

  String get descripcion => movimiento.descripcionFormato;

  /// Valor de venta e IGV. Si el movimiento no está afecto, todo es valor de
  /// venta y el IGV es cero.
  ({int base, int igv}) get desglose => movimiento.tieneIgv
      ? (base: movimiento.baseCentavos, igv: movimiento.igvCentavos)
      : (base: movimiento.centavos, igv: 0);

  /// La suma de los descuentos de las líneas, sin IGV.
  int get descuentos => items.fold(0, (t, i) => t + i.descuento);

  /// Cómo se llama el valor de venta en los totales.
  String get rotuloBase => movimiento.exportacion
      ? 'EXPORTACIÓN'
      : desglose.igv > 0
      ? 'OP. GRAVADA'
      : 'OP. INAFECTA';

  int get total => movimiento.centavos;

  String get montoEnLetras => MontoEnLetras.soles(total);

  String get medioDetallado => medioConDetalle(movimiento);

  /// Tasa que se imprime junto al IGV.
  static int get tasaIgvPorcentaje => (Igv.tasa * 100).round();
}
