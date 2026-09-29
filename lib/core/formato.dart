import 'package:intl/intl.dart';

/// Formatos de moneda y fecha para Perú.
///
/// Todo lo que el usuario lee pasa por aquí, para que "S/ 1,250.00" se escriba
/// igual en el dashboard, en el historial y en los reportes (§5, consistencia).
class Formato {
  /// Los datos de `es_PE` que trae intl escriben el sol como "1.250,50 S/",
  /// con coma decimal y el símbolo al final. En Perú se escribe al revés:
  /// "S/ 1,250.50". Por eso el patrón se fija a mano en vez de confiar en el
  /// locale. El patrón numérico coincide con el de en_US, que es el que usa
  /// punto decimal y coma de miles.
  static final _numero = NumberFormat('#,##0.00', 'en_US');
  static final _dia = DateFormat('dd/MM/yyyy', 'es_PE');
  static final _diaCorto = DateFormat('dd MMM', 'es_PE');
  static final _mes = DateFormat("MMMM 'de' yyyy", 'es_PE');
  static final _mesSolo = DateFormat('MMMM', 'es_PE');
  static final _mesCorto = DateFormat('MMM', 'es_PE');
  static final _hora = DateFormat('HH:mm', 'es_PE');

  /// El signo va antes del símbolo ("−S/ 300.00"), no entre medio.
  static String soles(num monto) {
    final signo = monto < 0 ? '−' : '';
    return '${signo}S/ ${_numero.format(monto.abs())}';
  }

  /// El número sin el símbolo: "1,250.00". Es lo que va en las columnas de los
  /// formatos oficiales, donde la moneda ya la dice el encabezado y repetir
  /// "S/" en cada celda sólo ensucia.
  static String monto(num valor) => _numero.format(valor);

  static String fecha(DateTime d) => _dia.format(d);
  static String fechaCorta(DateTime d) => _diaCorto.format(d);

  /// "1 sep", "28 sep": para el eje de un gráfico, donde no entra más.
  /// intl abrevia septiembre como "sept." y los demás con punto; acá van
  /// todos a tres letras y sin punto, para que las etiquetas midan lo mismo.
  static String diaMes(DateTime d) {
    final mes = _mesCorto.format(d).replaceAll('.', '');
    return '${d.day} ${mes.length > 3 ? mes.substring(0, 3) : mes}';
  }

  /// "50 mil", "1.2 M", "850": los montos del eje de un gráfico, donde
  /// "S/ 50,000.00" no entra y tampoco hace falta tanta precisión.
  static String compacto(num soles) {
    final signo = soles < 0 ? '−' : '';
    final v = soles.abs();
    String corto(num x) =>
        x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1);
    if (v >= 1000000) return '$signo${corto(v / 1000000)} M';
    if (v >= 1000) return '$signo${corto(v / 1000)} mil';
    return '$signo${v.round()}';
  }

  static String mes(DateTime d) => _mes.format(d);

  /// Sólo el nombre del mes: "septiembre".
  static String mesSolo(DateTime d) => _mesSolo.format(d);
  static String mesCorto(DateTime d) => _mesCorto.format(d);
  static String hora(DateTime d) => _hora.format(d);

  /// "septiembre de 2026" → "Septiembre de 2026". intl devuelve los meses en
  /// minúscula, que es lo correcto en medio de una frase pero no como título.
  static String capitalizar(String texto) =>
      texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);

  /// "Hoy" / "Ayer" / "12/09/2025" — lenguaje simple antes que exactitud.
  static String fechaRelativa(DateTime d) {
    final hoy = DateTime.now();
    final soloFecha = DateTime(d.year, d.month, d.day);
    final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final dias = soloHoy.difference(soloFecha).inDays;
    if (dias == 0) return 'Hoy';
    if (dias == 1) return 'Ayer';
    return fecha(d);
  }
}
