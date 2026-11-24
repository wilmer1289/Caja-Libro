import 'boleta.dart';
import 'costo_ventas_resumen.dart';
import 'enums.dart';
import 'inventario.dart';
import 'kardex.dart';
import 'mercaderia.dart';
import 'movimiento.dart';
import 'negocio.dart';
import 'pcge.dart';
import 'recibo.dart';
import 'reglas_asiento.dart';
import 'reglas_mercaderia.dart';

export 'costo_ventas_resumen.dart' show CostoVentasResumen;

/// Una cuenta dentro de la cadena de una línea: 40, 401, 4011, 40111.
class CuentaDiario {
  const CuentaDiario(this.codigo, this.denominacion);

  final String codigo;
  final String denominacion;

  /// Cuántos dígitos tiene: 2 es el elemento, 5 la subdivisionaria.
  int get nivel => codigo.length;
}

/// Una línea de un asiento: una cuenta con su importe al Debe o al Haber.
///
/// La cuenta viene con su cadena completa, de arriba a abajo
/// (60 › 601 › 6011), porque así se escribe en el Formato 5.1: cada nivel en
/// su fila y el importe en la primera.
class LineaDiario {
  const LineaDiario({
    required this.cadena,
    this.debe = 0,
    this.haber = 0,
    required this.porQue,
  });

  final List<CuentaDiario> cadena;

  /// En centavos. Uno de los dos es siempre cero.
  final int debe;
  final int haber;

  /// Por qué esta cuenta va en este lado, dicho para alguien que recién
  /// aprende. Es lo que muestra el modo Entender.
  final String porQue;

  /// La cuenta final, la que de verdad se mueve.
  CuentaDiario get cuenta => cadena.last;
  String get codigo => cuenta.codigo;
  String get denominacion => cuenta.denominacion;

  bool get alDebe => debe > 0;
}

/// Las etapas de una operación. La segunda cambia según lo que se hizo.
enum EtapaTipo {
  reconocimiento('Reconocimiento'),
  variacionInventarios('Variación de inventarios'),
  costoDeVenta('Costo de venta'),
  destinoDelGasto('Destino del gasto'),
  pagoOCobro('Pago o cobro');

  const EtapaTipo(this.etiqueta);
  final String etiqueta;
}

/// Un asiento: una etapa de la operación, con su glosa y sus líneas.
class EtapaAsiento {
  const EtapaAsiento({
    required this.tipo,
    required this.glosa,
    required this.lineas,
  });

  final EtapaTipo tipo;

  /// "Por la compra de tela".
  final String glosa;
  final List<LineaDiario> lineas;

  int get totalDebe => lineas.fold(0, (s, l) => s + l.debe);
  int get totalHaber => lineas.fold(0, (s, l) => s + l.haber);

  /// La regla de oro: el Debe es igual al Haber.
  bool get cuadra => totalDebe == totalHaber && totalDebe > 0;
}

/// Una operación del Libro Diario: un movimiento con sus asientos, bajo un
/// mismo correlativo.
class AsientoDiario {
  const AsientoDiario({
    required this.correlativo,
    required this.fecha,
    required this.etapas,
    required this.origen,
    this.documento,
    this.codigoLibro,
    this.mercaderia,
    this.faltaCosto = false,
  });

  /// El número de la operación en el libro, desde 1.
  final int correlativo;

  /// Todo es al contado: las etapas comparten la fecha del movimiento.
  final DateTime fecha;

  final List<EtapaAsiento> etapas;

  /// El movimiento de donde sale.
  final Movimiento origen;

  /// El documento que lo sustenta: la boleta o el recibo, si los tiene; si
  /// no, el N° de operación del voucher del banco.
  final String? documento;

  /// El código del libro de la Tabla 8 de SUNAT. Sólo lo llevan las compras
  /// de mercadería (08, Registro de Compras), como en el ejemplo del Excel.
  final String? codigoLibro;

  /// El tipo de mercadería, si se sabe: "tela".
  final String? mercaderia;

  /// Una venta de mercadería sin costo anotado, como lo registrado antes de
  /// los tipos de mercadería: no tiene asiento 2.
  final bool faltaCosto;

  /// "001", como en el Excel.
  String get numero => correlativo.toString().padLeft(3, '0');

  /// La glosa de la operación: la de su primer asiento.
  String get glosa => etapas.first.glosa;

  int get totalDebe => etapas.fold(0, (s, e) => s + e.totalDebe);
  int get totalHaber => etapas.fold(0, (s, e) => s + e.totalHaber);

  bool get cuadra => etapas.isNotEmpty && etapas.every((e) => e.cuadra);
}

/// Datos opcionales para armar el Libro Diario con kardex.
///
/// Permite pasar el kardex y las líneas de almacén para que el asiento 2
/// de las ventas use el costo real del kardex, y para generar los asientos
/// de operaciones de almacén (devoluciones, merma, desmedro, ajuste) y el
/// asiento de apertura.
/// Cuándo va el asiento de apertura: el inicio del período o, si todavía no
/// se configuró, el día del primer inventario inicial.
DateTime fechaDeApertura(Negocio negocio) =>
    negocio.inicioPeriodo ?? negocio.kardexDesde ?? DateTime.now();

class LibroDiarioDatos {
  const LibroDiarioDatos({this.kardex, this.lineasAlmacen, this.mercaderias});

  final Kardex? kardex;
  final List<LineaAlmacen>? lineasAlmacen;
  final List<Mercaderia>? mercaderias;
}

