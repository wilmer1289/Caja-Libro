import 'dart:math' as math;

import 'linea_kardex.dart';
import 'tablas_sunat.dart';

// `LineaAlmacen` y `OperacionAlmacen` son el contrato del motor del kardex
// (P1) y viven en linea_kardex.dart. Aquí se les agrega lo que necesita la
// base de datos y el registro, sin cambiarlas.
export 'linea_kardex.dart';

/// Las cantidades del almacén van en **milésimas enteras**, igual que la
/// plata va en centavos: 1,600 unidades son 1,600,000 y medio millar es 500.
/// Así un kilo y medio se guarda exacto y las sumas no acumulan error.
class Cantidad {
  Cantidad._();

  static const escala = 1000;

  /// Mil millones de unidades: más de lo que cabe en cualquier almacén.
  static const maxima = 999999999999;

  /// Lee lo que escribe el usuario: "1600", "2.5", "0,125". Hasta 3
  /// decimales. La coma vale como punto decimal, igual que en los montos.
  static int? leer(String texto) {
    final limpio = texto.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(?:\.\d{1,3})?$').hasMatch(limpio)) return null;
    final partes = limpio.split('.');
    final enteras = int.tryParse(partes[0]);
    if (enteras == null || enteras > maxima ~/ escala) return null;
    final decimales = partes.length == 2 ? partes[1].padRight(3, '0') : '000';
    final valor = enteras * escala + int.parse(decimales);
    return valor > maxima ? null : valor;
  }

  /// Para mostrar: "1,600", "0.5", "2.125".
  static String texto(int milesimas) {
    final signo = milesimas < 0 ? '-' : '';
    final valor = milesimas.abs();
    final enteras = (valor ~/ escala).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final decimales = (valor % escala)
        .toString()
        .padLeft(3, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return decimales.isEmpty ? '$signo$enteras' : '$signo$enteras.$decimales';
  }

  static bool esEntera(int milesimas) => milesimas % escala == 0;

  /// Unidades a milésimas. Para las pruebas y los datos fijos.
  static int de(num unidades) => (unidades * escala).round();

  /// Pasa una cantidad en la unidad de compra a la unidad del stock: 10 cajas
  /// de 12 (`factor` 12,000 milésimas) son 120 unidades. Redondea a la
  /// milésima. Null si el resultado no cabe.
  static int? convertir(int cantidad, int factor) {
    if (cantidad <= 0 || factor <= 0) return null;
    if (cantidad > (maxima * escala) ~/ factor) return null;
    final valor = (cantidad * factor + escala ~/ 2) ~/ escala;
    return valor > maxima ? null : valor;
  }
}

/// Lo que la app necesita saber de cada operación del almacén, además de
/// su código de la Tabla 12.
extension OperacionAlmacenDatos on OperacionAlmacen {
  String get etiqueta => switch (this) {
    OperacionAlmacen.venta => 'Venta',
    OperacionAlmacen.compra => 'Compra',
    OperacionAlmacen.devolucionRecibida => 'Devolución de un cliente',
    OperacionAlmacen.devolucionEntregada => 'Devolución a un proveedor',
    OperacionAlmacen.merma => 'Merma',
    OperacionAlmacen.desmedro => 'Desmedro',
    OperacionAlmacen.saldoInicial => 'Saldo inicial',
    OperacionAlmacen.ajuste => 'Ajuste por conteo',
  };

  /// Hacia dónde va: true entra, false sale y null depende (el ajuste por
  /// conteo puede ir para los dos lados).
  bool? get sentido => switch (this) {
    OperacionAlmacen.compra ||
    OperacionAlmacen.devolucionRecibida ||
    OperacionAlmacen.saldoInicial => true,
    OperacionAlmacen.ajuste => null,
    _ => false,
  };

  /// Las compras y las ventas entran por el registro de caja, con su
  /// movimiento. Las demás se anotan sueltas, en el almacén.
  bool get vaPorCaja =>
      this == OperacionAlmacen.venta || this == OperacionAlmacen.compra;

  bool get esDevolucion =>
      this == OperacionAlmacen.devolucionRecibida ||
      this == OperacionAlmacen.devolucionEntregada;

