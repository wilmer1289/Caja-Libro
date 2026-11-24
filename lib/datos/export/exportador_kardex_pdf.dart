import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/formato.dart';
import '../../dominio/almacen.dart';
import '../../dominio/registro_inventario.dart';

/// Los formatos 13.1 y 12.1 en PDF, en A4 apaisado como la hoja REG INV.
///
/// Cada producto empieza en una hoja nueva: así "Todos los productos" es un
/// solo archivo con el registro de cada existencia, como lo pide SUNAT. El
/// encabezado de la tabla se repite en cada hoja.
class ExportadorKardexPdf {
  static const _hoja = PdfPageFormat.a4;
  static const _margen = 20.0;
  static double get _usable => _hoja.landscape.width - _margen * 2;

  static pw.Font? _normal;
  static pw.Font? _negrita;

  static Future<void> _cargarFuentes() async {
    if (_normal != null) return;
    _normal = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
    );
    _negrita = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
    );
  }

  static const _texto = PdfColor.fromInt(0xFF24211F);
  static const _texto2 = PdfColor.fromInt(0xFF77716B);
  static const _borde = PdfColor.fromInt(0xFFD6D0C9);
  static const _cabecera = PdfColor.fromInt(0xFFF1EEE9);
  static const _total = PdfColor.fromInt(0xFFF7F6F3);

  /// Formato 13.1, valorizado.
  static Future<Uint8List> formato131(
    List<RegistroInventario> registros,
  ) async {
    await _cargarFuentes();
    const fijas = [50.0, 30.0, 38.0, 46.0, 40.0];
    final numerica = (_usable - fijas.fold(0.0, (t, a) => t + a)) / 9;
    final anchos = [...fijas, for (var i = 0; i < 9; i++) numerica];

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: _normal!, bold: _negrita!),
    );
    for (final r in registros) {
      final filas = [
        for (final f in r.filas)
          [
            Formato.fecha(f.fecha),
            f.tipoDocumento,
            f.serie,
            f.numero,
            f.operacion,
            _cantidad(f.entradaCantidad),
            RegistroInventario.unitario(f.entradaUnitario),
            _monto(f.entradaCosto),
            _cantidad(f.salidaCantidad),
            RegistroInventario.unitario(f.salidaUnitario),
            _monto(f.salidaCosto),
            _cantidad(f.saldoCantidad),
            RegistroInventario.unitario(f.saldoUnitario),
            _monto(f.saldoCosto),
          ],
      ];
      final total = [
        '',
        '',
        '',
        '',
        'TOTALES',
        _cantidad(r.entradasCantidad),
        '',
        _monto(r.entradasCosto),
        _cantidad(r.salidasCantidad),
        '',
        _monto(r.salidasCosto),
        _cantidad(r.saldoFinalCantidad),
        '',
        _monto(r.saldoFinalCosto),
      ];
      doc.addPage(
        _pagina(
          titulo: RegistroInventario.titulo131,
          encabezado: r.encabezado(),
          anchos: anchos,
          grupos: [
            (
              'DOCUMENTO DE TRASLADO, COMPROBANTE DE PAGO,\n'
                  'DOCUMENTO INTERNO O SIMILAR',
              4,
            ),
            ('TIPO DE\nOPERACIÓN\n(TABLA 12)', 1),
            ('ENTRADAS', 3),
            ('SALIDAS', 3),
            ('SALDO FINAL', 3),
          ],
          titulos: const [
            'FECHA',
            'TIPO\n(T. 10)',
            'SERIE',
            'NÚMERO',
            '',
            'CANTIDAD',
            'COSTO\nUNITARIO',
            'COSTO\nTOTAL',
            'CANTIDAD',
            'COSTO\nUNITARIO',
            'COSTO\nTOTAL',
            'CANTIDAD',
            'COSTO\nUNITARIO',
            'COSTO\nTOTAL',
          ],
          filas: filas,
          total: total,
          primeraNumerica: 5,
        ),
      );
    }
    return doc.save();
  }

  /// Formato 12.1, en unidades físicas.
  static Future<Uint8List> formato121(
    List<RegistroInventario> registros,
  ) async {
    await _cargarFuentes();
    const fijas = [60.0, 44.0, 50.0, 60.0, 64.0];
    final numerica = (_usable - fijas.fold(0.0, (t, a) => t + a)) / 3;
    final anchos = [...fijas, for (var i = 0; i < 3; i++) numerica];

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: _normal!, bold: _negrita!),
    );
    for (final r in registros) {
      doc.addPage(
        _pagina(
          titulo: RegistroInventario.titulo121,
          encabezado: r.encabezado(valorizado: false),
          anchos: anchos,
          grupos: [
            (
              'DOCUMENTO DE TRASLADO, COMPROBANTE DE PAGO,\n'
                  'DOCUMENTO INTERNO O SIMILAR',
              4,
            ),
            ('TIPO DE\nOPERACIÓN\n(TABLA 12)', 1),
            ('ENTRADAS', 1),
            ('SALIDAS', 1),
            ('SALDO FINAL', 1),
          ],
          titulos: const [
            'FECHA',
            'TIPO\n(TABLA 10)',
            'SERIE',
            'NÚMERO',
            '',
            'CANTIDAD',
            'CANTIDAD',
            'CANTIDAD',
          ],
          filas: [
            for (final f in r.filas)
              [
                Formato.fecha(f.fecha),
                f.tipoDocumento,
                f.serie,
                f.numero,
                f.operacion,
                _cantidad(f.entradaCantidad),
                _cantidad(f.salidaCantidad),
                _cantidad(f.saldoCantidad),
              ],
          ],
          total: [
            '',
            '',
            '',
            '',
            'TOTALES',
            _cantidad(r.entradasCantidad),
            _cantidad(r.salidasCantidad),
            _cantidad(r.saldoFinalCantidad),
          ],
          primeraNumerica: 5,
        ),
      );
    }
    return doc.save();
  }

  static pw.MultiPage _pagina({
    required String titulo,
    required List<(String, String)> encabezado,
    required List<double> anchos,
    required List<(String, int)> grupos,
    required List<String> titulos,
    required List<List<String>> filas,
    required List<String> total,
    required int primeraNumerica,
  }) {
    final columnas = {
      for (var i = 0; i < anchos.length; i++)
        i: pw.FixedColumnWidth(anchos[i]),
    };
    pw.Widget cabeceraTabla() => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _filaGrupos(grupos, anchos),
        pw.Table(
          border: pw.TableBorder.all(color: _borde, width: .4),
          columnWidths: columnas,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _cabecera),
              children: [
                for (final t in titulos)
                  pw.Container(
                    height: 22,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      t,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 5.6,
                        fontWeight: pw.FontWeight.bold,
                        color: _texto,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );

    return pw.MultiPage(
      pageFormat: _hoja.landscape,
      margin: const pw.EdgeInsets.fromLTRB(
        _margen,
        _margen,
        _margen,
        _margen + 4,
      ),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            titulo,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: _texto,
            ),
          ),
          pw.SizedBox(height: 6),
          _encabezado(encabezado),
          pw.SizedBox(height: 8),
          cabeceraTabla(),
        ],
      ),
      footer: (ctx) => pw.Padding(
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
      ),
      build: (ctx) => [
        pw.Table(
          border: pw.TableBorder.all(color: _borde, width: .35),
          columnWidths: columnas,
          children: [
            for (final fila in filas) _fila(fila, primeraNumerica),
            _fila(total, primeraNumerica, total: true),
          ],
        ),
        if (filas.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Sin movimientos en el período.',
              style: const pw.TextStyle(fontSize: 7, color: _texto2),
            ),
          ),
      ],
    );
  }

  /// "PERÍODO: OCTUBRE 2026", en dos columnas.
  static pw.Widget _encabezado(List<(String, String)> datos) {
    final mitad = (datos.length / 2).ceil();
    pw.Widget columna(Iterable<(String, String)> parte) => pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final (rotulo, valor) in parte)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '$rotulo: ',
                      style: pw.TextStyle(
                        fontSize: 6.8,
                        fontWeight: pw.FontWeight.bold,
                        color: _texto,
                      ),
                    ),
                    pw.TextSpan(
                      text: valor.isEmpty ? '—' : valor,
                      style: const pw.TextStyle(fontSize: 6.8, color: _texto),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        columna(datos.take(mitad)),
        pw.SizedBox(width: 16),
        columna(datos.skip(mitad)),
      ],
    );
  }

  /// La fila de arriba de la cabecera: los grupos de columnas.
  static pw.Widget _filaGrupos(List<(String, int)> grupos, List<double> anchos) {
    var i = 0;
    return pw.Row(
      children: [
        for (final (texto, columnas) in grupos)
          () {
            final ancho = anchos
                .sublist(i, i + columnas)
                .fold(0.0, (t, a) => t + a);
            i += columnas;
            return pw.Container(
              width: ancho,
              height: 24,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: _cabecera,
                border: pw.Border.all(color: _borde, width: .4),
              ),
              child: pw.Text(
                texto,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 5.8,
                  fontWeight: pw.FontWeight.bold,
                  color: _texto,
                ),
              ),
            );
          }(),
      ],
    );
  }

  static pw.TableRow _fila(
    List<String> celdas,
    int primeraNumerica, {
    bool total = false,
  }) => pw.TableRow(
    decoration: total ? const pw.BoxDecoration(color: _total) : null,
    children: [
      for (var i = 0; i < celdas.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: pw.Text(
            celdas[i],
            textAlign: i >= primeraNumerica
                ? pw.TextAlign.right
                : pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 6.4,
              fontWeight: total ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: _texto,
            ),
          ),
        ),
    ],
  );

  static String _cantidad(int? milesimas) =>
      milesimas == null ? '' : Cantidad.texto(milesimas);

  static String _monto(int? centavos) =>
      centavos == null ? '' : Formato.monto(centavos / 100);
}
