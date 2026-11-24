/// Las tablas de SUNAT que pide el Formato 13.1 (Resolución 234-2006/SUNAT).
///
/// Salen de las hojas T5, T6, T10 y T12 del Excel del kardex. Se guardan los
/// códigos tal cual, porque son los que se imprimen en el formato; la
/// descripción es para mostrarla en pantalla.
class TablasSunat {
  TablasSunat._();

  /// Tabla 5: tipo de existencia. Por ahora la app sólo usa 01.
  static const tiposDeExistencia = <TipoExistencia>[
    TipoExistencia('01', 'Mercadería'),
    TipoExistencia('02', 'Producto terminado'),
    TipoExistencia('03', 'Materias primas y auxiliares - materiales'),
    TipoExistencia('04', 'Envases y embalajes'),
    TipoExistencia('05', 'Suministros diversos'),
    TipoExistencia('99', 'Otros (especificar)'),
  ];

  /// Tabla 6: unidad de medida. `entera` dice si la cantidad va sin
  /// decimales: no se venden 2.5 unidades, pero sí 2.5 kilos.
  static const unidades = <UnidadMedida>[
    UnidadMedida('01', 'Kilogramos', 'kg', entera: false),
    UnidadMedida('02', 'Libras', 'lb', entera: false),
    UnidadMedida('03', 'Toneladas largas', 't larga', entera: false),
    UnidadMedida('04', 'Toneladas métricas', 't', entera: false),
    UnidadMedida('05', 'Toneladas cortas', 't corta', entera: false),
    UnidadMedida('06', 'Gramos', 'g', entera: false),
    UnidadMedida('07', 'Unidades', 'und', entera: true),
    UnidadMedida('08', 'Litros', 'l', entera: false),
    UnidadMedida('09', 'Galones', 'gal', entera: false),
    UnidadMedida('10', 'Barriles', 'bbl', entera: false),
    UnidadMedida('11', 'Latas', 'lata', entera: true),
    UnidadMedida('12', 'Cajas', 'caja', entera: true),
    UnidadMedida('13', 'Millares', 'mll', entera: false),
    UnidadMedida('14', 'Metros cúbicos', 'm³', entera: false),
    UnidadMedida('15', 'Metros', 'm', entera: false),
    UnidadMedida('99', 'Otros (especificar)', 'otro', entera: false),
  ];

