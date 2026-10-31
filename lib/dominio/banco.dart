import 'categoria.dart';
import 'enums.dart';

/// Los datos del voucher que pide el Libro Bancos (Formato 1.2).
///
/// En el Excel de la exposición cada transferencia trae su voucher, y de él
/// salen la descripción, el tercero, el N° de operación y la cuenta contable:
/// "Mercaderías, sucursal, letra" no es un texto suelto, es lo que decide que
/// el cobro vaya a la 1332 y no a la 1212.

/// Qué es el otro para el negocio.
///
/// Las relacionadas (matriz, filial, sucursal, asociada) tienen sus propias
/// cuentas en el PCGE: lo que se le cobra a una sucursal va en la 13 y no en
/// la 12, lo que se le debe a la matriz va en la 43 y no en la 42.
enum Vinculo {
  tercero('Público en general'),
  matriz('Matriz'),
  filial('Filial'),
  sucursal('Sucursal'),
  asociada('Asociada'),
  personal('Trabajador o socio');

  const Vinculo(this.etiqueta);
  final String etiqueta;

  bool get relacionada =>
      this == matriz || this == filial || this == sucursal || this == asociada;

  /// Cómo se nombra dentro de la descripción del formato, como en el Excel:
  /// "Mercaderías, sucursal, letra".
  String get enDescripcion => switch (this) {
    tercero => 'terceros',
    personal => 'trabajador o socio',
    _ => etiqueta.toLowerCase(),
  };

  /// Tolerante: lo que no se reconoce (o un movimiento de antes de la v8,
  /// que no lo tiene) es un tercero, que es lo que era hasta ahora.
  static Vinculo desdeBd(String? v) =>
      values.firstWhere((x) => x.name == v, orElse: () => tercero);
}

/// El papel que se cancela con el cobro o el pago.
enum DocumentoPago {
  factura('Factura o boleta'),
  letra('Letra');

  const DocumentoPago(this.etiqueta);
  final String etiqueta;

  static DocumentoPago desdeBd(String? v) =>
      values.firstWhere((x) => x.name == v, orElse: () => factura);
}

/// Dónde estaba el documento cuando se cobró. Sólo cuenta en los cobros: la
/// factura que el banco tenía en cobranza se cancela en la 1213, no en la
/// 1212.
enum Situacion {
  cartera('En cartera', 'La tenía el negocio y el cliente le pagó.'),
  cobranza('En cobranza', 'El banco la estaba cobrando por el negocio.'),
  descuento('En descuento', 'El banco ya había adelantado la plata.');

  const Situacion(this.etiqueta, this.ayuda);
  final String etiqueta;
  final String ayuda;

  static Situacion desdeBd(String? v) =>
      values.firstWhere((x) => x.name == v, orElse: () => cartera);
}

/// El Impuesto a las Transacciones Financieras.
///
/// No se anota en el libro: lo descuenta el banco y aparece en su estado de
/// cuenta. La app lo calcula para que el dueño sepa cuánto se le va en cada
/// operación y en el mes.
class Itf {
  Itf._();

  /// 0.005% del monto, truncado a múltiplos de cinco céntimos. Por eso una
  /// operación de menos de S/ 1,000 no paga nada: es lo que el Excel hace con
  /// su SI(monto > 1000).
  static int de(int centavos) => centavos <= 0 ? 0 : (centavos ~/ 100000) * 5;
}

/// Bancos y apps de pago, para elegir el del otro con una ficha.
class EntidadesBancarias {
  EntidadesBancarias._();

  static const apps = ['Yape', 'Plin'];

  static const bancos = [
    'BCP',
    'BBVA',
    'Interbank',
    'Scotiabank',
    'Banco de la Nación',
    'BanBif',
    'Pichincha',
    'Caja municipal',
    'Otro',
  ];

  /// Las que tienen sentido para el medio: un Yape viene de Yape o de Plin;
  /// una transferencia, de un banco.
  static List<String> para(MedioPago medio) =>
      medio == MedioPago.yape ? apps : bancos;

  /// Si dos nombres son el mismo banco: "BBVA" y "BBVA Banco Continental".
  static bool mismoBanco(String? a, String? b) {
    final x = _clave(a);
    final y = _clave(b);
    return x.isNotEmpty && y.isNotEmpty && (x.contains(y) || y.contains(x));
  }

