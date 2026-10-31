import 'banco.dart';
import 'enums.dart';
import 'movimiento.dart';

/// Qué forma tiene el asiento de una operación: cuántas etapas lleva y cuál
/// es la segunda.
///
/// Toda operación del Libro Diario sigue el mismo esquema de la exposición:
/// se reconoce el hecho, se le da su destino y se paga o se cobra. Lo que
/// cambia de una a otra es el asiento 2, y algunas no lo tienen.
enum Esquema {
  /// Reconocimiento, costo de venta (si se sabe el costo) y cobro.
  venta,

  /// Reconocimiento, variación de inventarios y pago.
  compraMercaderia,

  /// Reconocimiento, destino del gasto (91 contra 79) y pago.
  gasto,

  /// Reconocimiento y cobro: un ingreso no tiene destino.
  otroIngreso,

  /// Un solo asiento: el pago de algo que ya se debía.
  pago,

  /// Un solo asiento: el cobro de algo que ya se tenía por cobrar.
  cobro,
}

/// La regla de una operación: su esquema y las cuentas que usa.
class ReglaAsiento {
  const ReglaAsiento({
    required this.esquema,
    required this.contrapartida,
    this.resultado,
    this.objeto,
    this.glosa,
    this.delExcel = false,
  });

  final Esquema esquema;

  /// La cuenta del otro lado del efectivo: lo que se debe (4212, 4699,
  /// 4111…) o lo que se cobra (1212, 122). En un pago o un cobro sueltos, es
  /// la cuenta que se cancela.
  final String contrapartida;

  /// La cuenta de venta, de compra o de gasto (70121, 6011, 6352…). Null en
  /// los pagos y cobros sueltos.
  final String? resultado;

  /// Cómo se nombra en la glosa: con "del alquiler" salen "Por el registro
  /// del alquiler" y "Por el pago del alquiler".
  final String? objeto;

  /// La glosa entera, para las que no siguen el molde.
  final String? glosa;

  /// Viene de los ejemplos de la exposición. Las demás son propuestas que
  /// hay que confirmar con el docente.
  final bool delExcel;
}

/// Las cuentas del Libro Diario, en un solo lugar.
///
/// La referencia es el Excel de la exposición y su hoja PCGE 2026. Donde el
/// Excel no trae un ejemplo, se usa la cuenta de la categoría. Si el docente
/// corrige una cuenta, se corrige acá y en ningún otro sitio.
class ReglasAsiento {
  ReglasAsiento._();

  // --- Cuentas fijas ---

  static const caja = '101';

  /// Yape, transferencia, depósito y tarjetas: la misma cuenta que usa el
  /// Formato 1.2.
  static const banco = '1041';

  static const igv = '40111';
  static const porCobrar = '1212';
  static const anticiposRecibidos = '122';

  /// Venta local a terceros. El Excel se queda en 701; se baja hasta la
  /// cuenta final, igual que en el resto del libro.
  static const ventas = '70121';
  static const costoDeVentas = '69121';

  static const compras = '6011';
  static const mercaderias = '20111';
  static const variacionDeInventarios = '6111';

  static const porPagarComercial = '4212';

  /// La deuda de los servicios. En los ejemplos, alquiler y luz van en 46 y
  /// no en 42.
  static const porPagarDiversas = '4699';

  static const destinoDelGasto = '91';
  static const cargasImputables = '791';

  // --- Por categoría ---

  /// Los servicios: la deuda va en 4699 y el gasto tiene destino.
  static const _servicios = <String, String>{
    'alquiler': 'del alquiler',
    'luz': 'del servicio de luz',
    'agua': 'del servicio de agua',
    'internet': 'del servicio de internet',
    'telefono': 'del servicio de teléfono',
    'contable': 'del servicio contable',
    'servicios': 'de otros servicios',
  };

  /// Los dos que vienen en los ejemplos de la exposición.
  static const _serviciosDelExcel = {'alquiler', 'luz'};

  /// Gastos que no son servicios: la deuda va en la cuenta de su categoría
  /// (4212, 4111, 4031).
  static const _gastosConDeudaPropia = <String, String>{
    'suministros': 'de los suministros',
    'sueldos': 'de los sueldos',
    'essalud': 'de EsSalud',
  };

  /// Pagos de algo que ya se debía: no generan un gasto nuevo.
  static const _pagos = <String, String>{
    'proveedores': 'al proveedor',
    'onp': 'a la ONP',
    'afp': 'a la AFP',
    'otras_obligaciones': 'de otras obligaciones',
    'honorarios': 'de los honorarios',
    'compra_activo': 'del activo fijo comprado',
    'pago_prestamo': 'del préstamo',
    'dividendos_pago': 'de los dividendos',
  };

  /// Cobros de algo que ya se tenía por cobrar: no generan un ingreso nuevo.
  static const _cobros = <String, String>{
    'venta_activo': 'del activo fijo vendido',
    'cobro_prestamo': 'del préstamo',
    'dividendos_cobro': 'de los dividendos',
    'regalias': 'de las regalías',
  };

  /// La cuenta de efectivo según el medio: la caja o el banco.
  static String efectivoDe(MedioPago medio) =>
      medio.cuenta == Cuenta.caja ? caja : banco;

