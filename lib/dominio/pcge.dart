import 'dart:convert';

import 'package:flutter/services.dart';

/// El Plan Contable General Empresarial 2023, tal como viene en el Excel del
/// curso: 1,776 cuentas de código a denominación.
///
/// Hace falta porque el Formato 1.1 pide, por cada operación, el **código** y
/// la **denominación** de la cuenta asociada. En el Excel eso lo resuelve un
/// `VLOOKUP` contra la hoja PCGE; acá es este catálogo.
///
/// Se carga una sola vez al arrancar y queda en memoria: son 61 KB, no vale
/// la pena ir al disco cada vez que se dibuja una fila.
class Pcge {
  Pcge._(this._cuentas);

  final Map<String, String> _cuentas;

  static Pcge? _instancia;

  /// El catálogo ya cargado. Revienta a propósito si se usa antes de
  /// `cargar()`: es un error de programación, no algo que deba pasar en
  /// silencio.
  static Pcge get instancia {
    final p = _instancia;
    if (p == null) {
      throw StateError('Hay que llamar a Pcge.cargar() antes de usarlo');
    }
    return p;
  }

  static Future<void> cargar() async {
    if (_instancia != null) return;
    final crudo = await rootBundle.loadString('assets/pcge.json');
    final mapa = (jsonDecode(crudo) as Map<String, dynamic>).map(
      (codigo, nombre) => MapEntry(codigo, nombre as String),
    );
    _instancia = Pcge._(mapa);
  }

  /// Para las pruebas, que no tienen bundle de assets.
  static void cargarDePrueba(Map<String, String> cuentas) {
    _instancia = Pcge._(cuentas);
  }

  /// La denominación de una cuenta. Si no está, devuelve el código mismo:
  /// una fila del libro con el código suelto es fea, pero es mejor que una
  /// pantalla caída.
  String denominacion(String codigo) => _cuentas[codigo] ?? codigo;

  bool existe(String codigo) => _cuentas.containsKey(codigo);

  /// El camino completo de la cuenta, armado con los códigos que la contienen:
  /// 70121 → "VENTAS > Mercaderías > Mercaderías - Venta local > Terceros".
  ///
  /// Se reconstruye de los propios códigos, sin guardar la jerarquía aparte:
  /// en el PCGE cada cuenta es prefijo de sus hijas.
  String ruta(String codigo) {
    final partes = <String>[];
    for (var largo = 2; largo <= codigo.length; largo++) {
      final nombre = _cuentas[codigo.substring(0, largo)];
      if (nombre != null) partes.add(nombre);
    }
    return partes.isEmpty ? denominacion(codigo) : partes.join(' › ');
  }

  /// La denominación con su padre, que es lo mínimo para que se entienda:
  /// "Terceros" solo no dice nada; "Mercaderías - Venta local › Terceros" sí.
  String denominacionConPadre(String codigo) {
    final partes = <String>[];
    for (var largo = 2; largo <= codigo.length; largo++) {
      final nombre = _cuentas[codigo.substring(0, largo)];
      if (nombre != null) partes.add(nombre);
    }
    if (partes.length <= 1) return denominacion(codigo);
    return partes.sublist(partes.length - 2).join(' › ');
  }

  /// Busca por código o por nombre, para el selector de cuentas del modo
  /// contador. Ordena los que empiezan con el texto antes que los que lo
  /// tienen en el medio.
  List<String> buscar(String texto, {int limite = 40}) {
    final q = texto.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final empiezan = <String>[];
    final contienen = <String>[];

    for (final entrada in _cuentas.entries) {
      final codigo = entrada.key;
      final nombre = entrada.value.toLowerCase();
      if (codigo.startsWith(q) || nombre.startsWith(q)) {
        empiezan.add(codigo);
      } else if (codigo.contains(q) || nombre.contains(q)) {
        contienen.add(codigo);
      }
      if (empiezan.length >= limite) break;
    }

    return [...empiezan, ...contienen].take(limite).toList();
  }

  /// Las cuentas que pueden ir como contrapartida de la plata que entra o
  /// sale, para el "¿En qué exactamente?" del formulario.
  ///
  /// - Sin tildes ni mayúsculas: se escribe "regalias" y aparece "Regalías".
  /// - Cada palabra escrita tiene que aparecer: "alquiler edif" encuentra
  ///   "Alquileres › Edificaciones".
  /// - Deja afuera lo que nunca es contrapartida: el efectivo mismo (10), las
  ///   cuentas de orden (0x) y los elementos de dos dígitos, que son títulos.
  /// - `primero` ordena por elemento: en una entrada van antes los ingresos
  ///   (7), en una salida los gastos (6). Nada se esconde, sólo se ordena.
  List<String> buscarContrapartida(
    String texto, {
    List<String> primero = const [],
    int limite = 8,
  }) {
    final palabras = _sinTildes(texto)
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (palabras.isEmpty) return const [];

    final hallados = <(int, int, String)>[];
    for (final entrada in _cuentas.entries) {
      final codigo = entrada.key;
      if (codigo.length < 3 ||
          codigo.startsWith('0') ||
          codigo.startsWith('10')) {
        continue;
      }
      final nombre = _sinTildes(entrada.value);
      final todas = palabras.every(
        (p) => codigo.startsWith(p) || nombre.contains(p),
      );
      if (!todas) continue;

      final p0 = palabras.first;
      final coincidencia = codigo.startsWith(p0)
          ? 0
          : (nombre.startsWith(p0) || nombre.contains(' $p0'))
          ? 1
          : 2;
      var prioridad = primero.indexWhere(codigo.startsWith);
      if (prioridad < 0) prioridad = primero.length;
      hallados.add((coincidencia, prioridad, codigo));
    }

    hallados.sort((a, b) {
      final porCoincidencia = a.$1.compareTo(b.$1);
      if (porCoincidencia != 0) return porCoincidencia;
      final porElemento = a.$2.compareTo(b.$2);
      if (porElemento != 0) return porElemento;
      // La cuenta general antes que sus subcuentas: "754 Alquileres" antes
      // que "7542 Edificaciones".
      final porLargo = a.$3.length.compareTo(b.$3.length);
      return porLargo != 0 ? porLargo : a.$3.compareTo(b.$3);
    });
    return hallados.take(limite).map((h) => h.$3).toList();
  }

  static String _sinTildes(String texto) {
    const con = 'áéíóúüñ';
    const sin = 'aeiouun';
    final minusculas = texto.toLowerCase();
    final salida = StringBuffer();
    for (final letra in minusculas.split('')) {
      final i = con.indexOf(letra);
      salida.write(i < 0 ? letra : sin[i]);
    }
    return salida.toString();
  }

  /// Cuentas que se usan seguido, para tenerlas a mano.
  static const caja = '101';
  static const cuentaCorriente = '1041';
  static const porCobrar = '1212';
  static const porPagar = '4212';
  static const igvPorPagar = '40111';
}
