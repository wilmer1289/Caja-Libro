import 'dart:convert';

/// Los billetes y monedas del sol que circulan hoy, en centavos.
///
/// No van las monedas de 1 y 5 céntimos: el BCRP las sacó de circulación y
/// en una bodega ya nadie las cuenta.
class Denominacion {
  static const billetes = [20000, 10000, 5000, 2000, 1000];
  static const monedas = [500, 200, 100, 50, 20, 10];
  static const todas = [...billetes, ...monedas];

  static bool esBillete(int centavos) => centavos >= 1000;

  /// "S/ 50", "S/ 0.20".
  static String etiqueta(int centavos) => centavos >= 100
      ? 'S/ ${centavos ~/ 100}'
      : 'S/ 0.${centavos.toString().padLeft(2, '0')}';
}

/// Cuántos billetes y monedas de cada uno. Es lo que se cuenta en un arqueo,
/// y lo que se anota cuando un cliente paga con "dos de 50 y uno de 10".
class Conteo {
  const Conteo([this.cantidades = const {}]);

  /// Denominación en centavos → cuántos.
  final Map<int, int> cantidades;

  static const vacio = Conteo();

  int cantidadDe(int denominacion) => cantidades[denominacion] ?? 0;

  int get total =>
      cantidades.entries.fold(0, (suma, e) => suma + e.key * e.value);

  bool get estaVacio => cantidades.values.every((c) => c == 0);

  Conteo con(int denominacion, int cantidad) {
    final nuevas = Map<int, int>.of(cantidades);
    if (cantidad <= 0) {
      nuevas.remove(denominacion);
    } else {
      nuevas[denominacion] = cantidad;
    }
    return Conteo(nuevas);
  }

  Conteo operator +(Conteo otro) {
    final nuevas = Map<int, int>.of(cantidades);
    otro.cantidades.forEach((d, c) => nuevas[d] = (nuevas[d] ?? 0) + c);
    return Conteo(nuevas);
  }

  Conteo operator -(Conteo otro) {
    final nuevas = Map<int, int>.of(cantidades);
    otro.cantidades.forEach((d, c) => nuevas[d] = (nuevas[d] ?? 0) - c);
    return Conteo(nuevas);
  }

  /// "2 × S/ 50 · 1 × S/ 10", de la más grande a la más chica.
  String get resumen {
    final partes = [
      for (final d in Denominacion.todas)
        if (cantidadDe(d) > 0) '${cantidadDe(d)} × ${Denominacion.etiqueta(d)}',
    ];
    return partes.join(' · ');
  }

  /// Cómo dar un monto con la menor cantidad de billetes y monedas.
  ///
  /// Es una sugerencia para el vuelto: quien atiende la puede cambiar si no
  /// tiene monedas de 1 y prefiere dar dos de 50 céntimos. Lo que no alcanza
  /// a formarse con 10 céntimos (un resto de 5) queda afuera: esas monedas ya
  /// no circulan y el vuelto se redondea.
  static Conteo sugerir(int centavos) {
    var resto = centavos;
    final cantidades = <int, int>{};
    for (final d in Denominacion.todas) {
      final n = resto ~/ d;
      if (n > 0) {
        cantidades[d] = n;
        resto -= n * d;
      }
    }
    return Conteo(cantidades);
  }

  Map<String, int> aJson() => {
    for (final e in cantidades.entries)
      if (e.value != 0) '${e.key}': e.value,
  };

  factory Conteo.desdeJson(Map<String, dynamic>? json) => Conteo({
    for (final e in (json ?? const {}).entries)
      int.parse(e.key): (e.value as num).toInt(),
  });

  @override
  bool operator ==(Object other) =>
      other is Conteo && other.aJson().toString() == aJson().toString();

  @override
  int get hashCode => aJson().toString().hashCode;
}

/// Con qué se pagó en efectivo y qué vuelto se dio.
///
/// En una entrada, `entregado` es lo que dio el cliente y `vuelto` lo que se
/// le devolvió. En una salida es al revés de lado: `entregado` es lo que
/// salió de la caja y `vuelto` lo que devolvieron. En los dos casos
/// entregado − vuelto = el monto del movimiento.
class DetalleEfectivo {
  const DetalleEfectivo({required this.entregado, required this.vuelto});

  final Conteo entregado;
  final Conteo vuelto;

  bool cuadraCon(int centavos) =>
      entregado.total - vuelto.total == centavos && entregado.total > 0;

  String aTexto() =>
      jsonEncode({'entregado': entregado.aJson(), 'vuelto': vuelto.aJson()});

  static DetalleEfectivo? desdeTexto(String? texto) {
    if (texto == null || texto.trim().isEmpty) return null;
    final json = jsonDecode(texto) as Map<String, dynamic>;
    return DetalleEfectivo(
      entregado: Conteo.desdeJson(json['entregado'] as Map<String, dynamic>?),
      vuelto: Conteo.desdeJson(json['vuelto'] as Map<String, dynamic>?),
    );
  }
}
