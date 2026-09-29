import 'enums.dart';
import 'movimiento.dart';
import 'negocio.dart';
import 'pcge.dart';

/// Una fila del formato oficial, ya lista para imprimirse.
///
/// Los montos siguen en centavos enteros: recién se convierten a texto al
/// dibujarlos. Un formato que redondea antes de sumar es un formato que no
/// cuadra.
class FilaFormato {
  const FilaFormato({
    this.numero,
    this.fecha,
    required this.descripcion,
    this.codigoCuenta,
    this.denominacion,
    this.deudor = 0,
    this.acreedor = 0,
    this.medioTabla1,
    this.contraparte,
    this.numeroTransaccion,
  });

  /// N° DE OPER. La fila del saldo inicial también lleva número: en el Excel
  /// es la 1.
  final int? numero;
  final DateTime? fecha;
  final String descripcion;

  final String? codigoCuenta;
  final String? denominacion;

  /// DEUDOR (+) y ACREEDOR (-), en centavos. Uno de los dos es siempre cero.
  final int deudor;
  final int acreedor;

  // --- Sólo el Formato 1.2 ---

  /// Código de la Tabla 1 de SUNAT.
  final String? medioTabla1;
  final String? contraparte;
  final String? numeroTransaccion;
}

/// Una línea del asiento resumen que va al Libro Diario.
class LineaAsiento {
  const LineaAsiento({
    required this.codigo,
    required this.denominacion,
    this.debe = 0,
    this.haber = 0,
  });

  final String codigo;
  final String denominacion;
  final int debe;
  final int haber;
}

/// El asiento resumen del mes: los bloques "RESUMEN COBROS" y "RESUMEN PAGOS"
/// que el Excel pone debajo del formato y copia a la hoja LD CAJA.
///
/// No es un detalle del formato, es el puente al Libro Diario: el libro de
/// caja registra cada operación, y el diario recibe un solo asiento por mes con
/// el total.
class AsientoResumen {
  const AsientoResumen({
    required this.numero,
    required this.titulo,
    required this.glosa,
    required this.lineas,
  });

  /// "1.1" / "1.2", como los numera la hoja LD CAJA.
  final String numero;

  /// "RESUMEN COBROS DE CAJA".
  final String titulo;

  /// "Por los cobros del mes de septiembre de 2026".
  final String glosa;

  final List<LineaAsiento> lineas;

  int get totalDebe => lineas.fold(0, (s, l) => s + l.debe);
  int get totalHaber => lineas.fold(0, (s, l) => s + l.haber);

  /// Un asiento que no cuadra está mal armado. Se expone para poder probarlo
  /// y para que la pantalla lo avise en vez de imprimir algo torcido.
  bool get cuadra => totalDebe == totalHaber;

  bool get vacio => lineas.isEmpty || totalDebe == 0;
}

/// El Formato 1.1 (caja) o 1.2 (cuenta corriente) de un período, armado a
/// partir de los movimientos.
///
/// Reproduce el cuadre del Excel tal cual:
///
/// ```
/// SUBTOTAL     = saldo inicial + sumas de cada columna
/// SALDO FINAL  = la diferencia, puesta en la columna contraria
/// TOTALES      = subtotal + saldo final   → las dos columnas dan igual
/// ```
///
/// Que el saldo final vaya cruzado no es un truco de planilla: es la partida
/// doble. El efectivo que queda en el cajón al cierre es un saldo deudor, y
/// para cerrar la cuenta se lo abona.
class LibroOficial {
  LibroOficial._({
    required this.cuenta,
    required this.negocio,
    required this.desde,
    required this.hasta,
    required this.saldoInicial,
    required this.filas,
    required this.resumenCobros,
    required this.resumenPagos,
  });

  final Cuenta cuenta;
  final Negocio negocio;

  /// El período que cubre, de la primera a la última hora del rango.
  final DateTime desde;
  final DateTime hasta;

  /// Con cuánto abre el período: el saldo de apertura del negocio más todo lo
  /// que se movió antes de `desde`. Sin arrastrar lo anterior, cada mes
  /// empezaría de nuevo y el libro no sería un libro.
  final int saldoInicial;

