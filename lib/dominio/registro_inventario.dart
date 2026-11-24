import 'kardex.dart';
import 'mercaderia.dart';
import 'negocio.dart';
import 'tablas_sunat.dart';

/// Una fila del Formato 13.1 (y del 12.1, que es el mismo sin costos).
///
/// Sale de una fila del kardex de P1. El saldo inicial (operación 16) va
/// sólo en las columnas del saldo: no es una entrada del período, y así las
/// entradas suman lo que de verdad entró.
class FilaRegistro {
  const FilaRegistro({
    required this.fecha,
    required this.tipoDocumento,
    required this.serie,
    required this.numero,
    required this.operacion,
    required this.saldoCantidad,
    required this.saldoCosto,
    this.entradaCantidad,
    this.entradaCosto,
    this.salidaCantidad,
    this.salidaCosto,
    this.fila,
    this.glosa = '',
  });

  final DateTime fecha;

  /// Tipo de la Tabla 10: 01 factura, 03 boleta, 00 otros.
  final String tipoDocumento;
  final String serie;
  final String numero;

  /// Código de la Tabla 12: 01 venta, 02 compra, 16 saldo inicial…
  final String operacion;

  /// En milésimas y centavos; null si la fila no tiene esa columna.
  final int? entradaCantidad;
  final int? entradaCosto;
  final int? salidaCantidad;
  final int? salidaCosto;
  final int saldoCantidad;
  final int saldoCosto;

  /// La fila del kardex de donde salió. Null en el saldo que se arrastra del
  /// período anterior.
  final FilaKardex? fila;

  /// El motivo de una merma o un ajuste.
  final String glosa;

  bool get esSaldoInicial =>
      operacion == OperacionAlmacen.saldoInicial.codigo;

  /// Si es el saldo que viene del período anterior.
  bool get arrastrado => fila == null;

  String get nombreOperacion =>
      TablasSunat.operacion(operacion)?.descripcion ?? operacion;

  static double? _unitario(int? costo, int? cantidad) =>
      costo == null || cantidad == null || cantidad == 0
      ? null
      : costo / cantidad * 10;

  /// En soles por unidad.
  double? get entradaUnitario => _unitario(entradaCosto, entradaCantidad);
  double? get salidaUnitario => _unitario(salidaCosto, salidaCantidad);
  double? get saldoUnitario => _unitario(saldoCosto, saldoCantidad);
}

/// El Formato 13.1 de un producto en un período: el encabezado de SUNAT y
/// las filas con sus totales. De aquí leen la pantalla, el PDF y el CSV.
class RegistroInventario {
  const RegistroInventario._({
    required this.negocio,
    required this.producto,
    required this.desde,
    required this.hasta,
    required this.filas,
  });

  final Negocio negocio;
  final Mercaderia producto;
  final DateTime desde;
  final DateTime hasta;
  final List<FilaRegistro> filas;

  static DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

  /// Arma el registro de un producto entre dos días, inclusive.
  ///
  /// Si el producto ya tenía saldo antes de `desde`, la primera fila es ese
  /// saldo, como saldo inicial del período (operación 16).
  factory RegistroInventario.de(
    Kardex kardex, {
    required Negocio negocio,
    required Mercaderia producto,
    required DateTime desde,
    required DateTime hasta,
  }) {
    final inicio = _dia(desde);
    final fin = _dia(hasta);
    final previo = kardex.saldo(
      producto.id,
      al: inicio.subtract(const Duration(days: 1)),
    );
    final filas = <FilaRegistro>[];
    if (previo.cantidad != 0 || previo.costo != 0) {
      filas.add(
        FilaRegistro(
          fecha: inicio,
          tipoDocumento: TablasSunat.otros,
          serie: '',
          numero: '',
          operacion: OperacionAlmacen.saldoInicial.codigo,
          saldoCantidad: previo.cantidad,
          saldoCosto: previo.costo,
        ),
      );
    }
    for (final f in kardex.filas(producto.id)) {
      final dia = _dia(f.linea.fecha);
      if (dia.isBefore(inicio) || dia.isAfter(fin)) continue;
      final l = f.linea;
      final inicial = l.operacion == OperacionAlmacen.saldoInicial;
      filas.add(
        FilaRegistro(
          fecha: l.fecha,
          tipoDocumento: l.docTipo ?? TablasSunat.otros,
          serie: l.docSerie ?? '',
          numero: l.docNumero ?? '',
          operacion: l.operacion.codigo,
          entradaCantidad: l.entrada && !inicial ? l.cantidad : null,
          entradaCosto: l.entrada && !inicial ? f.costoTotal : null,
          salidaCantidad: l.entrada ? null : l.cantidad,
          salidaCosto: l.entrada ? null : f.costoTotal,
          saldoCantidad: f.saldoCantidad,
          saldoCosto: f.saldoCosto,
          fila: f,
          glosa: l.glosa,
        ),
      );
    }
    return RegistroInventario._(
      negocio: negocio,
      producto: producto,
      desde: inicio,
      hasta: fin,
      filas: filas,
    );
  }