/// El Libro Diario de un período (Formato 5.1): cada movimiento convertido
/// en sus asientos.
///
/// Se arma desde los mismos movimientos del libro de caja, sin anotar nada
/// aparte: cada Entró o Salió ya dice qué pasó, cuánto fue, con qué IGV y por
/// qué medio. Las cuentas salen de [ReglasAsiento].
class LibroDiario {
  const LibroDiario._({
    required this.negocio,
    required this.desde,
    required this.hasta,
    required this.asientos,
    this.costoVentasResumen,
    this.asientoApertura,
  });

  final Negocio negocio;
  final DateTime desde;
  final DateTime hasta;

  /// En orden de fecha y, el mismo día, en el orden en que se anotaron.
  final List<AsientoDiario> asientos;

  /// Resumen del costo de ventas del período, por cuenta.
  final CostoVentasResumen? costoVentasResumen;

  /// Asiento de apertura (caja, banco, mercaderías contra 50 Capital).
  final AsientoDiario? asientoApertura;

  int get totalDebe => asientos.fold(0, (s, a) => s + a.totalDebe);
  int get totalHaber => asientos.fold(0, (s, a) => s + a.totalHaber);

  bool get cuadra => totalDebe == totalHaber && asientos.every((a) => a.cuadra);

  bool get vacio => asientos.isEmpty;

  /// Arma el libro de un rango de fechas.
  ///
  /// `movimientos` puede venir completo y sin ordenar: acá se filtran los
  /// borrados, lo anterior a la apertura del negocio, lo anulado y lo que cae
  /// fuera del rango. `mercaderia` dice qué tipo se compró o vendió y con qué
  /// costo; `ajustes` son los ids de los movimientos con que se llevaron al
  /// libro los faltantes y sobrantes de caja. `datos` trae el kardex y las
  /// líneas de almacén para usar costos reales y generar asientos de almacén.
  static LibroDiario armar({
    required Negocio negocio,
    required List<Movimiento> movimientos,
    required DateTime desde,
    required DateTime hasta,
    LeerMercaderia mercaderia = sinDatoDeMercaderia,
    Set<String> ajustes = const {},
    LibroDiarioDatos? datos,
  }) {
    final inicio = DateTime(desde.year, desde.month, desde.day);
    final fin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59, 999);
    final apertura = negocio.inicioPeriodo;

    final delPeriodo =
        movimientos
            .where(
              (m) =>
                  !m.eliminado &&
                  !m.anulado &&
                  (apertura == null || !m.fecha.isBefore(apertura)) &&
                  !m.fecha.isBefore(inicio) &&
                  !m.fecha.isAfter(fin),
            )
            .toList()
          ..sort((a, b) {
            final porFecha = a.fecha.compareTo(b.fecha);
            return porFecha != 0 ? porFecha : a.numero.compareTo(b.numero);
          });

    final armador = _Armador(
      Pcge.instancia,
      negocio,
      mercaderia,
      ajustes,
      datos,
    );
    final fechaApertura = fechaDeApertura(negocio);
    final aperturaEnRango =
        !fechaApertura.isBefore(inicio) && !fechaApertura.isAfter(fin);
    final asientoApertura = aperturaEnRango
        ? armador.asientoApertura(siguienteCorrelativo: 1)
        : null;
    final desplazamiento = asientoApertura == null ? 0 : 1;
    final asientosGenerados = [
      for (var i = 0; i < delPeriodo.length; i++)
        armador.asiento(i + 1 + desplazamiento, delPeriodo[i]),
    ];

    // Asientos de operaciones de almacén (devoluciones, merma, desmedro, ajuste)
    final asientosAlmacen = armador.asientosAlmacen(
      siguienteCorrelativo: delPeriodo.length + desplazamiento + 1,
      desde: inicio,
      hasta: fin,
    );

    // Resumen de costo de ventas
    CostoVentasResumen? costoVentasResumen;
    if (datos?.kardex != null) {
      costoVentasResumen = CostoVentasResumen.enRango(
        datos!.kardex!,
        desde: inicio,
        hasta: fin,
      );
    }

    final ordenados =
        <AsientoDiario>[
          ?asientoApertura,
          ...asientosGenerados,
          ...asientosAlmacen,
        ]..sort((a, b) {
          final fecha = a.fecha.compareTo(b.fecha);
          return fecha != 0 ? fecha : a.correlativo.compareTo(b.correlativo);
        });
    final todosLosAsientos = [
      for (var i = 0; i < ordenados.length; i++)
        _conCorrelativo(ordenados[i], i + 1),
    ];

    return LibroDiario._(
      negocio: negocio,
      desde: inicio,
      hasta: fin,
      asientos: todosLosAsientos,
      costoVentasResumen: costoVentasResumen,
      asientoApertura: asientoApertura,
    );
  }
}

AsientoDiario _conCorrelativo(AsientoDiario asiento, int correlativo) =>
    AsientoDiario(
      correlativo: correlativo,
      fecha: asiento.fecha,
      etapas: asiento.etapas,
      origen: asiento.origen,
      documento: asiento.documento,
      codigoLibro: asiento.codigoLibro,
      mercaderia: asiento.mercaderia,
      faltaCosto: asiento.faltaCosto,
    );

/// Convierte un movimiento en sus etapas. Está aparte para que cada esquema
/// se lea de corrido, línea por línea, como en el Excel.
class _Armador {
  _Armador(this.pcge, this.negocio, this.leer, this.ajustes, this.datos);

  final Pcge pcge;
  final Negocio negocio;
  final LeerMercaderia leer;
  final Set<String> ajustes;
  final LibroDiarioDatos? datos;

