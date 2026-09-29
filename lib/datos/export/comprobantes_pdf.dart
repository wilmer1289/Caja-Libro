part of 'exportador_pdf.dart';

// Los mismos colores del Formato 1.1 (ver ExportadorPdf).
const _cromo = PdfColor.fromInt(0xFF292724);
const _cromoTexto = PdfColor.fromInt(0xFFF7F6F3);
const _texto = PdfColor.fromInt(0xFF24211F);
const _texto2 = PdfColor.fromInt(0xFF77716B);
const _borde = PdfColor.fromInt(0xFFD6D0C9);

/// Dibuja en PDF los papeles descritos en `dominio/documento.dart`: boleta,
/// recibo, acta de cierre y resumen de cajas.
///
/// Todos con la forma de un comprobante de verdad: logo y negocio arriba, el
/// recuadro redondeado con el RUC y el número, la caja de datos, la fila de
/// casilleros, la tabla con sus líneas verticales y el importe en letras. Van
/// en tinta oscura sobre blanco, sin fondos de color: salen bien en cualquier
/// impresora, y el único toque de marca es la rayita naranja del logo.
///
/// La vista en pantalla (`ui/documentos/vista_documento.dart`) dibuja lo mismo
/// con las mismas medidas: si se cambia algo acá, se cambia allá.
class _Doc {
  static const _tinta = _texto;
  static const _marca = PdfColor.fromInt(0xFFF97316);
  static const _grosor = 0.8;
  static const _radio = 7.0;

  static pw.BoxDecoration get _recuadro => pw.BoxDecoration(
    border: pw.Border.all(color: _tinta, width: _grosor),
    borderRadius: pw.BorderRadius.circular(_radio),
  );

  static const _divisor = pw.BorderSide(color: _tinta, width: 0.5);

  static pw.TextAlign _alinear(AlineacionDoc a) => switch (a) {
    AlineacionDoc.izquierda => pw.TextAlign.left,
    AlineacionDoc.centro => pw.TextAlign.center,
    AlineacionDoc.derecha => pw.TextAlign.right,
  };

