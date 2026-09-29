import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../../datos/export/exportador_pdf.dart';
import '../../dominio/boleta.dart';
import '../../dominio/documento.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/negocio.dart';
import '../../dominio/recibo.dart';
import '../documentos/hoja_documento.dart';
import '../documentos/vista_documento.dart';

/// El recibo interno en pantalla: el original, tal como sale impreso. La
/// copia es igual y va en la otra mitad de la hoja.
///
/// Antes de guardar todavía no tiene número —se asigna al guardar, para que
/// el talonario no tenga huecos— y lo dice en su lugar.
class ReciboVista extends StatelessWidget {
  const ReciboVista({super.key, required this.recibo});

  final Recibo recibo;

  @override
  Widget build(BuildContext context) =>
      VistaDocumento(hoja: Documentos.reciboOriginal(recibo));
}

/// La ventana del recibo: la hoja, y al pie imprimir y descargar.
class ReciboHoja extends StatelessWidget {
  const ReciboHoja({super.key, required this.recibo});

  final Recibo recibo;

  static Future<void> abrir(
    BuildContext context, {
    required Movimiento movimiento,
    required Negocio negocio,
  }) {
    final recibo = Recibo(negocio: negocio, movimiento: movimiento);
    return DocumentoDialogo.abrir(
      context,
      hoja: Documentos.reciboOriginal(recibo),
      pdf: () => ExportadorPdf.recibo(recibo),
      nombreArchivo: ExportadorPdf.nombreRecibo(recibo),
      aviso: recibo.identificaContraparte ? null : const AvisoSinNombre(),
      pie: 'Operación N° ${movimiento.numero} · original y copia en A4',
    );
  }

  @override
  Widget build(BuildContext context) => ReciboVista(recibo: recibo);
}

/// La boleta de control interno en pantalla, igual que la impresa.
class BoletaVista extends StatelessWidget {
  const BoletaVista({super.key, required this.boleta});

  final Boleta boleta;

  @override
  Widget build(BuildContext context) =>
      VistaDocumento(hoja: Documentos.boleta(boleta));
}

class BoletaHoja {
  static Future<void> abrir(
    BuildContext context, {
    required Movimiento movimiento,
    required Negocio negocio,
  }) {
    final boleta = Boleta(negocio: negocio, movimiento: movimiento);
    return DocumentoDialogo.abrir(
      context,
      hoja: Documentos.boleta(boleta),
      pdf: () => ExportadorPdf.boleta(boleta),
      nombreArchivo: ExportadorPdf.nombreBoleta(boleta),
      pie: 'Operación N° ${movimiento.numero} · A4',
    );
  }
}

class AvisoSinNombre extends StatelessWidget {
  const AvisoSinNombre({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Tokens.marcaSuave,
        borderRadius: BorderRadius.circular(Tokens.radio),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: Tokens.marca),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Este movimiento no tiene nombre ni documento. El recibo sirve '
              'igual, pero sin eso no sustenta el gasto.',
              style: TextStyle(fontSize: 12, color: Tokens.texto2),
            ),
          ),
        ],
      ),
    );
  }
}
