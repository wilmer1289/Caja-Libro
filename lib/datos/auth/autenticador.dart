/// Resultado de intentar entrar.
sealed class ResultadoEntrada {
  const ResultadoEntrada();
}

class EntradaOk extends ResultadoEntrada {
  const EntradaOk(this.nombre);

  /// Cómo se llama el usuario, para saludarlo. Lo da el autenticador y no lo
  /// que se tipeó, porque "  Usuario " y "usuario" son la misma cuenta.
  final String nombre;
}

class EntradaFallida extends ResultadoEntrada {
  const EntradaFallida(this.mensaje);

  /// Lo que se le muestra al usuario, en lenguaje simple.
  final String mensaje;
}

/// Contrato de autenticación.
///
/// Mismo patrón que `FuenteRemota`: hoy detrás hay una lista fija de cuentas,
/// mañana habrá Firebase Auth, y el login no cambia ni una línea.
abstract interface class Autenticador {
  Future<ResultadoEntrada> entrar({
    required String usuario,
    required String clave,
  });
}
