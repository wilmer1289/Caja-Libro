import 'banco.dart';
import 'categoria.dart';
import 'efectivo.dart';
import 'enums.dart';

/// Un renglón del libro de caja.
///
/// El monto se guarda en **centavos enteros**, no en decimales. Sumar miles de
/// `double` va acumulando error de redondeo y un libro de caja descuadrado por
/// un céntimo no sirve; en centavos la suma es exacta siempre.
class Movimiento {
  static const _sinCambio = Object();
  const Movimiento({
    required this.id,
    required this.numero,
    required this.tipo,
    required this.centavos,
    required this.categoriaId,
    required this.concepto,
    required this.medio,
    required this.fecha,
    required this.creadoEn,
    required this.actualizadoEn,
    this.cuentaAsociada,
    this.igvCentavos = 0,
    this.contraparte,
    this.documentoContraparte,
    this.numeroTransaccion,
    this.bancoTercero,
    this.vinculo = Vinculo.tercero,
    this.documentoPago = DocumentoPago.factura,
    this.situacion = Situacion.cartera,
    this.numeroRecibo,
    this.numeroBoleta,
    this.tesorero,
    this.detalleEfectivo,
    this.mercaderiaId,
    this.mercaderiaNombre,
    this.costoCentavos,
    this.rutaFoto,
    this.eliminadoEn,
    this.sync = EstadoSync.guardando,
  });

  final String id;

  /// N° DE OPER. del Formato 1.1: correlativo y visible para el usuario. El
  /// `id` es interno y sirve para sincronizar; este es el que se imprime.
  final int numero;

  final Tipo tipo;

  /// El total que de verdad se movió, con IGV incluido si lo hubiera.
  final int centavos;

  final String categoriaId;
  final String concepto;
  final MedioPago medio;

  /// Cuándo ocurrió el movimiento (la elige el usuario).
  final DateTime fecha;

  /// Cuándo se registró y cuándo se tocó por última vez. `actualizadoEn` es lo
  /// que decide quién gana al sincronizar: el último cambio manda (§2.3).
  final DateTime creadoEn;
  final DateTime actualizadoEn;

  /// La cuenta del plan contable que va en el formato oficial. Se guarda por
  /// movimiento —y no se lee sólo de la categoría— porque el contador puede
  /// cambiarla en un caso puntual, y porque si mañana se corrige el catálogo,
  /// lo ya registrado tiene que seguir diciendo lo mismo que se imprimió.
  final String? cuentaAsociada;

  /// Cuánto de `centavos` es IGV. Cero cuando la operación no está afecta.
  final int igvCentavos;

  final String? contraparte;

  /// DNI o RUC de la contraparte: el recibo de caja lo pide.
  final String? documentoContraparte;

  /// N° de la transacción bancaria. Columna obligatoria del Formato 1.2.
  final String? numeroTransaccion;

  /// El banco o la app del otro: "BCP", "Yape". Con él se sabe si una
  /// transferencia fue interbancaria.
  final String? bancoTercero;

  /// Qué es el otro para el negocio. Decide, junto con el documento, la
  /// cuenta del formato (ver `ReglasCuenta`).
  final Vinculo vinculo;

  /// Qué se canceló: una factura o una letra. Sólo se pregunta en el cobro
  /// de un fiado y en el pago a un proveedor.
  final DocumentoPago documentoPago;

  /// Dónde estaba el documento cobrado: en cartera, en cobranza o en
  /// descuento.
  final Situacion situacion;

  /// Correlativo del recibo interno (de ingreso o de egreso). Sólo lo tienen
  /// los movimientos para los que se pidió recibo.
  final int? numeroRecibo;

  /// Correlativo de la boleta de venta de control interno. Lo tienen todas
  /// las ventas: se genera sola al guardar.
  final int? numeroBoleta;

  /// Quién estaba a cargo de la caja cuando se emitió el recibo. Se guarda
  /// con el movimiento y no se lee de los datos del negocio: el responsable
  /// cambia, y un recibo ya firmado tiene que seguir diciendo el mismo nombre.
  final String? tesorero;

  /// Con qué billetes y monedas se pagó y qué vuelto se dio. Opcional.
  final DetalleEfectivo? detalleEfectivo;

  final String? mercaderiaId;

  /// Copia histórica: cambiar el catálogo no modifica los comprobantes emitidos.
  final String? mercaderiaNombre;

  /// null: desconocido; 0 sin tipo: servicio; positivo: costo vendido sin IGV.
  final int? costoCentavos;

  /// El voucher del banco: la foto, la captura o el PDF que prueba la
  /// operación. Es el nombre del archivo dentro del almacén de evidencias, no
  /// una ruta absoluta, para que un respaldo copiado a otro equipo no la
  /// pierda.
  final String? rutaFoto;

  /// Borrado lógico. Nunca se hace DELETE: si un equipo borra y otro todavía
  /// tiene la fila vieja, sin esta marca el registro reaparecería al sincronizar.
  final DateTime? eliminadoEn;

