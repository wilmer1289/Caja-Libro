/// El importe escrito con palabras, como lo pide el recibo de caja.
///
/// La hoja INGRESOS CAJA del Excel lo escribe así:
/// "UN MIL SETECIENTOS SETENTA Y 00/100 SOLES".
///
/// No es un adorno: el monto en letras es lo que impide que a un recibo se le
/// agregue un cero a mano después de firmado. Por eso los céntimos van como
/// fracción —00/100— y no como palabras: es la forma en que se lee de golpe si
/// alguien los cambió.
class MontoEnLetras {
  /// Del 0 al 29 cada número tiene su palabra propia; de ahí en adelante se
  /// arman. El 1 va apocopado ("UN") porque siempre precede a "SOLES".
  static const _unidades = <String>[
    '',
    'UN',
    'DOS',
    'TRES',
    'CUATRO',
    'CINCO',
    'SEIS',
    'SIETE',
    'OCHO',
    'NUEVE',
    'DIEZ',
    'ONCE',
    'DOCE',
    'TRECE',
    'CATORCE',
    'QUINCE',
    'DIECISÉIS',
    'DIECISIETE',
    'DIECIOCHO',
    'DIECINUEVE',
    'VEINTE',
    'VEINTIÚN',
    'VEINTIDÓS',
    'VEINTITRÉS',
    'VEINTICUATRO',
    'VEINTICINCO',
    'VEINTISÉIS',
    'VEINTISIETE',
    'VEINTIOCHO',
    'VEINTINUEVE',
  ];

  static const _decenas = <String>[
    '',
    '',
    '',
    'TREINTA',
    'CUARENTA',
    'CINCUENTA',
    'SESENTA',
    'SETENTA',
    'OCHENTA',
    'NOVENTA',
  ];

  static const _centenas = <String>[
    '',
    'CIENTO',
    'DOSCIENTOS',
    'TRESCIENTOS',
    'CUATROCIENTOS',
    'QUINIENTOS',
    'SEISCIENTOS',
    'SETECIENTOS',
    'OCHOCIENTOS',
    'NOVECIENTOS',
  ];

  /// Un recibo de caja de una bodega no llega a mil millones; si llegara, es
  /// más honesto devolver el número que una frase equivocada.
  static const _tope = 999999999;

  static String _hasta999(int n) {
    // "CIEN" sólo cuando es exacto: 100 es CIEN, 101 es CIENTO UNO.
    if (n == 100) return 'CIEN';

    final centena = n ~/ 100;
    final resto = n % 100;
    final partes = <String>[];

    if (centena > 0) partes.add(_centenas[centena]);
    if (resto > 0) {
      if (resto < 30) {
        partes.add(_unidades[resto]);
      } else {
        final decena = resto ~/ 10;
        final unidad = resto % 10;
        partes.add(
          unidad == 0
              ? _decenas[decena]
              : '${_decenas[decena]} Y ${_unidades[unidad]}',
        );
      }
    }

    return partes.join(' ');
  }

  static String _entero(int n) {
    if (n == 0) return 'CERO';

    final millones = n ~/ 1000000;
    final resto = n % 1000000;
    final miles = resto ~/ 1000;
    final cientos = resto % 1000;
    final partes = <String>[];

    if (millones == 1) {
      partes.add('UN MILLÓN');
    } else if (millones > 1) {
      partes.add('${_hasta999(millones)} MILLONES');
    }

    // "MIL" va solo: se dice MIL DOSCIENTOS, no UN MIL DOSCIENTOS.
    if (miles == 1) {
      partes.add('MIL');
    } else if (miles > 1) {
      partes.add('${_hasta999(miles)} MIL');
    }

    if (cientos > 0) partes.add(_hasta999(cientos));

    return partes.join(' ');
  }

  /// "MIL SETECIENTOS SETENTA Y 00/100 SOLES", a partir de centavos enteros.
  static String soles(int centavos) {
    final signo = centavos < 0 ? 'MENOS ' : '';
    final absoluto = centavos.abs();
    final enteros = absoluto ~/ 100;
    final fraccion = absoluto % 100;

    if (enteros > _tope) return '$signo$enteros Y $fraccion/100 SOLES';

    final letras = _entero(enteros);
    final centimos = fraccion.toString().padLeft(2, '0');
    return '$signo$letras Y $centimos/100 SOLES';
  }
}
