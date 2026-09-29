import 'dart:io';

/// Abre un archivo recién generado con el programa que el sistema tenga
/// asociado: el visor de PDF, o Excel para el CSV.
///
/// Sirve sólo en el escritorio. En Android haría falta un componente nativo
/// para compartir el archivo, y por ahora la app se limita a decir dónde quedó.
/// Por eso devuelve si pudo o no: la pantalla muestra un mensaje u otro.
Future<bool> abrirArchivo(String ruta) async {
  try {
    if (Platform.isWindows) {
      // `explorer` con la ruta de un archivo lo abre con su programa asociado.
      // No se mira el código de salida: devuelve 1 aunque haya funcionado, que
      // es una rareza vieja del Explorador de Windows.
      await Process.start('explorer', [ruta]);
      return true;
    }
    if (Platform.isMacOS) {
      return (await Process.run('open', [ruta])).exitCode == 0;
    }
    if (Platform.isLinux) {
      return (await Process.run('xdg-open', [ruta])).exitCode == 0;
    }
  } catch (_) {
    // Que no se pueda abrir no es un error del que haya que avisar aparte: el
    // archivo ya está escrito y la pantalla muestra la ruta igual.
    return false;
  }
  return false;
}
