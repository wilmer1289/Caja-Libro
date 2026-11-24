/// Un mes cerrado: desde que se cierra, nada se registra con su fecha, ni en
/// caja ni en el inventario. Así el Formato 13.1 que ya se entregó no cambia
/// por un costo recalculado.
///
/// Cerrar un mes deja cerrados también los anteriores: si octubre está
/// cerrado, una compra con fecha de septiembre cambiaría el costo promedio
/// de octubre. Por eso basta con mirar el último mes cerrado.
class CierreMes {
  const CierreMes({
    required this.anio,
    required this.mes,
    required this.cerradoEn,
    this.cerradoPor = '',
  });

  final int anio;

  /// De 1 (enero) a 12 (diciembre).
  final int mes;
  final DateTime cerradoEn;
  final String cerradoPor;

  /// Para comparar meses: 2026 × 12 + 10.
  int get clave => anio * 12 + mes;

  static int claveDe(DateTime fecha) => fecha.year * 12 + fecha.month;

  /// "octubre de 2026".
  String get nombre => nombreDe(anio, mes);

  static String nombreDe(int anio, int mes) => '${_meses[mes - 1]} de $anio';

  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// El último mes cerrado, o null si no se cerró ninguno.
  static CierreMes? ultimo(Iterable<CierreMes> cierres) {
    CierreMes? ultimo;
    for (final c in cierres) {
      if (ultimo == null || c.clave > ultimo.clave) ultimo = c;
    }
    return ultimo;
  }

  /// Si la fecha cae en un mes cerrado: el último o uno anterior.
  static bool cerrado(Iterable<CierreMes> cierres, DateTime fecha) {
    final u = ultimo(cierres);
    return u != null && claveDe(fecha) <= u.clave;
  }

  /// El motivo por el que no se puede registrar con esa fecha, o null.
  static String? problemaCon(Iterable<CierreMes> cierres, DateTime fecha) {
    if (!cerrado(cierres, fecha)) return null;
    final u = ultimo(cierres)!;
    return 'El mes de ${nombreDe(fecha.year, fecha.month)} está cerrado '
        '(se cerró hasta ${u.nombre}): ya no se registra nada con esa fecha.';
  }

  /// Qué impide cerrar ese mes hoy, o null si se puede.
  ///
  /// Sólo se cierra un mes que ya terminó y que va después del último
  /// cerrado. No se reabre: lo que se entregó queda como se entregó.
  static String? problemaAlCerrar(
    Iterable<CierreMes> cierres,
    int anio,
    int mes, {
    required DateTime hoy,
  }) {
    if (mes < 1 || mes > 12) return 'El mes no es válido.';
    if (hoy.isBefore(DateTime(anio, mes + 1))) {
      return 'El mes de ${nombreDe(anio, mes)} todavía no termina: se '
          'cierra desde el primer día del mes siguiente.';
    }
    final u = ultimo(cierres);
    if (u != null && anio * 12 + mes <= u.clave) {
      return 'El mes de ${nombreDe(anio, mes)} ya está cerrado (se cerró '
          'hasta ${u.nombre}).';
    }
    return null;
  }

  Map<String, Object?> aMapa() => {
    'anio': anio,
    'mes': mes,
    'cerrado_en': cerradoEn.millisecondsSinceEpoch,
    'cerrado_por': cerradoPor,
  };

  factory CierreMes.desdeMapa(Map<String, Object?> m) => CierreMes(
    anio: m['anio']! as int,
    mes: m['mes']! as int,
    cerradoEn: DateTime.fromMillisecondsSinceEpoch(m['cerrado_en']! as int),
    cerradoPor: (m['cerrado_por'] as String?) ?? '',
  );
}
