import 'enums.dart';

/// En qué grupo va la categoría dentro del selector. Con veinte categorías,
/// una lista plana de fichas no se puede leer.
enum GrupoCategoria {
  ventas('Ventas y cobros'),
  compras('Compras'),
  servicios('Servicios'),
  personal('Personal'),
  financiero('Activos y financiamiento'),
  otros('Otros'),
  propias('Mis categorías');

  const GrupoCategoria(this.etiqueta);
  final String etiqueta;
}

/// Catálogo de categorías (§4.3), con la contabilidad que exige el Excel.
///
/// Cada categoría lleva **dos** cuentas del plan contable, igual que cada
/// operación del Excel:
///
/// - `cuentaAsociada` es la que sale impresa en el Formato 1.1 / 1.2, en la
///   columna "CUENTA CONTABLE ASOCIADA". Es la contrapartida del efectivo:
///   cobrar es `101 Caja` contra `1212 Por cobrar`; pagar a un proveedor es
///   `4212 Por pagar` contra `101 Caja`.
/// - `cuentaResultado` es la de venta o gasto (70121, 6011, 6361…), la que
///   usa el Libro Diario en la provisión. No todas la tienen: cobrar un
///   fiado no genera venta nueva, sólo cancela lo que ya estaba anotado.
///
/// El dueño del negocio nunca ve nada de esto: toca "Ventas" y la app sabe
/// sola que eso es 1212 contra 70121.
class Categoria {
  const Categoria({
    required this.id,
    required this.etiqueta,
    required this.tipo,
    required this.cuentaAsociada,
    required this.grupo,
    this.cuentaResultado,
    this.cuentaRelacionada,
    this.cuentaPersonal,
    this.frase,
    this.afectoIgv = false,
    this.comun = false,
    this.propia = false,
  });

  final String id;
  final String etiqueta;
  final Tipo tipo;
  final GrupoCategoria grupo;

  /// La que va en la columna "CUENTA CONTABLE ASOCIADA" del formato oficial.
  final String cuentaAsociada;

  /// La cuenta de venta o de gasto, para el Libro Diario. Null cuando la
  /// operación sólo mueve plata sin generar venta ni gasto nuevo.
  final String? cuentaResultado;

  /// La cuenta cuando el otro es una relacionada (matriz, filial, sucursal o
  /// asociada): el PCGE las separa de los terceros. Null si no cambia.
  ///
  /// Las cuentas comerciales (1212, 122, 4212) no la necesitan: su variante
  /// depende además del documento, y la arma `ReglasCuenta`.
  final String? cuentaRelacionada;

  /// La cuenta cuando el otro es un trabajador o un socio. Null si no cambia.
  final String? cuentaPersonal;

  /// Cómo se describe la operación en el formato oficial, cuando armarla con
  /// "Cobro de " + etiqueta sale mal.
  ///
  /// El Excel arma esa frase con un CONCAT y funciona para las categorías que
  /// nombran una cosa —"Pago de Mercaderías"—, pero no para las que ya nombran
  /// la acción: "Pago de Pago a proveedor" no lo escribiría nadie.
  final String? frase;

  /// Si el monto trae IGV adentro. Las ventas y las compras sí; cobrar una
  /// deuda vieja o pagar una planilla, no.
  final bool afectoIgv;

  /// Las de todos los días, que se muestran primero.
  final bool comun;

  /// Creada por el usuario con el "+" del formulario: no viene con la app, se
  /// guarda en la base del equipo.
  final bool propia;

  /// "Otros" es la puerta a todo el plan contable: al elegirla, el
  /// formulario pide la cuenta exacta en vez de mandar todo a una cuenta
  /// genérica.
  bool get pideCuenta => id == otrosIngresos.id || id == otrosEgresos.id;

  /// Cancela un documento que ya existía: el fiado cobra una factura o una
  /// letra, el pago al proveedor paga una. Por eso se pregunta cuál.
  bool get cancelaDocumento => id == cobrosFiado.id || id == proveedores.id;

  // --- Entradas ---

  static const ventas = Categoria(
    id: 'ventas',
    etiqueta: 'Ventas',
    tipo: Tipo.entro,
    grupo: GrupoCategoria.ventas,
    cuentaAsociada: '1212',
    cuentaResultado: '70121',
    afectoIgv: true,
    comun: true,
  );

  static const cobrosFiado = Categoria(
    id: 'cobros_fiado',
    etiqueta: 'Cobros de fiado',
    tipo: Tipo.entro,
    grupo: GrupoCategoria.ventas,
    cuentaAsociada: '1212',
    frase: 'Cobro de fiado',
    comun: true,
  );

  static const anticipos = Categoria(
    id: 'anticipos',
    etiqueta: 'Adelanto de cliente',
    tipo: Tipo.entro,
    grupo: GrupoCategoria.ventas,
    cuentaAsociada: '122',
    frase: 'Adelanto de cliente',
    comun: true,
  );