  AsientoDiario asiento(int correlativo, Movimiento m) {
    final esAjuste = ajustes.contains(m.id);
    final regla = ReglasAsiento.para(m, esAjuste: esAjuste);
    final dato = leer(m);

    final etapas = switch (regla.esquema) {
      Esquema.venta => _venta(m, regla, dato),
      Esquema.compraMercaderia => _compra(m, regla, dato),
      Esquema.gasto => _gasto(m, regla),
      Esquema.otroIngreso => _otroIngreso(m, regla),
      Esquema.pago => [_pago(m, regla, esAjuste)],
      Esquema.cobro => [_cobro(m, regla, esAjuste)],
    };

    final esVentaDeMercaderia =
        regla.esquema == Esquema.venta && (dato?.esMercaderia ?? true);
    return AsientoDiario(
      correlativo: correlativo,
      fecha: m.fecha,
      etapas: etapas,
      origen: m,
      documento: _documento(m),
      codigoLibro: regla.esquema == Esquema.compraMercaderia ? '08' : null,
      mercaderia: dato?.nombre,
      faltaCosto: esVentaDeMercaderia && _costoVenta(m, dato) <= 0,
    );
  }

  // --- Los esquemas ---

  /// Reconocimiento, costo de venta y cobro. Sin costo no hay asiento 2: no
  /// se inventa lo que costó la mercadería.
  List<EtapaAsiento> _venta(
    Movimiento m,
    ReglaAsiento regla,
    DatoMercaderia? dato,
  ) {
    final esMercaderia = dato?.esMercaderia ?? true;
    final cuentasCosto = _costosVentaPorCuenta(m, dato);
    final costo = cuentasCosto.values.fold(0, (s, monto) => s + monto);
    final nombre = _nombreVenta(m, dato);
    final baseVenta = m.exportacion ? m.centavos : m.baseCentavos;
    final efectivo = ReglasAsiento.efectivoDe(m.medio);

    // Cuenta de ventas según destino y vínculo (decisión 12)
    final cuentaVentas = regla.resultado!;
    final etapas = [
      EtapaAsiento(
        tipo: EtapaTipo.reconocimiento,
        glosa: esMercaderia
            ? 'Por la venta de ${nombre ?? 'mercadería'}'
            : 'Por la venta del servicio',
        lineas: [
          _linea(
            regla.contrapartida,
            debe: m.centavos,
            porQue:
                'Lo que el cliente te debe por la venta, con IGV, hasta que '
                'te paga.',
          ),
          if (m.tieneIgv && !m.exportacion)
            _linea(
              ReglasAsiento.igv,
              haber: m.igvCentavos,
              porQue: 'El IGV que le cobras al cliente: se lo debes al Estado.',
            ),
          _linea(
            cuentaVentas,
            haber: baseVenta,
            porQue: 'La venta sin IGV: es tu ingreso.',
          ),
        ],
      ),
      if (esMercaderia && costo > 0)
        EtapaAsiento(
          tipo: EtapaTipo.costoDeVenta,
          glosa: 'Por el costo de venta${nombre == null ? '' : ' ($nombre)'}',
          lineas: [
            for (final entrada in cuentasCosto.entries)
              if (entrada.value > 0)
                _linea(
                  entrada.key,
                  debe: entrada.value,
                  porQue: 'Lo que te costó la mercadería que vendiste.',
                ),
            _linea(
              ReglasAsiento.mercaderias,
              haber: costo,
              porQue: 'La mercadería sale del almacén, a su costo.',
            ),
          ],
        ),
      EtapaAsiento(
        tipo: EtapaTipo.pagoOCobro,
        glosa: 'Por el cobro al cliente',
        lineas: [
          _linea(efectivo, debe: m.centavos, porQue: _entra(efectivo)),
          _linea(
            regla.contrapartida,
            haber: m.centavos,
            porQue: 'El cliente pagó: se cancela lo que te debía.',
          ),
        ],
      ),
    ];
    return etapas;
  }

  /// Reconocimiento, variación de inventarios y pago. El asiento 2 va por la
  /// base, sin IGV: es lo que de verdad costó la mercadería.
  List<EtapaAsiento> _compra(
    Movimiento m,
    ReglaAsiento regla,
    DatoMercaderia? dato,
  ) {
    final nombre = dato?.nombre;
    final efectivo = ReglasAsiento.efectivoDe(m.medio);

    final etapas = [
      EtapaAsiento(
        tipo: EtapaTipo.reconocimiento,
        glosa: 'Por la compra de ${nombre ?? 'mercadería'}',
        lineas: [
          _linea(
            regla.resultado!,
            debe: m.baseCentavos,
            porQue: 'La compra de mercadería, sin IGV.',
          ),
          if (m.tieneIgv)
            _linea(
              ReglasAsiento.igv,
              debe: m.igvCentavos,
              porQue:
                  'El IGV que pagaste: lo descuentas del que le debes al '
                  'Estado.',
            ),
          _linea(
            regla.contrapartida,
            haber: m.centavos,
            porQue: 'Lo que le debes al proveedor hasta que le pagas.',
          ),
        ],
      ),
      EtapaAsiento(
        tipo: EtapaTipo.variacionInventarios,
        glosa:
            'Por la variación de inventarios'
            '${nombre == null ? '' : ' ($nombre)'}',
        lineas: [
          _linea(
            ReglasAsiento.mercaderias,
            debe: m.baseCentavos,
            porQue: 'La mercadería entra al almacén, a su costo.',
          ),
          _linea(
            ReglasAsiento.variacionDeInventarios,
            haber: m.baseCentavos,
            porQue:
                'La compra pasa al inventario: es la variación de '
                'existencias.',
          ),
        ],
      ),
      EtapaAsiento(
        tipo: EtapaTipo.pagoOCobro,
        glosa: 'Por el pago de la mercadería',
        lineas: [
          _linea(
            regla.contrapartida,
            debe: m.centavos,
            porQue: 'Le pagaste al proveedor: se cancela la deuda.',
          ),
          _linea(efectivo, haber: m.centavos, porQue: _sale(efectivo)),
        ],
      ),
    ];
    return etapas;
  }