  /// Las que piden escribir por qué se hicieron.
  bool get pideMotivo =>
      this == OperacionAlmacen.merma ||
      this == OperacionAlmacen.desmedro ||
      this == OperacionAlmacen.ajuste;
}

/// Lo que se lee de una línea guardada.
extension LineaAlmacenDatos on LineaAlmacen {
  /// Cuánto suma al saldo en cantidad: positivo si entra, negativo si sale.
  int get efecto => entrada ? cantidad : -cantidad;

  Comprobante? get comprobante => Comprobante.de(docTipo, docSerie, docNumero);

  /// La fila de la tabla `kardex`. `creadoEn` es cuándo se anotó: queda en
  /// la base para auditoría, aunque el motor no lo necesita.
  Map<String, Object?> aMapa({required DateTime creadoEn}) => {
    'id': id,
    'mercaderia_id': mercaderiaId,
    'fecha': fecha.millisecondsSinceEpoch,
    'numero': numero,
    'operacion': operacion.name,
    'entrada': entrada ? 1 : 0,
    'cantidad': cantidad,
    'costo_total': costoTotal,
    'importe': importe,
    'descuento': descuento,
    'movimiento_id': movimientoId,
    'origen_id': origenId,
    'doc_tipo': docTipo,
    'doc_serie': docSerie,
    'doc_numero': docNumero,
    'cuenta_costo': cuentaCosto,
    'glosa': glosa,
    'registrado_por': registradoPor,
    'creado_en': creadoEn.millisecondsSinceEpoch,
  };
}

/// Leer y guardar líneas del almacén.
class LineasAlmacen {
  LineasAlmacen._();

  static OperacionAlmacen operacionDesdeBd(String nombre) {
    for (final o in OperacionAlmacen.values) {
      if (o.name == nombre) return o;
    }
    throw ArgumentError('Operación de almacén desconocida: $nombre');
  }

  /// Una fila de la tabla. Si trae la columna calculada `anulada` (la de su
  /// movimiento), la línea sale marcada.
  static LineaAlmacen desdeMapa(Map<String, Object?> m) => LineaAlmacen(
    id: m['id']! as String,
    mercaderiaId: m['mercaderia_id']! as String,
    fecha: DateTime.fromMillisecondsSinceEpoch(m['fecha']! as int),
    numero: m['numero']! as int,
    operacion: operacionDesdeBd(m['operacion']! as String),
    entrada: m['entrada'] == 1,
    cantidad: m['cantidad']! as int,
    costoTotal: m['costo_total'] as int?,
    importe: m['importe'] as int?,
    descuento: (m['descuento'] as int?) ?? 0,
    movimientoId: m['movimiento_id'] as String?,
    origenId: m['origen_id'] as String?,
    docTipo: m['doc_tipo'] as String?,
    docSerie: m['doc_serie'] as String?,
    docNumero: m['doc_numero'] as String?,
    cuentaCosto: m['cuenta_costo'] as String?,
    registradoPor: m['registrado_por'] as String?,
    glosa: (m['glosa'] as String?) ?? '',
    anulada: m['anulada'] == 1,
  );

  /// La misma línea, marcada como anulada (la de un movimiento anulado).
  static LineaAlmacen anulada(LineaAlmacen l) => LineaAlmacen(
    id: l.id,
    mercaderiaId: l.mercaderiaId,
    fecha: l.fecha,
    numero: l.numero,
    operacion: l.operacion,
    entrada: l.entrada,
    cantidad: l.cantidad,
    costoTotal: l.costoTotal,
    importe: l.importe,
    descuento: l.descuento,
    movimientoId: l.movimientoId,
    origenId: l.origenId,
    docTipo: l.docTipo,
    docSerie: l.docSerie,
    docNumero: l.docNumero,
    cuentaCosto: l.cuentaCosto,
    registradoPor: l.registradoPor,
    glosa: l.glosa,
    anulada: true,
    gastoCompraAsignado: l.gastoCompraAsignado,
  );
}

/// El comprobante que sustenta una operación: tipo de la Tabla 10, serie y
/// número. Una factura FE01-112 es `Comprobante(tipo: '01', serie: 'FE01',
/// numero: '112')`.
class Comprobante {
  const Comprobante({required this.tipo, this.serie = '', this.numero = ''});

