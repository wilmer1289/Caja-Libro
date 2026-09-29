import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/libro_oficial.dart';

/// El asiento resumen que va al Libro Diario.
///
/// El libro de caja anota cada operación; el diario recibe una sola línea por
/// mes con el total. Este bloque es ese puente, y es el mismo que el Excel pone
/// debajo del formato y copia a la hoja LD CAJA.
///
/// Se muestra aunque el dueño de la bodega no lo vaya a mirar nunca: es lo que
/// el contador necesita para pasar el mes a los libros, y tenerlo acá le ahorra
/// rehacer la suma a mano.
class BloqueAsiento extends StatelessWidget {
  const BloqueAsiento({
    super.key,
    required this.asiento,
    required this.periodo,
  });

  final AsientoResumen asiento;

  /// "septiembre de 2026", para la glosa.
  final String periodo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tokens.superficie,
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        border: Border.all(color: Tokens.borde),
        boxShadow: Tokens.sombraTarjeta,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: const BoxDecoration(
              color: Tokens.fondo,
              border: Border(bottom: BorderSide(color: Tokens.bordeFuerte)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Tokens.cromo,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    asiento.numero,
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        asiento.titulo,
                        style: const TextStyle(
                          fontSize: 12.5,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w700,
                          color: Tokens.texto,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${asiento.glosa} de $periodo',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Tokens.texto2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _Cabecera(),
          for (final linea in asiento.lineas) _Linea(linea: linea),
          _Total(asiento: asiento),
        ],
      ),
    );
  }
}

const _borde = BorderSide(color: Tokens.borde);

const _cifras = TextStyle(
  fontSize: 12.5,
  color: Tokens.texto,
  fontFeatures: [FontFeature.tabularFigures()],
);

class _Cabecera extends StatelessWidget {
  const _Cabecera();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
      fontSize: 9.5,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w700,
      color: Tokens.texto2,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 9, 18, 9),
      decoration: const BoxDecoration(border: Border(bottom: _borde)),
      child: const Row(
        children: [
          SizedBox(width: 74, child: Text('COD. CTA.', style: estilo)),
          Expanded(child: Text('DENOMINACIÓN DE LA CUENTA', style: estilo)),
          SizedBox(
            width: 104,
            child: Text('DEBE', style: estilo, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 104,
            child: Text('HABER', style: estilo, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.linea});

  final LineaAsiento linea;

  @override
  Widget build(BuildContext context) {
    // La cuenta abonada va sangrada, como se escribe un asiento a mano.
    final abona = linea.haber > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: const BoxDecoration(border: Border(bottom: _borde)),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              linea.codigo,
              style: _cifras.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: abona ? 20 : 0),
              child: Text(
                linea.denominacion,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _cifras,
              ),
            ),
          ),
          SizedBox(
            width: 104,
            child: Text(
              linea.debe == 0 ? '' : Formato.monto(linea.debe / 100),
              textAlign: TextAlign.right,
              style: _cifras,
            ),
          ),
          SizedBox(
            width: 104,
            child: Text(
              linea.haber == 0 ? '' : Formato.monto(linea.haber / 100),
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
  const _Total({required this.asiento});

  final AsientoResumen asiento;

  @override
  Widget build(BuildContext context) {
    final estilo = _cifras.copyWith(
      fontWeight: FontWeight.w700,
      color: Tokens.texto,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 11),
      color: Tokens.fondo,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'TOTAL',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
                color: Tokens.texto,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 104,
            child: Text(
              Formato.monto(asiento.totalDebe / 100),
              textAlign: TextAlign.right,
              style: estilo,
            ),
          ),
          SizedBox(
            width: 104,
            child: Text(
              Formato.monto(asiento.totalHaber / 100),
              textAlign: TextAlign.right,
              style: estilo,
            ),
          ),
        ],
      ),
    );
  }
}