  /// Reconocimiento, destino del gasto y pago.
  List<EtapaAsiento> _gasto(Movimiento m, ReglaAsiento regla) {
    final objeto = regla.objeto ?? 'de ${m.descripcionFormato}';
    final efectivo = ReglasAsiento.efectivoDe(m.medio);

    return [
      EtapaAsiento(
        tipo: EtapaTipo.reconocimiento,
        glosa: 'Por el registro $objeto',
        lineas: [
          _linea(
            regla.resultado!,
            debe: m.baseCentavos,
            porQue: 'El gasto sin IGV, en su cuenta según lo que es.',
          ),
          if (m.tieneIgv)
            _linea(
              ReglasAsiento.igv,
              debe: m.igvCentavos,
              porQue:
                  'El IGV que pagaste: lo descuentas del que le debes al '
                  'Estado.',
            ),
          _linea(
            regla.contrapartida,
            haber: m.centavos,
            porQue: 'Lo que debes por esto hasta que lo pagas.',
          ),
        ],
      ),
      EtapaAsiento(
        tipo: EtapaTipo.destinoDelGasto,
        glosa: 'Por el destino del gasto',
        lineas: [
          _linea(
            ReglasAsiento.destinoDelGasto,
            debe: m.baseCentavos,
            porQue: 'El gasto pasa a su destino: los gastos de operación.',
          ),
          _linea(
            ReglasAsiento.cargasImputables,
            haber: m.baseCentavos,
            porQue:
                'La contrapartida del destino: así el gasto no se cuenta dos '
                'veces.',
          ),
        ],
      ),
      EtapaAsiento(
        tipo: EtapaTipo.pagoOCobro,
        glosa: 'Por el pago $objeto',
        lineas: [
          _linea(
            regla.contrapartida,
            debe: m.centavos,
            porQue: 'Pagaste: se cancela la deuda.',
          ),
          _linea(efectivo, haber: m.centavos, porQue: _sale(efectivo)),
        ],
      ),
    ];
  }

  /// Reconocimiento y cobro. Un ingreso no se destina.
  List<EtapaAsiento> _otroIngreso(Movimiento m, ReglaAsiento regla) {
    final objeto = regla.objeto ?? 'de ${m.descripcionFormato}';
    final efectivo = ReglasAsiento.efectivoDe(m.medio);

    return [
      EtapaAsiento(
        tipo: EtapaTipo.reconocimiento,
        glosa: 'Por el registro $objeto',
        lineas: [
          _linea(
            regla.contrapartida,
            debe: m.centavos,
            porQue: 'Lo que te deben por este ingreso hasta que lo cobras.',
          ),
          if (m.tieneIgv)
            _linea(
              ReglasAsiento.igv,
              haber: m.igvCentavos,
              porQue: 'El IGV que cobras: se lo debes al Estado.',
            ),
          _linea(
            regla.resultado!,
            haber: m.baseCentavos,
            porQue: 'El ingreso sin IGV.',
          ),
        ],
      ),
      EtapaAsiento(
        tipo: EtapaTipo.pagoOCobro,
        glosa: 'Por el cobro $objeto',
        lineas: [
          _linea(efectivo, debe: m.centavos, porQue: _entra(efectivo)),
          _linea(
            regla.contrapartida,
            haber: m.centavos,
            porQue: 'Se cobró: se cancela lo que te debían.',
          ),
        ],
      ),
    ];
  }

  /// Un solo asiento: se cancela lo que ya se debía.
  EtapaAsiento _pago(Movimiento m, ReglaAsiento regla, bool esAjuste) {
    final efectivo = ReglasAsiento.efectivoDe(m.medio);
    return EtapaAsiento(
      tipo: EtapaTipo.pagoOCobro,
      glosa:
          regla.glosa ??
          'Por el pago ${regla.objeto ?? 'de ${m.descripcionFormato}'}',
      lineas: [
        _linea(
          regla.contrapartida,
          debe: m.centavos,
          porQue: esAjuste
              ? 'Faltó plata al contar la caja: es un gasto.'
              : 'Se paga algo que ya se debía: se cancela la deuda.',
        ),
        _linea(efectivo, haber: m.centavos, porQue: _sale(efectivo)),
      ],
    );
  }

  /// Un solo asiento: se cobra lo que ya se tenía por cobrar.
  EtapaAsiento _cobro(Movimiento m, ReglaAsiento regla, bool esAjuste) {
    final efectivo = ReglasAsiento.efectivoDe(m.medio);
    final porQue = esAjuste
        ? 'Sobró plata al contar la caja: es un ingreso.'
        : switch (regla.contrapartida) {
            ReglasAsiento.porCobrar =>
              'El cliente te pagó lo que te debía: se cancela la cuenta.',
            ReglasAsiento.anticiposRecibidos =>
              'El adelanto que te dio el cliente: se lo debes hasta '
                  'entregarle lo que compró.',
            _ => 'Se cobra algo que ya te debían.',
          };
    return EtapaAsiento(
      tipo: EtapaTipo.pagoOCobro,
      glosa:
          regla.glosa ??
          'Por el cobro ${regla.objeto ?? 'de ${m.descripcionFormato}'}',
      lineas: [
        _linea(efectivo, debe: m.centavos, porQue: _entra(efectivo)),
        _linea(regla.contrapartida, haber: m.centavos, porQue: porQue),
      ],
    );
  }

