import 'almacen.dart';
import 'banco.dart';
import 'categoria.dart';
import 'igv.dart';
import 'importe.dart';
import 'mercaderia.dart';
import 'tablas_sunat.dart';

/// Validación compartida por SQLite y la demo web: los productos, las líneas
/// de una compra o una venta, y lo que se anota suelto en el almacén.
class ReglasMercaderia {
  /// El largo máximo del nombre de un producto. Lo usan el repositorio y el
  /// diálogo, para que los dos digan lo mismo.
  static const largoMaximo = 40;
  static const largoCodigo = 24;
  static const largoMotivo = 200;

  /// P4 exige líneas para compras y ventas de mercadería. Una venta de
  /// servicios se identifica sin producto ni costo de kardex (se guarda en cero).
  static const exigirLineas = true;

  static String validarNombre(String nombre) {
    final limpio = Mercaderia.limpiarNombre(nombre);
    if (limpio.isEmpty || limpio.length > largoMaximo) {
      throw ArgumentError(
        'Escribe un nombre de mercadería de 1 a $largoMaximo caracteres.',
      );
    }
    return limpio;
  }

  static String validarCodigo(String codigo) {
    final limpio = Mercaderia.limpiarCodigo(codigo);
    if (!RegExp(r'^[A-Z0-9][A-Z0-9 .\-]*$').hasMatch(limpio) ||
        limpio.length > largoCodigo) {
      throw ArgumentError(
        'El código va con letras, números, puntos o guiones, hasta '
        '$largoCodigo caracteres.',
      );
    }
    return limpio;
  }

  /// El siguiente código libre de la forma P001, P002…
  static String codigoSugerido(Iterable<Mercaderia> existentes) {
    var mayor = 0;
    for (final m in existentes) {
      final numero = RegExp(r'^P(\d+)$').firstMatch(m.codigo)?.group(1);
      if (numero != null) {
        final n = int.parse(numero);
        if (n > mayor) mayor = n;
      }
    }
    return 'P${(mayor + 1).toString().padLeft(3, '0')}';
  }

  /// Revisa un producto antes de guardarlo y lo devuelve limpio.
  ///
  /// `otros` son los demás productos, para que no se repitan ni el nombre
  /// ni el código. `conMovimientos` dice si ya pasó por el almacén: entonces
  /// la unidad no se cambia, porque lo anotado en unidades no se vuelve
  /// kilos.
  static Mercaderia validarProducto(
    Mercaderia producto, {
    required Iterable<Mercaderia> otros,
    Mercaderia? anterior,
    bool conMovimientos = false,
  }) {
    final nombre = validarNombre(producto.nombre);
    final codigo = validarCodigo(producto.codigo);
    final demas = otros.where((m) => m.id != producto.id);
    if (demas.any(
      (m) => Mercaderia.claveDe(m.nombre) == nombre.toLowerCase(),
    )) {
      throw ArgumentError('Ya existe una mercadería con ese nombre.');
    }
    if (demas.any((m) => m.codigo == codigo)) {
      throw ArgumentError('Ya hay un producto con el código $codigo.');
    }
    if (TablasSunat.tipoExistencia(producto.tipoExistencia) == null) {
      throw ArgumentError('Elige el tipo de existencia de la Tabla 5.');
    }
    if (TablasSunat.unidad(producto.unidad) == null) {
      throw ArgumentError('Elige la unidad de medida de la Tabla 6.');
    }
    if (anterior != null &&
        conMovimientos &&
        anterior.unidad != producto.unidad) {
      throw ArgumentError(
        'Este producto ya tiene movimientos en el almacén: su unidad de '
        'medida ya no se puede cambiar.',
      );
    }
    if (producto.stockMinimo < 0 || producto.stockMinimo > Cantidad.maxima) {
      throw ArgumentError('El stock mínimo no es válido.');
    }
    if (producto.cantidadesEnteras &&
        !Cantidad.esEntera(producto.stockMinimo)) {
      throw ArgumentError('El stock mínimo va sin decimales en esta unidad.');
    }
    final precio = producto.precioSugerido;
    if (precio != null && (precio <= 0 || precio > Importe.maximoCentavos)) {
      throw ArgumentError('El precio sugerido tiene que ser mayor que cero.');
    }
    _validarUnidadDeCompra(producto);
    final factura = producto.unidadFactura.trim().toUpperCase();
    if (factura.isNotEmpty && TablasSunat.unidadFactura(factura) == null) {
      throw ArgumentError(
        'Elige la unidad de la factura electrónica del catálogo 03.',
      );
    }
    return producto.copiarCon(
      nombre: nombre,
      codigo: codigo,
      unidadFactura: factura.isEmpty
          ? TablasSunat.unidadFacturaDe(producto.unidad)
          : factura,
    );
  }

