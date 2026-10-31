import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/enums.dart';
import '../../dominio/movimiento.dart';

/// Un renglón del historial.
///
/// El signo se comunica dos veces: por color y por flecha (↑/↓). Quien no
/// distingue verde de rojo sigue leyendo la app sin problema (§5).
class FilaMovimiento extends StatelessWidget {
  const FilaMovimiento({
    super.key,
    required this.movimiento,
    this.onTap,
    this.resaltar = false,
    this.accion,
  });

  final Movimiento movimiento;
  final VoidCallback? onTap;

  /// La fila del movimiento recién registrado: hace un destello verde que se
  /// apaga solo, para que se vea dónde quedó lo que se acaba de anotar.
  final bool resaltar;

  /// Algo al final de la fila, como el botón "⋮" del historial.
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final entro = movimiento.tipo == Tipo.entro;
    final color = entro ? Tokens.entro : Tokens.salio;

    final fila = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Text(
                movimiento.tipo.flecha,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movimiento.concepto.isEmpty
                        ? movimiento.categoria.etiqueta
                        : movimiento.concepto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Tokens.texto,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${movimiento.categoria.etiqueta} · '
                          '${movimiento.medio.etiqueta} · '
                          '${Formato.fechaRelativa(movimiento.fecha)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Tokens.texto2,
                          ),
                        ),
                      ),
                      if (movimiento.tieneVoucher) ...[
                        const SizedBox(width: 4),
                        const Tooltip(
                          message: 'Con voucher',
                          child: Icon(
                            Icons.attach_file_rounded,
                            size: 14,
                            color: Tokens.texto2,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_tipoDeMercaderia(movimiento) case final tipo?) ...[
                    const SizedBox(height: 4),
                    _EtiquetaMercaderia(texto: tipo),
                  ],
                  // Desde S/ 700 el voucher es obligatorio: si falta (porque
                  // se anotó antes de la regla), la fila lo recuerda.
                  if (movimiento.exigeVoucher && !movimiento.tieneVoucher) ...[
                    const SizedBox(height: 4),
                    const _FaltaVoucher(),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entro ? '+' : '−'} ${Formato.soles(movimiento.monto)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                _PuntoSync(estado: movimiento.sync),
              ],
            ),
            if (accion != null) ...[const SizedBox(width: 4), accion!],
          ],
        ),
      ),
    );

    if (!resaltar) return fila;
    return _Destello(child: fila);
  }
}

/// El tipo de mercadería del movimiento, para mostrarlo en su fila: "tela" en
/// una compra y "tela · costo S/ 1,000.00" en una venta. Null si no tiene.
String? _tipoDeMercaderia(Movimiento m) {
  final nombre = m.mercaderiaNombre?.trim();
  if (nombre == null || nombre.isEmpty) return null;
  final costo = m.costoCentavos ?? 0;
  if (m.tipo == Tipo.entro && costo > 0) {
    return '$nombre · costo ${Formato.soles(costo / 100)}';
  }
  return nombre;
}

class _EtiquetaMercaderia extends StatelessWidget {
  const _EtiquetaMercaderia({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Tokens.marcaSuave,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 12,
            color: Tokens.marcaOscura,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Tokens.marcaOscura,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaltaVoucher extends StatelessWidget {
  const _FaltaVoucher();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF0DCB4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 12, color: Color(0xFF6B520F)),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              'Falta el voucher',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B520F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un fondo verde que aparece y se apaga solo en poco más de un segundo.
class _Destello extends StatefulWidget {
  const _Destello({required this.child});

  final Widget child;

  @override
  State<_Destello> createState() => _DestelloState();
}

class _DestelloState extends State<_Destello>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, hijo) {
        // Entra rápido y se va despacio: así se nota sin molestar.
        final t = _ctrl.value;
        final intensidad = t < 0.12 ? t / 0.12 : 1 - (t - 0.12) / 0.88;
        return ColoredBox(
          color: Tokens.marca.withValues(
            alpha: 0.16 * intensidad.clamp(0.0, 1.0),
          ),
          child: hijo,
        );
      },
      child: widget.child,
    );
  }
}

/// Indicador de sincronización (§5): guardando → guardado aquí → respaldado.
class _PuntoSync extends StatelessWidget {
  const _PuntoSync({required this.estado});

  final EstadoSync estado;

  @override
  Widget build(BuildContext context) {
    final (icono, color) = switch (estado) {
      EstadoSync.guardando => (Icons.more_horiz, Tokens.texto2),
      EstadoSync.local => (Icons.check, Tokens.texto2),
      EstadoSync.respaldado => (Icons.cloud_done_outlined, Tokens.marca),
    };

    return Tooltip(
      message: estado.etiqueta,
      child: Icon(icono, size: 14, color: color),
    );
  }
}
