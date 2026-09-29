import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../../dominio/documento.dart';

/// Un papel del negocio en pantalla, igual al PDF.
///
/// Dibuja la hoja con las mismas piezas y las mismas medidas que
/// `comprobantes_pdf.dart` —una A4 mide 595 de ancho— y después la escala al
/// lugar que haya. Así la vista previa del recibo, la boleta o el acta es
/// exactamente lo que va a salir impreso.
class VistaDocumento extends StatelessWidget {
  const VistaDocumento({
    super.key,
    required this.hoja,
    this.escalaMaxima = 1.3,
  });

  final HojaDoc hoja;

  /// Hasta cuánto se agranda en una pantalla ancha: más que esto, la letra
  /// del papel se ve de juguete.
  final double escalaMaxima;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        final escala = math.min(medidas.maxWidth / hoja.ancho, escalaMaxima);
        return Center(
          child: SizedBox(
            width: hoja.ancho * escala,
            child: FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              child: _Papel(hoja: hoja),
            ),
          ),
        );
      },
    );
  }
}

class _Papel extends StatelessWidget {
  const _Papel({required this.hoja});

  final HojaDoc hoja;

  @override
  Widget build(BuildContext context) {
    final fijo = hoja.alto != null;
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: fijo ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final b in hoja.bloques) _Pieza.de(b, alFijo: fijo),
        if (!fijo && hoja.pie != null) ...[
          const SizedBox(height: 18),
          _Pieza.de(hoja.pie!),
        ],
      ],
    );

    return Container(
      width: hoja.ancho,
      height: hoja.alto,
      padding: EdgeInsets.fromLTRB(
        hoja.margen.izquierda,
        hoja.margen.arriba,
        hoja.margen.derecha,
        hoja.margen.abajo,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142A1A0C),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x1A2A1A0C),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: Tokens.tipografia,
          color: _tinta,
          fontSize: 8,
          height: 1.25,
        ),
        child: contenido,
      ),
    );
  }
}

const _tinta = Color(0xFF24211F);
const _gris = Color(0xFF77716B);
const _grisClaro = Color(0xFFD6D0C9);
const _marca = Color(0xFFF97316);
const _divisor = BorderSide(color: _tinta, width: 0.5);

final _recuadro = BoxDecoration(
  border: Border.all(color: _tinta, width: 0.8),
  borderRadius: BorderRadius.circular(7),
);

TextStyle _estilo(double tamano, {bool negrita = false, Color? color}) =>
    TextStyle(
      fontSize: tamano,
      fontWeight: negrita ? FontWeight.w700 : FontWeight.w400,
      color: color ?? _tinta,
    );

TextAlign _alinear(AlineacionDoc a) => switch (a) {
  AlineacionDoc.izquierda => TextAlign.left,
  AlineacionDoc.centro => TextAlign.center,
  AlineacionDoc.derecha => TextAlign.right,
};

