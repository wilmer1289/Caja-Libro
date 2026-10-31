import 'boleta.dart';
import 'inventario.dart';
import 'movimiento.dart';
import 'negocio.dart';
import 'pcge.dart';
import 'recibo.dart';
import 'reglas_asiento.dart';

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
  });

  final Negocio negocio;
  final DateTime desde;
  final DateTime hasta;

  /// En orden de fecha y, el mismo día, en el orden en que se anotaron.
  final List<AsientoDiario> asientos;

  int get totalDebe => asientos.fold(0, (s, a) => s + a.totalDebe);
  int get totalHaber => asientos.fold(0, (s, a) => s + a.totalHaber);

  bool get cuadra => totalDebe == totalHaber && asientos.every((a) => a.cuadra);

  bool get vacio => asientos.isEmpty;

  /// Arma el libro de un rango de fechas.
  ///
  /// `movimientos` puede venir completo y sin ordenar: acá se filtran los
  /// borrados, lo anterior a la apertura del negocio y lo que cae fuera del
  /// rango. `mercaderia` dice qué tipo se compró o vendió y con qué costo;
  /// `ajustes` son los ids de los movimientos con que se llevaron al libro
  /// los faltantes y sobrantes de caja.
  static LibroDiario armar({
    required Negocio negocio,
    required List<Movimiento> movimientos,
    required DateTime desde,
    required DateTime hasta,
    LeerMercaderia mercaderia = sinDatoDeMercaderia,
    Set<String> ajustes = const {},
  }) {
    final inicio = DateTime(desde.year, desde.month, desde.day);
    final fin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59, 999);
    final apertura = negocio.inicioPeriodo;

    final delPeriodo =
        movimientos
            .where(
              (m) =>
                  !m.eliminado &&
                  (apertura == null || !m.fecha.isBefore(apertura)) &&
                  !m.fecha.isBefore(inicio) &&
                  !m.fecha.isAfter(fin),
            )
            .toList()
          ..sort((a, b) {
            final porFecha = a.fecha.compareTo(b.fecha);
            return porFecha != 0 ? porFecha : a.numero.compareTo(b.numero);
          });

    final armador = _Armador(Pcge.instancia, negocio, mercaderia, ajustes);
    return LibroDiario._(
      negocio: negocio,
      desde: inicio,
      hasta: fin,
      asientos: [
        for (var i = 0; i < delPeriodo.length; i++)
          armador.asiento(i + 1, delPeriodo[i]),
      ],
    );
  }
}

/// Convierte un movimiento en sus etapas. Está aparte para que cada esquema
/// se lea de corrido, línea por línea, como en el Excel.
class _Armador {
  _Armador(this.pcge, this.negocio, this.leer, this.ajustes);

  final Pcge pcge;
  final Negocio negocio;
  final LeerMercaderia leer;
  final Set<String> ajustes;

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
      faltaCosto: esVentaDeMercaderia && (dato?.costoCentavos ?? 0) <= 0,
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
    final nombre = dato?.nombre;
    final costo = dato?.costoCentavos ?? 0;
    final efectivo = ReglasAsiento.efectivoDe(m.medio);

    return [
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
          if (m.tieneIgv)
            _linea(
              ReglasAsiento.igv,
              haber: m.igvCentavos,
              porQue: 'El IGV que le cobras al cliente: se lo debes al Estado.',
            ),
          _linea(
            regla.resultado!,
            haber: m.baseCentavos,
            porQue: 'La venta sin IGV: es tu ingreso.',
          ),
        ],
      ),
      if (esMercaderia && costo > 0)
        EtapaAsiento(
          tipo: EtapaTipo.costoDeVenta,
          glosa: 'Por el costo de venta${nombre == null ? '' : ' ($nombre)'}',
          lineas: [
            _linea(
              ReglasAsiento.costoDeVentas,
              debe: costo,
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

    return [
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

  // --- Piezas ---

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

  /// La cuenta con todas las que la contienen, de arriba a abajo: en el PCGE
  /// cada cuenta es prefijo de sus hijas, así que la cadena sale del código.
  List<CuentaDiario> _cadena(String codigo) {
    final cadena = <CuentaDiario>[
      for (final cuenta in pcge.cadena(codigo))
        CuentaDiario(cuenta.codigo, cuenta.nombre),
    ];
    // Una cuenta que no está en el catálogo igual se muestra, con su código.
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
    // Sin boleta ni recibo, lo que sustenta una operación por banco es su
    // voucher: se cita por su N° de operación.
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
}
