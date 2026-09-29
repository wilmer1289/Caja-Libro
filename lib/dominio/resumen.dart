import 'enums.dart';
import 'movimiento.dart';

/// Los números grandes del dashboard (§3.2). Todo en centavos.
class Resumen {
  const Resumen({
    required this.saldoCaja,
    required this.saldoBanco,
    required this.entroMes,
    required this.salioMes,
    this.cantidadEntroMes = 0,
    this.cantidadSalioMes = 0,
  });

  final int saldoCaja;
  final int saldoBanco;
  final int entroMes;
  final int salioMes;

  /// Cuántos movimientos hubo, no cuánta plata: "3 ingresos este mes" dice
  /// algo que el monto solo no dice.
  final int cantidadEntroMes;
  final int cantidadSalioMes;

  int get saldoTotal => saldoCaja + saldoBanco;

  /// Qué parte de lo que entró este mes ya salió, de 0 a 1 (o más, si salió
  /// más de lo que entró). Null si no entró nada: ahí no hay proporción que
  /// calcular, y mostrar "0%" o "∞" confundiría.
  double? get proporcionGastada => entroMes == 0 ? null : salioMes / entroMes;

  /// El mes va bien si entró al menos lo que salió.
  bool get flujoPositivo => entroMes >= salioMes;

  static const vacio = Resumen(
    saldoCaja: 0,
    saldoBanco: 0,
    entroMes: 0,
    salioMes: 0,
  );

  /// Se calcula en memoria sobre los movimientos vivos. Con los volúmenes de
  /// una bodega (unos miles de filas al año) alcanza de sobra; si algún día
  /// crece, el mismo cálculo se baja a SQL sin tocar la UI.
  factory Resumen.de(
    List<Movimiento> movimientos, {
    DateTime? ahora,
    int saldoInicialCaja = 0,
    int saldoInicialBanco = 0,
    DateTime? inicioPeriodo,
  }) {
    final hoy = ahora ?? DateTime.now();
    final manana = DateTime(hoy.year, hoy.month, hoy.day + 1);
    // Se arranca del saldo con que abrió el libro, no de cero: es la primera
    // línea del Formato 1.1 y ningún negocio empieza en cero.
    var caja = saldoInicialCaja, banco = saldoInicialBanco;
    var entro = 0, salio = 0;
    var cuantosEntro = 0, cuantosSalio = 0;

    for (final m in movimientos) {
      if (m.eliminado) continue;
      if (!m.fecha.isBefore(manana) ||
          (inicioPeriodo != null && m.fecha.isBefore(inicioPeriodo))) {
        continue;
      }

      if (m.cuenta == Cuenta.caja) {
        caja += m.efectoEnSaldo;
      } else {
        banco += m.efectoEnSaldo;
      }

      final esDelMes = m.fecha.year == hoy.year && m.fecha.month == hoy.month;
      if (esDelMes) {
        if (m.tipo == Tipo.entro) {
          entro += m.centavos;
          cuantosEntro++;
        } else {
          salio += m.centavos;
          cuantosSalio++;
        }
      }
    }

    return Resumen(
      saldoCaja: caja,
      saldoBanco: banco,
      entroMes: entro,
      salioMes: salio,
      cantidadEntroMes: cuantosEntro,
      cantidadSalioMes: cuantosSalio,
    );
  }
}