  /// Si una cuenta es un gasto por naturaleza (62 a 68), que en el PCGE se
  /// lleva a su destino (91) contra la 79. Las compras (60), la variación de
  /// inventarios (61) y el costo de ventas (69) no se destinan.
  static bool esGastoPorNaturaleza(String cuenta) {
    if (cuenta.length < 2 || !cuenta.startsWith('6')) return false;
    final elemento = int.tryParse(cuenta.substring(0, 2)) ?? 0;
    return elemento >= 62 && elemento <= 68;
  }

  /// Cómo se asienta un movimiento.
  ///
  /// `esAjuste` marca el faltante o el sobrante con que se cerró una caja: es
  /// plata que ya faltaba o sobraba en el cajón, así que va en un solo
  /// asiento contra la caja.
  static ReglaAsiento para(Movimiento m, {bool esAjuste = false}) {
    final categoria = m.categoria;
    final cuenta = m.cuentaDelFormato;

    if (esAjuste) {
      return m.tipo == Tipo.salio
          ? ReglaAsiento(
              esquema: Esquema.pago,
              contrapartida: cuenta,
              glosa: 'Por el faltante de caja',
            )
          : ReglaAsiento(
              esquema: Esquema.cobro,
              contrapartida: cuenta,
              glosa: 'Por el sobrante de caja',
            );
    }

    final objetoLibre = 'de ${m.descripcionFormato}';

    if (m.tipo == Tipo.entro) {
      switch (categoria.id) {
        // La contrapartida es la cuenta del formato: 1212 con un tercero,
        // 1312 con una relacionada, 1233 con una letra en cobranza. Así el
        // diario y el Libro Bancos dicen lo mismo.
        case 'ventas':
          return ReglaAsiento(
            esquema: Esquema.venta,
            contrapartida: cuenta,
            resultado: ReglasCuenta.ventaSegun(
              m.vinculo,
              categoria.cuentaResultado ?? ventas,
            ),
            delExcel: true,
          );
        case 'cobros_fiado':
          return ReglaAsiento(
            esquema: Esquema.cobro,
            contrapartida: cuenta,
            glosa: 'Por el cobro del fiado',
          );
        case 'anticipos':
          return ReglaAsiento(
            esquema: Esquema.cobro,
            contrapartida: cuenta,
            glosa: 'Por el adelanto del cliente',
          );
      }
      final cobro = _cobros[categoria.id];
      if (cobro != null) {
        return ReglaAsiento(
          esquema: Esquema.cobro,
          contrapartida: cuenta,
          objeto: cobro,
        );
      }
      // Otros ingresos y categorías propias: manda la cuenta elegida. Si es
      // un ingreso (7), se reconoce y se cobra; si no, se cobra directo.
      final resultado = cuenta.startsWith('7')
          ? cuenta
          : (categoria.cuentaResultado?.startsWith('7') ?? false)
          ? categoria.cuentaResultado
          : null;
      return resultado != null
          ? ReglaAsiento(
              esquema: Esquema.otroIngreso,
              contrapartida: porCobrar,
              resultado: resultado,
              objeto: objetoLibre,
            )
          : ReglaAsiento(
              esquema: Esquema.cobro,
              contrapartida: cuenta,
              objeto: objetoLibre,
            );
    }

    final id = categoria.id;
    if (id == 'mercaderia') {
      return ReglaAsiento(
        esquema: Esquema.compraMercaderia,
        contrapartida: cuenta,
        resultado: categoria.cuentaResultado ?? compras,
        delExcel: true,
      );
    }

    final servicio = _servicios[id];
    if (servicio != null && categoria.cuentaResultado != null) {
      return ReglaAsiento(
        esquema: Esquema.gasto,
        contrapartida: porPagarDiversas,
        resultado: categoria.cuentaResultado,
        objeto: servicio,
        delExcel: _serviciosDelExcel.contains(id),
      );
    }

    final gastoPropio = _gastosConDeudaPropia[id];
    if (gastoPropio != null && categoria.cuentaResultado != null) {
      return ReglaAsiento(
        esquema: Esquema.gasto,
        contrapartida: cuenta,
        resultado: categoria.cuentaResultado,
        objeto: gastoPropio,
      );
    }

    final pago = _pagos[id];
    if (pago != null) {
      return ReglaAsiento(
        esquema: Esquema.pago,
        contrapartida: cuenta,
        objeto: pago,
      );
    }

    // Otros egresos y categorías propias: si la cuenta elegida es un gasto,
    // se reconoce, se destina y se paga, como un servicio; si no (una deuda,
    // un activo), se paga directo.
    final gasto = esGastoPorNaturaleza(cuenta)
        ? cuenta
        : (categoria.cuentaResultado != null &&
              esGastoPorNaturaleza(categoria.cuentaResultado!))
        ? categoria.cuentaResultado
        : null;
    return gasto != null
        ? ReglaAsiento(
            esquema: Esquema.gasto,
            contrapartida: porPagarDiversas,
            resultado: gasto,
            objeto: objetoLibre,
          )
        : ReglaAsiento(
            esquema: Esquema.pago,
            contrapartida: cuenta,
            objeto: objetoLibre,
          );
  }
}