  // --- Asientos de operaciones de almacén (no pasan por caja) ---

  /// Genera asientos para devoluciones, merma, desmedro y ajuste.
  ///
  /// Estas operaciones no tienen movimiento de caja asociado (movimientoId == null)
  /// y se registran directamente en el almacén. Cada una genera un asiento
  /// independiente.
  List<AsientoDiario> asientosAlmacen({
    required int siguienteCorrelativo,
    required DateTime desde,
    required DateTime hasta,
  }) {
    if (datos?.lineasAlmacen == null || datos!.lineasAlmacen!.isEmpty) {
      return [];
    }

    final kardex = datos!.kardex;
    if (kardex == null) return [];

    final lineas = datos!.lineasAlmacen!
        .where(
          (l) =>
              l.movimientoId == null &&
              !l.anulada &&
              !l.fecha.isBefore(desde) &&
              !l.fecha.isAfter(hasta),
        )
        .toList();

    if (lineas.isEmpty) return [];

    // Agrupar por operación y día para generar un asiento por operación
    final Map<String, List<LineaAlmacen>> porOperacion = {};
    for (final l in lineas) {
      final key =
          '${l.operacion.name}-${l.fecha.year}-${l.fecha.month}-${l.fecha.day}-${l.numero}';
      porOperacion.putIfAbsent(key, () => []).add(l);
    }

    var correlativo = siguienteCorrelativo;
    final asientos = <AsientoDiario>[];

    for (final grupo in porOperacion.values) {
      grupo.sort((a, b) => a.numero.compareTo(b.numero));
      final primera = grupo.first;
      final etapas = _asientoOperacionAlmacen(primera, grupo, kardex);
      if (etapas.isNotEmpty) {
        asientos.add(
          AsientoDiario(
            correlativo: correlativo++,
            fecha: primera.fecha,
            etapas: etapas,
            origen: _movimientoSintetico(primera),
            documento: _comprobanteTexto(primera),
            codigoLibro: null,
            mercaderia: _nombreMercaderia(primera.mercaderiaId),
          ),
        );
      }
    }

    return asientos;
  }

  List<EtapaAsiento> _asientoOperacionAlmacen(
    LineaAlmacen primera,
    List<LineaAlmacen> grupo,
    Kardex kardex,
  ) {
    final op = primera.operacion;

    return switch (op) {
      OperacionAlmacen.devolucionRecibida => _asientoDevolucionRecibida(
        grupo,
        kardex,
      ),
      OperacionAlmacen.devolucionEntregada => _asientoDevolucionEntregada(
        grupo,
        kardex,
      ),
      OperacionAlmacen.merma => _asientoMerma(grupo, kardex),
      OperacionAlmacen.desmedro => _asientoDesmedro(grupo, kardex),
      OperacionAlmacen.ajuste => _asientoAjuste(grupo, kardex),
      OperacionAlmacen.saldoInicial => [], // Se maneja en asientoApertura
      _ => [],
    };
  }

  List<EtapaAsiento> _asientoDevolucionRecibida(
    List<LineaAlmacen> lineas,
    Kardex kardex,
  ) {
    if (lineas.isEmpty) return [];

    // Devolución de un cliente: entra mercadería a costo de la venta original
    // Debe: 20111 Mercaderías (costo de la devolución)
    // Haber: 1212 / 4212 según el caso, o 70121 si es nota de crédito
    // Pero en el libro diario: entra a 20111 y sale de la cuenta de clientes
    var totalCosto = 0;
    final costosPorCuenta = <String, int>{};
    final productos = <String>[];

    for (final l in lineas) {
      final costo = kardex.costoDe(l.id);
      totalCosto += costo;
      final origen = _lineaOrigen(l.origenId);
      final cuentaCosto = origen?.cuentaCosto ?? ReglasAsiento.costoDeVentas;
      costosPorCuenta[cuentaCosto] =
          (costosPorCuenta[cuentaCosto] ?? 0) + costo;
      final nombre = _nombreMercaderia(l.mercaderiaId);
      if (!productos.contains(nombre)) productos.add(nombre);
    }

    if (totalCosto <= 0) return [];
    final glosa =
        'Por devolución de cliente${productos.isEmpty ? '' : ' (${productos.join(', ')})'}';

    return [
      EtapaAsiento(
        tipo: EtapaTipo.reconocimiento,
        glosa: glosa,
        lineas: [
          _linea(
            ReglasAsiento.mercaderias,
            debe: totalCosto,
            porQue: 'La mercadería devuelta entra al almacén a su costo.',
          ),
          for (final entrada in costosPorCuenta.entries)
            if (entrada.value > 0)
              _linea(
                entrada.key,
                haber: entrada.value,
                porQue: 'Se revierte el costo de la venta devuelta.',
              ),
        ],
      ),
    ];
  }

