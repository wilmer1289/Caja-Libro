import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/export/exportador_pdf.dart';
import '../../datos/export/impresion.dart';
import '../../datos/local/evidencias.dart';
import '../../datos/local/selector_voucher.dart';
import '../../datos/ocr/lector_voucher.dart';
import '../../dominio/banco.dart';
import '../../dominio/boleta.dart';
import '../../dominio/enums.dart';
import '../../dominio/lectura_voucher.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/pcge.dart';
import '../../dominio/recibo.dart';
import '../../estado/estado_caja.dart';
import '../formatos/recibo_hoja.dart';
import '../widgets/voucher_adjunto.dart';
import 'datos_voucher_dialogo.dart';

/// La miniventana del "⋮" de cada movimiento: sus papeles.
///
/// Ver, imprimir o descargar el recibo interno y la boleta. Si el movimiento
/// se guardó sin recibo, acá se le puede emitir uno después. Las operaciones
/// por banco muestran además su voucher: se ve, se adjunta si faltó, y se
/// completan sus datos.
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

  /// El mensaje es un aviso, no un error: se hizo, pero hay algo que mirar.
  bool _advertencia = false;

  Future<void> _ejecutar(Future<String?> Function() accion) async {
    setState(() {
      _ocupado = true;
      _mensaje = null;
      _advertencia = false;
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
          // Los avisos del selector ya vienen escritos para el usuario.
          _mensaje = e is FormatException ? e.message : 'No se pudo: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Adjunta el voucher (o lo cambia) y, si el equipo puede leerlo, completa
  /// lo que el movimiento no tenía. Lo que ya estaba anotado no se pisa.
  Future<String?> _adjuntarVoucher(
    EstadoCaja estado,
    Movimiento m, {
    required bool camara,
  }) async {
    final selector = SelectorVoucher.instancia;
    final archivo = camara
        ? await selector.tomarFoto()
        : await selector.elegirArchivo();
    if (archivo == null) return null;
    final ruta = await AlmacenEvidencias.instancia.guardar(archivo);

    LecturaVoucher? lectura;
    try {
      lectura = await LectorVoucher.leer(archivo);
    } catch (_) {
      // Sin lectura el voucher queda adjunto igual.
    }
    final completado = <String>[];
    String? numero;
    String? banco;
    String? nombre;
    if ((m.numeroTransaccion ?? '').trim().isEmpty &&
        lectura?.numeroOperacion != null) {
      numero = lectura!.numeroOperacion;
      completado.add('el N° de operación');
    }
    final leido = lectura?.banco;
    if (m.bancoTercero == null &&
        leido != null &&
        EntidadesBancarias.para(m.medio).contains(leido) &&
        (m.medio == MedioPago.yape || m.tipo == Tipo.entro)) {
      banco = leido;
      completado.add('el banco');
    }
    if ((m.contraparte ?? '').trim().isEmpty && lectura?.nombre != null) {
      nombre = lectura!.nombre;
      completado.add('el nombre');
    }
    await estado.completarVoucher(
      m,
      rutaFoto: ruta,
      numeroTransaccion: numero,
      bancoTercero: banco,
      contraparte: nombre,
    );

    final partes = [
      'Voucher adjunto',
      if (completado.isNotEmpty) 'se completó ${completado.join(', ')}',
      if (lectura?.centavos case final c? when c != m.centavos)
        'ojo: el voucher dice ${Formato.soles(c / 100)}',
    ];
    // El monto del libro no se cambia solo, pero que no coincida se avisa en
    // ámbar, no en verde.
    _advertencia = lectura?.centavos != null && lectura!.centavos != m.centavos;
    return partes.join('; ');
  }

  Future<String?> _verVoucher(Movimiento m) async {
    final archivo = await AlmacenEvidencias.instancia.leer(m.rutaFoto!);
    if (archivo == null) {
      throw const FormatException(
        'El archivo del voucher no está en este equipo.',
      );
    }
    if (!mounted) return null;
    await VisorVoucher.abrir(
      context,
      archivo,
      titulo: (m.numeroTransaccion ?? '').isEmpty
          ? 'Voucher'
          : 'Voucher · Oper. ${m.numeroTransaccion}',
    );
    return null;
  }

  Future<String?> _completarDatos(EstadoCaja estado, Movimiento m) async {
    final datos = await DatosVoucherDialogo.abrir(context, m);
    if (datos == null) return null;
    await estado.completarVoucher(
      m,
      numeroTransaccion: datos.numero,
      bancoTercero: datos.banco,
      contraparte: datos.nombre,
      documentoContraparte: datos.documento,
    );
    return 'Datos del voucher guardados';
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
                      '${Formato.fecha(m.fecha)} · Oper. N° ${m.numero}'
                      '${(m.mercaderiaNombre ?? '').trim().isEmpty ? '' : ' · ${m.mercaderiaNombre!.trim()}'}',
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
              if (m.enBanco) ...[
                const SizedBox(height: 10),
                _Papel(
                  icono: Icons.account_balance_outlined,
                  titulo: m.tieneVoucher
                      ? 'Voucher del banco'
                      : 'Voucher del banco · sin adjuntar',
                  detalle: _detalleBanco(m, negocio.entidadFinanciera),
                  acciones: [
                    if (m.tieneVoucher)
                      _Accion(
                        icono: Icons.visibility_outlined,
                        texto: 'Ver',
                        onTap: _ocupado
                            ? null
                            : () => _ejecutar(() => _verVoucher(m)),
                      ),
                    if (SelectorVoucher.instancia.puedeTomarFoto)
                      _Accion(
                        icono: Icons.photo_camera_outlined,
                        texto: 'Tomar foto',
                        principal: !m.tieneVoucher,
                        onTap: _ocupado
                            ? null
                            : () => _ejecutar(
                                () => _adjuntarVoucher(estado, m, camara: true),
                              ),
                      ),
                    _Accion(
                      icono: Icons.upload_file_rounded,
                      texto: m.tieneVoucher ? 'Cambiar' : 'Adjuntar',
                      principal:
                          !m.tieneVoucher &&
                          !SelectorVoucher.instancia.puedeTomarFoto,
                      onTap: _ocupado
                          ? null
                          : () => _ejecutar(
                              () => _adjuntarVoucher(estado, m, camara: false),
                            ),
                    ),
                    _Accion(
                      icono: Icons.edit_outlined,
                      texto: 'Completar datos',
                      onTap: _ocupado
                          ? null
                          : () => _ejecutar(() => _completarDatos(estado, m)),
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
                      color: _error
                          ? Tokens.salio
                          : _advertencia
                          ? const Color(0xFF6B520F)
                          : Tokens.entro,
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

/// Lo que dice el voucher, en el orden del Formato 1.2. El ITF va al final y
/// aclarado: lo descuenta el banco, pero no es un renglón del libro.
String _detalleBanco(Movimiento m, String bancoNegocio) {
  final tipo = EntidadesBancarias.tipoOperacion(
    m.medio,
    bancoTercero: m.bancoTercero,
    bancoNegocio: bancoNegocio,
  );
  final numero = (m.numeroTransaccion ?? '').trim();
  final nombre = (m.contraparte ?? '').trim();
  final documento = (m.documentoContraparte ?? '').trim();
  final cuenta = m.cuentaDelFormato;
  final itf = m.itfCentavos;
  return [
    [tipo, ?m.bancoTercero].join(' · '),
    numero.isEmpty
        ? 'N° de operación: falta anotarlo'
        : 'N° de operación: $numero',
    if (nombre.isNotEmpty || documento.isNotEmpty)
      [
        if (nombre.isNotEmpty) nombre,
        if (documento.isNotEmpty) documento,
      ].join(' · '),
    '${m.vinculo.etiqueta} · cuenta $cuenta ${Pcge.instancia.denominacion(cuenta)}',
    itf > 0
        ? 'ITF estimado ${Formato.soles(itf / 100)}: lo descuenta el banco, no va al libro'
        : 'Sin ITF: menos de S/ 1,000',
  ].join('\n');
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
