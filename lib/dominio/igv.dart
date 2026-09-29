/// El IGV, como lo trata el Excel: la venta se provisiona por el valor de
/// venta más el impuesto, y lo que se mueve en caja es el total.
///
/// Por eso el monto que guarda el movimiento es siempre **el total**, el que
/// de verdad entró o salió del cajón, y el IGV se desagrega hacia adentro.
/// Si se guardara la base y se sumara el impuesto aparte, el saldo del libro
/// dejaría de coincidir con la plata contada a mano.
class Igv {
  /// Tasa vigente en Perú: 18% (16% IGV + 2% IPM).
  static const tasa = 0.18;

  /// Separa un total que ya trae el impuesto adentro.
  ///
  /// El IGV se calcula por diferencia y no con su propia multiplicación, para
  /// que `base + igv` sea **exactamente** el total. Redondeando los dos por
  /// separado, la suma se va de un céntimo y el asiento no cuadra.
  static ({int base, int igv}) desagregar(int totalCentavos) {
    final base = (totalCentavos / (1 + tasa)).round();
    return (base: base, igv: totalCentavos - base);
  }

  /// El camino inverso: a cuánto asciende el total de un valor de venta.
  static int agregar(int baseCentavos) =>
      baseCentavos + (baseCentavos * tasa).round();
}
