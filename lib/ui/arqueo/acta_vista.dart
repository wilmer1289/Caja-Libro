import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/export/exportador_pdf.dart';
import '../../dominio/documento.dart';
import '../../dominio/jornada.dart';
import '../../estado/estado_caja.dart';
import '../documentos/hoja_documento.dart';

/// El acta de cierre de una caja, en pantalla igual que impresa: con cuánto
/// empezó, qué entró y salió en efectivo, lo contado y con cuánto terminó.
class ActaCierre {
  static Future<void> abrir(BuildContext context, Jornada caja) {
    final estado = context.read<EstadoCaja>();
    final movimientos = estado.movimientosDeCaja(caja);
    final direccion = estado.negocio.direccion;
    return DocumentoDialogo.abrir(
      context,
      hoja: Documentos.actaCierre(caja, movimientos, direccion: direccion),
      pdf: () =>
          ExportadorPdf.actaCierre(caja, movimientos, direccion: direccion),
      nombreArchivo: ExportadorPdf.nombreActa(caja),
      pie: 'Caja N° ${caja.numero} · acta de cierre en A4',
    );
  }
}

/// Todas las cajas de un período en una hoja, para imprimir o guardar.
class ResumenCajasHoja {
  static Future<void> abrir(BuildContext context, ResumenCajas resumen) {
    final negocio = context.read<EstadoCaja>().negocio;
    return DocumentoDialogo.abrir(
      context,
      hoja: Documentos.resumenCajas(resumen, negocio: negocio),
      pdf: () => ExportadorPdf.resumenCajas(resumen, negocio: negocio),
      nombreArchivo: ExportadorPdf.nombreResumenCajas(resumen),
      pie: '${resumen.periodo.etiqueta} · A4 apaisado',
    );
  }
}