  /// Tabla 10: tipo de comprobante de pago o documento.
  static const comprobantes = <ComprobanteSunat>[
    ComprobanteSunat('00', 'Otros (especificar)'),
    ComprobanteSunat('01', 'Factura'),
    ComprobanteSunat('02', 'Recibo por Honorarios'),
    ComprobanteSunat('03', 'Boleta de Venta'),
    ComprobanteSunat('04', 'Liquidación de compra'),
    ComprobanteSunat(
      '05',
      'Boleto de compañía de aviación comercial por el servicio de transporte aéreo de pasajeros',
    ),
    ComprobanteSunat(
      '06',
      'Carta de porte aéreo por el servicio de transporte de carga aérea',
    ),
    ComprobanteSunat('07', 'Nota de crédito'),
    ComprobanteSunat('08', 'Nota de débito'),
    ComprobanteSunat('09', 'Guía de remisión - Remitente'),
    ComprobanteSunat('10', 'Recibo por Arrendamiento'),
    ComprobanteSunat(
      '11',
      'Póliza emitida por las Bolsas de Valores, Bolsas de Productos o Agentes de Intermediación por operaciones realizadas en las Bolsas de Valores o Productos o fuera de las mismas, autorizadas por CONASEV',
    ),
    ComprobanteSunat('12', 'Ticket o cinta emitido por máquina registradora'),
    ComprobanteSunat(
      '13',
      'Documento emitido por bancos, instituciones financieras, crediticias y de seguros que se encuentren bajo el control de la Superintendencia de Banca y Seguros',
    ),
    ComprobanteSunat(
      '14',
      'Recibo por servicios públicos de suministro de energía eléctrica, agua, teléfono, telex y telegráficos y otros servicios complementarios que se incluyan en el recibo de servicio público',
    ),
    ComprobanteSunat(
      '15',
      'Boleto emitido por las empresas de transporte público urbano de pasajeros',
    ),
    ComprobanteSunat(
      '16',
      'Boleto de viaje emitido por las empresas de transporte público interprovincial de pasajeros dentro del país',
    ),
    ComprobanteSunat(
      '17',
      'Documento emitido por la Iglesia Católica por el arrendamiento de bienes inmuebles',
    ),
    ComprobanteSunat(
      '18',
      'Documento emitido por las Administradoras Privadas de Fondo de Pensiones que se encuentran bajo la supervisión de la Superintendencia de Administradoras Privadas de Fondos de Pensiones',
    ),
    ComprobanteSunat(
      '19',
      'Boleto o entrada por atracciones y espectáculos públicos',
    ),
    ComprobanteSunat('20', 'Comprobante de Retención'),
    ComprobanteSunat(
      '21',
      'Conocimiento de embarque por el servicio de transporte de carga marítima',
    ),
    ComprobanteSunat('22', 'Comprobante por Operaciones No Habituales'),
    ComprobanteSunat(
      '23',
      'Pólizas de Adjudicación emitidas con ocasión del remate o adjudicación de bienes por venta forzada, por los martilleros o las entidades que rematen o subasten bienes por cuenta de terceros',
    ),
    ComprobanteSunat(
      '24',
      'Certificado de pago de regalías emitidas por PERUPETRO S.A',
    ),
    ComprobanteSunat(
      '25',
      'Documento de Atribución (Ley del Impuesto General a las Ventas e Impuesto Selectivo al Consumo, Art. 19º, último párrafo, R.S. N° 022-98-SUNAT).',
    ),
    ComprobanteSunat(
      '26',
      'Recibo por el Pago de la Tarifa por Uso de Agua Superficial con fines agrarios y por el pago de la Cuota para la ejecución de una determinada obra o actividad acordada por la Asamblea General de la Comisión de Regantes o Resolución expedida por el Jefe de la Unidad de Aguas y de Riego (Decreto Supremo N° 003-90-AG, Arts. 28 y 48)',
    ),
    ComprobanteSunat('27', 'Seguro Complementario de Trabajo de Riesgo'),
    ComprobanteSunat('28', 'Tarifa Unificada de Uso de Aeropuerto'),
    ComprobanteSunat(
      '29',
      'Documentos emitidos por la COFOPRI en calidad de oferta de venta de terrenos, los correspondientes a las subastas públicas y a la retribución de los servicios que presta',
    ),
    ComprobanteSunat(
      '30',
      'Documentos emitidos por las empresas que desempeñan el rol adquirente en los sistemas de pago mediante tarjetas de crédito y débito',
    ),
    ComprobanteSunat('31', 'Guía de Remisión - Transportista'),
    ComprobanteSunat(
      '32',
      'Documentos emitidos por las empresas recaudadoras de la denominada Garantía de Red Principal a la que hace referencia el numeral 7.6 del artículo 7° de la Ley N° 27133 – Ley de Promoción del Desarrollo de la Industria del Gas Natural',
    ),
    ComprobanteSunat('34', 'Documento del Operador'),
    ComprobanteSunat('35', 'Documento del Partícipe'),
    ComprobanteSunat('36', 'Recibo de Distribución de Gas Natural'),
    ComprobanteSunat(
      '37',
      'Documentos que emitan los concesionarios del servicio de revisiones técnicas vehiculares, por la prestación de dicho servicio',
    ),
    ComprobanteSunat(
      '50',
      'Declaración Única de Aduanas - Importación definitiva',
    ),
    ComprobanteSunat('52', 'Despacho Simplificado - Importación Simplificada'),
    ComprobanteSunat('53', 'Declaración de Mensajería o Courier'),
    ComprobanteSunat('54', 'Liquidación de Cobranza'),
    ComprobanteSunat('87', 'Nota de Crédito Especial'),
    ComprobanteSunat('88', 'Nota de Débito Especial'),
    ComprobanteSunat('91', 'Comprobante de No Domiciliado'),
    ComprobanteSunat('96', 'Exceso de crédito fiscal por retiro de bienes'),
    ComprobanteSunat('97', 'Nota de Crédito - No Domiciliado'),
    ComprobanteSunat('98', 'Nota de Débito - No Domiciliado'),
    ComprobanteSunat('99', 'Otros -Consolidado de Boletas de Venta'),
  ];

  /// Tabla 12: tipo de operación. Las que usa el kardex están en
  /// `OperacionAlmacen`; esta es la lista completa, para mostrarla.
  static const operaciones = <OperacionSunat>[
    OperacionSunat('01', 'Venta'),
    OperacionSunat('02', 'Compra'),
    OperacionSunat('03', 'Consignación recibida'),
    OperacionSunat('04', 'Consignación entregada'),
    OperacionSunat('05', 'Devolución recibida'),
    OperacionSunat('06', 'Devolución entregada'),
    OperacionSunat('07', 'Promoción'),
    OperacionSunat('08', 'Premio'),
    OperacionSunat('09', 'Donación'),
    OperacionSunat('10', 'Salida a producción'),
    OperacionSunat('11', 'Transferencia entre almacenes'),
    OperacionSunat('12', 'Retiro'),
    OperacionSunat('13', 'Mermas'),
    OperacionSunat('14', 'Desmedros'),
    OperacionSunat('15', 'Destrucción'),
    OperacionSunat('16', 'Saldo inicial'),
    OperacionSunat('99', 'Otros (especificar)'),
  ];