  List<EtapaAsiento> _asientoDevolucionEntregada(
    List<LineaAlmacen> lineas,
    Kardex kardex,
  ) {
    if (lineas.isEmpty) return [];

    // Devolución a un proveedor: sale mercadería al costo original de la compra
    // Debe: 4212 Proveedores (se le debe menos al proveedor)
    // Haber: 20111 Mercaderías (sale del almacén a su costo)
    var totalCosto = 0;
    final productos = <String>[];

    for (final l in lineas) {
      final costo = kardex.costoDe(l.id);
      totalCosto += costo;
      final nombre = _nombreMercaderia(l.mercaderiaId);
      if (!productos.contains(nombre)) productos.add(nombre);
    }

    if (totalCosto <= 0) return [];
    final glosa =
        'Por devolución a proveedor${productos.isEmpty ? '' : ' (${productos.join(', ')})'}';

    return [
      EtapaAsiento(
        tipo: EtapaTipo.reconocimiento,
        glosa: glosa,
        lineas: [
          _linea(
            ReglasAsiento.porPagarComercial,
            debe: totalCosto,
            porQue: 'Se reduce la deuda con el proveedor por la devolución.',
          ),
          _linea(
            ReglasAsiento.mercaderias,
            haber: totalCosto,
            porQue: 'La mercadería sale del almacén a su costo original.',
          ),
        ],
      ),
    ];
  }

  List<EtapaAsiento> _asientoMerma(List<LineaAlmacen> lineas, Kardex kardex) {
    if (lineas.isEmpty) return [];

    // Merma: pérdida de mercadería por causas propias de su naturaleza.
    // Debe: 6951 Mercaderías (gastos por deterioro de inventarios)
    // Haber: 20111 Mercaderías
    var totalCosto = 0;
    final productos = <String>[];

    for (final l in lineas) {
      final costo = kardex.costoDe(l.id);
      totalCosto += costo;
      final nombre = _nombreMercaderia(l.mercaderiaId);
      if (!productos.contains(nombre)) productos.add(nombre);
    }

    if (totalCosto <= 0) return [];
    final glosa =
        'Por merma${productos.isEmpty ? '' : ' (${productos.join(', ')})'}${lineas.first.glosa.isEmpty ? '' : ': ${lineas.first.glosa}'}';

    return [
      EtapaAsiento(
        tipo: EtapaTipo.costoDeVenta,
        glosa: glosa,
        lineas: [
          _linea(
            ReglasAsiento.deterioroDeMercaderias,
            debe: totalCosto,
            porQue: 'La merma es un gasto por deterioro de inventarios.',
          ),
          _linea(
            ReglasAsiento.mercaderias,
            haber: totalCosto,
            porQue: 'La mercadería sale del almacén por merma.',
          ),
        ],
      ),
    ];
  }

  List<EtapaAsiento> _asientoDesmedro(
    List<LineaAlmacen> lineas,
    Kardex kardex,
  ) {
    if (lineas.isEmpty) return [];

    // Desmedro: pérdida de calidad que deja la mercadería inutilizable.
    // Debe: 6951 Mercaderías (gastos por deterioro de inventarios)
    // Haber: 20111 Mercaderías
    var totalCosto = 0;
    final productos = <String>[];

    for (final l in lineas) {
      final costo = kardex.costoDe(l.id);
      totalCosto += costo;
      final nombre = _nombreMercaderia(l.mercaderiaId);
      if (!productos.contains(nombre)) productos.add(nombre);
    }

    if (totalCosto <= 0) return [];
    final glosa =
        'Por desmedro${productos.isEmpty ? '' : ' (${productos.join(', ')})'}${lineas.first.glosa.isEmpty ? '' : ': ${lineas.first.glosa}'}';

    return [
      EtapaAsiento(
        tipo: EtapaTipo.costoDeVenta,
        glosa: glosa,
        lineas: [
          _linea(
            ReglasAsiento.deterioroDeMercaderias,
            debe: totalCosto,
            porQue: 'El desmedro es un gasto por deterioro de inventarios.',
          ),
          _linea(
            ReglasAsiento.mercaderias,
            haber: totalCosto,
            porQue: 'La mercadería sale del almacén por desmedro.',
          ),
        ],
      ),
    ];
  }

  List<EtapaAsiento> _asientoAjuste(List<LineaAlmacen> lineas, Kardex kardex) {
    if (lineas.isEmpty) return [];

    // Ajuste por conteo: puede ser entrada (sobrante) o salida (faltante)
    // Entrada: Debe 20111 / Haber 7599 Otros ingresos de gestión
    // Salida: Debe 6593 Otros gastos de gestión / Haber 20111
    var totalEntrada = 0;
    var totalSalida = 0;
    final productos = <String>[];

    for (final l in lineas) {
      final costo = kardex.costoDe(l.id);
      if (l.entrada) {
        totalEntrada += costo;
      } else {
        totalSalida += costo;
      }
      final nombre = _nombreMercaderia(l.mercaderiaId);
      if (!productos.contains(nombre)) productos.add(nombre);
    }

    final glosa =
        'Por ajuste por conteo${productos.isEmpty ? '' : ' (${productos.join(', ')})'}${lineas.first.glosa.isEmpty ? '' : ': ${lineas.first.glosa}'}';

    final etapas = <EtapaAsiento>[];

    if (totalEntrada > 0) {
      etapas.add(
        EtapaAsiento(
          tipo: EtapaTipo.variacionInventarios,
          glosa: glosa,
          lineas: [
            _linea(
              ReglasAsiento.mercaderias,
              debe: totalEntrada,
              porQue: 'El sobrante de conteo entra al almacén.',
            ),
            _linea(
              ReglasAsiento.otrosIngresosDeGestion,
              haber: totalEntrada,
              porQue: 'El sobrante se reconoce como ingreso de gestión.',
            ),
          ],
        ),
      );
    }

    if (totalSalida > 0) {
      etapas.add(
        EtapaAsiento(
          tipo: EtapaTipo.costoDeVenta,
          glosa: glosa,
          lineas: [
            _linea(
              ReglasAsiento.otrosGastosDeGestion,
              debe: totalSalida,
              porQue:
                  'El faltante de conteo se reconoce como gasto de gestión.',
            ),
            _linea(
              ReglasAsiento.mercaderias,
              haber: totalSalida,
              porQue: 'El faltante sale del almacén.',
            ),
          ],
        ),
      );
    }

    return etapas;
  }

