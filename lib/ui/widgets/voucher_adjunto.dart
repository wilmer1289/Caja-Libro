import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/tema.dart';
import '../../datos/local/evidencias.dart';

/// El voucher en miniatura: la imagen recortada, o la hoja de un PDF.
class MiniaturaVoucher extends StatelessWidget {
  const MiniaturaVoucher({super.key, required this.archivo, this.lado = 64});

  final ArchivoVoucher archivo;
  final double lado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Tokens.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: archivo.esPdf
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 26,
                  color: Tokens.salio,
                ),
                SizedBox(height: 2),
                Text(
                  'PDF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Tokens.texto2,
                  ),
                ),
              ],
            )
          : Image.memory(
              archivo.bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined, color: Tokens.texto2),
            ),
    );
  }
}

/// El voucher en grande, para revisarlo: se puede acercar con dos dedos o
/// con la rueda del mouse.
class VisorVoucher extends StatelessWidget {
  const VisorVoucher({super.key, required this.archivo, this.titulo});

  final ArchivoVoucher archivo;
  final String? titulo;

  static Future<void> abrir(
    BuildContext context,
    ArchivoVoucher archivo, {
    String? titulo,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Tokens.cromo.withValues(alpha: 0.6),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
          child: VisorVoucher(archivo: archivo, titulo: titulo),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
          child: Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                size: 20,
                color: Tokens.marca,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo ?? 'Voucher',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Tokens.texto,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ColoredBox(
            color: Tokens.fondo,
            child: archivo.esPdf
                ? FutureBuilder<Uint8List>(
                    future: _primeraPagina(),
                    builder: (context, foto) => foto.hasData
                        ? _Ampliable(child: Image.memory(foto.data!))
                        : foto.hasError
                        ? const _NoSeVe()
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                  )
                : _Ampliable(
                    child: Image.memory(
                      archivo.bytes,
                      errorBuilder: (_, _, _) => const _NoSeVe(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<Uint8List> _primeraPagina() async {
    final pagina = await Printing.raster(
      archivo.bytes,
      pages: const [0],
      dpi: 150,
    ).first;
    return pagina.toPng();
  }
}

class _Ampliable extends StatelessWidget {
  const _Ampliable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 5,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(child: child),
      ),
    );
  }
}

class _NoSeVe extends StatelessWidget {
  const _NoSeVe();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Text(
        'No se pudo mostrar el archivo.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Tokens.texto2),
      ),
    );
  }
}

/// Dónde se adjunta el voucher: vacía, invita a adjuntarlo; con un archivo,
/// lo muestra y deja verlo, cambiarlo o quitarlo.
class TarjetaVoucher extends StatelessWidget {
  const TarjetaVoucher({
    super.key,
    required this.archivo,
    required this.obligatorio,
    required this.leyendo,
    required this.puedeTomarFoto,
    required this.puedeLeer,
    required this.onTomarFoto,
    required this.onElegir,
    this.onQuitar,
    this.error,
  });

  final ArchivoVoucher? archivo;
  final bool obligatorio;
  final bool leyendo;
  final bool puedeTomarFoto;
  final bool puedeLeer;
  final VoidCallback onTomarFoto;
  final VoidCallback onElegir;
  final VoidCallback? onQuitar;

  /// En rojo, como el resto de lo que impide guardar.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final archivo = this.archivo;
    final conError = error != null;

    final botones = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (puedeTomarFoto)
          FilledButton.tonalIcon(
            onPressed: leyendo ? null : onTomarFoto,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(archivo == null ? 'Tomar foto' : 'Otra foto'),
          ),
        OutlinedButton.icon(
          onPressed: leyendo ? null : onElegir,
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: Text(archivo == null ? 'Elegir imagen o PDF' : 'Cambiar'),
        ),
        if (archivo != null && onQuitar != null)
          TextButton.icon(
            onPressed: leyendo ? null : onQuitar,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Quitar'),
          ),
      ],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: archivo == null ? Tokens.fondo : Tokens.superficie,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(
          color: conError
              ? Tokens.salio.withValues(alpha: 0.6)
              : archivo == null
              ? Tokens.bordeFuerte
              : Tokens.borde,
          width: conError ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (archivo != null)
                GestureDetector(
                  onTap: () => VisorVoucher.abrir(context, archivo),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: MiniaturaVoucher(archivo: archivo),
                  ),
                )
              else
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Tokens.marcaSuave,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: Tokens.marcaOscura,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      archivo == null
                          ? 'Adjunta el voucher'
                          : 'Voucher adjunto',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Tokens.texto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      archivo != null
                          ? '${archivo.esPdf ? 'PDF' : 'Imagen'} · '
                                '${_peso(archivo.bytes.length)} · tócalo para verlo'
                          : obligatorio
                          ? 'Obligatorio desde S/ 700: es la prueba de la '
                                'operación.'
                          : 'Opcional. La captura o el PDF que te dio el banco.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: conError && archivo == null
                            ? Tokens.salio
                            : Tokens.texto2,
                      ),
                    ),
                    if (archivo == null && puedeLeer) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'La app lo lee y llena los datos por ti.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Tokens.marcaOscura,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (leyendo) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 8),
            const Text(
              'Leyendo el voucher…',
              style: TextStyle(fontSize: 12.5, color: Tokens.texto2),
            ),
          ] else
            botones,
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Tokens.salio,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _peso(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).ceil()} KB';
}
