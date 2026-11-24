import 'almacen.dart';
import 'tablas_sunat.dart';

/// Un producto del inventario. En pantalla se llama "producto"; la clase
/// sigue llamándose así para no romper lo que ya la usa.
///
/// No guarda su stock ni su costo: los dos salen del kardex, repasando las
/// líneas del almacén. Así no hay dos lugares que puedan decir cosas
/// distintas.
class Mercaderia {
  const Mercaderia({
    required this.id,
    required this.nombre,
    required this.creadoEn,
    this.codigo = '',
    this.tipoExistencia = TablasSunat.mercaderia,
    this.unidad = TablasSunat.unidadesSueltas,
    this.stockMinimo = 0,
    this.precioSugerido,
    this.activo = true,
    this.unidadCompra,
    this.factorCompra,
    String? unidadFactura,
  }) : unidadFactura = unidadFactura ?? '';

  final String id;

  /// La descripción del Formato 13.1: "Ponchos artesanales talla estándar".
  final String nombre;
  final DateTime creadoEn;

  /// El código de la existencia: "P001", "POSA 001". Único y en mayúsculas.
  final String codigo;

  /// Código de la Tabla 5. Por ahora siempre 01, mercadería.
  final String tipoExistencia;

  /// Código de la Tabla 6: 07 unidades, 01 kilogramos…
  final String unidad;

  /// En milésimas. Cuando el stock llega aquí, la app avisa que queda poco.
  final int stockMinimo;

  /// El precio de venta sin IGV que se propone al vender, en centavos.
  final int? precioSugerido;

  /// Un producto que ya no se vende no se borra: se desactiva y deja de
  /// aparecer al registrar. Su kardex sigue ahí.
  final bool activo;

  /// La unidad en que se compra, si no es la del stock: se compra por cajas
  /// (12) y se vende por unidades (07). Código de la Tabla 6. Null si se
  /// compra en la misma unidad en que se vende.
  final String? unidadCompra;

  /// Cuánto trae cada unidad de compra, en milésimas de la unidad del
  /// stock: una caja de 12 unidades es 12,000.
  final int? factorCompra;

  /// El código de la unidad en la factura electrónica (catálogo 03): NIU,
  /// KGM, MIL… No es el de la Tabla 6. Vacío quiere decir el de fábrica.
  final String unidadFactura;

  /// Si la cantidad va sin decimales, como en unidades o cajas.
  bool get cantidadesEnteras => TablasSunat.unidadEntera(unidad);

  /// "und", "kg".
  String get abreviaturaUnidad =>
      TablasSunat.unidad(unidad)?.abreviatura ?? unidad;

  /// El código que va en la factura: el elegido o, si no se eligió, el que
  /// corresponde a su unidad de la Tabla 6.
  String get codigoUnidadFactura => unidadFactura.isEmpty
      ? TablasSunat.unidadFacturaDe(unidad)
      : unidadFactura;

  bool get tieneUnidadDeCompra => unidadCompra != null && factorCompra != null;

  /// "caja".
  String get abreviaturaUnidadCompra => unidadCompra == null
      ? abreviaturaUnidad
      : TablasSunat.unidad(unidadCompra!)?.abreviatura ?? unidadCompra!;

  /// Una cantidad en la unidad de compra, pasada a la del stock: 10 cajas de
  /// 12 son 120 unidades. Null si el producto no tiene unidad de compra o si
  /// no cabe.
  int? aStock(int cantidadEnCompra) => tieneUnidadDeCompra
      ? Cantidad.convertir(cantidadEnCompra, factorCompra!)
      : null;

  static String limpiarNombre(String nombre) =>
      nombre.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String claveDe(String nombre) => limpiarNombre(nombre).toLowerCase();

  /// "posa  001 " queda "POSA 001".
  static String limpiarCodigo(String codigo) =>
      codigo.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  Mercaderia copiarCon({
    String? nombre,
    String? codigo,
    String? tipoExistencia,
    String? unidad,
    int? stockMinimo,
    Object? precioSugerido = _sinCambio,
    bool? activo,
    Object? unidadCompra = _sinCambio,
    Object? factorCompra = _sinCambio,
    String? unidadFactura,
  }) {
    return Mercaderia(
      id: id,
      nombre: nombre ?? this.nombre,
      creadoEn: creadoEn,
      codigo: codigo ?? this.codigo,
      tipoExistencia: tipoExistencia ?? this.tipoExistencia,
      unidad: unidad ?? this.unidad,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      precioSugerido: identical(precioSugerido, _sinCambio)
          ? this.precioSugerido
          : precioSugerido as int?,
      activo: activo ?? this.activo,
      unidadCompra: identical(unidadCompra, _sinCambio)
          ? this.unidadCompra
          : unidadCompra as String?,
      factorCompra: identical(factorCompra, _sinCambio)
          ? this.factorCompra
          : factorCompra as int?,
      unidadFactura: unidadFactura ?? this.unidadFactura,
    );
  }

  static const _sinCambio = Object();

  Map<String, Object?> aMapa() => {
    'id': id,
    'nombre': nombre,
    'nombre_clave': claveDe(nombre),
    'creado_en': creadoEn.millisecondsSinceEpoch,
    'codigo': codigo,
    'tipo_existencia': tipoExistencia,
    'unidad': unidad,
    'stock_minimo': stockMinimo,
    'precio_sugerido': precioSugerido,
    'activo': activo ? 1 : 0,
    'unidad_compra': unidadCompra,
    'factor_compra': factorCompra,
    'unidad_factura': codigoUnidadFactura,
  };

  /// Tolerante con las filas de la v7 y la v8, que sólo tenían el nombre.
  factory Mercaderia.desdeMapa(Map<String, Object?> mapa) => Mercaderia(
    id: mapa['id']! as String,
    nombre: mapa['nombre']! as String,
    creadoEn: DateTime.fromMillisecondsSinceEpoch(mapa['creado_en']! as int),
    codigo: (mapa['codigo'] as String?) ?? '',
    tipoExistencia:
        (mapa['tipo_existencia'] as String?) ?? TablasSunat.mercaderia,
    unidad: (mapa['unidad'] as String?) ?? TablasSunat.unidadesSueltas,
    stockMinimo: (mapa['stock_minimo'] as int?) ?? 0,
    precioSugerido: mapa['precio_sugerido'] as int?,
    activo: (mapa['activo'] as int?) != 0,
    unidadCompra: mapa['unidad_compra'] as String?,
    factorCompra: mapa['factor_compra'] as int?,
    unidadFactura: mapa['unidad_factura'] as String?,
  );
}
