import 'enums.dart';
import 'movimiento.dart';
import 'negocio.dart';

/// Qué parte de la plata se está mirando: toda, sólo el efectivo, sólo lo del
/// banco, o un medio en particular (sólo Yape / Plin, sólo transferencias…).
class Bolsillo {
  const Bolsillo._(this.cuenta, this.medio);

  /// Null = las dos cuentas.
  final Cuenta? cuenta;

  /// Null = todos los medios de la cuenta.
  final MedioPago? medio;

  static const todo = Bolsillo._(null, null);
  static const caja = Bolsillo._(Cuenta.caja, null);
  static const banco = Bolsillo._(Cuenta.banco, null);

  /// Un medio suelto. El efectivo es el único medio de la caja, así que
  /// "sólo efectivo" y "la caja" son el mismo bolsillo y se devuelve ese:
  /// si no, habría dos filtros que muestran exactamente lo mismo.
  factory Bolsillo.deMedio(MedioPago medio) =>
      medio.cuenta == Cuenta.caja ? caja : Bolsillo._(medio.cuenta, medio);

  bool incluye(Movimiento m) {
    final medio = this.medio;
    if (medio != null) return m.medio == medio;
    return cuenta == null || m.cuenta == cuenta;
  }

  String get etiqueta =>
      medio?.etiqueta ??
      switch (cuenta) {
        null => 'Todo',
        Cuenta.caja => 'Efectivo',
        Cuenta.banco => 'Banco / Digital',
      };