  /// Catálogo 03 de la factura electrónica: la unidad de medida comercial
  /// (UN/ECE Recomendación 20). No es la Tabla 6: la Tabla 6 va en el
  /// Formato 13.1 y esta en la línea de la factura. Van las de uso más
  /// común en un negocio; el catálogo completo tiene cientos.
  static const unidadesFactura = <UnidadFactura>[
    UnidadFactura('NIU', 'Unidad (bienes)'),
    UnidadFactura('ZZ', 'Unidad (servicios)'),
    UnidadFactura('KGM', 'Kilogramo'),
    UnidadFactura('GRM', 'Gramo'),
    UnidadFactura('LBR', 'Libra'),
    UnidadFactura('TNE', 'Tonelada métrica'),
    UnidadFactura('LTN', 'Tonelada larga'),
    UnidadFactura('STN', 'Tonelada corta'),
    UnidadFactura('LTR', 'Litro'),
    UnidadFactura('MLT', 'Mililitro'),
    UnidadFactura('GLL', 'Galón (EE. UU.)'),
    UnidadFactura('BLL', 'Barril (EE. UU.)'),
    UnidadFactura('MTR', 'Metro'),
    UnidadFactura('CMT', 'Centímetro'),
    UnidadFactura('MTK', 'Metro cuadrado'),
    UnidadFactura('MTQ', 'Metro cúbico'),
    UnidadFactura('MIL', 'Millar'),
    UnidadFactura('CEN', 'Ciento'),
    UnidadFactura('DZN', 'Docena'),
    UnidadFactura('BX', 'Caja'),
    UnidadFactura('CA', 'Lata'),
    UnidadFactura('PK', 'Paquete'),
    UnidadFactura('BG', 'Bolsa'),
    UnidadFactura('BO', 'Botella'),
    UnidadFactura('SET', 'Juego'),
    UnidadFactura('PR', 'Par'),
    UnidadFactura('KT', 'Kit'),
    UnidadFactura('RM', 'Resma'),
    UnidadFactura('ST', 'Pliego'),
    UnidadFactura('C62', 'Pieza'),
  ];

  /// La equivalencia de fábrica de la Tabla 6 al catálogo 03: un producto
  /// en unidades (07) sale en la factura como NIU, uno en kilos (01) como
  /// KGM. Se puede cambiar producto por producto.
  static const _facturaDeTabla6 = <String, String>{
    '01': 'KGM',
    '02': 'LBR',
    '03': 'LTN',
    '04': 'TNE',
    '05': 'STN',
    '06': 'GRM',
    '07': 'NIU',
    '08': 'LTR',
    '09': 'GLL',
    '10': 'BLL',
    '11': 'CA',
    '12': 'BX',
    '13': 'MIL',
    '14': 'MTQ',
    '15': 'MTR',
    '99': 'NIU',
  };

  static const mercaderia = '01';
  static const unidadesSueltas = '07';
  static const unidadFacturaSuelta = 'NIU';
  static const factura = '01';
  static const boleta = '03';
  static const notaDeCredito = '07';
  static const notaDeDebito = '08';

  /// El documento interno de la app: la nota de venta, y lo que se registra
  /// sin comprobante.
  static const otros = '00';

  static TipoExistencia? tipoExistencia(String codigo) =>
      _buscar(tiposDeExistencia, codigo, (t) => t.codigo);

  static UnidadMedida? unidad(String codigo) =>
      _buscar(unidades, codigo, (u) => u.codigo);

  static ComprobanteSunat? comprobante(String codigo) =>
      _buscar(comprobantes, codigo, (c) => c.codigo);

  static OperacionSunat? operacion(String codigo) =>
      _buscar(operaciones, codigo, (o) => o.codigo);

  static UnidadFactura? unidadFactura(String codigo) =>
      _buscar(unidadesFactura, codigo, (u) => u.codigo);

  /// El código de la factura que corresponde a una unidad de la Tabla 6.
  static String unidadFacturaDe(String codigoTabla6) =>
      _facturaDeTabla6[codigoTabla6] ?? unidadFacturaSuelta;

  /// Una unidad que no está en la tabla se trata como entera: es lo más
  /// seguro, porque no deja anotar fracciones de algo que no se parte.
  static bool unidadEntera(String codigo) => unidad(codigo)?.entera ?? true;

  static T? _buscar<T>(List<T> lista, String codigo, String Function(T) de) {
    for (final x in lista) {
      if (de(x) == codigo) return x;
    }
    return null;
  }
}

class TipoExistencia {
  const TipoExistencia(this.codigo, this.descripcion);
  final String codigo;
  final String descripcion;
}

class UnidadMedida {
  const UnidadMedida(
    this.codigo,
    this.descripcion,
    this.abreviatura, {
    required this.entera,
  });
  final String codigo;
  final String descripcion;

  /// Para mostrar junto a la cantidad: "1,600 und", "2.5 kg".
  final String abreviatura;
  final bool entera;
}

class ComprobanteSunat {
  const ComprobanteSunat(this.codigo, this.descripcion);
  final String codigo;
  final String descripcion;
}

class OperacionSunat {
  const OperacionSunat(this.codigo, this.descripcion);
  final String codigo;
  final String descripcion;
}

class UnidadFactura {
  const UnidadFactura(this.codigo, this.descripcion);
  final String codigo;
  final String descripcion;
}
