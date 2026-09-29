import '../core/formato.dart';
import 'enums.dart';
import 'monto_en_letras.dart';
import 'movimiento.dart';
import 'negocio.dart';

/// El recibo de caja, como las hojas INGRESOS CAJA y EGRESOS CAJA del Excel.
///
/// Es el comprobante interno del movimiento: quién entregó o recibió la plata,
/// cuánto, por qué concepto y con qué medio de pago, con el importe repetido en
/// letras y dos firmas. En una bodega es el papel que queda en el talonario;
/// en una empresa es lo que sustenta el asiento cuando no hay factura.
///
/// Se emite sólo si se pide al registrar (o después, desde el historial): no
/// todo movimiento necesita un papel firmado. Sirve también para una venta,
/// cuando además de la boleta se quiere la firma de quien pagó.
class Recibo {
  const Recibo({required this.negocio, required this.movimiento});

  final Negocio negocio;
  final Movimiento movimiento;

  bool get esIngreso => movimiento.tipo == Tipo.entro;

  String get titulo =>
      esIngreso ? 'RECIBO DE INGRESO DE CAJA' : 'RECIBO DE EGRESO DE CAJA';

  /// El correlativo del talonario, con ceros a la izquierda: los recibos de
  /// papel vienen numerados así, y ayuda a ver de un vistazo si falta uno.
  String get numero =>
      (movimiento.numeroRecibo ?? 0).toString().padLeft(6, '0');

  /// En el recibo de ingreso lo firma quien cobra; en el de egreso, quien
  /// recibe el pago. Por eso cambia hasta el verbo.
  String get lineaConformidad => esIngreso
      ? 'Recibí conforme del señor(a):'
      : 'Recibió conforme el señor(a):';

  /// El rol con que firma la contraparte, al pie.
  String get rolContraparte => esIngreso ? 'Ingresante' : 'Egresante';

  String get montoEnLetras => MontoEnLetras.soles(movimiento.centavos);

  String get concepto => movimiento.descripcionFormato;

  /// Quién firma por la caja: el que quedó guardado con el recibo, y si el
  /// recibo es anterior a eso, el responsable actual del negocio.
  String get tesorero {
    final propio = (movimiento.tesorero ?? '').trim();
    return propio.isNotEmpty ? propio : negocio.tesorero.trim();
  }

  /// "Efectivo · Pagó con S/ 110.00 · Vuelto S/ 7.60".
  String get medioDetallado => medioConDetalle(movimiento);

  /// Un recibo sin nombre y sin documento no sustenta nada. No se bloquea la
  /// impresión —el dueño de la bodega muchas veces no lo tiene a mano—, pero
  /// la pantalla lo avisa.
  bool get identificaContraparte =>
      (movimiento.contraparte ?? '').trim().isNotEmpty;

  /// Se puede emitir: hay número y hay datos del negocio en el encabezado.
  bool get emitible => movimiento.numeroRecibo != null && negocio.completo;
}

/// El medio de pago con el detalle del efectivo, si se anotó.
String medioConDetalle(Movimiento m) {
  final d = m.detalleEfectivo;
  if (d == null) return m.medio.etiqueta;
  final entro = m.tipo == Tipo.entro;
  return [
    m.medio.etiqueta,
    '${entro ? 'Pagó con' : 'Se entregó'} ${Formato.soles(d.entregado.total / 100)}',
    if (d.vuelto.total > 0) 'Vuelto ${Formato.soles(d.vuelto.total / 100)}',
  ].join(' · ');
}