  /// El saldo inicial y las operaciones, en orden de fecha.
  final List<FilaFormato> filas;

  final AsientoResumen resumenCobros;
  final AsientoResumen resumenPagos;

  String get titulo => cuenta == Cuenta.caja
      ? 'FORMATO 1.1: "LIBRO CAJA Y BANCOS - DETALLE DE LOS MOVIMIENTOS DEL '
            'EFECTIVO"'
      : 'FORMATO 1.2: "LIBRO CAJA Y BANCOS - DETALLE DE LOS MOVIMIENTOS DE LA '
            'CUENTA CORRIENTE"';

  /// El rótulo de la esquina: "101 CAJA" / "1041 C.C. Operativas".
  String get rotuloCuenta =>
      '${cuenta.codigoPcge}  ${Pcge.instancia.denominacion(cuenta.codigoPcge)}';

  int get subtotalDeudor => filas.fold(0, (s, f) => s + f.deudor);
  int get subtotalAcreedor => filas.fold(0, (s, f) => s + f.acreedor);

  /// La diferencia, en la columna contraria a la que pesa más.
  int get saldoFinalDeudor =>
      subtotalAcreedor > subtotalDeudor ? subtotalAcreedor - subtotalDeudor : 0;
  int get saldoFinalAcreedor =>
      subtotalDeudor > subtotalAcreedor ? subtotalDeudor - subtotalAcreedor : 0;

  int get totalDeudor => subtotalDeudor + saldoFinalDeudor;
  int get totalAcreedor => subtotalAcreedor + saldoFinalAcreedor;

  /// Las dos columnas tienen que dar lo mismo. Por construcción siempre pasa;
  /// se expone para probarlo y para que la pantalla lo pueda afirmar.
  bool get cuadra => totalDeudor == totalAcreedor;

  /// Lo que queda al cierre. Es el saldo final con el signo natural del
  /// negocio: positivo cuando hay plata.
  int get saldoDeCierre => subtotalDeudor - subtotalAcreedor;

  /// Sólo está el saldo inicial: no hubo movimientos en el período.
  bool get sinOperaciones => filas.length <= 1;

  /// Arma el formato de una cuenta para un rango de fechas.
  ///
  /// `movimientos` puede venir completo y sin ordenar: acá se filtra por cuenta
  /// y por período, y se ordena por fecha. Así la pantalla no tiene que
  /// preparar nada.
  static LibroOficial armar({
    required Cuenta cuenta,
    required Negocio negocio,
    required List<Movimiento> movimientos,
    required DateTime desde,
    required DateTime hasta,
  }) {
    final inicio = DateTime(desde.year, desde.month, desde.day);
    final fin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59, 999);

    final deLaCuenta = movimientos
        .where(
          (m) =>
              !m.eliminado &&
              m.cuenta == cuenta &&
              (negocio.inicioPeriodo == null ||
                  !m.fecha.isBefore(negocio.inicioPeriodo!)),
        )
        .toList();

    // Todo lo anterior al período se arrastra al saldo de apertura.
    final saldoInicial = deLaCuenta
        .where((m) => m.fecha.isBefore(inicio))
        .fold(
          negocio.inicioPeriodo != null && fin.isBefore(negocio.inicioPeriodo!)
              ? 0
              : negocio.saldoInicialDe(cuenta == Cuenta.caja),
          (s, m) => s + m.efectoEnSaldo,
        );

    final delPeriodo =
        deLaCuenta
            .where((m) => !m.fecha.isBefore(inicio) && !m.fecha.isAfter(fin))
            .toList()
          ..sort((a, b) {
            final porFecha = a.fecha.compareTo(b.fecha);
            // Con la misma fecha manda el correlativo: es el orden en que se
            // anotaron, y el formato tiene que leerse en ese orden.
            return porFecha != 0 ? porFecha : a.numero.compareTo(b.numero);
          });

    final pcge = Pcge.instancia;

