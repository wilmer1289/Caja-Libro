import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/export/exportador_pdf.dart';
import '../../dominio/acta_conteo.dart';
import '../../dominio/documento.dart';
import '../../estado/estado_caja.dart';
import '../documentos/hoja_documento.dart';

/// Visor del acta del conteo con descarga e impresión en PDF.
class ActaConteoVista {
  static Future<void> abrir(BuildContext context, ActaConteo acta) {
    final negocio = context.read<EstadoCaja>().negocio;
    final fecha = acta.conteo.fecha;
    return DocumentoDialogo.abrir(
      context,
      hoja: Documentos.actaConteo(acta),
      pdf: () => ExportadorPdf.documento(Documentos.actaConteo(acta)),
      nombreArchivo:
          'Acta de conteo ${acta.anual ? 'anual ' : ''}${fecha.year}-'
          '${fecha.month.toString().padLeft(2, '0')}-'
          '${fecha.day.toString().padLeft(2, '0')}.pdf',
      pie:
          '${negocio.razonSocial} · '
          'acta de conteo ${acta.anual ? 'anual' : 'físico'}',
    );
  }
}