  final String tipo;
  final String serie;
  final String numero;

  /// Sin espacios de más y con la serie en mayúsculas, como se imprime.
  Comprobante get limpio => Comprobante(
    tipo: tipo.trim(),
    serie: serie.trim().toUpperCase(),
    numero: numero.trim().toUpperCase(),
  );

  /// Los que tienen el formato fijo de SUNAT: serie de 4 y número de hasta 8.
  bool get formatoSunat => const {
    TablasSunat.factura,
    TablasSunat.boleta,
    TablasSunat.notaDeCredito,
    TablasSunat.notaDeDebito,
  }.contains(tipo);

  /// Qué está mal, o null si se puede guardar.
  String? get problema {
    if (TablasSunat.comprobante(tipo) == null) {
      return 'Elige el tipo de comprobante de la Tabla 10.';
    }
    if (formatoSunat) {
      if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(serie)) {
        return 'La serie tiene 4 letras o números, como F001 o FE01.';
      }
      if (!RegExp(r'^\d{1,8}$').hasMatch(numero)) {
        return 'El número del comprobante va sin letras, hasta 8 dígitos.';
      }
      return null;
    }
    final valido = RegExp(r'^[A-Z0-9-]{0,20}$');
    if (!valido.hasMatch(serie) || !valido.hasMatch(numero)) {
      return 'La serie y el número van con letras, números o guiones, '
          'hasta 20 cada uno.';
    }
    if (tipo != TablasSunat.otros && numero.isEmpty) {
      return 'Escribe el número del comprobante.';
    }
    return null;
  }

  /// "FE01-112", o sólo el número si no tiene serie.
  String get texto {
    if (serie.isEmpty) return numero;
    if (numero.isEmpty) return serie;
    return '$serie-$numero';
  }

  String get nombreTipo => TablasSunat.comprobante(tipo)?.descripcion ?? tipo;

  /// El de una fila de la base: null si no tiene tipo.
  static Comprobante? de(String? tipo, String? serie, String? numero) =>
      tipo == null
      ? null
      : Comprobante(tipo: tipo, serie: serie ?? '', numero: numero ?? '');

  @override
  bool operator ==(Object other) =>
      other is Comprobante &&
      other.tipo == tipo &&
      other.serie == serie &&
      other.numero == numero;

  @override
  int get hashCode => Object.hash(tipo, serie, numero);

  @override
  String toString() => '$tipo $texto';
}

/// Lo que el registro manda por cada producto de una compra o una venta.
///
/// `importe` es el valor sin IGV de esa línea del comprobante, con el
/// descuento ya restado: en una compra, lo que costó; en una venta, el
/// precio. Las líneas suman el valor sin IGV del movimiento.
class LineaNueva {
  const LineaNueva({
    required this.mercaderiaId,
    required this.cantidad,
    required this.importe,
    this.descuento = 0,
    this.enUnidadDeCompra = false,
  });

  final String mercaderiaId;

  /// En milésimas (ver [Cantidad]). En la unidad del stock, o en la de
  /// compra si `enUnidadDeCompra`.
  final int cantidad;

  /// En centavos, sin IGV y ya con el descuento restado.
  final int importe;

  /// En centavos, sin IGV. Ya está restado del importe: se guarda para que
  /// la factura lo muestre.
  final int descuento;

  /// Sólo en compras: la cantidad va en la unidad de compra del producto (10
  /// cajas) y al inventario entra en la del stock (120 unidades).
  final bool enUnidadDeCompra;

  /// La misma línea con la cantidad ya en la unidad del stock.
  LineaNueva enStock(int cantidadEnStock) => LineaNueva(
    mercaderiaId: mercaderiaId,
    cantidad: cantidadEnStock,
    importe: importe,
    descuento: descuento,
  );
}

/// Un producto que se queda corto: cuánto se podía sacar, y el día en que
/// el saldo quedaría en negativo.
class Faltante {
  const Faltante(this.mercaderiaId, this.disponible, {required this.cuando});
  final String mercaderiaId;
  final int disponible;
  final DateTime cuando;
}