  /// El factor más grande: un millón de unidades por unidad de compra.
  static const factorMaximo = 1000000 * Cantidad.escala;

  /// La unidad de compra va con su factor, o ninguno de los dos.
  static void _validarUnidadDeCompra(Mercaderia producto) {
    final unidad = producto.unidadCompra;
    final factor = producto.factorCompra;
    if (unidad == null && factor == null) return;
    if (unidad == null || factor == null) {
      throw ArgumentError(
        'La unidad de compra va con cuánto trae: por ejemplo, caja de 12.',
      );
    }
    if (TablasSunat.unidad(unidad) == null) {
      throw ArgumentError('Elige la unidad de compra de la Tabla 6.');
    }
    if (unidad == producto.unidad) {
      throw ArgumentError(
        'La unidad de compra es la misma del stock: déjala vacía.',
      );
    }
    final nombre = TablasSunat.unidad(unidad)!.abreviatura;
    if (factor <= 0 || factor > factorMaximo) {
      throw ArgumentError(
        'Escribe cuánto trae cada $nombre, mayor que cero.',
      );
    }
    if (producto.cantidadesEnteras && !Cantidad.esEntera(factor)) {
      throw ArgumentError(
        'Cada $nombre trae unidades enteras: va sin decimales.',
      );
    }
  }

  /// Las reglas de la v7, para lo que se registra sin líneas de productos.
  static void validar({
    required String categoriaId,
    required String? mercaderiaId,
    required int? costoCentavos,
    bool permitirHeredado = false,
  }) {
    final compra = categoriaId == Categoria.mercaderia.id;
    final venta = categoriaId == Categoria.ventas.id;
    if (costoCentavos != null &&
        (costoCentavos < 0 || costoCentavos > Importe.maximoCentavos)) {
      throw ArgumentError('El costo en soles está fuera del límite permitido.');
    }
    if (compra) {
      if (mercaderiaId == null && !permitirHeredado) {
        throw ArgumentError('Elige el tipo de mercadería que compraste.');
      }
      if (costoCentavos != null) {
        throw ArgumentError('En una compra, el costo es su importe sin IGV.');
      }
    } else if (venta) {
      if (mercaderiaId != null && (costoCentavos ?? 0) <= 0) {
        throw ArgumentError(
          'Escribe el costo de la mercadería vendida, mayor que cero.',
        );
      }
      if (mercaderiaId == null && costoCentavos != null && costoCentavos != 0) {
        throw ArgumentError('Elige a qué mercadería corresponde el costo.');
      }
    } else if (mercaderiaId != null || costoCentavos != null) {
      throw ArgumentError(
        'Estos datos solo corresponden a compras o ventas de mercadería.',
      );
    }
  }

  /// Sólo las compras de mercadería y las ventas llevan productos.
  static bool llevaProductos(String categoriaId) =>
      categoriaId == Categoria.mercaderia.id ||
      categoriaId == Categoria.ventas.id;

  /// Una cantidad para un producto: mayor que cero, dentro del límite y sin
  /// decimales si la unidad no se parte.
  static void validarCantidad(Mercaderia producto, int cantidad) {
    if (cantidad <= 0 || cantidad > Cantidad.maxima) {
      throw ArgumentError(
        'La cantidad de ${producto.nombre} tiene que ser mayor que cero.',
      );
    }
    if (producto.cantidadesEnteras && !Cantidad.esEntera(cantidad)) {
      throw ArgumentError(
        '${producto.nombre} se cuenta en '
        '${TablasSunat.unidad(producto.unidad)?.descripcion.toLowerCase() ?? 'unidades'}: '
        'la cantidad va sin decimales.',
      );
    }
  }