  /// Asiento de apertura: caja, banco y mercaderías contra 50 Capital.
  AsientoDiario? asientoApertura({required int siguienteCorrelativo}) {
    // El inventario inicial es la suma de los saldos iniciales (operación
    // 16) tal como se anotaron. No es el saldo del kardex al cierre del
    // primer día: ese ya incluye las compras y ventas de ese día, que tienen
    // sus propios asientos.
    final valorMercaderias = (datos?.lineasAlmacen ?? const <LineaAlmacen>[])
        .where(
          (l) => !l.anulada && l.operacion == OperacionAlmacen.saldoInicial,
        )
        .fold(0, (t, l) => t + (l.costoTotal ?? 0));
    if (negocio.saldoInicialCaja == 0 &&
        negocio.saldoInicialBanco == 0 &&
        valorMercaderias == 0) {
      return null;
    }

    // Determinar cuenta de capital: 5011 Acciones (S.A.) o 5012 Participaciones (E.I.R.L., S.R.L.)
    final formaJuridica = negocio.razonSocial.toUpperCase().replaceAll(
      RegExp(r'[^A-Z]'),
      '',
    );
    final esSRL = formaJuridica.contains('SRL');
    final esEIRL = formaJuridica.contains('EIRL');
    final cuentaCapital = (esSRL || esEIRL) ? '5012' : '5011';

    final lineas = <LineaDiario>[];
    var totalHaber = 0;

    if (negocio.saldoInicialCaja > 0) {
      lineas.add(
        _linea(
          ReglasAsiento.caja,
          debe: negocio.saldoInicialCaja,
          porQue: 'Saldo inicial de caja.',
        ),
      );
      totalHaber += negocio.saldoInicialCaja;
    }

    if (negocio.saldoInicialBanco > 0) {
      lineas.add(
        _linea(
          ReglasAsiento.banco,
          debe: negocio.saldoInicialBanco,
          porQue: 'Saldo inicial de banco.',
        ),
      );
      totalHaber += negocio.saldoInicialBanco;
    }

    if (valorMercaderias > 0) {
      lineas.add(
        _linea(
          ReglasAsiento.mercaderias,
          debe: valorMercaderias,
          porQue: 'Inventario inicial de mercaderías.',
        ),
      );
      totalHaber += valorMercaderias;
    }

    if (lineas.isEmpty) return null;

    lineas.add(
      _linea(
        cuentaCapital,
        haber: totalHaber,
        porQue: 'Capital inicial del negocio.',
      ),
    );

    return AsientoDiario(
      correlativo: siguienteCorrelativo,
      fecha: fechaDeApertura(negocio),
      etapas: [
        EtapaAsiento(
          tipo: EtapaTipo.reconocimiento,
          glosa: 'Asiento de apertura del período',
          lineas: lineas,
        ),
      ],
      origen: _movimientoSinteticoApertura(),
      documento: null,
      codigoLibro: null,
      mercaderia: null,
      faltaCosto: false,
    );
  }

  // --- Cálculo de costos y cuentas ---

  /// Obtiene el costo de venta para un movimiento.
  ///
  /// Si hay kardex y líneas de almacén, usa el costo del kardex.
  /// Si no, usa el costo guardado en el movimiento (legacy).
  int _costoVenta(Movimiento m, DatoMercaderia? dato) {
    final kardex = _kardex;
    final lineasAlmacen = _lineasAlmacen;
    if (kardex != null && lineasAlmacen != null) {
      final lineasVenta = lineasAlmacen
          .where(
            (l) =>
                l.movimientoId == m.id && l.operacion == OperacionAlmacen.venta,
          )
          .where((l) => !l.anulada)
          .toList();
      if (lineasVenta.isNotEmpty) {
        return lineasVenta.fold(0, (s, l) => s + kardex.costoDe(l.id));
      }
    }

    // Las ventas anteriores a las líneas de almacén conservan su costo.
    final costoGuardado = m.costoCentavos;
    if (costoGuardado != null && costoGuardado > 0) return costoGuardado;
    return dato?.costoCentavos ?? 0;
  }

  Map<String, int> _costosVentaPorCuenta(Movimiento m, DatoMercaderia? dato) {
    final kardex = _kardex;
    final lineasAlmacen = _lineasAlmacen;
    final lineasVenta =
        lineasAlmacen
            ?.where(
              (l) =>
                  !l.anulada &&
                  l.movimientoId == m.id &&
                  l.operacion == OperacionAlmacen.venta,
            )
            .toList() ??
        const <LineaAlmacen>[];
    if (kardex != null && lineasVenta.isNotEmpty) {
      final porCuenta = <String, int>{};
      for (final linea in lineasVenta) {
        final cuenta = linea.cuentaCosto ?? _cuentaCostoDeVenta(m);
        porCuenta[cuenta] = (porCuenta[cuenta] ?? 0) + kardex.costoDe(linea.id);
      }
      return porCuenta;
    }

    final costo = _costoVenta(m, dato);
    return costo > 0 ? {_cuentaCostoDeVenta(m): costo} : const {};
  }

  String? _nombreVenta(Movimiento m, DatoMercaderia? dato) {
    final lineasVenta =
        _lineasAlmacen
            ?.where(
              (l) =>
                  !l.anulada &&
                  l.movimientoId == m.id &&
                  l.operacion == OperacionAlmacen.venta,
            )
            .toList() ??
        const <LineaAlmacen>[];
    final nombres = <String>[];
    for (final linea in lineasVenta) {
      final nombre = _nombreMercaderia(linea.mercaderiaId);
      if (!nombres.contains(nombre)) nombres.add(nombre);
    }
    if (nombres.isNotEmpty) return nombres.join(', ');
    return dato?.nombre ?? m.mercaderiaNombre;
  }

