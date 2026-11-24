import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/libro_diario.dart';
import '../../dominio/pcge.dart';

/// Panel que muestra el "Costo de ventas del período" agrupado por cuenta,
/// con su total y el asiento de cierre (como la hoja CÁLCULOS).
class CostoVentasResumenPanel extends StatelessWidget {
  const CostoVentasResumenPanel({
    super.key,
    required this.resumen,
    required this.libro,
  });

  final CostoVentasResumen? resumen;
  final LibroDiario libro;

  @override
  Widget build(BuildContext context) {
    if (resumen == null || resumen!.vacio) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tokens.superficie,
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        border: Border.all(color: Tokens.borde),
        boxShadow: Tokens.sombraTarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, size: 18, color: Tokens.texto2),
              SizedBox(width: 8),
              Text(
                'Costo de ventas del período',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Tokens.texto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Resumen por cuenta
          for (final entrada in resumen!.porCuenta.entries) ...[
            _FilaCuenta(
              cuenta: entrada.key,
              monto: entrada.value,
              denominacion: libro.negocio.razonSocial.isNotEmpty
                  ? Pcge.instancia.denominacion(entrada.key)
                  : entrada.key,
            ),
            const Divider(height: 16),
          ],
          // Total
          Row(
            children: [
              const Text(
                'Total costo de ventas',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Tokens.texto,
                ),
              ),
              const Spacer(),
              Text(
                Formato.soles(resumen!.total / 100),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Tokens.texto,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Asiento de cierre (referencial, no se suma al libro)
          const Text(
            'Asiento de cierre (referencial):',
            style: TextStyle(fontSize: 11.5, color: Tokens.texto2),
          ),
          const SizedBox(height: 8),
          _AsientoReferencial(resumen: resumen!),
        ],
      ),
    );
  }
}

class _FilaCuenta extends StatelessWidget {
  const _FilaCuenta({
    required this.cuenta,
    required this.monto,
    required this.denominacion,
  });

  final String cuenta;
  final int monto;
  final String denominacion;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Tokens.cromo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Tokens.cromo.withValues(alpha: 0.3)),
          ),
          child: Text(
            cuenta,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Tokens.cromoTexto,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            denominacion,
            style: const TextStyle(fontSize: 12, color: Tokens.texto2),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          Formato.soles(monto / 100),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Tokens.texto,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _AsientoReferencial extends StatelessWidget {
  const _AsientoReferencial({required this.resumen});

  final CostoVentasResumen resumen;

  @override
  Widget build(BuildContext context) {
    final asientos = resumen.asientosDeCierre(
      pcge: Pcge.instancia,
      cuentaMercaderias: '20111',
    );

    if (asientos.isEmpty) return const SizedBox.shrink();

    final etapa = asientos.first;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'DEBE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Tokens.salio,
                ),
              ),
              const Spacer(),
              const Text(
                'HABER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Tokens.entro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final linea in etapa.lineas) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    '${linea.codigo} ${linea.denominacion}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: linea.alDebe ? Tokens.salio : Tokens.entro,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    linea.debe > 0
                        ? Formato.soles(linea.debe / 100)
                        : '',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: linea.alDebe ? Tokens.salio : Tokens.texto2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    linea.haber > 0
                        ? Formato.soles(linea.haber / 100)
                        : '',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: linea.haber > 0 ? Tokens.entro : Tokens.texto2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
          const Divider(height: 8),
          Row(
            children: [
              const Expanded(
                flex: 3,
                child: Text(
                  'Total',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Text(
                  Formato.soles(etapa.totalDebe / 100),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Tokens.salio,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  Formato.soles(etapa.totalHaber / 100),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Tokens.entro,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}