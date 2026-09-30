import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import 'abrir_archivo.dart';
import 'exportador_pdf.dart';

/// Imprimir, descargar y compartir los PDF de la app.
///
/// Imprimir abre el diálogo de impresión del sistema —el de Windows o el de
/// Android—, así se elige la impresora y cuántas copias sin salir de la app.
///
/// Las funciones son variables a propósito: en las pruebas no hay impresora ni
/// sistema de archivos, y se reemplazan por unas que sólo anotan qué se pidió.
class Impresion {
  static Future<void> Function(Uint8List pdf, String nombre) imprimir =
      _imprimir;

  /// Guarda el PDF en Documentos\Mi Caja y devuelve la ruta. En el celular,
  /// además abre la hoja de compartir: "descargar" ahí significa mandarlo por
  /// WhatsApp o guardarlo en el teléfono. En la web no hay carpeta de
  /// documentos: el navegador lo descarga solo, como cualquier archivo.
  static Future<String> Function(Uint8List pdf, String nombre) descargar =
      _descargar;

  static Future<void> _imprimir(Uint8List pdf, String nombre) =>
      Printing.layoutPdf(onLayout: (_) async => pdf, name: nombre);

  static Future<String> _descargar(Uint8List pdf, String nombre) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: pdf, filename: nombre);
      return 'tu carpeta de descargas';
    }
    final ruta = await ExportadorPdf.guardar(pdf, nombre);
    if (Platform.isAndroid || Platform.isIOS) {
      await Printing.sharePdf(bytes: pdf, filename: nombre);
    } else {
      await abrirArchivo(ruta);
    }
    return ruta;
  }
}
