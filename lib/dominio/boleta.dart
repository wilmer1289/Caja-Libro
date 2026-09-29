import 'categoria.dart';
import 'enums.dart';
import 'igv.dart';
import 'monto_en_letras.dart';
import 'movimiento.dart';
import 'negocio.dart';
import 'recibo.dart';

/// La boleta de venta de control interno.
///
/// No es un comprobante de pago de SUNAT ni pretende serlo: no se envía a
/// ningún lado y no tiene serie autorizada. Es el papel que el negocio le da
/// al cliente —impreso o en PDF— y que le sirve para su propio control. Por
/// eso la palabra "control interno" va impresa en ella.
///
/// La tienen todas las ventas (y los adelantos de cliente): se numera sola al
/// guardar. Imprimirla es opcional.
class Boleta {
  const Boleta({required this.negocio, required this.movimiento});

  final Negocio negocio;
  final Movimiento movimiento;

  /// Desde este monto, la boleta lleva el nombre y el documento del cliente.
  /// Por debajo es opcional y sale "Clientes varios".
  static const umbralIdentificacionCentavos = 70000; // S/ 700.00

  static const serie = 'B001';

  /// Qué movimientos llevan boleta.
  static bool corresponde(Categoria categoria) =>
      categoria.tipo == Tipo.entro &&
      (categoria.id == Categoria.ventas.id ||
          categoria.id == Categoria.anticipos.id);

  static bool exigeCliente(int centavos) =>
      centavos >= umbralIdentificacionCentavos;

  /// "B001-00000012", con ceros como en un talonario de verdad.
  String get numero =>
      '$serie-${(movimiento.numeroBoleta ?? 0).toString().padLeft(8, '0')}';

  /// Como va en el recuadro de la boleta: "B001 - 00000012".
  String get numeroImpreso => numero.replaceFirst('-', ' - ');

  String get cliente {
    final nombre = (movimiento.contraparte ?? '').trim();
    return nombre.isEmpty ? 'Clientes varios' : nombre;
  }

  String get documentoCliente => (movimiento.documentoContraparte ?? '').trim();

  /// "DNI" u "RUC" según el largo del número.
  String get tipoDocumento => documentoCliente.length == 11 ? 'RUC' : 'DNI';

  String get descripcion => movimiento.descripcionFormato;

  /// Valor de venta e IGV. Si el movimiento no está afecto, todo es valor de
  /// venta y el IGV es cero.
  ({int base, int igv}) get desglose => movimiento.tieneIgv
      ? (base: movimiento.baseCentavos, igv: movimiento.igvCentavos)
      : (base: movimiento.centavos, igv: 0);

  int get total => movimiento.centavos;

  String get montoEnLetras => MontoEnLetras.soles(total);

  String get medioDetallado => medioConDetalle(movimiento);

  /// Tasa que se imprime junto al IGV.
  static int get tasaIgvPorcentaje => (Igv.tasa * 100).round();
}
