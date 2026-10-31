/// Lo que se pudo leer de un voucher: la captura de un Yape, la constancia de
/// una transferencia, la foto de un depósito.
///
/// El texto lo saca el lector de la cámara (en el celular) o el de Windows (en
/// la computadora); esto sólo lo interpreta. Cada banco arma su voucher a su
/// manera, así que no se busca un formato fijo sino las palabras que todos
/// usan: "monto", "N° de operación", "S/".
///
/// Lo que no se entiende queda en null. Nunca se inventa un dato: un N° de
/// operación mal leído es peor que uno vacío.
class LecturaVoucher {
  const LecturaVoucher({
    this.centavos,
    this.fecha,
    this.numeroOperacion,
    this.nombre,
    this.banco,
    this.texto = '',
  });

  /// El monto de la operación, sin la comisión ni el ITF.
  final int? centavos;

  /// El día de la operación, sin la hora.
  final DateTime? fecha;
  final String? numeroOperacion;

  /// A quién se le pagó o quién pagó, según el voucher.
  final String? nombre;

  /// "Yape", "Plin", "BCP"…: de qué app o banco es el voucher.
  final String? banco;

  /// El texto completo que se leyó, por si hay que revisarlo.
  final String texto;

  bool get vacia =>
      centavos == null &&
      fecha == null &&
      numeroOperacion == null &&
      nombre == null &&
      banco == null;

  factory LecturaVoucher.de(String texto) {
    final lineas = _parearColumnas(
      _unirMontosPartidos(
        texto
            .split(RegExp(r'\r?\n'))
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList(),
      ),
    );
    return LecturaVoucher(
      centavos: _monto(lineas),
      fecha: _fecha(lineas),
      numeroOperacion: _numeroOperacion(lineas),
      nombre: _nombre(lineas),
      banco: _banco(texto),
      texto: texto,
    );
  }

  // --- El monto ---

  static final _soles = RegExp(
    r'(?:S\s*/\s*\.?|PEN)\s*(\d[\d.,\s]*\d|\d)',
    caseSensitive: false,
  );

  /// Las líneas que tienen un monto que no es el de la operación.
  static const _noEsElMonto = [
    'comisi',
    'itf',
    'saldo',
    'disponible',
    'cargo',
    'tipo de cambio',
    'limite',
  ];

  /// Las que lo anuncian.
  static const _anunciaMonto = [
    'monto',
    'importe',
    'total',
    'transferid',
    'yapeaste',
    'te yape',
    'plineaste',
    'pagaste',
    'enviaste',
    'recibiste',
    'depositad',
    'exitos',
  ];

  /// El OCR a veces deja "S/" en una línea y "50.00" en la siguiente.
  static List<String> _unirMontosPartidos(List<String> lineas) {
    final unidas = <String>[];
    for (var i = 0; i < lineas.length; i++) {
      final l = lineas[i];
      if (RegExp(r'^S\s*/\s*\.?$', caseSensitive: false).hasMatch(l) &&
          i + 1 < lineas.length &&
          RegExp(r'^\d[\d.,\s]*$').hasMatch(lineas[i + 1])) {
        unidas.add('S/ ${lineas[i + 1]}');
        i++;
      } else {
        unidas.add(l);
      }
    }
    return unidas;
  }

  /// Un rótulo solo, sin su valor: "Fecha", "N° de operación", "Cliente".
  static final _rotuloSolo = RegExp(
    r'^(fecha(\s+y\s+hora)?|hora|'
    r'(n\s*[°ºo]?\.?|nro\.?|numero|codigo|cod\.?)\s*de\s+(la\s+)?(operacion|transaccion)|'
    r'cliente|destinatario|beneficiario|titular|remitente|origen|destino|'
    r'banco(\s+de)?(\s+(origen|destino))?|'
    r'cuenta(\s+de)?(\s+(origen|destino|cargo|abono))?|'
    r'comision|monto(\s+(transferido|total|enviado))?|'
    r'importe(\s+(transferido|total))?|concepto|tipo\s+de\s+operacion|'
    r'dni|ruc|dni\s*/\s*ruc|itf|moneda|para|de)\s*:?$',
  );

  /// Los vouchers de dos columnas: el lector de Windows (y a veces el del
  /// celular) devuelve primero todos los rótulos y después todos los valores.
  /// Si vienen dos o más rótulos seguidos, se emparejan con las líneas que
  /// les siguen, en orden: "Fecha" con "15/10/2026", "N° de operación" con
  /// "04512378".
  static List<String> _parearColumnas(List<String> lineas) {
    bool rotulo(String l) => _rotuloSolo.hasMatch(_sinTildes(l.toLowerCase()));
    final salida = <String>[];
    var i = 0;
    while (i < lineas.length) {
      var fin = i;
      while (fin < lineas.length && rotulo(lineas[fin])) {
        fin++;
      }
      final cuantos = fin - i;
      if (cuantos >= 2 && fin + cuantos <= lineas.length) {
        for (var j = 0; j < cuantos; j++) {
          salida.add('${lineas[i + j]}: ${lineas[fin + j]}');
        }
        i = fin + cuantos;
      } else if (cuantos > 0) {
        salida.addAll(lineas.sublist(i, fin));
        i = fin;
      } else {
        salida.add(lineas[i]);
        i++;
      }
    }
    return salida;
  }

