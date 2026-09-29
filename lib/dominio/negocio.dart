/// Los datos del negocio y los saldos con que abre el libro.
///
/// Son los de la hoja DATOS del Excel, más los del encabezado de los formatos
/// oficiales:
///
/// - El **Formato 1.1** pide PERÍODO, RUC y razón social.
/// - El **Formato 1.2** pide además la entidad financiera y el código de la
///   cuenta corriente.
///
/// El saldo inicial no es un detalle: la primera línea del Formato 1.1 es
/// justamente el saldo con que arranca el período. Sin él, el libro empieza
/// en cero y ningún negocio de verdad empieza en cero.
class Negocio {
  const Negocio({
    this.razonSocial = '',
    this.documento = '',
    this.direccion = '',
    this.entidadFinanciera = '',
    this.cuentaCorriente = '',
    this.saldoInicialCaja = 0,
    this.saldoInicialBanco = 0,
    this.inicioPeriodo,
    this.tesorero = '',
  });

  /// "LIBERTAD SA", o el nombre de la bodega.
  final String razonSocial;

  /// RUC de la empresa o DNI de la persona.
  final String documento;

  final String direccion;

  /// Para el Formato 1.2: "BBVA".
  final String entidadFinanciera;
  final String cuentaCorriente;

  /// Con cuánto abre el período, en centavos.
  final int saldoInicialCaja;
  final int saldoInicialBanco;

  /// Primer día del período que cubre el libro. Null mientras no se configuró.
  final DateTime? inicioPeriodo;

  /// Quién está a cargo de la caja: sale en cada recibo y en el acta de
  /// arqueo. Es el valor de arranque; en cada recibo se puede cambiar.
  final String tesorero;

  static const vacio = Negocio();

  /// Con esto alcanza para emitir el Formato 1.1 y los recibos.
  bool get completo =>
      razonSocial.trim().isNotEmpty &&
      documento.trim().isNotEmpty &&
      inicioPeriodo != null;

  /// El 1.2 pide dos datos más que el 1.1.
  bool get completoParaBanco =>
      completo &&
      entidadFinanciera.trim().isNotEmpty &&
      cuentaCorriente.trim().isNotEmpty;

  int saldoInicialDe(bool esCaja) =>
      esCaja ? saldoInicialCaja : saldoInicialBanco;

  Negocio copiarCon({
    String? razonSocial,
    String? documento,
    String? direccion,
    String? entidadFinanciera,
    String? cuentaCorriente,
    int? saldoInicialCaja,
    int? saldoInicialBanco,
    DateTime? inicioPeriodo,
    String? tesorero,
  }) {
    return Negocio(
      razonSocial: razonSocial ?? this.razonSocial,
      documento: documento ?? this.documento,
      direccion: direccion ?? this.direccion,
      entidadFinanciera: entidadFinanciera ?? this.entidadFinanciera,
      cuentaCorriente: cuentaCorriente ?? this.cuentaCorriente,
      saldoInicialCaja: saldoInicialCaja ?? this.saldoInicialCaja,
      saldoInicialBanco: saldoInicialBanco ?? this.saldoInicialBanco,
      inicioPeriodo: inicioPeriodo ?? this.inicioPeriodo,
      tesorero: tesorero ?? this.tesorero,
    );
  }

  Map<String, Object?> aMapa() => {
    'id': 1,
    'razon_social': razonSocial,
    'documento': documento,
    'direccion': direccion,
    'entidad_financiera': entidadFinanciera,
    'cuenta_corriente': cuentaCorriente,
    'saldo_inicial_caja': saldoInicialCaja,
    'saldo_inicial_banco': saldoInicialBanco,
    'inicio_periodo': inicioPeriodo?.millisecondsSinceEpoch,
    'tesorero': tesorero,
  };

  factory Negocio.desdeMapa(Map<String, Object?> m) => Negocio(
    razonSocial: (m['razon_social'] as String?) ?? '',
    documento: (m['documento'] as String?) ?? '',
    direccion: (m['direccion'] as String?) ?? '',
    entidadFinanciera: (m['entidad_financiera'] as String?) ?? '',
    cuentaCorriente: (m['cuenta_corriente'] as String?) ?? '',
    saldoInicialCaja: (m['saldo_inicial_caja'] as int?) ?? 0,
    saldoInicialBanco: (m['saldo_inicial_banco'] as int?) ?? 0,
    inicioPeriodo: m['inicio_periodo'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['inicio_periodo']! as int),
    tesorero: (m['tesorero'] as String?) ?? '',
  );
}
