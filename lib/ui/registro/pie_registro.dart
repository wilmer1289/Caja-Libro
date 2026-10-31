import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// Qué papeles se mandan a imprimir al guardar.
enum QueImprimir {
  boleta('Boleta'),
  recibo('Recibo'),
  ambos('Boleta y recibo');

  const QueImprimir(this.etiqueta);
  final String etiqueta;
}

/// Pie compartido por el registro en celular y escritorio.
///
/// Mantiene las acciones en el mismo orden y deja la validación/guardado en
/// RegistroHoja para que el componente sólo se encargue de la presentación.
class PieRegistro extends StatelessWidget {
  const PieRegistro({
    super.key,
    required this.color,
    required this.ultimoPaso,
    required this.hayBoleta,
    required this.hayRecibo,
    required this.guardando,
    required this.bloqueaBancarizacion,
    required this.bloqueaCajaCerrada,
    required this.errorGuardar,
    required this.compacto,
    required this.onAtras,
    required this.onContinuar,
    required this.onGuardar,
    required this.onGuardarEImprimir,
    this.onAbrirCaja,
  });

  final Color color;
  final bool ultimoPaso;

  /// Qué papeles tiene este movimiento. Con los dos, el ícono de imprimir
  /// pregunta cuál; con uno solo, imprime ese.
  final bool hayBoleta;
  final bool hayRecibo;
  final bool guardando;
  final bool bloqueaBancarizacion;
  final bool bloqueaCajaCerrada;
  final String? errorGuardar;
  final bool compacto;
  final VoidCallback onAtras;
  final VoidCallback onContinuar;
  final VoidCallback onGuardar;
  final ValueChanged<QueImprimir> onGuardarEImprimir;
  final VoidCallback? onAbrirCaja;

  @override
  Widget build(BuildContext context) {
    final bloqueado = bloqueaBancarizacion || bloqueaCajaCerrada;
    final hayError = errorGuardar != null || bloqueado;

    final siguiente = ultimoPaso
        ? FilledButton(
            onPressed: guardando || bloqueado ? null : onGuardar,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Guardar'),
          )
        : FilledButton.icon(
            onPressed: bloqueado ? null : onContinuar,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            label: const Text('Continuar'),
          );

    final atras = OutlinedButton(
      onPressed: onAtras,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: const Text('Atrás'),
    );

    final activo = !guardando && !bloqueado;
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Tokens.radio),
      side: const BorderSide(color: Tokens.borde),
    );
    final Widget? imprimir = !ultimoPaso || (!hayBoleta && !hayRecibo)
        ? null
        : hayBoleta && hayRecibo
        // Con boleta y recibo, se elige qué imprimir.
        ? SizedBox.square(
            dimension: 52,
            child: PopupMenuButton<QueImprimir>(
              tooltip: 'Guardar e imprimir',
              enabled: activo,
              onSelected: onGuardarEImprimir,
              itemBuilder: (_) => [
                for (final opcion in QueImprimir.values)
                  PopupMenuItem(value: opcion, child: Text(opcion.etiqueta)),
              ],
              child: Material(
                color: activo ? Tokens.marcaSuave : Tokens.fondo,
                shape: forma,
                child: Icon(
                  Icons.print_rounded,
                  color: activo ? Tokens.marcaOscura : Tokens.bordeFuerte,
                ),
              ),
            ),
          )
        : SizedBox.square(
            dimension: 52,
            child: IconButton(
              tooltip: 'Guardar e imprimir',
              onPressed: activo
                  ? () => onGuardarEImprimir(
                      hayBoleta ? QueImprimir.boleta : QueImprimir.recibo,
                    )
                  : null,
              icon: const Icon(Icons.print_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Tokens.marcaSuave,
                foregroundColor: Tokens.marcaOscura,
                shape: forma,
              ),
            ),
          );

    final mensaje = errorGuardar == null && bloqueaCajaCerrada
        ? Row(
            children: [
              const Icon(Icons.lock_rounded, size: 17, color: Tokens.salio),
              const SizedBox(width: 7),
              const Flexible(
                child: Text(
                  'Abre la caja para registrar en efectivo',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Tokens.salio,
                  ),
                ),
              ),
              if (onAbrirCaja != null) ...[
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: onAbrirCaja,
                  style: TextButton.styleFrom(
                    foregroundColor: Tokens.salio,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.lock_open_rounded, size: 17),
                  label: const Text('Abrir la caja'),
                ),
              ],
            ],
          )
        : hayError
        ? Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 17,
                color: Tokens.salio,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  errorGuardar ?? 'Cambia el medio de pago para guardar',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Tokens.salio,
                  ),
                ),
              ),
            ],
          )
        : const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(
        compacto ? 16 : 28,
        12,
        compacto ? 16 : 28,
        compacto ? 16 : 18,
      ),
      decoration: const BoxDecoration(
        color: Tokens.fondo,
        border: Border(top: BorderSide(color: Tokens.borde)),
      ),
      child: compacto
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hayError) ...[mensaje, const SizedBox(height: 10)],
                Row(
                  children: [
                    atras,
                    const SizedBox(width: 8),
                    Expanded(child: siguiente),
                    if (imprimir != null) ...[
                      const SizedBox(width: 8),
                      imprimir,
                    ],
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: mensaje),
                const SizedBox(width: 12),
                atras,
                const SizedBox(width: 10),
                siguiente,
                if (imprimir != null) ...[const SizedBox(width: 10), imprimir],
              ],
            ),
    );
  }
}