  static int? _monto(List<String> lineas) {
    final candidatos = <({int centavos, bool anunciado})>[];
    for (var i = 0; i < lineas.length; i++) {
      final linea = _sinTildes(lineas[i].toLowerCase());
      if (_noEsElMonto.any(linea.contains)) continue;
      final anterior = i > 0 ? _sinTildes(lineas[i - 1].toLowerCase()) : '';
      final anunciado =
          _anunciaMonto.any(linea.contains) ||
          (_anunciaMonto.any(anterior.contains) &&
              !_noEsElMonto.any(anterior.contains));
      for (final m in _soles.allMatches(lineas[i])) {
        final c = centavosDe(m.group(1)!);
        if (c != null && c > 0) {
          candidatos.add((centavos: c, anunciado: anunciado));
        }
      }
    }
    if (candidatos.isEmpty) return null;
    final anunciado = candidatos.where((c) => c.anunciado);
    if (anunciado.isNotEmpty) return anunciado.first.centavos;
    // Sin una palabra que lo anuncie, el más grande: la comisión y el ITF
    // siempre son menores que la operación.
    return candidatos.map((c) => c.centavos).reduce((a, b) => a > b ? a : b);
  }

  /// "1,250.50", "1.250,50", "50", "50.5" → centavos. Null si no es un monto.
  ///
  /// El separador decimal es el último punto o coma seguido de uno o dos
  /// dígitos; los demás separan miles.
  static int? centavosDe(String crudo) {
    final s = crudo.replaceAll(RegExp(r'\s'), '');
    final decimal = RegExp(r'^(.*?)[.,](\d{1,2})$').firstMatch(s);
    final entero = (decimal?.group(1) ?? s).replaceAll(RegExp(r'[.,]'), '');
    final centimos = (decimal?.group(2) ?? '00').padRight(2, '0');
    if (!RegExp(r'^\d{1,9}$').hasMatch(entero)) return null;
    return int.parse(entero) * 100 + int.parse(centimos);
  }

  // --- La fecha ---

  static const _meses = {
    'ene': 1,
    'feb': 2,
    'mar': 3,
    'abr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'ago': 8,
    'set': 9,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dic': 12,
  };