  /// Las líneas de una compra o una venta, revisadas y con la cantidad ya en
  /// la unidad del stock.
  ///
  /// Cada producto aparece una sola vez, está activo y tiene una cantidad
  /// válida; y entre todas suman `baseCentavos`, el valor sin IGV del
  /// movimiento, con los descuentos ya restados. Una compra en la unidad de
  /// compra (10 cajas) vuelve en la del stock (120 unidades). El stock lo
  /// revisa quien guarda, porque necesita el kardex.
  static List<LineaNueva> validarLineas({
    required String categoriaId,
    required List<LineaNueva> lineas,
    required int baseCentavos,
    required Map<String, Mercaderia> productos,
  }) {
    if (lineas.isEmpty) return const [];
    if (!llevaProductos(categoriaId)) {
      throw ArgumentError(
        'Solo las compras de mercadería y las ventas llevan productos.',
      );
    }
    final compra = categoriaId == Categoria.mercaderia.id;
    final vistos = <String>{};
    final enStock = <LineaNueva>[];
    var suma = 0;
    for (final linea in lineas) {
      final producto = productos[linea.mercaderiaId];
      if (producto == null) {
        throw ArgumentError('Uno de los productos elegidos no existe.');
      }
      if (!producto.activo) {
        throw ArgumentError(
          '${producto.nombre} está desactivado: actívalo para usarlo.',
        );
      }
      if (!vistos.add(producto.id)) {
        throw ArgumentError(
          '${producto.nombre} está dos veces: júntalo en una sola línea.',
        );
      }
      var cantidad = linea.cantidad;
      if (linea.enUnidadDeCompra) {
        if (!compra) {
          throw ArgumentError(
            'La unidad de compra solo se usa al comprar: '
            '${producto.nombre} se vende en ${producto.abreviaturaUnidad}.',
          );
        }
        if (!producto.tieneUnidadDeCompra) {
          throw ArgumentError(
            '${producto.nombre} no tiene unidad de compra: escribe la '
            'cantidad en ${producto.abreviaturaUnidad}.',
          );
        }
        _validarCantidadEn(
          producto.nombre,
          producto.unidadCompra!,
          linea.cantidad,
        );
        final convertida = producto.aStock(linea.cantidad);
        if (convertida == null) {
          throw ArgumentError(
            'La cantidad de ${producto.nombre} es demasiado grande.',
          );
        }
        cantidad = convertida;
      }
      validarCantidad(producto, cantidad);
      if (linea.importe <= 0 || linea.importe > Importe.maximoCentavos) {
        throw ArgumentError(
          'El importe de ${producto.nombre} tiene que ser mayor que cero.',
        );
      }
      if (linea.descuento < 0 || linea.descuento > Importe.maximoCentavos) {
        throw ArgumentError(
          'El descuento de ${producto.nombre} no puede ser negativo.',
        );
      }
      if (linea.importe > Importe.maximoCentavos - linea.descuento) {
        throw ArgumentError(
          'El importe antes del descuento de ${producto.nombre} supera el límite permitido.',
        );
      }
      if (suma > Importe.maximoCentavos - linea.importe) {
        throw ArgumentError(
          'La suma de los importes de los productos supera el límite permitido.',
        );
      }
      suma += linea.importe;
      enStock.add(linea.enStock(cantidad));
    }
    if (suma != baseCentavos) {
      throw ArgumentError(
        'Los productos suman ${_soles(suma)} y el valor sin IGV es '
        '${_soles(baseCentavos)}: tienen que ser iguales.',
      );
    }
    return enStock;
  }

  static void _validarCantidadEn(String nombre, String unidad, int cantidad) {
    if (cantidad <= 0 || cantidad > Cantidad.maxima) {
      throw ArgumentError(
        'La cantidad de $nombre tiene que ser mayor que cero.',
      );
    }
    if (TablasSunat.unidadEntera(unidad) && !Cantidad.esEntera(cantidad)) {
      throw ArgumentError(
        '$nombre se compra en '
        '${TablasSunat.unidad(unidad)?.descripcion.toLowerCase() ?? 'unidades'}: '
        'la cantidad va sin decimales.',
      );
    }
  }

  // --- El comprobante de una venta ---

  static const serieFactura = 'F001';
  static const serieBoleta = 'B001';

  /// Qué movimientos reciben tipo, serie y correlativo de comprobante:
  /// ventas y adelantos de clientes.
  static bool emiteComprobante(String categoriaId) =>
      categoriaId == Categoria.ventas.id ||
      categoriaId == Categoria.anticipos.id;

  /// Un RUC tiene 11 dígitos; un DNI, 8.
  static bool esRuc(String? documento) =>
      RegExp(r'^\d{11}$').hasMatch((documento ?? '').trim());

