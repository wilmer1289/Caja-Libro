import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Un voucher elegido: la foto, la captura o el PDF, con su tipo.
class ArchivoVoucher {
  const ArchivoVoucher({required this.bytes, required String extension})
    : extension = extension == 'jpeg' ? 'jpg' : extension;

  final Uint8List bytes;

  /// "jpg", "png", "webp" o "pdf", siempre en minúsculas.
  final String extension;

  bool get esPdf => extension == 'pdf';

  /// Los tipos que se aceptan: los que la app sabe mostrar y leer.
  static const extensiones = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];

  /// Un voucher es una captura o una foto: más que esto es otra cosa, o una
  /// foto sin comprimir que llenaría el equipo.
  static const maximoBytes = 15 * 1024 * 1024;
}

/// Dónde viven los vouchers adjuntos.
///
/// En la base sólo se guarda el nombre del archivo (`ruta_foto`); el archivo
/// va aparte, en una carpeta propia. Así la base sigue liviana y un respaldo
/// de la carpeta lleva todos los vouchers juntos.
abstract class AlmacenEvidencias {
  /// En la web no hay sistema de archivos: la demo los guarda en memoria y se
  /// pierden al recargar, igual que sus movimientos. Las pruebas usan el de
  /// memoria también.
  static AlmacenEvidencias instancia = kIsWeb
      ? AlmacenEnMemoria()
      : AlmacenEnDisco();

  /// Guarda el archivo y devuelve el nombre con que se lo vuelve a pedir.
  Future<String> guardar(ArchivoVoucher archivo);

  /// Null si el archivo ya no está (por ejemplo, en otro equipo que recibió
  /// el movimiento por la nube, pero no el voucher).
  Future<ArchivoVoucher?> leer(String nombre);
}

class AlmacenEnDisco implements AlmacenEvidencias {
  static const carpeta = 'mi_caja_vouchers';
  static const _uuid = Uuid();

  Future<Directory> _carpeta() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, carpeta));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<String> guardar(ArchivoVoucher archivo) async {
    final nombre = '${_uuid.v4()}.${archivo.extension}';
    final dir = await _carpeta();
    await File(p.join(dir.path, nombre)).writeAsBytes(archivo.bytes);
    return nombre;
  }

  @override
  Future<ArchivoVoucher?> leer(String nombre) async {
    final dir = await _carpeta();
    // Sólo el nombre: una ruta guardada no puede salir de la carpeta.
    final archivo = File(p.join(dir.path, p.basename(nombre)));
    if (!await archivo.exists()) return null;
    return ArchivoVoucher(
      bytes: await archivo.readAsBytes(),
      extension: p.extension(nombre).replaceFirst('.', '').toLowerCase(),
    );
  }
}

class AlmacenEnMemoria implements AlmacenEvidencias {
  final _archivos = <String, ArchivoVoucher>{};
  var _siguiente = 1;

  @override
  Future<String> guardar(ArchivoVoucher archivo) async {
    final nombre = 'voucher-${_siguiente++}.${archivo.extension}';
    _archivos[nombre] = archivo;
    return nombre;
  }

  @override
  Future<ArchivoVoucher?> leer(String nombre) async => _archivos[nombre];
}