  static DateTime? _fecha(List<String> lineas) {
    final numerica = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4}|\d{2})\b');
    final conMes = RegExp(
      r'\b(\d{1,2})\s*(?:de\s+)?(ene|feb|mar|abr|may|jun|jul|ago|set|sep|oct|nov|dic)[a-z]*\.?\s*(?:de\s+|del\s+)?(\d{4})\b',
      caseSensitive: false,
    );
    for (final l in lineas) {
      final n = numerica.firstMatch(l);
      if (n != null) {
        final anio = int.parse(n.group(3)!);
        final f = _valida(
          int.parse(n.group(1)!),
          int.parse(n.group(2)!),
          anio < 100 ? 2000 + anio : anio,
        );
        if (f != null) return f;
      }
      final m = conMes.firstMatch(_sinTildes(l));
      if (m != null) {
        final f = _valida(
          int.parse(m.group(1)!),
          _meses[m.group(2)!.toLowerCase()]!,
          int.parse(m.group(3)!),
        );
        if (f != null) return f;
      }
    }
    return null;
  }

  static DateTime? _valida(int dia, int mes, int anio) {
    if (mes < 1 || mes > 12 || dia < 1 || anio < 2000 || anio > 2100) {
      return null;
    }
    final f = DateTime(anio, mes, dia);
    return f.month == mes ? f : null;
  }

  // --- El N° de operación ---

  /// "N° de operación", "Nro. de operación", "Número de operación", "Código
  /// de operación", "Operación N°", "N° de transacción", "Referencia".
  /// El lector a veces se come el "°": "N de operación" también vale.
  static final _rotuloOperacion = RegExp(
    r'(n\s*[°ºo]|nro|num|numero|cod|codigo|#)\.?\s*(de\s+)?(la\s+)?(operacion|transaccion|referencia|constancia)'
    r'|\bn\.?\s+de\s+(la\s+)?(operacion|transaccion)'
    r'|(operacion|transaccion)\s*(n\s*[°ºo]|nro|#)',
  );

  /// Un código de operación: al menos cuatro caracteres, con algún dígito, sin
  /// barras ni dos puntos (esos son fechas y horas).
  static final _codigo = RegExp(
    r'(?<![\w/:])([A-Za-z]*\d[A-Za-z\d-]{3,})(?![\w/:])',
  );

  static String? _numeroOperacion(List<String> lineas) {
    for (var i = 0; i < lineas.length; i++) {
      final linea = _sinTildes(lineas[i].toLowerCase());
      final rotulo = _rotuloOperacion.firstMatch(linea);
      if (rotulo == null) continue;
      // En la misma línea, después del rótulo; si no, en la siguiente.
      final resto = lineas[i].substring(rotulo.end.clamp(0, lineas[i].length));
      final enLinea = _codigo.firstMatch(resto);
      if (enLinea != null) return _limpiarCodigo(enLinea.group(1)!);
      for (var j = i + 1; j < lineas.length && j <= i + 2; j++) {
        final siguiente = _codigo.firstMatch(lineas[j]);
        if (siguiente != null && lineas[j].length <= 30) {
          return _limpiarCodigo(siguiente.group(1)!);
        }
      }
    }
    return null;
  }

  static String _limpiarCodigo(String c) => c.replaceAll(RegExp(r'-+$'), '');

  // --- El nombre ---

  /// Los rótulos que anuncian a la otra persona.
  static final _rotuloNombre = RegExp(
    r'^(para|destinatario|beneficiario|enviado a|cliente|titular|nombre|'
    r'de|origen|remitente|yapeaste a|pagaste a|recibiste de|empresa)\b\s*:?\s*',
  );

  static String? _nombre(List<String> lineas) {
    for (var i = 0; i < lineas.length; i++) {
      final linea = _sinTildes(lineas[i].toLowerCase());
      final rotulo = _rotuloNombre.firstMatch(linea);
      if (rotulo == null) continue;
      // "de" suelto es muy común ("de diciembre"): sólo vale con dos puntos.
      if (rotulo.group(1) == 'de' && !linea.startsWith(RegExp(r'de\s*:'))) {
        continue;
      }
      final resto = _limpiarNombre(lineas[i].substring(rotulo.end));
      if (_pareceNombre(resto)) return resto;
      if (resto.isEmpty && i + 1 < lineas.length) {
        final siguiente = _limpiarNombre(lineas[i + 1]);
        if (_pareceNombre(siguiente)) return siguiente;
      }
    }
    // Un Yape no rotula a nadie: el nombre va justo después del monto.
    final yape = lineas.indexWhere(
      (l) =>
          RegExp(r'yapeaste|te yape|plineaste')
              .hasMatch(_sinTildes(l.toLowerCase())),
    );
    if (yape >= 0) {
      for (var i = yape + 1; i < lineas.length && i <= yape + 4; i++) {
        if (_soles.hasMatch(lineas[i])) continue;
        final nombre = _limpiarNombre(lineas[i]);
        if (_pareceNombre(nombre)) return nombre;
      }
    }
    return null;
  }

  static const _noEsNombre = [
    'operaci',
    'monto',
    'importe',
    'fecha',
    'hora',
    'comisi',
    'cuenta',
    'destino',
    'exitos',
    'transfer',
    'yapeaste',
    'constancia',
    'detalle',
    'compartir',
  ];

  /// Sin los signos raros que deja el lector cuando duda de una letra.
  static String _limpiarNombre(String s) => s
      .replaceAll(RegExp(r"[^\p{L}\p{N}\s.,&'-]", unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _pareceNombre(String s) {
    final t = s.trim();
    if (t.length < 3 || t.length > 60) return false;
    final minus = _sinTildes(t.toLowerCase());
    if (_noEsNombre.any(minus.contains)) return false;
    if (_soles.hasMatch(t)) return false;
    final letras = RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]').allMatches(t).length;
    final digitos = RegExp(r'\d').allMatches(t).length;
    return letras >= 3 && digitos <= 2;
  }

  // --- El banco ---

  static String? _banco(String texto) {
    final t = _sinTildes(texto.toLowerCase());
    // Yape y Plin primero: el voucher de Yape también dice "BCP".
    if (RegExp(r'yape').hasMatch(t)) return 'Yape';
    if (RegExp(r'\bplin').hasMatch(t)) return 'Plin';
    if (t.contains('interbank')) return 'Interbank';
    if (t.contains('scotiabank')) return 'Scotiabank';
    if (t.contains('bbva')) return 'BBVA';
    if (t.contains('banco de la nacion')) return 'Banco de la Nación';
    if (t.contains('banbif')) return 'BanBif';
    if (t.contains('pichincha')) return 'Pichincha';
    if (RegExp(r'\bbcp\b').hasMatch(t) || t.contains('banco de credito')) {
      return 'BCP';
    }
    return null;
  }

  static String _sinTildes(String s) => s
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u');
}
