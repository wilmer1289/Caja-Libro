import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/enums.dart';
import '../../dominio/libro_diario.dart';
import '../formatos/bloque_asiento.dart';

/// Una operación del Libro Diario: correlativo, fecha, glosa y documento.
/// Al tocarla se despliega en sus asientos, cada uno con su cadena de cuentas.
class TarjetaOperacion extends StatefulWidget {
  const TarjetaOperacion({
    super.key,
    required this.asiento,
    this.abierta = false,
  });

  final AsientoDiario asiento;

  /// Si arranca desplegada.
  final bool abierta;

  @override
  State<TarjetaOperacion> createState() => _TarjetaOperacionState();
}

class _TarjetaOperacionState extends State<TarjetaOperacion> {
  late bool _abierta = widget.abierta;

  @override
  Widget build(BuildContext context) {
    final a = widget.asiento;
    final entro = a.origen.tipo == Tipo.entro;
    final color = entro ? Tokens.entro : Tokens.salio;

    final detalle = [
      Formato.fecha(a.fecha),
      if (a.documento != null) a.documento!,
      if (a.mercaderia != null) a.mercaderia!,
    ].join('  ·  ');

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
          InkWell(
            onTap: () => setState(() => _abierta = !_abierta),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Tokens.cromo,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      a.numero,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Tokens.cromoTexto,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.glosa,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Tokens.texto,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detalle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Tokens.texto2,
                          ),
                        ),
                        if (a.faltaCosto) ...[
                          const SizedBox(height: 6),
                          const _AvisoSinCosto(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entro ? '+' : '−'} ${Formato.soles(a.origen.centavos / 100)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Icon(
                    _abierta
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Tokens.texto2,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _abierta
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (a.faltaCosto) ...[
                          const _ExplicacionSinCosto(),
                          const SizedBox(height: 10),
                        ],
                        for (var i = 0; i < a.etapas.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          BloqueAsiento(numero: i + 1, etapa: a.etapas[i]),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// La etiqueta de una venta anterior a los tipos de mercadería.
class _AvisoSinCosto extends StatelessWidget {
  const _AvisoSinCosto();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Tokens.marcaSuave,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Tokens.marca.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 13, color: Tokens.marcaOscura),
          SizedBox(width: 5),
          Text(
            'Sin asiento 2',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Tokens.marcaOscura,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplicacionSinCosto extends StatelessWidget {
  const _ExplicacionSinCosto();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Tokens.marcaSuave,
        borderRadius: BorderRadius.circular(Tokens.radio),
      ),
      child: const Text(
        'Esta venta se anotó sin el costo de la mercadería, así que no tiene '
        'asiento de costo de venta. Los asientos que ves son los que se '
        'pueden armar con lo registrado.',
        style: TextStyle(fontSize: 12.5, color: Tokens.texto),
      ),
    );
  }
}
