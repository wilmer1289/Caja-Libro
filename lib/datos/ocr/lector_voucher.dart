import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../dominio/lectura_voucher.dart';
import '../local/evidencias.dart';

/// Lee el texto de un voucher sin internet.
///
/// - En el celular, con el lector de texto de Google (ML Kit), que viaja
///   dentro de la app.
/// - En Windows, con el lector que trae el propio Windows
///   (`Windows.Media.Ocr`), en el idioma del usuario.
/// - En la web no hay lector: el voucher se adjunta igual, pero los datos se
///   escriben a mano.
///
/// Un PDF primero se convierte en imagen: los lectores sólo leen imágenes.
abstract class LectorTexto {
  Future<String> leer(Uint8List imagen, String extension);
}

class LectorVoucher {
  LectorVoucher._();

  /// El del equipo, o null si no hay. Se puede reemplazar en las pruebas.
  static LectorTexto? instancia = _delSistema();

  static LectorTexto? _delSistema() {
    if (kIsWeb) return null;
    if (Platform.isWindows) return LectorWindows();
    if (Platform.isAndroid || Platform.isIOS) return LectorMlKit();
    return null;
  }

  static bool get disponible => instancia != null;

  /// Null si en este equipo no se puede leer.
  static Future<LecturaVoucher?> leer(ArchivoVoucher archivo) async {
    final lector = instancia;
    if (lector == null) return null;
    final imagen = archivo.esPdf
        ? await _primeraPagina(archivo.bytes)
        : archivo.bytes;
    final texto = await lector.leer(
      imagen,
      archivo.esPdf ? 'png' : archivo.extension,
    );
    return LecturaVoucher.de(texto);
  }

  /// La primera página del PDF, a 200 ppp: suficiente para que se lean las
  /// letras chicas del N° de operación.
  static Future<Uint8List> _primeraPagina(Uint8List pdf) async {
    final pagina = await Printing.raster(pdf, pages: const [0], dpi: 200).first;
    return pagina.toPng();
  }

  /// Una carpeta temporal para pasarle la imagen al lector, que se borra al
  /// terminar. En la computadora sirve la del sistema; en el celular, la de
  /// la app.
  static Future<T> conArchivoTemporal<T>(
    Uint8List bytes,
    String extension,
    Future<T> Function(File imagen, Directory carpeta) usar,
  ) async {
    final base = Platform.isAndroid || Platform.isIOS
        ? await getTemporaryDirectory()
        : Directory.systemTemp;
    final carpeta = await base.createTemp('mi_caja_ocr_');
    try {
      final imagen = File(p.join(carpeta.path, 'voucher.$extension'));
      await imagen.writeAsBytes(bytes);
      return await usar(imagen, carpeta);
    } finally {
      await carpeta.delete(recursive: true);
    }
  }
}

class LectorMlKit implements LectorTexto {
  @override
  Future<String> leer(Uint8List imagen, String extension) =>
      LectorVoucher.conArchivoTemporal(imagen, extension, (archivo, _) async {
        final reconocedor = TextRecognizer();
        try {
          final resultado = await reconocedor.processImage(
            InputImage.fromFilePath(archivo.path),
          );
          return resultado.text;
        } finally {
          await reconocedor.close();
        }
      });
}

/// El lector de Windows se usa desde PowerShell: las clases de Windows
/// (WinRT) se cargan ahí sin instalar nada, y el texto vuelve por la salida
/// estándar, una línea por renglón del voucher.
class LectorWindows implements LectorTexto {
  @override
  Future<String> leer(Uint8List imagen, String extension) =>
      LectorVoucher.conArchivoTemporal(imagen, extension, (
        archivo,
        carpeta,
      ) async {
        final script = File(p.join(carpeta.path, 'leer.ps1'));
        await script.writeAsString(_script);
        final r = await Process.run(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            script.path,
            archivo.path,
          ],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        if (r.exitCode != 0) {
          throw StateError(
            'Windows no pudo leer el voucher. ${(r.stderr as String).trim()}',
          );
        }
        return r.stdout as String;
      });

  static const _script = r'''
param([string]$ruta)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType = WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
  $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Esperar($op, [Type]$tipo) {
  $t = $asTask.MakeGenericMethod($tipo).Invoke($null, @($op))
  $t.Wait() | Out-Null
  $t.Result
}
$archivo = Esperar ([Windows.Storage.StorageFile]::GetFileFromPathAsync($ruta)) ([Windows.Storage.StorageFile])
$flujo = Esperar ($archivo.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
$decodificador = Esperar ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($flujo)) ([Windows.Graphics.Imaging.BitmapDecoder])
$imagen = Esperar ($decodificador.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
$motor = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
if ($null -eq $motor) { throw 'Windows no tiene instalado el lector de texto para tu idioma.' }
$resultado = Esperar ($motor.RecognizeAsync($imagen)) ([Windows.Media.Ocr.OcrResult])
foreach ($linea in $resultado.Lines) { $linea.Text }
''';
}