    final filas = <FilaFormato>[
      FilaFormato(
        numero: 1,
        fecha: inicio,
        descripcion: 'Saldo Inicial',
        // El saldo de apertura va del lado que le toca por su signo: si el
        // período abre en rojo, abre por el acreedor.
        deudor: saldoInicial >= 0 ? saldoInicial : 0,
        acreedor: saldoInicial < 0 ? -saldoInicial : 0,
      ),
      for (var i = 0; i < delPeriodo.length; i++)
        () {
          final m = delPeriodo[i];
          final codigo = m.cuentaDelFormato;
          return FilaFormato(
            numero: i + 2, // la 1 es el saldo inicial
            fecha: m.fecha,
            descripcion: m.descripcionFormato,
            codigoCuenta: codigo,
            denominacion: pcge.denominacion(codigo),
            deudor: m.tipo == Tipo.entro ? m.centavos : 0,
            acreedor: m.tipo == Tipo.salio ? m.centavos : 0,
            medioTabla1: m.medio.codigoTabla1,
            contraparte: m.contraparte,
            numeroTransaccion: m.numeroTransaccion,
          );
        }(),
    ];

    return LibroOficial._(
      cuenta: cuenta,
      negocio: negocio,
      desde: inicio,
      hasta: fin,
      saldoInicial: saldoInicial,
      filas: filas,
      resumenCobros: _resumen(
        movimientos: delPeriodo,
        cuenta: cuenta,
        tipo: Tipo.entro,
        pcge: pcge,
      ),
      resumenPagos: _resumen(
        movimientos: delPeriodo,
        cuenta: cuenta,
        tipo: Tipo.salio,
        pcge: pcge,
      ),
    );
  }

  /// El asiento resumen de un lado: un solo renglón de caja por el total, y
  /// enfrente las cuentas asociadas agrupadas.
  ///
  /// Agrupar es lo que lo vuelve un resumen: veinte ventas del mes entran al
  /// diario como una línea de 1212, no como veinte.
  static AsientoResumen _resumen({
    required List<Movimiento> movimientos,
    required Cuenta cuenta,
    required Tipo tipo,
    required Pcge pcge,
  }) {
    final delTipo = movimientos.where((m) => m.tipo == tipo);

    final porCuenta = <String, int>{};
    for (final m in delTipo) {
      porCuenta.update(
        m.cuentaDelFormato,
        (v) => v + m.centavos,
        ifAbsent: () => m.centavos,
      );
    }

    final total = porCuenta.values.fold(0, (s, v) => s + v);
    final esCaja = cuenta == Cuenta.caja;
    final cobro = tipo == Tipo.entro;

    final lineaPropia = LineaAsiento(
      codigo: cuenta.codigoPcge,
      denominacion: pcge.denominacion(cuenta.codigoPcge),
      // Cobrar carga la cuenta de efectivo; pagar la abona.
      debe: cobro ? total : 0,
      haber: cobro ? 0 : total,
    );

    // Las cuentas asociadas van del lado contrario al del efectivo. Se ordenan
    // por código para que el asiento salga siempre igual.
    final contrapartidas = [
      for (final codigo in porCuenta.keys.toList()..sort())
        LineaAsiento(
          codigo: codigo,
          denominacion: pcge.denominacion(codigo),
          debe: cobro ? 0 : porCuenta[codigo]!,
          haber: cobro ? porCuenta[codigo]! : 0,
        ),
    ];

    final donde = esCaja ? 'DE CAJA' : 'BANCARIOS';

    return AsientoResumen(
      numero: cobro ? '1.1' : '1.2',
      titulo: cobro ? 'RESUMEN COBROS $donde' : 'RESUMEN PAGOS $donde',
      glosa: cobro ? 'Por los cobros del mes' : 'Por los pagos del mes',
      // El renglón de efectivo va primero cuando es cargo y último cuando es
      // abono: así se lee "debe / haber" de arriba abajo, como un asiento.
      lineas: cobro
          ? [lineaPropia, ...contrapartidas]
          : [...contrapartidas, lineaPropia],
    );
  }

  /// Los dos asientos que se copian al Libro Diario, ya sin los vacíos.
  List<AsientoResumen> get asientos =>
      [resumenCobros, resumenPagos].where((a) => !a.vacio).toList();
}
