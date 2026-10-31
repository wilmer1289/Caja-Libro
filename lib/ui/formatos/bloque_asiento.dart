import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/libro_diario.dart';

/// Un asiento del Libro Diario: su glosa y sus líneas, cada cuenta con su
/// cadena completa (60 › 601 › 6011), el Debe y el Haber.
///
/// Antes este archivo dibujaba el asiento resumen del mes que colgaba de
/// Formatos oficiales. Ese resumen salió de allí: ahora cada operación se ve en
/// la sección Libro diario, con sus asientos reales, y este bloque dibuja uno.
///
/// En un ancho chico (celular) el Debe y el Haber comparten una sola columna,
/// cada importe con su rótulo; en uno amplio van en dos columnas, como en el
/// Formato 5.1.
class BloqueAsiento extends StatelessWidget {
  const BloqueAsiento({super.key, required this.numero, required this.etapa});

  /// La posición del asiento dentro de su operación: 1, 2 o 3.
  final int numero;
  final EtapaAsiento etapa;

  /// Por debajo de este ancho el bloque pasa a la disposición del celular.
  static const anchoCompacto = 520.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        final compacto = medidas.maxWidth < anchoCompacto;
        return Container(
          decoration: BoxDecoration(
            color: Tokens.superficie,
            borderRadius: BorderRadius.circular(Tokens.radio),
            border: Border.all(color: Tokens.borde),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cabecera(numero: numero, etapa: etapa),
              if (!compacto) const _Columnas(),
              for (final linea in etapa.lineas)
                _Linea(linea: linea, compacto: compacto),
              _Total(etapa: etapa, compacto: compacto),
            ],
          ),
        );
      },
    );
  }
}

const _borde = BorderSide(color: Tokens.borde);

const _cifras = TextStyle(
  fontSize: 12.5,
  color: Tokens.texto,
  fontFeatures: [FontFeature.tabularFigures()],
);

const _anchoImporte = 100.0;

String _importe(int centavos) =>
    centavos == 0 ? '' : Formato.monto(centavos / 100);

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.numero, required this.etapa});

  final int numero;
  final EtapaAsiento etapa;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Tokens.fondo,
        border: Border(bottom: BorderSide(color: Tokens.bordeFuerte)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Tokens.cromo,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Asiento $numero',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Tokens.cromoTexto,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etapa.tipo.etiqueta.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                    color: Tokens.texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  etapa.glosa,
                  style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Columnas extends StatelessWidget {
  const _Columnas();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
      fontSize: 9.5,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w700,
      color: Tokens.texto2,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: const BoxDecoration(border: Border(bottom: _borde)),
      child: const Row(
        children: [
          Expanded(child: Text('CUENTA', style: estilo)),
          SizedBox(
            width: _anchoImporte,
            child: Text('DEBE', style: estilo, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: _anchoImporte,
            child: Text('HABER', style: estilo, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.linea, required this.compacto});

  final LineaDiario linea;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    // La cuenta abonada va sangrada, como se escribe un asiento a mano.
    final abona = linea.haber > 0;
    final cadena = linea.cadena.map((c) => c.codigo).join(' › ');

    final cuenta = Padding(
      padding: EdgeInsets.only(left: abona ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cadena,
            style: const TextStyle(
              fontSize: 11,
              color: Tokens.texto2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            linea.denominacion,
            style: _cifras.copyWith(fontWeight: FontWeight.w600),
          ),
          // Por qué esta cuenta va de este lado: lo explica el motor, para
          // quien recién aprende a leer un asiento.
          if (linea.porQue.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              linea.porQue,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: Tokens.texto2,
              ),
            ),
          ],
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      decoration: const BoxDecoration(border: Border(bottom: _borde)),
      child: compacto
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cuenta),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      abona ? 'HABER' : 'DEBE',
                      style: const TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700,
                        color: Tokens.texto2,
                      ),
                    ),
                    Text(
                      _importe(abona ? linea.haber : linea.debe),
                      style: _cifras,
                    ),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cuenta),
                SizedBox(
                  width: _anchoImporte,
                  child: Text(
                    _importe(linea.debe),
                    textAlign: TextAlign.right,
                    style: _cifras,
                  ),
                ),
                SizedBox(
                  width: _anchoImporte,
                  child: Text(
                    _importe(linea.haber),
                    textAlign: TextAlign.right,
                    style: _cifras,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.etapa, required this.compacto});

  final EtapaAsiento etapa;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final estilo = _cifras.copyWith(fontWeight: FontWeight.w700);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      color: Tokens.fondo,
      child: compacto
          ? Row(
              children: [
                const Expanded(
                  child: Text(
                    'TOTAL',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                      color: Tokens.texto,
                    ),
                  ),
                ),
                Text(
                  'Debe ${Formato.monto(etapa.totalDebe / 100)}  ·  '
                  'Haber ${Formato.monto(etapa.totalHaber / 100)}',
                  style: estilo,
                ),
              ],
            )
          : Row(
              children: [
                const Expanded(
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                      color: Tokens.texto,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: _anchoImporte,
                  child: Text(
                    Formato.monto(etapa.totalDebe / 100),
                    textAlign: TextAlign.right,
                    style: estilo,
                  ),
                ),
                SizedBox(
                  width: _anchoImporte,
                  child: Text(
                    Formato.monto(etapa.totalHaber / 100),
                    textAlign: TextAlign.right,
                    style: estilo,
                  ),
                ),
              ],
            ),
    );
  }
}