/// El saldo en **cantidad** de cada producto. No sabe de costos: eso es del
/// kardex. Sirve para no dejar que algo salga del almacén sin haber entrado.
/// Las líneas anuladas no cuentan.
class StockAlmacen {
  StockAlmacen._();

  static DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

  /// El orden del kardex: por día y, dentro del día, por número. Se ordena
  /// por día y no por hora porque una fecha elegida en el calendario queda a
  /// medianoche, y una venta así no puede quedar antes de la compra de esa
  /// misma mañana.
  static int comparar(LineaAlmacen a, LineaAlmacen b) {
    final dia = _dia(a.fecha).compareTo(_dia(b.fecha));
    return dia != 0 ? dia : a.numero.compareTo(b.numero);
  }

  static List<LineaAlmacen> ordenadas(Iterable<LineaAlmacen> lineas) =>
      lineas.where((l) => !l.anulada).toList()..sort(comparar);

  /// Lo que hay de un producto al cierre del día `al`, o al final de todo.
  static int saldo(
    Iterable<LineaAlmacen> lineas,
    String mercaderiaId, {
    DateTime? al,
  }) {
    final corte = al == null ? null : _dia(al);
    var total = 0;
    for (final l in lineas) {
      if (l.anulada || l.mercaderiaId != mercaderiaId) continue;
      if (corte != null && _dia(l.fecha).isAfter(corte)) continue;
      total += l.efecto;
    }
    return total;
  }

  /// Cuánto puede salir el día `fecha` sin que el saldo quede en negativo,
  /// ni ese día ni después. Lo que se anota hoy va después de todo lo de hoy,
  /// pero si es con fecha pasada, las ventas que vinieron después también
  /// tienen que seguir teniendo de dónde salir.
  static int disponible(
    Iterable<LineaAlmacen> lineas,
    String mercaderiaId,
    DateTime fecha,
  ) {
    final corte = _dia(fecha);
    final propias = ordenadas(
      lineas.where((l) => l.mercaderiaId == mercaderiaId),
    );
    var saldo = 0;
    var minimo = 0;
    var pasado = false;
    for (final l in propias) {
      if (!pasado && _dia(l.fecha).isAfter(corte)) {
        pasado = true;
        minimo = saldo;
      }
      saldo += l.efecto;
      if (pasado) minimo = math.min(minimo, saldo);
    }
    if (!pasado) minimo = saldo;
    return math.max(0, minimo);
  }

  /// El primer producto que, con las líneas nuevas, queda en negativo en
  /// algún momento. Null si todo alcanza.
  ///
  /// `tambien` son productos que hay que revisar aunque no salgan en las
  /// líneas nuevas: los de una operación que se anula, porque sin su compra
  /// las ventas de después pueden quedarse sin stock.
  static Faltante? faltante(
    Iterable<LineaAlmacen> existentes,
    Iterable<LineaAlmacen> nuevas, {
    Iterable<String> tambien = const [],
  }) {
    final productos = {
      for (final l in nuevas)
        if (!l.entrada) l.mercaderiaId,
      ...tambien,
    };
    for (final id in productos) {
      final nuevasDelProducto = ordenadas(
        nuevas.where((l) => l.mercaderiaId == id),
      );
      final todas = ordenadas([
        ...existentes.where((l) => l.mercaderiaId == id),
        ...nuevasDelProducto,
      ]);
      var saldo = 0;
      for (final l in todas) {
        saldo += l.efecto;
        if (saldo < 0) {
          final desde = nuevasDelProducto.isEmpty
              ? l.fecha
              : nuevasDelProducto.first.fecha;
          return Faltante(
            id,
            disponible(existentes, id, desde),
            cuando: _dia(l.fecha),
          );
        }
      }
    }
    return null;
  }

  /// El último día con algo anotado de un producto. Si se registra con una
  /// fecha anterior, cambian los costos de lo que vino después, y la app lo
  /// avisa.
  static DateTime? ultimaFecha(
    Iterable<LineaAlmacen> lineas,
    String mercaderiaId,
  ) {
    DateTime? ultima;
    for (final l in lineas) {
      if (l.anulada || l.mercaderiaId != mercaderiaId) continue;
      final dia = _dia(l.fecha);
      if (ultima == null || dia.isAfter(ultima)) ultima = dia;
    }
    return ultima;
  }
}