  final EstadoSync sync;

  bool get eliminado => eliminadoEn != null;
  double get monto => centavos / 100;
  Cuenta get cuenta => medio.cuenta;
  Categoria get categoria => Categoria.porId(categoriaId);

  /// El valor de venta, sin impuesto.
  int get baseCentavos => centavos - igvCentavos;
  bool get tieneIgv => igvCentavos > 0;

  bool get enBanco => medio.cuenta == Cuenta.banco;
  bool get tieneVoucher => (rutaFoto ?? '').trim().isNotEmpty;

  /// El ITF que el banco descuenta por esta operación. No va al libro: es
  /// informativo, para que el dueño sepa cuánto se le fue.
  int get itfCentavos => enBanco ? Itf.de(centavos) : 0;

  /// Desde este monto, una operación por banco lleva su voucher adjunto. Es
  /// el mismo tope desde el que la boleta pide el DNI del cliente.
  static const umbralVoucherCentavos = 70000; // S/ 700.00

  bool get exigeVoucher => enBanco && centavos >= umbralVoucherCentavos;

  /// La cuenta que se imprime: la del movimiento si se fijó, y si no la que
  /// trae su categoría.
  String get cuentaDelFormato => cuentaAsociada ?? categoria.cuentaAsociada;

  /// Cómo se describe en el Formato 1.1.
  ///
  /// Manda el detalle que escribió el usuario; si no escribió nada, se arma
  /// con la categoría, igual que el CONCAT del Excel: "Pago de Mercaderías".
  /// Las categorías que ya nombran la acción traen su propia frase, para que
  /// no salga "Pago de Pago a proveedor".
  String get descripcionFormato {
    if (concepto.trim().isNotEmpty) return concepto.trim();
    final detalle = _detalleDelVoucher;
    return detalle.isEmpty ? _descripcionBase : '$_descripcionBase, $detalle';
  }

  /// Lo que agrega el voucher, como en el Excel: "Cobro de fiado, sucursal,
  /// letra en cobranza". Sólo lo que no es lo de siempre: un tercero que paga
  /// una factura en cartera no suma nada.
  String get _detalleDelVoucher {
    final cobro = tipo == Tipo.entro;
    final situacionRara = cobro && situacion != Situacion.cartera;
    final documentoRaro =
        categoria.cancelaDocumento &&
        (documentoPago != DocumentoPago.factura || situacionRara);
    return [
      if (vinculo != Vinculo.tercero) vinculo.enDescripcion,
      if (documentoRaro)
        [
          documentoPago == DocumentoPago.letra ? 'letra' : 'factura',
          if (situacionRara) situacion.etiqueta.toLowerCase(),
        ].join(' '),
    ].join(', ');
  }

  String get _descripcionBase {
    if (mercaderiaNombre != null && mercaderiaNombre!.trim().isNotEmpty) {
      if (categoriaId == Categoria.mercaderia.id) {
        return 'Compra de $mercaderiaNombre';
      }
      if (categoriaId == Categoria.ventas.id) {
        return 'Venta de $mercaderiaNombre';
      }
    }
    final propia = categoria.frase;
    if (propia != null) return propia;
    final verbo = tipo == Tipo.entro ? 'Cobro' : 'Pago';
    return '$verbo de ${categoria.etiqueta}';
  }

  /// Cuánto suma este movimiento al saldo: positivo si entró, negativo si salió.
  int get efectoEnSaldo => tipo == Tipo.entro ? centavos : -centavos;

  /// Umbral de la Ley de Bancarización. Desde este monto, el efectivo no se
  /// acepta: el formulario no deja guardar y el repositorio lo rechaza.
  static const umbralBancarizacionCentavos = 200000; // S/ 2,000.00

  bool get superaUmbralBancarizacion =>
      centavos >= umbralBancarizacionCentavos && medio == MedioPago.efectivo;