  /// El registro de cada producto, en orden de código. Los que no tienen
  /// nada en el período (ni saldo que arrastrar) no salen.
  static List<RegistroInventario> deTodos(
    Kardex kardex, {
    required Negocio negocio,
    required List<Mercaderia> productos,
    required DateTime desde,
    required DateTime hasta,
  }) => [
    for (final p in List.of(productos)
      ..sort((a, b) => a.codigo.compareTo(b.codigo)))
      RegistroInventario.de(
        kardex,
        negocio: negocio,
        producto: p,
        desde: desde,
        hasta: hasta,
      ),
  ].where((r) => r.filas.isNotEmpty).toList();

  bool get vacio => filas.isEmpty;

  int get entradasCantidad =>
      filas.fold(0, (t, f) => t + (f.entradaCantidad ?? 0));
  int get entradasCosto => filas.fold(0, (t, f) => t + (f.entradaCosto ?? 0));
  int get salidasCantidad =>
      filas.fold(0, (t, f) => t + (f.salidaCantidad ?? 0));
  int get salidasCosto => filas.fold(0, (t, f) => t + (f.salidaCosto ?? 0));

  /// El saldo con que empezó el período: su fila de saldo inicial, si la
  /// hay. Sólo puede ser la primera: un saldo inicial va antes de todo.
  FilaRegistro? get _inicial =>
      filas.isNotEmpty && filas.first.esSaldoInicial ? filas.first : null;
  int get inicialCantidad => _inicial?.saldoCantidad ?? 0;
  int get inicialCosto => _inicial?.saldoCosto ?? 0;

  int get saldoFinalCantidad => filas.isEmpty ? 0 : filas.last.saldoCantidad;
  int get saldoFinalCosto => filas.isEmpty ? 0 : filas.last.saldoCosto;

  /// "OCTUBRE 2026" si es un mes entero; si no, "01/10/2026 AL 15/10/2026".
  String get periodo {
    final mesEntero =
        desde.day == 1 &&
        desde.year == hasta.year &&
        desde.month == hasta.month &&
        DateTime(hasta.year, hasta.month, hasta.day + 1).month != hasta.month;
    if (mesEntero) return '${_meses[desde.month - 1]} ${desde.year}';
    return '${_fecha(desde)} AL ${_fecha(hasta)}';
  }

  static String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static const _meses = [
    'ENERO',
    'FEBRERO',
    'MARZO',
    'ABRIL',
    'MAYO',
    'JUNIO',
    'JULIO',
    'AGOSTO',
    'SETIEMBRE',
    'OCTUBRE',
    'NOVIEMBRE',
    'DICIEMBRE',
  ];

  /// El encabezado del formato, como en la plantilla de SUNAT. `valorizado`
  /// separa el 13.1 del 12.1, que no lleva el método de valuación.
  List<(String, String)> encabezado({bool valorizado = true}) => [
    ('PERÍODO', periodo),
    ('RUC', negocio.documento),
    (
      'APELLIDOS Y NOMBRES, DENOMINACIÓN O RAZÓN SOCIAL',
      negocio.razonSocial,
    ),
    ('ESTABLECIMIENTO (1)', negocio.direccion),
    ('CÓDIGO DE LA EXISTENCIA', producto.codigo),
    (
      'TIPO (TABLA 5)',
      '${producto.tipoExistencia} '
          '${TablasSunat.tipoExistencia(producto.tipoExistencia)?.descripcion ?? ''}'
          .trim(),
    ),
    ('DESCRIPCIÓN', producto.nombre),
    (
      'CÓDIGO DE LA UNIDAD DE MEDIDA (TABLA 6)',
      '${producto.unidad} '
          '${TablasSunat.unidad(producto.unidad)?.descripcion ?? ''}'
          .trim(),
    ),
    if (valorizado)
      ('MÉTODO DE VALUACIÓN', negocio.metodoValuacion.etiqueta.toUpperCase()),
  ];

  static const titulo131 =
      'FORMATO 13.1: REGISTRO DE INVENTARIO PERMANENTE VALORIZADO - '
      'DETALLE DEL INVENTARIO VALORIZADO';
  static const titulo121 =
      'FORMATO 12.1: REGISTRO DEL INVENTARIO PERMANENTE EN UNIDADES FÍSICAS - '
      'DETALLE DEL INVENTARIO PERMANENTE EN UNIDADES FÍSICAS';

  /// Un costo unitario con hasta 4 decimales y al menos 2: 51.60, 49.1495.
  static String unitario(double? soles) {
    if (soles == null) return '';
    var texto = soles.toStringAsFixed(4);
    while (texto.endsWith('0') && texto.split('.')[1].length > 2) {
      texto = texto.substring(0, texto.length - 1);
    }
    return texto;
  }
}
