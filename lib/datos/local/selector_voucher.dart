import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'evidencias.dart';

/// De dónde sale el voucher: la cámara del celular o un archivo.
///
/// Se puede reemplazar en las pruebas, donde no hay cámara ni diálogo de
/// archivos.
abstract class SelectorVoucher {
  static SelectorVoucher instancia = SelectorDelSistema();

  /// La cámara sólo está en el celular. En la computadora el voucher llega
  /// como captura o como PDF descargado del banco.
  bool get puedeTomarFoto;

  Future<ArchivoVoucher?> tomarFoto();
  Future<ArchivoVoucher?> elegirArchivo();
}

class SelectorDelSistema implements SelectorVoucher {
  @override
  bool get puedeTomarFoto => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<ArchivoVoucher?> tomarFoto() async {
    // Comprimida desde la cámara: un voucher se lee igual a 1800 px y pesa
    // una décima parte.
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 85,
    );
    return foto == null ? null : _leer(foto);
  }

  @override
  Future<ArchivoVoucher?> elegirArchivo() async {
    final archivo = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Voucher (imagen o PDF)',
          extensions: ArchivoVoucher.extensiones,
          mimeTypes: [
            'image/jpeg',
            'image/png',
            'image/webp',
            'application/pdf',
          ],
          uniformTypeIdentifiers: ['public.image', 'com.adobe.pdf'],
          webWildCards: ['image/*', 'application/pdf'],
        ),
      ],
      confirmButtonText: 'Adjuntar',
    );
    return archivo == null ? null : _leer(archivo);
  }

  static Future<ArchivoVoucher> _leer(XFile archivo) async {
    final extension = _extension(archivo);
    if (!ArchivoVoucher.extensiones.contains(extension)) {
      throw const FormatException(
        'Ese archivo no es una imagen ni un PDF. Adjunta la captura o el PDF '
        'del voucher.',
      );
    }
    final bytes = await archivo.readAsBytes();
    if (bytes.length > ArchivoVoucher.maximoBytes) {
      throw const FormatException(
        'El archivo pesa más de 15 MB. Adjunta una captura del voucher.',
      );
    }
    return ArchivoVoucher(bytes: bytes, extension: extension);
  }

  /// La extensión sale del nombre; si no tiene (Android a veces devuelve un
  /// nombre sin ella), del tipo MIME.
  static String _extension(XFile archivo) {
    final delNombre = p
        .extension(archivo.name)
        .replaceFirst('.', '')
        .toLowerCase();
    if (delNombre.isNotEmpty) return delNombre;
    return switch (archivo.mimeType) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }
}
