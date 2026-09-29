import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/export/exportador_pdf.dart';
import '../../datos/export/impresion.dart';
import '../../dominio/boleta.dart';
import '../../dominio/enums.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/recibo.dart';
import '../../estado/estado_caja.dart';
import '../formatos/recibo_hoja.dart';

/// La miniventana del "⋮" de cada movimiento: sus papeles.
///
/// Ver, imprimir o descargar el recibo interno y la boleta. Si el movimiento
/// se guardó sin recibo, acá se le puede emitir uno después.
///
/// No hay "eliminar": un movimiento del libro no se borra. Si se anotó mal,
/// se corrige con otro movimiento, como en cualquier libro contable.
class AccionesMovimiento extends StatefulWidget {
  const AccionesMovimiento({super.key, required this.movimientoId});

  final String movimientoId;

  static Future<void> abrir(BuildContext context, Movimiento movimiento) {
    return showDialog<void>(
      context: context,
      barrierColor: Tokens.cromo.withValues(alpha: 0.40),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AccionesMovimiento(movimientoId: movimiento.id),
        ),
      ),
    );
  }

  @override
  State<AccionesMovimiento> createState() => _AccionesMovimientoState();
}

class _AccionesMovimientoState extends State<AccionesMovimiento> {
  bool _ocupado = false;
  String? _mensaje;
  bool _error = false;

  Future<void> _ejecutar(Future<String?> Function() accion) async {
    setState(() {
      _ocupado = true;
      _mensaje = null;
    });
    try {
      final texto = await accion();
      if (mounted) {
        setState(() {
          _error = false;
          _mensaje = texto;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _mensaje = 'No se pudo: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final m = estado.movimientos.firstWhere((x) => x.id == widget.movimientoId);
    final negocio = estado.negocio;
    final entro = m.tipo == Tipo.entro;
    final color = entro ? Tokens.entro : Tokens.salio;

    final recibo = m.numeroRecibo == null
        ? null
        : Recibo(negocio: negocio, movimiento: m);
    final boleta = m.numeroBoleta == null
        ? null
        : Boleta(negocio: negocio, movimiento: m);
    final ventaSinBoleta = boleta == null && Boleta.corresponde(m.categoria);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // La cabeza: qué movimiento es.
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
          color: entro ? Tokens.entroSuave : Tokens.salioSuave,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  m.tipo.flecha,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.concepto.isEmpty ? m.categoria.etiqueta : m.concepto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Tokens.texto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formato.soles(m.monto)} · ${m.medio.etiqueta} · '
                      '${Formato.fecha(m.fecha)} · Oper. N° ${m.numero}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Tokens.texto2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Papel(
                icono: Icons.receipt_long_rounded,
                titulo: 'Recibo interno',
                detalle: recibo == null
                    ? 'Este movimiento se guardó sin recibo'
                    : 'N° ${recibo.numero} · para firmar',
                acciones: recibo == null
                    ? [
                        _Accion(
                          icono: Icons.add_rounded,
                          texto: 'Emitir recibo',
                          principal: true,
                          onTap: _ocupado
                              ? null
                              : () => _ejecutar(() async {
                                  await estado.emitirRecibo(
                                    m,
                                    tesorero: negocio.tesorero,
                                  );
                                  return 'Recibo emitido';
                                }),
                        ),
                      ]
                    : [
                        _Accion(
                          icono: Icons.visibility_outlined,
                          texto: 'Ver',
                          onTap: () => ReciboHoja.abrir(
                            context,
                            movimiento: m,
                            negocio: negocio,
                          ),
                        ),
                        _Accion(
                          icono: Icons.print_rounded,
                          texto: 'Imprimir',
                          onTap: _ocupado
                              ? null
                              : () => _ejecutar(() async {
                                  await Impresion.imprimir(
                                    await ExportadorPdf.recibo(recibo),
                                    ExportadorPdf.nombreRecibo(recibo),
                                  );
                                  return 'Enviado a imprimir';
                                }),
                        ),
                      ],
              ),
              if (boleta != null || ventaSinBoleta) ...[
                const SizedBox(height: 10),
                _Papel(
                  icono: Icons.shopping_bag_outlined,
                  titulo: 'Boleta de venta',
                  detalle: boleta == null
                      ? 'Venta anterior a las boletas: no tiene número'
                      : '${boleta.numero} · control interno',
                  acciones: boleta == null
                      ? const []
                      : [
                          _Accion(
                            icono: Icons.visibility_outlined,
                            texto: 'Ver',
                            onTap: () => BoletaHoja.abrir(
                              context,
                              movimiento: m,
                              negocio: negocio,
                            ),
                          ),
                          _Accion(
                            icono: Icons.print_rounded,
                            texto: 'Imprimir',
                            onTap: _ocupado
                                ? null
                                : () => _ejecutar(() async {
                                    await Impresion.imprimir(
                                      await ExportadorPdf.boleta(boleta),
                                      ExportadorPdf.nombreBoleta(boleta),
                                    );
                                    return 'Enviada a imprimir';
                                  }),
                          ),
                          _Accion(
                            icono: Icons.download_rounded,
                            texto: 'Descargar',
                            onTap: _ocupado
                                ? null
                                : () => _ejecutar(() async {
                                    final ruta = await Impresion.descargar(
                                      await ExportadorPdf.boleta(boleta),
                                      ExportadorPdf.nombreBoleta(boleta),
                                    );
                                    return 'Guardada en $ruta';
                                  }),
                          ),
                        ],
                ),
              ],
              if (_mensaje != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _mensaje!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _error ? Tokens.salio : Tokens.entro,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Un papel del movimiento: qué es, su número y lo que se puede hacer con él.
class _Papel extends StatelessWidget {
  const _Papel({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.acciones,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Tokens.superficie,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Tokens.marcaSuave,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: 18, color: Tokens.marca),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Tokens.texto,
                      ),
                    ),
                    Text(
                      detalle,
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
          if (acciones.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: acciones),
          ],
        ],
      ),
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({
    required this.icono,
    required this.texto,
    required this.onTap,
    this.principal = false,
  });

  final IconData icono;
  final String texto;
  final VoidCallback? onTap;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final estilo = principal
        ? FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          )
        : null;
    if (principal) {
      return FilledButton.icon(
        onPressed: onTap,
        style: estilo,
        icon: Icon(icono, size: 18),
        label: Text(texto),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      icon: Icon(icono, size: 18),
      label: Text(texto),
    );
  }
}
