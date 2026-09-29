import 'autenticador.dart';

/// Cuentas fijas, escritas en el código. **Provisional.**
///
/// Sirve para poder usar y mostrar la app mientras Firebase Auth no esté
/// conectado. No es seguridad de verdad: cualquiera que abra el .apk o el .exe
/// puede leer estas cadenas. Vale para una demo y para el desarrollo, no para
/// entregarle la app a un cliente con datos reales adentro.
///
/// Cuando se conecte Firebase Auth, esta clase se borra y en su lugar va un
/// `AutenticadorFirebase` que implemente la misma interfaz.
class AutenticadorLocal implements Autenticador {
  const AutenticadorLocal();

  /// Usuario en minúsculas → contraseña.
  static const _cuentas = <String, String>{'usuario': 'usuario123'};

  @override
  Future<ResultadoEntrada> entrar({
    required String usuario,
    required String clave,
  }) async {
    // El usuario no distingue mayúsculas y se le quitan los espacios de los
    // costados: en un celular es fácil que el teclado agregue uno al final o
    // ponga la primera letra en mayúscula sin que nadie se dé cuenta.
    final nombre = usuario.trim().toLowerCase();
    final esperada = _cuentas[nombre];

    if (esperada == null || esperada != clave) {
      // Un solo mensaje para los dos casos, a propósito: decir "ese usuario no
      // existe" le confirmaría a cualquiera qué cuentas hay.
      return const EntradaFallida('Usuario o contraseña incorrectos');
    }

    return EntradaOk(nombre);
  }
}
