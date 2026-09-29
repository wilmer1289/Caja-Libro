/// Frases que hacen que la app hable como una persona y no como un formulario.
///
/// Está en `core` y no en la pantalla del login porque el saludo también va en
/// el Resumen: es la misma voz en los dos sitios.
class Saludo {
  /// "Buenos días" / "Buenas tardes" / "Buenas noches" según la hora.
  ///
  /// El corte de la mañana va a las 12 y el de la noche a las 19, que es como
  /// se habla acá: a las seis de la tarde todavía es tarde.
  static String porHora([DateTime? ahora]) {
    final hora = (ahora ?? DateTime.now()).hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// Bajada del login, debajo del saludo.
  static const bienvenida = 'Bienvenido de nuevo a tu caja';

  /// Frase del panel de los personajes. Corta, en el lenguaje del §1: sin
  /// jerga contable y sin prometer nada que la app no haga.
  static const lema = 'Tu caja al día,\nsin complicarte.';

  /// Frase de apoyo del panel, más chica.
  static const lemaApoyo =
      'Anota lo que entra y lo que sale. El saldo se calcula solo.';
}