  /// El tipo y la serie que la app asigna: factura (01, F001) si el cliente
  /// tiene RUC o si es una exportación; si no, boleta (03, B001). El número
  /// lo pone quien guarda, en orden. Esto no transmite ni autoriza el
  /// comprobante ante SUNAT: esa emisión requiere un proveedor integrado.
  static Comprobante comprobanteDeVenta({
    required String? documentoCliente,
    required bool exportacion,
  }) {
    final documento = (documentoCliente ?? '').trim();
    if (!exportacion &&
        documento.isNotEmpty &&
        !RegExp(r'^\d{8}$').hasMatch(documento) &&
        !RegExp(r'^\d{11}$').hasMatch(documento)) {
      throw ArgumentError(
        'El documento del cliente debe tener 8 dígitos (DNI) o 11 dígitos (RUC).',
      );
    }
    return exportacion || esRuc(documento)
        ? const Comprobante(tipo: TablasSunat.factura, serie: serieFactura)
        : const Comprobante(tipo: TablasSunat.boleta, serie: serieBoleta);
  }

  /// Revisa un comprobante de venta escrito a mano, como los del ejercicio
  /// del Excel (FE01-112): factura o boleta, con la serie que empieza con
  /// F o con B, y factura sólo a un cliente con RUC o al exterior.
  static void validarComprobanteDeVenta(
    Comprobante comprobante, {
    required String? documentoCliente,
    required bool exportacion,
  }) {
    final factura = comprobante.tipo == TablasSunat.factura;
    final boleta = comprobante.tipo == TablasSunat.boleta;
    if (!factura && !boleta) {
      throw ArgumentError(
        'Una venta va con factura (01) o con boleta de venta (03).',
      );
    }
    if (!comprobante.serie.startsWith(factura ? 'F' : 'B')) {
      throw ArgumentError(
        'La serie de una ${factura ? 'factura' : 'boleta'} '
        'empieza con ${factura ? 'F' : 'B'}.',
      );
    }
    if (exportacion) {
      if (!factura) {
        throw ArgumentError('Una venta de exportación debe llevar factura.');
      }
      return;
    }
    final documento = (documentoCliente ?? '').trim();
    if (documento.isNotEmpty &&
        !RegExp(r'^\d{8}$').hasMatch(documento) &&
        !RegExp(r'^\d{11}$').hasMatch(documento)) {
      throw ArgumentError(
        'El documento del cliente debe tener 8 dígitos (DNI) o 11 dígitos (RUC).',
      );
    }
    if (esRuc(documento) && !factura) {
      throw ArgumentError('Un cliente con RUC debe recibir factura.');
    }
    if (RegExp(r'^\d{8}$').hasMatch(documento) && !boleta) {
      throw ArgumentError('Un cliente con DNI debe recibir boleta.');
    }
    if (documento.isEmpty && factura) {
      throw ArgumentError(
        'Para emitir factura registra el RUC del cliente; sin RUC corresponde boleta.',
      );
    }
  }

  /// El monto con IGV que corresponde a unas líneas que suman `suma` sin IGV.
  /// Es el que tiene que llevar el movimiento para que, al separar el IGV,
  /// el valor sin IGV dé exactamente lo que suman las líneas.
  static int montoParaLineas(int suma, {required bool conIgv}) {
    if (!conIgv) return suma;
    final aproximado = Igv.agregar(suma);
    for (final delta in const [0, -1, 1, -2, 2, -3, 3]) {
      final total = aproximado + delta;
      if (Igv.desagregar(total).base == suma) return total;
    }
    return aproximado;
  }

  /// La cuenta del costo de una venta, como la columna P del Excel: local o
  /// exportación, a terceros o a relacionadas.
  static String cuentaCostoDeVenta({
    required bool exportacion,
    required Vinculo vinculo,
  }) {
    final relacionada = vinculo.relacionada;
    if (exportacion) return relacionada ? '69112' : '69111';
    return relacionada ? '69122' : '69121';
  }

  /// Cómo se nombran los productos de una operación en su descripción:
  /// "Ponchos", "Ponchos y Mantas", "Ponchos y 2 productos más".
  static String descripcionDe(List<String> nombres) {
    if (nombres.isEmpty) return '';
    if (nombres.length == 1) return nombres.single;
    if (nombres.length == 2) return '${nombres[0]} y ${nombres[1]}';
    return '${nombres.first} y ${nombres.length - 1} productos más';
  }

  /// Un motivo de merma, desmedro o ajuste: obligatorio y corto.
  static String validarMotivo(String motivo) {
    final limpio = motivo.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (limpio.isEmpty) {
      throw ArgumentError('Escribe el motivo: queda en el kardex.');
    }
    if (limpio.length > largoMotivo) {
      throw ArgumentError('El motivo va en $largoMotivo caracteres o menos.');
    }
    return limpio;
  }

  static String _soles(int centavos) {
    final soles = (centavos ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return 'S/ $soles.${(centavos % 100).toString().padLeft(2, '0')}';
  }
}
