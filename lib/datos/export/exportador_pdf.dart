import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/formato.dart';
import '../../dominio/boleta.dart';
import '../../dominio/documento.dart';
import '../../dominio/enums.dart';
import '../../dominio/jornada.dart';
import '../../dominio/libro_oficial.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/negocio.dart';
import '../../dominio/recibo.dart';

part 'comprobantes_pdf.dart';

/// El Formato 1.1 / 1.2 y los recibos, en PDF.
///
/// El CSV sirve para que el contador siga trabajando el dato; el PDF es el
/// documento terminado: el que se imprime, se firma y se archiva. Por eso acá
/// sí importa la forma —los bordes, el cuadre abajo, las dos firmas del
/// recibo— y no sólo los números.
///
/// La biblioteca es Dart puro: no agrega ningún componente nativo, así que el
/// PDF se arma igual en Windows y en Android sin tocar la compilación.
class ExportadorPdf {
  /// El formato en A4 apaisado: son diez columnas, y en vertical no entran sin
  /// achicar la letra hasta donde deja de leerse.
  static const _hoja = PdfPageFormat.a4;

  /// Margen de la hoja, en puntos. Angosto a propósito: el formato es una
  /// tabla ancha y cada milímetro de margen se lo saca a las columnas.
  static const _margen = 20.0;

  static const _margenes = pw.EdgeInsets.fromLTRB(
    _margen,
    _margen,
    _margen,
    _margen + 4,
  );

  static pw.Font? _normal;
  static pw.Font? _negrita;