  Movimiento copiarCon({
    Tipo? tipo,
    int? centavos,
    String? categoriaId,
    String? concepto,
    MedioPago? medio,
    DateTime? fecha,
    DateTime? actualizadoEn,
    String? cuentaAsociada,
    int? igvCentavos,
    String? contraparte,
    String? documentoContraparte,
    String? numeroTransaccion,
    String? bancoTercero,
    Vinculo? vinculo,
    DocumentoPago? documentoPago,
    Situacion? situacion,
    int? numeroRecibo,
    String? tesorero,
    String? rutaFoto,
    Object? eliminadoEn = _sinCambio,
    Object? mercaderiaId = _sinCambio,
    Object? mercaderiaNombre = _sinCambio,
    Object? costoCentavos = _sinCambio,
    EstadoSync? sync,
  }) {
    return Movimiento(
      id: id,
      numero: numero,
      tipo: tipo ?? this.tipo,
      centavos: centavos ?? this.centavos,
      categoriaId: categoriaId ?? this.categoriaId,
      concepto: concepto ?? this.concepto,
      medio: medio ?? this.medio,
      fecha: fecha ?? this.fecha,
      creadoEn: creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      cuentaAsociada: cuentaAsociada ?? this.cuentaAsociada,
      igvCentavos: igvCentavos ?? this.igvCentavos,
      contraparte: contraparte ?? this.contraparte,
      documentoContraparte: documentoContraparte ?? this.documentoContraparte,
      numeroTransaccion: numeroTransaccion ?? this.numeroTransaccion,
      bancoTercero: bancoTercero ?? this.bancoTercero,
      vinculo: vinculo ?? this.vinculo,
      documentoPago: documentoPago ?? this.documentoPago,
      situacion: situacion ?? this.situacion,
      numeroRecibo: numeroRecibo ?? this.numeroRecibo,
      numeroBoleta: numeroBoleta,
      tesorero: tesorero ?? this.tesorero,
      detalleEfectivo: detalleEfectivo,
      mercaderiaId: identical(mercaderiaId, _sinCambio)
          ? this.mercaderiaId
          : mercaderiaId as String?,
      mercaderiaNombre: identical(mercaderiaNombre, _sinCambio)
          ? this.mercaderiaNombre
          : mercaderiaNombre as String?,
      costoCentavos: identical(costoCentavos, _sinCambio)
          ? this.costoCentavos
          : costoCentavos as int?,
      rutaFoto: rutaFoto ?? this.rutaFoto,
      eliminadoEn: identical(eliminadoEn, _sinCambio)
          ? this.eliminadoEn
          : eliminadoEn as DateTime?,
      sync: sync ?? this.sync,
    );
  }

  Map<String, Object?> aMapa() => {
    'id': id,
    'numero': numero,
    'tipo': tipo.name,
    'centavos': centavos,
    'categoria_id': categoriaId,
    'concepto': concepto,
    'medio': medio.name,
    'cuenta': medio.cuenta.name,
    'fecha': fecha.millisecondsSinceEpoch,
    'creado_en': creadoEn.millisecondsSinceEpoch,
    'actualizado_en': actualizadoEn.millisecondsSinceEpoch,
    'cuenta_asociada': cuentaAsociada,
    'igv_centavos': igvCentavos,
    'contraparte': contraparte,
    'documento_contraparte': documentoContraparte,
    'numero_transaccion': numeroTransaccion,
    'banco_tercero': bancoTercero,
    'vinculo': vinculo.name,
    'documento_pago': documentoPago.name,
    'situacion': situacion.name,
    'numero_recibo': numeroRecibo,
    'numero_boleta': numeroBoleta,
    'tesorero': tesorero,
    'detalle_efectivo': detalleEfectivo?.aTexto(),
    'mercaderia_id': mercaderiaId,
    'mercaderia_nombre': mercaderiaNombre,
    'costo_centavos': costoCentavos,
    'ruta_foto': rutaFoto,
    'eliminado_en': eliminadoEn?.millisecondsSinceEpoch,
    'sync': sync.name,
  };

  factory Movimiento.desdeMapa(Map<String, Object?> m) {
    DateTime fecha(Object? v) => DateTime.fromMillisecondsSinceEpoch(v! as int);

    return Movimiento(
      id: m['id']! as String,
      numero: (m['numero'] as int?) ?? 0,
      tipo: Tipo.desdeBd(m['tipo']! as String),
      centavos: m['centavos']! as int,
      categoriaId: m['categoria_id']! as String,
      concepto: m['concepto']! as String,
      medio: MedioPago.desdeBd(m['medio']! as String),
      fecha: fecha(m['fecha']),
      creadoEn: fecha(m['creado_en']),
      actualizadoEn: fecha(m['actualizado_en']),
      cuentaAsociada: m['cuenta_asociada'] as String?,
      igvCentavos: (m['igv_centavos'] as int?) ?? 0,
      contraparte: m['contraparte'] as String?,
      documentoContraparte: m['documento_contraparte'] as String?,
      numeroTransaccion: m['numero_transaccion'] as String?,
      bancoTercero: m['banco_tercero'] as String?,
      vinculo: Vinculo.desdeBd(m['vinculo'] as String?),
      documentoPago: DocumentoPago.desdeBd(m['documento_pago'] as String?),
      situacion: Situacion.desdeBd(m['situacion'] as String?),
      numeroRecibo: m['numero_recibo'] as int?,
      numeroBoleta: m['numero_boleta'] as int?,
      tesorero: m['tesorero'] as String?,
      detalleEfectivo: DetalleEfectivo.desdeTexto(
        m['detalle_efectivo'] as String?,
      ),
      mercaderiaId: m['mercaderia_id'] as String?,
      mercaderiaNombre: m['mercaderia_nombre'] as String?,
      costoCentavos: m['costo_centavos'] as int?,
      rutaFoto: m['ruta_foto'] as String?,
      eliminadoEn: m['eliminado_en'] == null ? null : fecha(m['eliminado_en']),
      sync: EstadoSync.desdeBd(m['sync']! as String),
    );
  }
}