  static String _clave(String? s) {
    final t = (s ?? '').toLowerCase();
    if (t.contains('crédito') || t.contains('credito') || t.contains('bcp')) {
      return 'bcp';
    }
    if (t.contains('bbva') || t.contains('continental')) return 'bbva';
    if (t.contains('nación') || t.contains('nacion')) return 'nacion';
    return t.replaceAll(RegExp(r'[^a-z]'), '');
  }

  /// "Tipo de operación", como lo dice el voucher del banco.
  ///
  /// Una transferencia a otro banco es interbancaria: viaja por la CCI y no
  /// llega al instante. Se deduce comparando el banco del otro con el del
  /// negocio; no hace falta preguntarlo.
  static String tipoOperacion(
    MedioPago medio, {
    String? bancoTercero,
    String? bancoNegocio,
  }) => switch (medio) {
    MedioPago.efectivo => 'Efectivo',
    MedioPago.yape => switch (bancoTercero) {
      'Yape' => 'Yape',
      'Plin' => 'Plin',
      _ => 'Yape / Plin',
    },
    MedioPago.transferencia =>
      bancoTercero == null ||
              (bancoNegocio ?? '').trim().isEmpty ||
              mismoBanco(bancoTercero, bancoNegocio)
          ? 'Transferencia'
          : 'Transferencia interbancaria',
    MedioPago.deposito => 'Depósito en cuenta',
    MedioPago.tarjeta => 'Pago con tarjeta de débito',
    MedioPago.tarjetaCredito => 'Pago con tarjeta de crédito',
    MedioPago.cheque => 'Cheque',
    MedioPago.otro => 'Otro medio',
  };
}

/// La cuenta del formato según la categoría, el vínculo y el documento.
///
/// Es la tabla que en el Excel arma el contador a mano, con las cuentas del
/// PCGE 2026 que trae la app:
///
/// | Cobro de…            | Tercero | Relacionada |
/// |----------------------|---------|-------------|
/// | factura en cartera   | 1212    | 1312        |
/// | factura en cobranza  | 1213    | 1313        |
/// | factura en descuento | 1214    | 1314        |
/// | letra en cartera     | 1232    | 1332        |
/// | letra en cobranza    | 1233    | 1333        |
/// | letra en descuento   | 1234    | 1334        |
///
/// | Pago de…             | Tercero | Relacionada |
/// |----------------------|---------|-------------|
/// | factura o boleta     | 4212    | 4312        |
/// | letra                | 423     | 4331        |
///
/// Las demás categorías traen su propia cuenta de relacionadas y de personal.
class ReglasCuenta {
  ReglasCuenta._();

  static String para(
    Categoria categoria, {
    Vinculo vinculo = Vinculo.tercero,
    DocumentoPago documento = DocumentoPago.factura,
    Situacion situacion = Situacion.cartera,
  }) {
    // La cuenta que el usuario eligió o creó es la que quiere ver impresa.
    if (categoria.pideCuenta || categoria.propia) {
      return categoria.cuentaAsociada;
    }
    final relacionada = vinculo.relacionada;
    final letra = documento == DocumentoPago.letra;

    switch (categoria.cuentaAsociada) {
      case '1212':
        final elemento = relacionada ? '13' : '12';
        final subcuenta = letra ? '3' : '1';
        // Cartera, cobranza y descuento son 2, 3 y 4 en las dos familias.
        return '$elemento$subcuenta${situacion.index + 2}';
      case '122':
        return relacionada ? '1321' : '122';
      case '4212':
        if (letra) return relacionada ? '4331' : '423';
        return relacionada ? '4312' : '4212';
    }

    if (vinculo == Vinculo.personal && categoria.cuentaPersonal != null) {
      return categoria.cuentaPersonal!;
    }
    if (relacionada && categoria.cuentaRelacionada != null) {
      return categoria.cuentaRelacionada!;
    }
    return categoria.cuentaAsociada;
  }

  /// La venta a una relacionada va a su propia cuenta de ingresos.
  static String ventaSegun(Vinculo vinculo, String cuentaVenta) =>
      vinculo.relacionada && cuentaVenta == '70121' ? '70122' : cuentaVenta;
}