  static const otrosIngresos = Categoria(
    id: 'otros_ingresos',
    etiqueta: 'Otros',
    tipo: Tipo.entro,
    grupo: GrupoCategoria.otros,
    cuentaAsociada: '1212',
    cuentaResultado: '759',
    frase: 'Otros cobros',
    comun: true,
  );

  // --- Activos y financiamiento: cobros de algo que ya se debía ---

  /// El cobro de un activo fijo vendido: una camioneta, una computadora.
  static const ventaActivo = Categoria(
    id: 'venta_activo',
    etiqueta: 'Venta de activo fijo',
    tipo: Tipo.entro,
    grupo: GrupoCategoria.financiero,
    cuentaAsociada: '1653',
    cuentaRelacionada: '1753',
    frase: 'Cobro por venta de activo fijo',
  );

  static const cobroPrestamo = Categoria(
    id: 'cobro_prestamo',
    etiqueta: 'Cobro de préstamo',
    tipo: Tipo.entro,
    grupo: GrupoCategoria.financiero,
    cuentaAsociada: '1612',
    cuentaRelacionada: '1712',
    cuentaPersonal: '1411',
    frase: 'Cobro de préstamo',
  );

  static const dividendosRecibidos = Categoria(
    id: 'dividendos_cobro',
    etiqueta: 'Dividendos',
    tipo: Tipo.entro,
    grupo: GrupoCategoria.financiero,
    cuentaAsociada: '1633',
    cuentaRelacionada: '1733',
    frase: 'Cobro de dividendos',
  );

  static const regalias = Categoria(
    id: 'regalias',
    etiqueta: 'Regalías',
    tipo: Tipo.entro,
    grupo: GrupoCategoria.financiero,
    cuentaAsociada: '1632',
    cuentaRelacionada: '1732',
    frase: 'Cobro de regalías',
  );

  // --- Salidas ---

  static const mercaderia = Categoria(
    id: 'mercaderia',
    etiqueta: 'Mercadería',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.compras,
    cuentaAsociada: '4212',
    cuentaResultado: '6011',
    afectoIgv: true,
    comun: true,
  );

  static const suministros = Categoria(
    id: 'suministros',
    etiqueta: 'Suministros',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.compras,
    cuentaAsociada: '4212',
    cuentaResultado: '656',
    afectoIgv: true,
  );

  static const proveedores = Categoria(
    id: 'proveedores',
    etiqueta: 'Pago a proveedor',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.compras,
    cuentaAsociada: '4212',
    frase: 'Pago a proveedor',
    comun: true,
  );

  static const luz = Categoria(
    id: 'luz',
    etiqueta: 'Luz',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.servicios,
    cuentaAsociada: '4212',
    cuentaResultado: '6361',
    afectoIgv: true,
    comun: true,
  );

  static const agua = Categoria(
    id: 'agua',
    etiqueta: 'Agua',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.servicios,
    cuentaAsociada: '4212',
    cuentaResultado: '6363',
    afectoIgv: true,
    comun: true,
  );

  static const internet = Categoria(
    id: 'internet',
    etiqueta: 'Internet',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.servicios,
    cuentaAsociada: '4212',
    cuentaResultado: '6365',
    afectoIgv: true,
  );

  static const telefono = Categoria(
    id: 'telefono',
    etiqueta: 'Teléfono',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.servicios,
    cuentaAsociada: '4212',
    cuentaResultado: '6364',
    afectoIgv: true,
  );

  static const alquiler = Categoria(
    id: 'alquiler',
    etiqueta: 'Alquiler',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.servicios,
    cuentaAsociada: '4212',
    cuentaResultado: '6352',
    afectoIgv: true,
    comun: true,
  );

  static const contable = Categoria(
    id: 'contable',
    etiqueta: 'Contador',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.servicios,
    cuentaAsociada: '4212',
    cuentaResultado: '6323',
    afectoIgv: true,
  );

  /// Id heredado de la versión anterior de la app, cuando "Servicios" era una
  /// sola categoría. Se mantiene para que los movimientos ya registrados no
  /// queden huérfanos.
  static const servicios = Categoria(
    id: 'servicios',
    etiqueta: 'Otros servicios',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.servicios,
    cuentaAsociada: '4212',
    cuentaResultado: '639',
    frase: 'Pago de otros servicios',
    afectoIgv: true,
  );

  // --- Planilla, tal como la desglosa el Excel ---

  static const sueldos = Categoria(
    id: 'sueldos',
    etiqueta: 'Sueldos',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.personal,
    cuentaAsociada: '4111',
    cuentaResultado: '6211',
    comun: true,
  );

  static const essalud = Categoria(
    id: 'essalud',
    etiqueta: 'ESSALUD',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.personal,
    cuentaAsociada: '4031',
    cuentaResultado: '6271',
  );