  /// La tipografía de la app va incrustada en el PDF.
  ///
  /// Las fuentes que el PDF trae de fábrica no cubren bien los acentos ni el
  /// símbolo de grado de "N° DE OPER."; incrustarla también hace que el
  /// documento impreso se vea como la pantalla.
  static Future<void> _cargarFuentes() async {
    if (_normal != null) return;
    _normal = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
    );
    _negrita = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
    );
  }

  static pw.ThemeData get _tema =>
      pw.ThemeData.withFont(base: _normal!, bold: _negrita!);

  // --- Colores, los mismos de la app ---

  static const _cromo = PdfColor.fromInt(0xFF292724);
  static const _cromoTexto = PdfColor.fromInt(0xFFF7F6F3);
  static const _texto = PdfColor.fromInt(0xFF24211F);
  static const _texto2 = PdfColor.fromInt(0xFF77716B);
  static const _borde = PdfColor.fromInt(0xFFD6D0C9);
  static const _fondo = PdfColor.fromInt(0xFFF7F6F3);
  static const _cabecera = PdfColor.fromInt(0xFFF1EEE9);

  // -------------------------------------------------------------------------
  // Formato 1.1 / 1.2
  // -------------------------------------------------------------------------

  /// Las columnas y su peso. El ancho real sale de repartir el ancho de la
  /// hoja según estos pesos, así el documento ocupa el papel completo tanto en
  /// el 1.1 (siete columnas) como en el 1.2 (diez).
  static List<_Col> _columnas(bool esCaja) => [
    const _Col('N° DE\nOPER.', 46, centro: true),
    const _Col('FECHA DE\nLA OPER.', 70, centro: true),
    if (!esCaja) const _Col('MEDIO DE\nPAGO (T1)', 56, centro: true),
    const _Col('DESCRIPCIÓN DE LA OPERACIÓN', 170),
    if (!esCaja) ...[
      const _Col('APELLIDOS Y NOMBRES,\nRAZÓN SOCIAL', 120),
      const _Col('N° DE TRANSACC.\nBANCARIA', 90, centro: true),
    ],
    const _Col('CÓDIGO', 52, centro: true, grupo: 'CUENTA CONTABLE ASOCIADA'),
    const _Col('DENOMINACIÓN', 130, grupo: 'CUENTA CONTABLE ASOCIADA'),
    const _Col('DEUDOR (+)', 80, derecha: true, grupo: 'SALDOS Y MOVIMIENTOS'),
    const _Col(
      'ACREEDOR (-)',
      80,
      derecha: true,
      grupo: 'SALDOS Y MOVIMIENTOS',
    ),
  ];

  static Future<Uint8List> formato(LibroOficial libro) async {
    await _cargarFuentes();

    final esCaja = libro.cuenta == Cuenta.caja;
    final columnas = _columnas(esCaja);
    final usable = _hoja.landscape.width - _margen * 2;
    final pesoTotal = columnas.fold<double>(0, (s, c) => s + c.peso);
    final anchos = [for (final c in columnas) usable * c.peso / pesoTotal];

    final doc = pw.Document(theme: _tema);

    doc.addPage(
      pw.MultiPage(
        pageFormat: _hoja.landscape,
        margin: _margenes,
        // El encabezado completo sólo en la primera hoja; de ahí en adelante
        // se repite la fila de títulos, que es lo que hace falta para seguir
        // leyendo la tabla.
        header: (ctx) => ctx.pageNumber == 1
            ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _titulo(libro),
                  _datosNegocio(libro),
                  _cabeceraTabla(columnas, anchos),
                ],
              )
            : _cabeceraTabla(columnas, anchos),
        footer: _pie,
        build: (ctx) => [
          _cuerpo(libro, columnas, anchos, esCaja),
          _cuadre(libro, anchos),
        ],
      ),
    );

    // Los asientos van en su propia sección y no al pie de la tabla.
    //
    // Dos razones: son otro documento —el libro de caja registra operación por
    // operación, el diario recibe un asiento por mes— y, si fueran parte de la
    // misma sección, al pasar de hoja se repetiría encima de ellos la fila de
    // títulos de la tabla, que no tiene nada que ver.
    if (libro.asientos.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: _hoja.landscape,
          margin: _margenes,
          header: (ctx) => _tituloSeccion(libro),
          footer: (ctx) => _pie(ctx),
          build: (ctx) => [
            for (final a in libro.asientos) ...[
              _asiento(a, Formato.mes(libro.desde), usable),
              pw.SizedBox(height: 12),
            ],
          ],
        ),
      );
    }

    return doc.save();
  }

  /// La franja que encabeza la sección del Libro Diario.
  static pw.Widget _tituloSeccion(LibroOficial libro) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _borde, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'PARA EL LIBRO DIARIO',
            style: pw.TextStyle(
              fontSize: 8.5,
              letterSpacing: 0.8,
              fontWeight: pw.FontWeight.bold,
              color: _texto,
            ),
          ),
          pw.Text(
            '${libro.negocio.razonSocial}  ·  '
            '${Formato.mesSolo(libro.desde).toUpperCase()} - '
            '${libro.desde.year}',
            style: const pw.TextStyle(fontSize: 7.5, color: _texto2),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pie(pw.Context ctx) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Emitido por Mi Caja · ${Formato.fecha(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 6.5, color: _texto2),
          ),
          pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 6.5, color: _texto2),
          ),
        ],
      ),
    );
  }

  static pw.Widget _titulo(LibroOficial libro) {
    return pw.Container(
      color: _cromo,
      padding: const pw.EdgeInsets.fromLTRB(12, 9, 10, 9),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              libro.titulo,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _cromoTexto,
              ),
            ),
          ),
          pw.Text(
            libro.rotuloCuenta,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: _cromoTexto,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _datosNegocio(LibroOficial libro) {
    final n = libro.negocio;
    final periodo =
        '${Formato.mesSolo(libro.desde).toUpperCase()} - ${libro.desde.year}';

    pw.Widget dato(String etiqueta, String valor) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          etiqueta,
          style: const pw.TextStyle(fontSize: 6, color: _texto2),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          valor.trim().isEmpty ? '—' : valor,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: _texto,
          ),
        ),
      ],
    );

    return pw.Container(
      width: double.infinity,
      color: _fondo,
      padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 9),
      child: pw.Wrap(
        spacing: 26,
        runSpacing: 6,
        children: [
          dato('PERÍODO', periodo),
          dato(n.documento.length == 11 ? 'RUC' : 'DNI', n.documento),
          dato(
            'APELLIDOS Y NOMBRES, DENOMINACIÓN O RAZÓN SOCIAL',
            n.razonSocial,
          ),
          if (libro.cuenta == Cuenta.banco) ...[
            dato('ENTIDAD FINANCIERA', n.entidadFinanciera),
            dato('CÓDIGO DE LA CUENTA CORRIENTE', n.cuentaCorriente),
          ],
        ],
      ),
    );
  }

  /// La fila de títulos, con los dos que abarcan dos columnas.
  static pw.Widget _cabeceraTabla(List<_Col> columnas, List<double> anchos) {
    // Cada grupo abarca las columnas seguidas que lo declaran.
    final tramos = <({String? grupo, int desde, int hasta})>[];
    for (var i = 0; i < columnas.length; i++) {
      final g = columnas[i].grupo;
      if (tramos.isNotEmpty && tramos.last.grupo == g && g != null) {
        tramos[tramos.length - 1] = (
          grupo: g,
          desde: tramos.last.desde,
          hasta: i,
        );
      } else {
        tramos.add((grupo: g, desde: i, hasta: i));
      }
    }

    double ancho(int desde, int hasta) {
      var total = 0.0;
      for (var i = desde; i <= hasta; i++) {
        total += anchos[i];
      }
      return total;
    }

    pw.Widget celda(String texto, double w, {bool centro = true}) =>
        pw.Container(
          width: w,
          height: 28,
          alignment: centro ? pw.Alignment.center : pw.Alignment.centerLeft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 3),
          decoration: const pw.BoxDecoration(
            border: pw.Border(right: pw.BorderSide(color: _borde, width: 0.5)),
          ),
          child: pw.Text(
            texto,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 5.8,
              lineSpacing: 1,
              fontWeight: pw.FontWeight.bold,
              color: _texto2,
            ),
          ),
        );

    return pw.Container(
      color: _cabecera,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final t in tramos)
            if (t.grupo == null)
              celda(columnas[t.desde].titulo, anchos[t.desde])
            else
              pw.SizedBox(
                width: ancho(t.desde, t.hasta),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      height: 12,
                      alignment: pw.Alignment.center,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: _borde, width: 0.5),
                          right: pw.BorderSide(color: _borde, width: 0.5),
                        ),
                      ),
                      child: pw.Text(
                        t.grupo!,
                        style: pw.TextStyle(
                          fontSize: 5.8,
                          fontWeight: pw.FontWeight.bold,
                          color: _texto2,
                        ),
                      ),
                    ),
                    pw.Row(
                      children: [
                        for (var i = t.desde; i <= t.hasta; i++)
                          celda(columnas[i].titulo, anchos[i]),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// El cuerpo de la tabla, como una sola `Table`.
  ///
  /// Una tabla y no una fila por widget porque `MultiPage` sabe partir una
  /// `Table` entre hojas, y porque es ella la que iguala el alto de las celdas:
  /// armado a mano con filas, una descripcion de dos renglones dejaba las
  /// lineas divisorias de las demas columnas cortadas por la mitad.
  static pw.Widget _cuerpo(
    LibroOficial libro,
    List<_Col> columnas,
    List<double> anchos,
    bool esCaja,
  ) {
    List<String> valores(FilaFormato f) => [
      f.numero?.toString() ?? '',
      f.fecha == null ? '' : Formato.fecha(f.fecha!),
      if (!esCaja) f.medioTabla1 ?? '',
      f.descripcion,
      if (!esCaja) ...[f.contraparte ?? '', f.numeroTransaccion ?? ''],
      f.codigoCuenta ?? '',
      f.denominacion ?? '',
      f.deudor == 0 ? '' : Formato.monto(f.deudor / 100),
      f.acreedor == 0 ? '' : Formato.monto(f.acreedor / 100),
    ];

    return pw.Table(
      columnWidths: {
        for (var i = 0; i < anchos.length; i++)
          i: pw.FixedColumnWidth(anchos[i]),
      },
      border: pw.TableBorder.all(color: _borde, width: 0.5),
      children: [
        for (var f = 0; f < libro.filas.length; f++)
          pw.TableRow(
            // El saldo inicial se distingue: es la linea con la que abre el
            // periodo, no una operacion mas.
            decoration: f == 0 ? const pw.BoxDecoration(color: _fondo) : null,
            children: [
              for (var i = 0; i < columnas.length; i++)
                pw.Container(
                  alignment: columnas[i].derecha
                      ? pw.Alignment.centerRight
                      : columnas[i].centro
                      ? pw.Alignment.center
                      : pw.Alignment.centerLeft,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 5,
                  ),
                  child: pw.Text(
                    valores(libro.filas[f])[i],
                    textAlign: columnas[i].derecha
                        ? pw.TextAlign.right
                        : columnas[i].centro
                        ? pw.TextAlign.center
                        : pw.TextAlign.left,
                    style: pw.TextStyle(
                      fontSize: 7.2,
                      color: _texto,
                      fontWeight: f == 0
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// SUBTOTAL, SALDO FINAL y TOTALES.
  static pw.Widget _cuadre(LibroOficial libro, List<double> anchos) {
    final anchoImportes = anchos[anchos.length - 2] + anchos.last;
    final anchoEtiqueta =
        anchos.fold<double>(0, (s, a) => s + a) - anchoImportes;

    pw.Widget linea({
      required String etiqueta,
      required int deudor,
      required int acreedor,
      required PdfColor fondo,
      required PdfColor color,
      double grosorAbajo = 0.5,
    }) {
      return pw.Container(
        decoration: pw.BoxDecoration(
          color: fondo,
          border: pw.Border(
            bottom: pw.BorderSide(color: _borde, width: grosorAbajo),
          ),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: anchoEtiqueta,
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.fromLTRB(4, 6, 8, 6),
              child: pw.Text(
                etiqueta,
                style: pw.TextStyle(
                  fontSize: 7,
                  letterSpacing: 0.6,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            for (var i = 0; i < 2; i++)
              pw.Container(
                width: anchos[anchos.length - 2 + i],
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 6,
                ),
                child: pw.Text(
                  Formato.monto((i == 0 ? deudor : acreedor) / 100),
                  style: pw.TextStyle(
                    fontSize: 7.6,
                    fontWeight: pw.FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        linea(
          etiqueta: 'SUBTOTAL',
          deudor: libro.subtotalDeudor,
          acreedor: libro.subtotalAcreedor,
          fondo: _fondo,
          color: _texto,
        ),
        linea(
          etiqueta: 'SALDO FINAL',
          deudor: libro.saldoFinalDeudor,
          acreedor: libro.saldoFinalAcreedor,
          fondo: _fondo,
          color: _texto2,
          // Línea doble antes de los totales, como en un libro de papel.
          grosorAbajo: 1.4,
        ),
        linea(
          etiqueta: 'TOTALES',
          deudor: libro.totalDeudor,
          acreedor: libro.totalAcreedor,
          fondo: _cromo,
          color: _cromoTexto,
          grosorAbajo: 0,
        ),
      ],
    );
  }

  static pw.Widget _asiento(
    AsientoResumen asiento,
    String periodo,
    double usable,
  ) {
    const anchoCodigo = 52.0;
    const anchoImporte = 80.0;

    pw.Widget fila(
      String codigo,
      String denominacion,
      String debe,
      String haber, {
      bool titulo = false,
      bool sangria = false,
    }) {
      final estilo = pw.TextStyle(
        fontSize: titulo ? 6 : 7.2,
        fontWeight: titulo ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: titulo ? _texto2 : _texto,
      );
      return pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _borde, width: 0.5)),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: anchoCodigo,
              child: pw.Text(codigo, style: estilo),
            ),
            pw.Expanded(
              child: pw.Padding(
                padding: pw.EdgeInsets.only(left: sangria ? 14 : 0),
                child: pw.Text(denominacion, style: estilo),
              ),
            ),
            pw.SizedBox(
              width: anchoImporte,
              child: pw.Text(
                debe,
                textAlign: pw.TextAlign.right,
                style: estilo,
              ),
            ),
            pw.SizedBox(
              width: anchoImporte,
              child: pw.Text(
                haber,
                textAlign: pw.TextAlign.right,
                style: estilo,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      width: usable,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borde, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: _fondo,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: pw.Row(
              children: [
                pw.Text(
                  '${asiento.numero}   ${asiento.titulo}',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _texto,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Text(
                  '${asiento.glosa} de $periodo',
                  style: const pw.TextStyle(fontSize: 7, color: _texto2),
                ),
              ],
            ),
          ),
          fila(
            'COD. CTA.',
            'DENOMINACIÓN DE LA CUENTA',
            'DEBE',
            'HABER',
            titulo: true,
          ),
          for (final l in asiento.lineas)
            fila(
              l.codigo,
              l.denominacion,
              l.debe == 0 ? '' : Formato.monto(l.debe / 100),
              l.haber == 0 ? '' : Formato.monto(l.haber / 100),
              sangria: l.haber > 0,
            ),
          pw.Container(
            color: _fondo,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'TOTAL',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto,
                    ),
                  ),
                ),
                for (final v in [asiento.totalDebe, asiento.totalHaber])
                  pw.SizedBox(
                    width: anchoImporte,
                    child: pw.Text(
                      Formato.monto(v / 100),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 7.4,
                        fontWeight: pw.FontWeight.bold,
                        color: _texto,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Boleta, recibo, acta de cierre y resumen de cajas
  // -------------------------------------------------------------------------
  //
  // Qué lleva cada uno está en dominio/documento.dart; cómo se dibuja en PDF,
  // en comprobantes_pdf.dart. La pantalla lee la misma descripción.

  static Future<Uint8List> documento(HojaDoc hoja) async {
    await _cargarFuentes();
    final doc = pw.Document(theme: _tema)..addPage(_Doc.pagina(hoja));
    return doc.save();
  }

  /// La boleta de control interno, en una hoja A4 como las de un sistema de
  /// facturación: se imprime en cualquier impresora y se manda en PDF.
  static Future<Uint8List> boleta(Boleta boleta) =>
      documento(Documentos.boleta(boleta));

  /// El recibo va dos veces en la misma hoja A4: uno se entrega y el otro
  /// queda en el talonario, que es como se usa el papel de verdad.
  static Future<Uint8List> recibo(Recibo recibo) =>
      documento(Documentos.recibo(recibo));

  /// El acta del cierre de caja. Sigue en otra hoja si la caja tuvo muchos
  /// movimientos.
  static Future<Uint8List> actaCierre(
    Jornada caja,
    List<Movimiento> movimientos, {
    String direccion = '',
  }) =>
      documento(Documentos.actaCierre(caja, movimientos, direccion: direccion));

  /// Todas las cajas de un período, en A4 apaisado: son once columnas.
  static Future<Uint8List> resumenCajas(
    ResumenCajas resumen, {
    required Negocio negocio,
  }) => documento(Documentos.resumenCajas(resumen, negocio: negocio));

  // -------------------------------------------------------------------------
  // Guardar
  // -------------------------------------------------------------------------

  /// Escribe el PDF junto al resto de lo que genera la app y devuelve la ruta.
  static Future<String> guardar(Uint8List bytes, String nombre) async {
    final documentos = await getApplicationDocumentsDirectory();
    final carpeta = Directory(p.join(documentos.path, 'Mi Caja'));
    if (!await carpeta.exists()) await carpeta.create(recursive: true);

    final archivo = File(p.join(carpeta.path, nombre));
    await archivo.writeAsBytes(bytes);
    return archivo.path;
  }

  static String nombreFormato(LibroOficial libro) =>
      'Formato ${libro.cuenta == Cuenta.caja ? '1.1' : '1.2'} '
      '- ${libro.desde.year}-${libro.desde.month.toString().padLeft(2, '0')}'
      '.pdf';

  static String nombreRecibo(Recibo recibo) =>
      'Recibo ${recibo.esIngreso ? 'ingreso' : 'egreso'} '
      '${recibo.numero}.pdf';

  static String nombreBoleta(Boleta boleta) => 'Boleta ${boleta.numero}.pdf';

  static String _dia(DateTime f) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${f.year}-${dos(f.month)}-${dos(f.day)}';
  }

  static String nombreActa(Jornada caja) =>
      'Cierre de caja ${caja.numero} - ${_dia(caja.cerradaEn ?? caja.abiertaEn)}.pdf';

  static String nombreResumenCajas(ResumenCajas resumen) =>
      'Resumen de cajas - ${resumen.periodo.etiqueta} - '
      '${_dia(DateTime.now())}.pdf';
}

/// Una columna del formato en el PDF. El `peso` no es un ancho en puntos: es
/// la proporción con que se reparte el ancho de la hoja, para que el documento
/// la ocupe entera tenga siete columnas o diez.
class _Col {
  const _Col(
    this.titulo,
    this.peso, {
    this.centro = false,
    this.derecha = false,
    this.grupo,
  });

  final String titulo;
  final double peso;
  final bool centro;
  final bool derecha;

  /// Título que abarca esta columna y la siguiente, si comparten grupo.
  final String? grupo;
}