  LineaAlmacen? _lineaOrigen(String? id) {
    if (id == null) return null;
    for (final linea in _lineasAlmacen ?? const <LineaAlmacen>[]) {
      if (linea.id == id) return linea;
    }
    return null;
  }

  /// Cuenta de costo de venta según exportación y vínculo (decisión 12).
  String _cuentaCostoDeVenta(Movimiento m) {
    return ReglasMercaderia.cuentaCostoDeVenta(
      exportacion: m.exportacion,
      vinculo: m.vinculo,
    );
  }

  Kardex? get _kardex => datos?.kardex;
  List<LineaAlmacen>? get _lineasAlmacen => datos?.lineasAlmacen;

  // --- Helpers ---

  LineaDiario _linea(
    String codigo, {
    int debe = 0,
    int haber = 0,
    required String porQue,
  }) => LineaDiario(
    cadena: _cadena(codigo),
    debe: debe,
    haber: haber,
    porQue: porQue,
  );

  List<CuentaDiario> _cadena(String codigo) {
    final cadena = <CuentaDiario>[
      for (final cuenta in pcge.cadena(codigo))
        CuentaDiario(cuenta.codigo, cuenta.nombre),
    ];
    if (cadena.isEmpty || cadena.last.codigo != codigo) {
      cadena.add(CuentaDiario(codigo, pcge.denominacion(codigo)));
    }
    return cadena;
  }

  String? _documento(Movimiento m) {
    if (m.numeroBoleta != null) {
      return Boleta(negocio: negocio, movimiento: m).numero;
    }
    if (m.numeroRecibo != null) {
      return 'Recibo ${Recibo(negocio: negocio, movimiento: m).numero}';
    }
    final operacion = m.numeroTransaccion?.trim() ?? '';
    if (m.enBanco && operacion.isNotEmpty) return 'Oper. $operacion';
    return null;
  }

  static String _entra(String efectivo) => efectivo == ReglasAsiento.caja
      ? 'Entra efectivo a la caja.'
      : 'Entra plata al banco.';

  static String _sale(String efectivo) => efectivo == ReglasAsiento.caja
      ? 'Sale efectivo de la caja.'
      : 'Sale plata del banco.';

  String _nombreMercaderia(String id) {
    final m = datos?.mercaderias?.firstWhere(
      (m) => m.id == id,
      orElse: () => Mercaderia(id: id, nombre: id, creadoEn: DateTime.now()),
    );
    return m?.nombre ?? id;
  }

  /// Movimiento sintético para operaciones de almacén (sin movimiento de caja).
  /// Necesario porque AsientoDiario.origen no puede ser null (tests usan a.origen.id).
  Movimiento _movimientoSintetico(LineaAlmacen linea) {
    return Movimiento(
      id: 'almacen-${linea.id}',
      numero: 0,
      tipo: linea.entrada ? Tipo.entro : Tipo.salio,
      centavos: linea.costoTotal ?? 0,
      categoriaId: 'mercaderia',
      concepto: linea.glosa.isEmpty
          ? _etiquetaOperacion(linea.operacion)
          : linea.glosa,
      medio: MedioPago.efectivo,
      fecha: linea.fecha,
      creadoEn: linea.fecha,
      actualizadoEn: linea.fecha,
      cuentaAsociada: null,
      igvCentavos: 0,
      mercaderiaId: linea.mercaderiaId,
      mercaderiaNombre: _nombreMercaderia(linea.mercaderiaId),
      costoCentavos: linea.costoTotal,
      eliminadoEn: linea.anulada ? linea.fecha : null,
      sync: EstadoSync.local,
    );
  }

  String _etiquetaOperacion(OperacionAlmacen op) => switch (op) {
    OperacionAlmacen.venta => 'Venta',
    OperacionAlmacen.compra => 'Compra',
    OperacionAlmacen.devolucionRecibida => 'Devolución de un cliente',
    OperacionAlmacen.devolucionEntregada => 'Devolución a un proveedor',
    OperacionAlmacen.merma => 'Merma',
    OperacionAlmacen.desmedro => 'Desmedro',
    OperacionAlmacen.saldoInicial => 'Saldo inicial',
    OperacionAlmacen.ajuste => 'Ajuste por conteo',
  };

  String _comprobanteTexto(LineaAlmacen linea) {
    final tipo = linea.docTipo;
    final serie = linea.docSerie;
    final numero = linea.docNumero;
    if (tipo == null) return '';
    if (serie == null || serie.isEmpty) return numero ?? '';
    if (numero == null || numero.isEmpty) return serie;
    return '$serie-$numero';
  }

  /// Movimiento sintético para el asiento de apertura.
  Movimiento _movimientoSinteticoApertura() {
    return Movimiento(
      id: 'apertura',
      numero: 0,
      tipo: Tipo.entro,
      centavos: negocio.saldoInicialCaja + negocio.saldoInicialBanco,
      categoriaId: 'apertura',
      concepto: 'Apertura del período',
      medio: MedioPago.efectivo,
      fecha: negocio.inicioPeriodo ?? DateTime.now(),
      creadoEn: DateTime.now(),
      actualizadoEn: DateTime.now(),
      cuentaAsociada: null,
      igvCentavos: 0,
      sync: EstadoSync.local,
    );
  }
}