  static const onp = Categoria(
    id: 'onp',
    etiqueta: 'ONP',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.personal,
    cuentaAsociada: '4032',
  );

  static const afp = Categoria(
    id: 'afp',
    etiqueta: 'AFP',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.personal,
    cuentaAsociada: '417',
  );

  static const otrasObligaciones = Categoria(
    id: 'otras_obligaciones',
    etiqueta: 'Otras obligaciones',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.personal,
    cuentaAsociada: '4539',
  );

  /// Honorarios de una persona que emite recibo por honorarios: no lleva IGV.
  static const honorarios = Categoria(
    id: 'honorarios',
    etiqueta: 'Honorarios',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.servicios,
    cuentaAsociada: '424',
    frase: 'Pago de honorarios',
  );

  // --- Activos y financiamiento: pagos de algo que ya se debía ---

  static const compraActivo = Categoria(
    id: 'compra_activo',
    etiqueta: 'Compra de activo fijo',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.financiero,
    cuentaAsociada: '4654',
    cuentaRelacionada: '4774',
    frase: 'Pago por compra de activo fijo',
  );

  static const pagoPrestamo = Categoria(
    id: 'pago_prestamo',
    etiqueta: 'Pago de préstamo',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.financiero,
    cuentaAsociada: '4511',
    cuentaRelacionada: '471',
    cuentaPersonal: '4411',
    frase: 'Pago de préstamo',
  );

  static const dividendosPagados = Categoria(
    id: 'dividendos_pago',
    etiqueta: 'Pago de dividendos',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.financiero,
    cuentaAsociada: '4412',
    cuentaRelacionada: '475',
    frase: 'Pago de dividendos',
  );

  static const otrosEgresos = Categoria(
    id: 'otros_egresos',
    etiqueta: 'Otros',
    tipo: Tipo.salio,
    grupo: GrupoCategoria.otros,
    cuentaAsociada: '4212',
    cuentaResultado: '659',
    frase: 'Otros pagos',
  );

  /// Las que vienen con la app.
  static const base = <Categoria>[
    ventas,
    cobrosFiado,
    anticipos,
    otrosIngresos,
    ventaActivo,
    cobroPrestamo,
    dividendosRecibidos,
    regalias,
    mercaderia,
    suministros,
    proveedores,
    luz,
    agua,
    internet,
    telefono,
    alquiler,
    contable,
    servicios,
    sueldos,
    essalud,
    onp,
    afp,
    otrasObligaciones,
    honorarios,
    compraActivo,
    pagoPrestamo,
    dividendosPagados,
    otrosEgresos,
  ];

  static List<Categoria> _propias = const [];

  /// Las que creó el usuario. Las carga el estado de la app al abrir la base,
  /// para que `porId` las encuentre en cualquier pantalla.
  static List<Categoria> get propias => _propias;

  static void registrarPropias(List<Categoria> propias) {
    _propias = List.unmodifiable(propias);
  }

  /// Las de la app más las del usuario.
  static List<Categoria> get todas => [...base, ..._propias];

  static List<Categoria> de(Tipo tipo) =>
      todas.where((c) => c.tipo == tipo).toList();

  /// Las de todos los días, que van primero en el formulario.
  static List<Categoria> comunesDe(Tipo tipo) =>
      base.where((c) => c.tipo == tipo && c.comun).toList();

  /// Las creadas por el usuario, que van como fichas después de las comunes.
  static List<Categoria> propiasDe(Tipo tipo) =>
      _propias.where((c) => c.tipo == tipo).toList();

  static List<Categoria> restoDe(Tipo tipo) =>
      base.where((c) => c.tipo == tipo && !c.comun).toList();

  Map<String, Object?> aMapa() => {
    'id': id,
    'etiqueta': etiqueta,
    'tipo': tipo.name,
    'cuenta_asociada': cuentaAsociada,
    'cuenta_resultado': cuentaResultado,
    'afecto_igv': afectoIgv ? 1 : 0,
  };

  factory Categoria.desdeMapa(Map<String, Object?> m) => Categoria(
    id: m['id']! as String,
    etiqueta: m['etiqueta']! as String,
    tipo: Tipo.desdeBd(m['tipo']! as String),
    grupo: GrupoCategoria.propias,
    cuentaAsociada: m['cuenta_asociada']! as String,
    cuentaResultado: m['cuenta_resultado'] as String?,
    afectoIgv: (m['afecto_igv'] as int? ?? 0) == 1,
    comun: true,
    propia: true,
  );

  /// Nunca devuelve null: un id desconocido (por ejemplo, de un respaldo
  /// viejo) cae en "Otros" en vez de romper la pantalla.
  static Categoria porId(String id) =>
      todas.firstWhere((c) => c.id == id, orElse: () => otrosEgresos);
}