  /// Con cuánto arranca este bolsillo. El saldo de apertura del banco no se
  /// puede repartir entre Yape y transferencia —el negocio lo dio como un
  /// solo número—, así que un medio digital suelto arranca de cero.
  int saldoInicial(Negocio negocio) {
    if (medio != null) return 0;
    return switch (cuenta) {
      null => negocio.saldoInicialCaja + negocio.saldoInicialBanco,
      Cuenta.caja => negocio.saldoInicialCaja,
      Cuenta.banco => negocio.saldoInicialBanco,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Bolsillo && other.cuenta == cuenta && other.medio == medio;

  @override
  int get hashCode => Object.hash(cuenta, medio);
}

/// Lo que se movió por un medio de pago.
class TotalMedio {
  const TotalMedio({
    required this.medio,
    required this.entro,
    required this.salio,
    required this.cantidad,
  });

  final MedioPago medio;
  final int entro;
  final int salio;

  /// Cuántos movimientos, no cuánta plata.
  final int cantidad;

  /// Lo que dejó: puede ser negativo si por ese medio sólo se pagó (una
  /// tarjeta de débito, por ejemplo). No es que "haya" menos que cero en la
  /// tarjeta: es que por ahí salió más de lo que entró.
  int get neto => entro - salio;
}

/// Un renglón del libro mayor: el movimiento y el saldo que dejó.
class LineaMayor {
  const LineaMayor(this.movimiento, this.saldo);

  final Movimiento movimiento;
  final int saldo;
}

/// Caja y bancos en un solo libro, como la cuenta 10 del plan contable
/// ("Efectivo y equivalentes de efectivo"): cuánto hay en total, cuánto de
/// eso es efectivo y cuánto está en el banco, y por qué medio llegó o se fue.
///
/// Usa las mismas reglas que el resumen —sin borrados, sin fechas futuras, sin
/// lo anterior a la apertura— para que el total de acá y el "Lo que tienes
/// ahora" del inicio sean siempre el mismo número.
class LibroMayor {
  LibroMayor._(this.negocio, this._movimientos, this.porMedio);

  final Negocio negocio;

  /// Ordenados del más viejo al más nuevo: el orden en que se arman los
  /// saldos.
  final List<Movimiento> _movimientos;

  /// Sólo los medios que tuvieron movimiento, en el orden de `MedioPago`.
  final List<TotalMedio> porMedio;

  factory LibroMayor.armar(
    List<Movimiento> movimientos, {
    required Negocio negocio,
    DateTime? ahora,
  }) {
    final hoy = ahora ?? DateTime.now();
    final manana = DateTime(hoy.year, hoy.month, hoy.day + 1);
    final apertura = negocio.inicioPeriodo;

    final vigentes =
        movimientos
            .where(
              (m) =>
                  !m.eliminado &&
                  m.fecha.isBefore(manana) &&
                  (apertura == null || !m.fecha.isBefore(apertura)),
            )
            .toList()
          // Por fecha, y a igual fecha por número de operación: es el orden del
          // libro, y el que hace que el saldo de cada renglón sea el correcto.
          ..sort((a, b) {
            final porFecha = a.fecha.compareTo(b.fecha);
            if (porFecha != 0) return porFecha;
            final porNumero = a.numero.compareTo(b.numero);
            if (porNumero != 0) return porNumero;
            return a.creadoEn.compareTo(b.creadoEn);
          });

    final entro = <MedioPago, int>{};
    final salio = <MedioPago, int>{};
    final cuantos = <MedioPago, int>{};
    for (final m in vigentes) {
      final destino = m.tipo == Tipo.entro ? entro : salio;
      destino[m.medio] = (destino[m.medio] ?? 0) + m.centavos;
      cuantos[m.medio] = (cuantos[m.medio] ?? 0) + 1;
    }

    return LibroMayor._(negocio, vigentes, [
      for (final medio in MedioPago.values)
        if (cuantos.containsKey(medio))
          TotalMedio(
            medio: medio,
            entro: entro[medio] ?? 0,
            salio: salio[medio] ?? 0,
            cantidad: cuantos[medio]!,
          ),
    ]);
  }

  int get saldoInicialCaja => negocio.saldoInicialCaja;
  int get saldoInicialBanco => negocio.saldoInicialBanco;

  /// Lo que dejaron los medios de una cuenta, sin el saldo de apertura.
  int _netoDe(Cuenta cuenta) => porMedio
      .where((t) => t.medio.cuenta == cuenta)
      .fold(0, (suma, t) => suma + t.neto);

  int get saldoCaja => saldoInicialCaja + _netoDe(Cuenta.caja);
  int get saldoBanco => saldoInicialBanco + _netoDe(Cuenta.banco);
  int get total => saldoCaja + saldoBanco;

  /// Los medios digitales que tuvieron movimiento: el desglose de "Banco /
  /// Digital".
  ///
  /// Van **todos** los que se ofrecen al registrar —Yape / Plin,
  /// transferencia, depósito, débito y crédito—, aunque todavía no tengan
  /// movimientos: así se ve que existen y que están en cero, en vez de que
  /// "falten". Un medio viejo (cheque, "otro") sólo aparece si se usó.
  List<TotalMedio> get mediosBanco {
    final usados = {for (final t in porMedio) t.medio: t};
    return [
      for (final medio in MedioPago.values)
        if (medio.cuenta == Cuenta.banco &&
            (MedioPago.disponibles.contains(medio) ||
                usados.containsKey(medio)))
          usados[medio] ??
              TotalMedio(medio: medio, entro: 0, salio: 0, cantidad: 0),
    ];
  }

  /// El efectivo, si hubo algún movimiento en efectivo.
  TotalMedio? get efectivo {
    for (final t in porMedio) {
      if (t.medio == MedioPago.efectivo) return t;
    }
    return null;
  }

  int cantidadDe(Bolsillo bolsillo) =>
      _movimientos.where(bolsillo.incluye).length;

  /// Cuánto hay hoy en un bolsillo.
  int saldoDe(Bolsillo bolsillo) => _movimientos
      .where(bolsillo.incluye)
      .fold(bolsillo.saldoInicial(negocio), (s, m) => s + m.efectoEnSaldo);

  /// Los renglones del bolsillo, **del más nuevo al más viejo**, cada uno con
  /// el saldo que quedó después de él. Así se lee como un estado de cuenta:
  /// arriba, lo último y el saldo de hoy.
  List<LineaMayor> lineas(Bolsillo bolsillo) {
    var saldo = bolsillo.saldoInicial(negocio);
    final lineas = <LineaMayor>[];
    for (final m in _movimientos) {
      if (!bolsillo.incluye(m)) continue;
      saldo += m.efectoEnSaldo;
      lineas.add(LineaMayor(m, saldo));
    }
    return lineas.reversed.toList();
  }
}
