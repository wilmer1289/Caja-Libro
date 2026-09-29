import 'pcge.dart';

/// El movimiento entra o sale. En toda la UI se dice "Entró" / "Salió",
/// nunca "Deudor" / "Acreedor" (§1, lenguaje simple).
///
/// Los formatos oficiales 1.1 y 1.2 **sí** están obligados a decir DEUDOR y
/// ACREEDOR, así que esos nombres viven acá y salen sólo en el documento
/// exportado, nunca en la pantalla del dueño.
enum Tipo {
  entro('Entró', '↑', 'DEUDOR (+)'),
  salio('Salió', '↓', 'ACREEDOR (-)');

  const Tipo(this.etiqueta, this.flecha, this.columnaFormato);
  final String etiqueta;
  final String flecha;

  /// Cómo se llama su columna en el Formato 1.1 / 1.2.
  final String columnaFormato;

  static Tipo desdeBd(String v) =>
      values.firstWhere((t) => t.name == v, orElse: () => Tipo.entro);
}

/// Cómo se movió la plata.
///
/// Cada uno lleva su **código de la Tabla 1 de SUNAT**, que es una columna
/// obligatoria del Formato 1.2. Los códigos salen de la hoja T1 del Excel.
enum MedioPago {
  efectivo('Efectivo', Cuenta.caja, '008'),
  yape('Yape / Plin', Cuenta.banco, '003'),
  transferencia('Transferencia', Cuenta.banco, '003'),
  deposito('Depósito en cuenta', Cuenta.banco, '001'),
  tarjeta('Tarjeta de débito', Cuenta.banco, '005'),
  tarjetaCredito('Tarjeta de crédito', Cuenta.banco, '006'),
  cheque('Cheque no negociable', Cuenta.banco, '007'),
  otro('Otro medio', Cuenta.banco, '999');

  const MedioPago(this.etiqueta, this.cuenta, this.codigoTabla1);
  final String etiqueta;
  final Cuenta cuenta;

  /// Código de la Tabla 1 de SUNAT (hoja T1 del Excel).
  final String codigoTabla1;

  /// Los que se ofrecen al registrar y en los filtros: cubren todo lo que
  /// usa un negocio. Cheque y "otro medio" siguen existiendo sólo para leer
  /// movimientos viejos que los usaron; ya no se ofrecen, porque un menú
  /// "Otro" para dos casos que nadie usaba era un paso de más.
  static const disponibles = [
    efectivo,
    yape,
    transferencia,
    deposito,
    tarjeta,
    tarjetaCredito,
  ];

  /// Tolerante a propósito: un valor viejo o desconocido en la base no debe
  /// tumbar la pantalla del historial.
  static MedioPago desdeBd(String v) =>
      values.firstWhere((m) => m.name == v, orElse: () => MedioPago.efectivo);
}

/// Los dos bolsillos del negocio (§4.2). Cada uno lleva su propio saldo y su
/// propia cuenta del plan contable, que es la que va en los formatos.
enum Cuenta {
  caja('Caja (efectivo)', Pcge.caja, 'FORMATO 1.1'),
  banco('Banco / Digital', Pcge.cuentaCorriente, 'FORMATO 1.2');

  const Cuenta(this.etiqueta, this.codigoPcge, this.formato);
  final String etiqueta;

  /// 101 para Caja, 1041 para Cuentas corrientes operativas.
  final String codigoPcge;

  /// Qué formato oficial le corresponde.
  final String formato;

  static Cuenta desdeBd(String v) =>
      values.firstWhere((c) => c.name == v, orElse: () => Cuenta.caja);
}

/// Qué tan lejos llegó el dato (§5, indicador de sincronización).
enum EstadoSync {
  guardando('Guardando…'),
  local('Guardado en tu equipo'),
  respaldado('Respaldado');

  const EstadoSync(this.etiqueta);
  final String etiqueta;

  static EstadoSync desdeBd(String v) =>
      values.firstWhere((e) => e.name == v, orElse: () => EstadoSync.local);
}
