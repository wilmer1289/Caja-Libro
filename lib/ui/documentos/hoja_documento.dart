import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../../datos/export/impresion.dart';
import '../../dominio/documento.dart';
import 'vista_documento.dart';

/// Una ventana con el papel y, al pie, imprimir y descargar.
///
/// La usan el recibo, la boleta, el acta de cierre y el resumen de cajas.
/// La hoja se ve sobre un fondo gris claro, como en un visor de PDF; en el
/// celular se puede agrandar con dos dedos para leer la letra chica.
/// Cuánto se agranda la hoja en una pantalla ancha: a tamaño real la letra
/// chica del papel cuesta leerla.
const _escala = 1.25;

class DocumentoDialogo extends StatefulWidget {
  const DocumentoDialogo({
    super.key,
    required this.hoja,
    required this.pdf,
    required this.nombreArchivo,
    this.aviso,
    this.pie,
  });

  final HojaDoc hoja;
  final Future<Uint8List> Function() pdf;
  final String nombreArchivo;

  /// Algo que conviene saber antes de imprimir (falta el nombre, por ejemplo).
  final Widget? aviso;

  /// Texto chico a la izquierda de los botones.
  final String? pie;

  static Future<void> abrir(
    BuildContext context, {
    required HojaDoc hoja,
    required Future<Uint8List> Function() pdf,
    required String nombreArchivo,
    Widget? aviso,
    String? pie,
  }) {
    final angosto = MediaQuery.sizeOf(context).width < 600;
    return showDialog<void>(
      context: context,
      barrierColor: Tokens.cromo.withValues(alpha: 0.45),
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.all(angosto ? 12 : 24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          // El ancho de la hoja más el aire alrededor: una A4 se ve a su
          // tamaño, una apaisada un poco más ancha.
          constraints: BoxConstraints(maxWidth: hoja.ancho * _escala + 56),
          child: DocumentoDialogo(
            hoja: hoja,
            pdf: pdf,
            nombreArchivo: nombreArchivo,
            aviso: aviso,
            pie: pie,
          ),
        ),
      ),
    );
  }

  @override
  State<DocumentoDialogo> createState() => _DocumentoDialogoState();
}

class _DocumentoDialogoState extends State<DocumentoDialogo> {
  bool _ocupado = false;
  String? _mensaje;
  bool _error = false;

  Future<void> _hacer(
    Future<String?> Function(Uint8List pdf) accion,
    String listo,
  ) async {
    setState(() {
      _ocupado = true;
      _mensaje = null;
    });
    try {
      final resultado = await accion(await widget.pdf());
      if (mounted) {
        setState(() {
          _error = false;
          _mensaje = resultado ?? listo;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _mensaje = 'No se pudo: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final angosto = MediaQuery.sizeOf(context).width < 600;

    final hoja = SingleChildScrollView(
      padding: EdgeInsets.all(angosto ? 12 : 28),
      child: VistaDocumento(hoja: widget.hoja, escalaMaxima: _escala),
    );

    final descargar = OutlinedButton.icon(
      onPressed: _ocupado
          ? null
          : () => _hacer(
              (pdf) => Impresion.descargar(
                pdf,
                widget.nombreArchivo,
              ).then((ruta) => 'Guardado en $ruta'),
              'Guardado',
            ),
      icon: const Icon(Icons.download_rounded, size: 18),
      label: Text(angosto ? 'PDF' : 'Descargar PDF'),
    );

    final imprimir = FilledButton.icon(
      onPressed: _ocupado
          ? null
          : () => _hacer(
              (pdf) => Impresion.imprimir(
                pdf,
                widget.nombreArchivo,
              ).then((_) => null),
              'Enviado a imprimir',
            ),
      icon: _ocupado
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.print_rounded, size: 18),
      label: const Text('Imprimir'),
    );

    final cerrar = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cerrar'),
    );

    final pie = Text(
      widget.pie ?? '',
      style: const TextStyle(fontSize: 12, color: Tokens.texto2),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ColoredBox(
            color: const Color(0xFFEDEAE5),
            // En el celular la hoja entra achicada: con dos dedos se agranda.
            child: angosto ? InteractiveViewer(maxScale: 4, child: hoja) : hoja,
          ),
        ),
        ?widget.aviso,
        if (_mensaje != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              _mensaje!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _error ? Tokens.salio : Tokens.entro,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
          decoration: const BoxDecoration(
            color: Tokens.superficie,
            border: Border(top: BorderSide(color: Tokens.borde)),
          ),
          child: angosto
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.pie != null) ...[pie, const SizedBox(height: 8)],
                    Row(
                      children: [
                        cerrar,
                        const Spacer(),
                        descargar,
                        const SizedBox(width: 8),
                        imprimir,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: pie),
                    cerrar,
                    const SizedBox(width: 6),
                    descargar,
                    const SizedBox(width: 8),
                    imprimir,
                  ],
                ),
        ),
      ],
    );
  }
}