/// Cada pieza, igual que en el PDF.
class _Pieza {
  static Widget de(BloqueDoc b, {bool alFijo = false}) => switch (b) {
    EncabezadoDoc() => _encabezado(b),
    DatosDoc() => _datos(b),
    CeldasDoc() => _celdas(b),
    TablaDoc() =>
      b.rellenar && alFijo
          ? Expanded(child: _tabla(b, rellenar: true))
          : _tabla(b),
    SonTotalesDoc() => _sonYTotales(b),
    SeccionDoc() => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        b.texto,
        style: _estilo(7.5, negrita: true).copyWith(letterSpacing: 0.6),
      ),
    ),
    FirmasDoc() => _firmas(b),
    PieDoc() => _pie(b),
    EspacioDoc() => SizedBox(height: b.alto),
    CorteDoc() => Row(
      children: [
        for (var i = 0; i < 70; i++)
          Expanded(
            child: Container(height: 0.6, color: i.isEven ? _grisClaro : null),
          ),
      ],
    ),
    LadoALadoDoc() => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < b.bloques.length; i++) ...[
          if (i > 0) SizedBox(width: b.separacion),
          Expanded(child: de(b.bloques[i])),
        ],
      ],
    ),
    MitadDoc() => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final x in b.bloques) de(x, alFijo: alFijo)],
      ),
    ),
  };

  static Widget _encabezado(EncabezadoDoc e) => Row(
    children: [
      Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Tokens.cromo,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                e.iniciales,
                style: _estilo(
                  21,
                  negrita: true,
                  color: Tokens.cromoTexto,
                ).copyWith(letterSpacing: 0.5),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 9,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _marca,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          children: [
            Text(
              e.nombre,
              textAlign: TextAlign.center,
              style: _estilo(14, negrita: true),
            ),
            if (e.direccion.trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                e.direccion.trim(),
                textAlign: TextAlign.center,
                style: _estilo(8, color: _gris),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(width: 14),
      Container(
        width: e.anchoRecuadro,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          border: Border.all(color: _tinta),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(e.lineaDocumento, style: _estilo(10, negrita: true)),
            const SizedBox(height: 5),
            Text(
              e.titulo,
              textAlign: TextAlign.center,
              style: _estilo(12.5, negrita: true),
            ),
            if (e.subtitulo != null)
              Text(
                e.subtitulo!,
                textAlign: TextAlign.center,
                style: _estilo(7, color: _gris).copyWith(letterSpacing: 0.8),
              ),
            const SizedBox(height: 6),
            Text(e.numero, style: _estilo(11.5, negrita: true)),
          ],
        ),
      ),
    ],
  );

  static Widget _datos(DatosDoc d) {
    Widget fila((String, String) f) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: d.anchoRotulo,
            child: Text(f.$1, style: _estilo(7.5, negrita: true)),
          ),
          Text(': ', style: _estilo(7.5)),
          Expanded(
            child: Text(f.$2.trim().isEmpty ? '---' : f.$2, style: _estilo(8)),
          ),
        ],
      ),
    );

    final columnas = d.porColumna;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: _recuadro,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columnas.length; c++) ...[
            if (c > 0) const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final f in columnas[c]) fila(f)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _celdas(CeldasDoc c) => Container(
    height: c.alto,
    decoration: _recuadro,
    child: Row(
      children: [
        for (var i = 0; i < c.items.length; i++)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: i == 0
                  ? null
                  : const BoxDecoration(border: Border(left: _divisor)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    c.items[i].$1,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: _estilo(6.5, negrita: true),
                  ),
                  const SizedBox(height: 2.5),
                  Text(
                    c.items[i].$2,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _estilo(8),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  static Widget _tabla(TablaDoc t, {bool rellenar = false}) {
    final anchos = <int, TableColumnWidth>{
      for (var i = 0; i < t.columnas.length; i++)
        i: t.columnas[i].ancho == null
            ? const FlexColumnWidth()
            : FixedColumnWidth(t.columnas[i].ancho!),
    };

    Widget celda(
      String texto,
      ColumnaDoc col, {
      bool titulo = false,
      bool negrita = false,
    }) => Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: titulo ? 6 : 4),
      child: Text(
        texto,
        textAlign: titulo ? TextAlign.center : _alinear(col.alineacion),
        style: _estilo(titulo ? 6.8 : 8, negrita: titulo || negrita),
      ),
    );

    Widget fila(
      List<String> valores, {
      bool titulo = false,
      bool negrita = false,
      Border? borde,
    }) => Table(
      columnWidths: anchos,
      border: const TableBorder(verticalInside: _divisor),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: borde == null ? null : BoxDecoration(border: borde),
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

    Widget columnaVacia(bool conLinea) => Container(
      decoration: conLinea
          ? const BoxDecoration(border: Border(left: _divisor))
          : null,
    );

    return Container(
      decoration: _recuadro,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: rellenar ? MainAxisSize.max : MainAxisSize.min,
        children: [
          fila(
            [for (final c in t.columnas) c.titulo],
            titulo: true,
            borde: const Border(bottom: _divisor),
          ),
          if (t.muestraVacio)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                t.vacio!,
                textAlign: TextAlign.center,
                style: _estilo(8, color: _gris),
              ),
            )
          else
            Table(
              columnWidths: anchos,
              border: const TableBorder(verticalInside: _divisor),
              children: [
                for (final f in t.filas)
                  TableRow(
                    children: [
                      for (var i = 0; i < t.columnas.length; i++)
                        celda(f[i], t.columnas[i]),
                    ],
                  ),
              ],
            ),
          if (rellenar)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < t.columnas.length; i++)
                    if (t.columnas[i].ancho == null)
                      Expanded(child: columnaVacia(i > 0))
                    else
                      SizedBox(
                        width: t.columnas[i].ancho,
                        child: columnaVacia(i > 0),
                      ),
                ],
              ),
            ),
          if (t.total != null)
            fila(t.total!, negrita: true, borde: const Border(top: _divisor)),
        ],
      ),
    );
  }

  static Widget _sonYTotales(SonTotalesDoc s) {
    Widget linea((String, String) t, bool ultimo) => Container(
      margin: EdgeInsets.only(top: ultimo ? 3 : 0),
      padding: EdgeInsets.only(top: ultimo ? 3 : 1.5, bottom: 1.5),
      decoration: ultimo
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: _tinta)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.$1,
              textAlign: TextAlign.right,
              style: _estilo(ultimo ? 8 : 7.3, negrita: true),
            ),
          ),
          SizedBox(
            width: 76,
            child: Text(
              t.$2,
              textAlign: TextAlign.right,
              style: _estilo(ultimo ? 11 : 8, negrita: ultimo),
            ),
          ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SON: ${s.son}', style: _estilo(8, negrita: true)),
              if (s.detalle != null && s.detalle!.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(s.detalle!, style: _estilo(7.5, color: _gris)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: s.anchoTotales,
          child: Column(
            children: [
              for (var i = 0; i < s.totales.length; i++)
                linea(s.totales[i], i == s.totales.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _firmas(FirmasDoc f) => Padding(
    padding: EdgeInsets.symmetric(horizontal: f.margen),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < f.firmas.length; i++) ...[
          if (i > 0) const SizedBox(width: 40),
          Expanded(
            child: Column(
              children: [
                Container(height: 0.7, color: _tinta),
                const SizedBox(height: 3),
                Text(
                  f.firmas[i].$1.trim().isEmpty ? ' ' : f.firmas[i].$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _estilo(8, negrita: true),
                ),
                Text(f.firmas[i].$2, style: _estilo(7, color: _gris)),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  static Widget _pie(PieDoc p) => Container(
    padding: const EdgeInsets.only(top: 5),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: _grisClaro, width: 0.6)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(p.texto, style: _estilo(6.5, color: _gris)),
        ),
        const SizedBox(width: 12),
        Text(p.derecha, style: _estilo(6.5, negrita: true, color: _gris)),
      ],
    ),
  );
}
