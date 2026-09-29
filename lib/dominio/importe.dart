/// Convierte moneda decimal a céntimos sin redondeos de coma flotante.
class Importe {
  static const maximoCentavos = 99999999999;

  static int? leer(String texto, {bool permitirNegativo = false}) {
    final limpio = texto.trim().replaceAll(',', '.');
    final patron = permitirNegativo
        ? RegExp(r'^-?\d+(?:\.\d{1,2})?$')
        : RegExp(r'^\d+(?:\.\d{1,2})?$');
    if (!patron.hasMatch(limpio)) return null;
    final negativo = limpio.startsWith('-');
    final partes = limpio.replaceFirst('-', '').split('.');
    final soles = int.tryParse(partes[0]);
    if (soles == null || soles > maximoCentavos ~/ 100) return null;
    final decimales = partes.length == 2 ? partes[1].padRight(2, '0') : '00';
    final centavos = soles * 100 + int.parse(decimales);
    if (centavos > maximoCentavos) return null;
    return negativo ? -centavos : centavos;
  }
}