  /// Toda la hoja, en una página de alto fijo o en las que haga falta.
  static pw.Page pagina(HojaDoc hoja) {
    final formato = hoja.apaisada
        ? PdfPageFormat.a4.landscape
        : PdfPageFormat(hoja.ancho, hoja.alto ?? HojaDoc.altoA4);
    final margen = pw.EdgeInsets.fromLTRB(
      hoja.margen.izquierda,
      hoja.margen.arriba,
      hoja.margen.derecha,
      hoja.margen.abajo,
    );

    if (hoja.alto != null) {
      return pw.Page(
        pageFormat: formato,
        margin: margen,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [for (final b in hoja.bloques) bloque(b, alFijo: true)],
        ),
      );
    }
    return pw.MultiPage(
      pageFormat: formato,
      margin: margen,
      footer: hoja.pie == null
          ? null
          : (ctx) => pw.Padding(
              padding: const pw.EdgeInsets.only(top: 10),
              child: pie(
                hoja.pie!,
                derecha:
                    '${hoja.pie!.derecha} · ${ctx.pageNumber} de '
                    '${ctx.pagesCount}',
              ),
            ),
      build: (ctx) => [for (final b in hoja.bloques) bloque(b)],
    );
  }

  /// Una pieza. En una hoja de alto fijo, la tabla que rellena y la media
  /// hoja se estiran hasta llenar lo que sobra.
  static pw.Widget bloque(BloqueDoc b, {bool alFijo = false}) => switch (b) {
    EncabezadoDoc() => encabezado(b),
    DatosDoc() => datos(b),
    CeldasDoc() => celdas(b),
    TablaDoc() =>
      b.rellenar && alFijo
          ? pw.Expanded(child: tabla(b, rellenar: true))
          : tabla(b),
    SonTotalesDoc() => sonYTotales(b),
    SeccionDoc() => seccion(b),
    FirmasDoc() => firmas(b),
    PieDoc() => pie(b),
    EspacioDoc() => pw.SizedBox(height: b.alto),
    CorteDoc() => lineaDeCorte(),
    LadoALadoDoc() => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < b.bloques.length; i++) ...[
          if (i > 0) pw.SizedBox(width: b.separacion),
          pw.Expanded(child: bloque(b.bloques[i])),
        ],
      ],
    ),
    MitadDoc() => pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [for (final x in b.bloques) bloque(x, alFijo: alFijo)],
      ),
    ),
  };

  static pw.Widget _monograma(String iniciales) => pw.Container(
    width: 60,
    height: 60,
    decoration: pw.BoxDecoration(
      color: _cromo,
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Stack(
      children: [
        pw.Center(
          child: pw.Text(
            iniciales,
            style: pw.TextStyle(
              fontSize: 21,
              fontWeight: pw.FontWeight.bold,
              color: _cromoTexto,
              letterSpacing: 0.5,
            ),
          ),
        ),
        pw.Positioned(
          left: 18,
          right: 18,
          bottom: 9,
          child: pw.Container(
            height: 3,
            decoration: pw.BoxDecoration(
              color: _marca,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    ),
  );

  static pw.Widget encabezado(EncabezadoDoc e) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      _monograma(e.iniciales),
      pw.SizedBox(width: 14),
      pw.Expanded(
        child: pw.Column(
          children: [
            pw.Text(
              e.nombre,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _tinta,
              ),
            ),
            if (e.direccion.trim().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                e.direccion.trim(),
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8, color: _texto2),
              ),
            ],
          ],
        ),
      ),
      pw.SizedBox(width: 14),
      pw.Container(
        width: e.anchoRecuadro,
        padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _tinta, width: 1),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              e.lineaDocumento,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _tinta,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              e.titulo,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 12.5,
                fontWeight: pw.FontWeight.bold,
                color: _tinta,
              ),
            ),
            if (e.subtitulo != null)
              pw.Text(
                e.subtitulo!,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 7,
                  letterSpacing: 0.8,
                  color: _texto2,
                ),
              ),
            pw.SizedBox(height: 6),
            pw.Text(
              e.numero,
              style: pw.TextStyle(
                fontSize: 11.5,
                fontWeight: pw.FontWeight.bold,
                color: _tinta,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  static pw.Widget datos(DatosDoc d) {
    pw.Widget fila((String, String) f) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: d.anchoRotulo,
            child: pw.Text(
              f.$1,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _tinta,
              ),
            ),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 7.5)),
          pw.Expanded(
            child: pw.Text(
              f.$2.trim().isEmpty ? '---' : f.$2,
              style: const pw.TextStyle(fontSize: 8, color: _tinta),
            ),
          ),
        ],
      ),
    );

    final columnas = d.porColumna;
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: _recuadro,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columnas.length; c++) ...[
            if (c > 0) pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [for (final f in columnas[c]) fila(f)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget celdas(CeldasDoc c) => pw.Container(
    height: c.alto,
    decoration: _recuadro,
    child: pw.Row(
      children: [
        for (var i = 0; i < c.items.length; i++)
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4),
              decoration: i == 0
                  ? null
                  : const pw.BoxDecoration(border: pw.Border(left: _divisor)),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    c.items[i].$1,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _tinta,
                    ),
                  ),
                  pw.SizedBox(height: 2.5),
                  pw.Text(
                    c.items[i].$2,
                    textAlign: pw.TextAlign.center,
                    maxLines: 1,
                    style: const pw.TextStyle(fontSize: 8, color: _tinta),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  /// Arriba los títulos con una línea debajo; después las filas, sin líneas
  /// entre ellas pero con las verticales que separan las columnas. Con
  /// [rellenar], las verticales siguen hasta abajo.
  static pw.Widget tabla(TablaDoc t, {bool rellenar = false}) {
    final anchos = <int, pw.TableColumnWidth>{
      for (var i = 0; i < t.columnas.length; i++)
        i: t.columnas[i].ancho == null
            ? const pw.FlexColumnWidth()
            : pw.FixedColumnWidth(t.columnas[i].ancho!),
    };

    pw.Widget celda(
      String texto,
      ColumnaDoc col, {
      bool titulo = false,
      bool negrita = false,
    }) => pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: titulo ? 6 : 4),
      child: pw.Text(
        texto,
        textAlign: titulo ? pw.TextAlign.center : _alinear(col.alineacion),
        style: pw.TextStyle(
          fontSize: titulo ? 6.8 : 8,
          fontWeight: titulo || negrita
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: _tinta,
        ),
      ),
    );

    pw.Widget fila(
      List<String> valores, {
      bool titulo = false,
      bool negrita = false,
      pw.BoxBorder? borde,
    }) => pw.Table(
      columnWidths: anchos,
      border: const pw.TableBorder(verticalInside: _divisor),
      children: [
        pw.TableRow(
          decoration: borde == null ? null : pw.BoxDecoration(border: borde),
          verticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            for (var i = 0; i < t.columnas.length; i++)
              celda(
                valores[i],
                t.columnas[i],
                titulo: titulo,
                negrita: negrita,
              ),
          ],
        ),
      ],
    );

    pw.Widget columnaVacia(bool conLinea) => pw.Container(
      decoration: conLinea
          ? const pw.BoxDecoration(border: pw.Border(left: _divisor))
          : null,
    );

    return pw.Container(
      decoration: _recuadro,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          fila(
            [for (final c in t.columnas) c.titulo],
            titulo: true,
            borde: const pw.Border(bottom: _divisor),
          ),
          if (t.muestraVacio)
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                t.vacio!,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8, color: _texto2),
              ),
            )
          else
            pw.Table(
              columnWidths: anchos,
              border: const pw.TableBorder(verticalInside: _divisor),
              children: [
                for (final f in t.filas)
                  pw.TableRow(
                    children: [
                      for (var i = 0; i < t.columnas.length; i++)
                        celda(f[i], t.columnas[i]),
                    ],
                  ),
              ],
            ),
          if (rellenar)
            pw.Expanded(
              child: pw.Row(
                children: [
                  for (var i = 0; i < t.columnas.length; i++)
                    if (t.columnas[i].ancho == null)
                      pw.Expanded(child: columnaVacia(i > 0))
                    else
                      pw.SizedBox(
                        width: t.columnas[i].ancho,
                        child: columnaVacia(i > 0),
                      ),
                ],
              ),
            ),
          if (t.total != null)
            fila(
              t.total!,
              negrita: true,
              borde: const pw.Border(top: _divisor),
            ),
        ],
      ),
    );
  }

  static pw.Widget sonYTotales(SonTotalesDoc s) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'SON: ${s.son}',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _tinta,
              ),
            ),
            if (s.detalle != null && s.detalle!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                s.detalle!,
                style: const pw.TextStyle(fontSize: 7.5, color: _texto2),
              ),
            ],
          ],
        ),
      ),
      pw.SizedBox(width: 18),
      pw.SizedBox(
        width: s.anchoTotales,
        child: pw.Column(
          children: [
            for (var i = 0; i < s.totales.length; i++)
              _lineaTotal(s.totales[i], ultimo: i == s.totales.length - 1),
          ],
        ),
      ),
    ],
  );

  static pw.Widget _lineaTotal((String, String) t, {required bool ultimo}) =>
      pw.Container(
        margin: pw.EdgeInsets.only(top: ultimo ? 3 : 0),
        padding: pw.EdgeInsets.only(top: ultimo ? 3 : 1.5, bottom: 1.5),
        decoration: ultimo
            ? const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: _tinta)),
              )
            : null,
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                t.$1,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: ultimo ? 8 : 7.3,
                  fontWeight: pw.FontWeight.bold,
                  color: _tinta,
                ),
              ),
            ),
            pw.SizedBox(
              width: 76,
              child: pw.Text(
                t.$2,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: ultimo ? 11 : 8,
                  fontWeight: ultimo
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: _tinta,
                ),
              ),
            ),
          ],
        ),
      );

  static pw.Widget seccion(SeccionDoc s) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Text(
      s.texto,
      style: pw.TextStyle(
        fontSize: 7.5,
        letterSpacing: 0.6,
        fontWeight: pw.FontWeight.bold,
        color: _tinta,
      ),
    ),
  );

  static pw.Widget pie(PieDoc p, {String? derecha}) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 5),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _borde, width: 0.6)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            p.texto,
            style: const pw.TextStyle(fontSize: 6.5, color: _texto2),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Text(
          derecha ?? p.derecha,
          style: pw.TextStyle(
            fontSize: 6.5,
            fontWeight: pw.FontWeight.bold,
            color: _texto2,
          ),
        ),
      ],
    ),
  );

  static pw.Widget firmas(FirmasDoc f) => pw.Padding(
    padding: pw.EdgeInsets.symmetric(horizontal: f.margen),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < f.firmas.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 40),
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Container(height: 0.7, color: _tinta),
                pw.SizedBox(height: 3),
                pw.Text(
                  f.firmas[i].$1.trim().isEmpty ? ' ' : f.firmas[i].$1,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _tinta,
                  ),
                ),
                pw.Text(
                  f.firmas[i].$2,
                  style: const pw.TextStyle(fontSize: 7, color: _texto2),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  static pw.Widget lineaDeCorte() => pw.Row(
    children: [
      for (var i = 0; i < 70; i++)
        pw.Expanded(
          child: pw.Container(height: 0.6, color: i.isEven ? _borde : null),
        ),
    ],
  );
}
