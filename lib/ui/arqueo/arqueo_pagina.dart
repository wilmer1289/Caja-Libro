import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/export/exportador_pdf.dart';
import '../../datos/export/impresion.dart';
import '../../dominio/efectivo.dart';
import '../../dominio/enums.dart';
import '../../dominio/fondo.dart';
import '../../dominio/importe.dart';
import '../../dominio/jornada.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/recibo.dart';
import '../../estado/estado_caja.dart';
import '../widgets/aparece.dart';
import '../widgets/conteo_editor.dart';
import '../widgets/esqueleto.dart';
import '../widgets/tarjeta_saldo.dart';
import 'acta_vista.dart';
import 'resumen_cajas.dart';

part 'efectivo_negocio.dart';

/// El arqueo de caja, pensado como la caja del día.
///
/// 0. La primera vez se **cuenta el efectivo del negocio**, billete por
///    billete. Queda bloqueado (sólo se corrige si se contó mal), y de ahí
///    sale lo que se pone en la caja cada día.
/// 1. Se **abre** la caja: seguir con lo que quedó, empezar de cero o con
///    otro monto. Lo que no se pone en la caja queda guardado aparte.
/// 2. Mientras está abierta, cada cobro y pago en **efectivo** entra solo, y
///    no se edita desde acá: lo que dice la caja es lo que dice el libro.
/// 3. Al terminar se **cierra** contando billete por billete. Queda el acta
///    con cuánto empezó, cuánto entró y salió, y con cuánto terminó.
///
/// Al costado, cuánto efectivo tiene el negocio y dónde está, y el resumen
/// de las cajas de hoy, la semana, el mes o todas.
class ArqueoPagina extends StatefulWidget {
  const ArqueoPagina({super.key, required this.usuario});

  /// Quién está usando la app: queda en el acta.
  final String usuario;

  @override
  State<ArqueoPagina> createState() => _ArqueoPaginaState();
}

class _ArqueoPaginaState extends State<ArqueoPagina> {
  /// La caja abierta pasó a contarse.
  bool _cerrando = false;

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    if (estado.cargando) return const EsqueletoLista();

    final abierta = estado.cajaAbierta;
    // Si la caja se cerró (o nunca se abrió), no hay nada que contar.
    final cerrando = _cerrando && abierta != null;

    return LayoutBuilder(
      builder: (context, medidas) {
        final amplio = medidas.maxWidth >= 980;
        final margen = medidas.maxWidth >= 760 ? 28.0 : 16.0;

        final Widget principal;
        if (abierta == null && estado.fondo == null) {
          principal = _ContarFondo(
            key: const ValueKey('fondo'),
            usuario: widget.usuario,
          );
        } else if (abierta == null) {
          principal = _AbrirCaja(
            key: const ValueKey('abrir'),
            usuario: widget.usuario,
          );
        } else if (cerrando) {
          principal = _CerrarCaja(
            key: ValueKey('cerrar-${abierta.id}'),
            caja: abierta,
            amplio: amplio,
            onCancelar: () => setState(() => _cerrando = false),
            onCerrada: () => setState(() => _cerrando = false),
          );
        } else {
          principal = _CajaAbierta(
            key: ValueKey('abierta-${abierta.id}'),
            caja: abierta,
            movimientos: estado.movimientosDeCaja(abierta),
            onCerrar: () => setState(() => _cerrando = true),
          );
        }

        final resumen = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (estado.fondo != null) ...[
              _EfectivoNegocioTarjeta(usuario: widget.usuario),
              const SizedBox(height: 20),
            ] else if (abierta != null) ...[
              const _FaltaFondo(),
              const SizedBox(height: 20),
            ],
            const ResumenCajasPanel(),
          ],
        );

        return ListView(
          padding: EdgeInsets.fromLTRB(margen, margen, margen, 120),
          children: [
            Aparece(
              key: ValueKey(principal.key),
              child: amplio && !cerrando
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: principal),
                        const SizedBox(width: 20),
                        SizedBox(width: 380, child: resumen),
                      ],
                    )
                  : principal,
            ),
            if (!amplio || cerrando) ...[
              const SizedBox(height: 20),
              Aparece(
                retraso: const Duration(milliseconds: 100),
                child: resumen,
              ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Abrir
// ---------------------------------------------------------------------------

/// Cómo se quiere empezar.
enum _Arranque { seguir, cero, otro }

/// El segundo paso: abrir la caja con lo que se elija. Lo que se pone en la
/// caja sale del efectivo del negocio —lo que dejó la caja anterior más lo
/// guardado aparte—, y lo que no se pone queda guardado.
class _AbrirCaja extends StatefulWidget {
  const _AbrirCaja({super.key, required this.usuario});

  final String usuario;

  @override
  State<_AbrirCaja> createState() => _AbrirCajaState();
}

class _AbrirCajaState extends State<_AbrirCaja> {
  late _Arranque _arranque;
  final _monto = TextEditingController();
  late final TextEditingController _responsable;
  bool _contar = false;
  Conteo _conteo = Conteo.vacio;
  bool _intento = false;
  bool _abriendo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final estado = context.read<EstadoCaja>();
    final anterior = estado.ultimaCajaCerrada;
    // Si quedó plata en la caja, lo más común es seguir con ella; si no,
    // hay que decir cuánto se saca de lo guardado.
    _arranque = (estado.efectivoNegocio?.enCaja ?? 0) > 0
        ? _Arranque.seguir
        : _Arranque.otro;
    _responsable = TextEditingController(
      text: anterior?.responsable.isNotEmpty == true
          ? anterior!.responsable
          : estado.negocio.tesorero,
    );
  }

  @override
  void dispose() {
    _monto.dispose();
    _responsable.dispose();
    super.dispose();
  }

  /// Lo escrito o contado, o null si no se entiende.
  int? get _montoEscrito =>
      _contar ? _conteo.total : Importe.leer(_monto.text.trim());

  Future<void> _abrir() async {
    final estado = context.read<EstadoCaja>();
    final efectivo = estado.efectivoNegocio;
    final anterior = estado.ultimaCajaCerrada;
    setState(() {
      _intento = true;
      _error = null;
    });
    if (efectivo == null) {
      setState(() => _error = 'Primero cuenta el efectivo del negocio.');
      return;
    }
    final quedo = efectivo.enCaja;

    final int apertura;
    final InicioCaja inicio;
    Conteo? conteo;
    if (_arranque == _Arranque.seguir && quedo > 0) {
      apertura = quedo;
      inicio = InicioCaja.continua;
      conteo = anterior?.cierre == quedo ? anterior!.conteoCierre : null;
    } else if (_arranque != _Arranque.otro) {
      apertura = 0;
      inicio = anterior == null ? InicioCaja.primera : InicioCaja.desdeCero;
      conteo = Conteo.vacio;
    } else {
      final escrito = _montoEscrito;
      if (escrito == null || escrito < 0) {
        setState(() => _error = 'Escribe con cuánto empieza. Ej. 100 o 0');
        return;
      }
      apertura = escrito;
      inicio = anterior == null ? InicioCaja.primera : InicioCaja.otroMonto;
      conteo = _contar ? _conteo : (escrito == 0 ? Conteo.vacio : null);
    }
    if (_responsable.text.trim().isEmpty) return;

    setState(() => _abriendo = true);
    try {
      await estado.abrirCaja(
        apertura: apertura,
        inicio: inicio,
        responsable: _responsable.text,
        usuario: widget.usuario,
        conteo: conteo,
        anterior: quedo,
      );
      HapticFeedback.mediumImpact();
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir. $e');
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final efectivo = estado.efectivoNegocio;
    if (efectivo == null) return const SizedBox.shrink();
    final anterior = estado.ultimaCajaCerrada;
    final quedo = efectivo.enCaja;
    final total = efectivo.total;
    String soles(int c) => Formato.soles(c / 100);

    final bajada = anterior == null
        ? 'Elige con cuánto empieza. Lo que no pongas en la caja queda '
              'guardado aparte. Desde que la abres, cada cobro y pago en '
              'efectivo entra solo.'
        : 'La caja N° ${anterior.numero} cerró ${_cuando(anterior.cerradaEn!)} '
              'con ${soles(anterior.cierre)}.';

    return TarjetaClara(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (anterior == null) ...[
              const _PasosApertura(actual: 1),
              const SizedBox(height: 18),
            ],
            _Titulo(
              icono: Icons.lock_open_rounded,
              titulo: anterior == null
                  ? 'Abre tu primera caja'
                  : 'Abre la caja',
              bajada: bajada,
            ),
            const SizedBox(height: 16),
            _Disponible(quedo: quedo, guardado: efectivo.guardado),
            const SizedBox(height: 16),
            if (quedo > 0) ...[
              _OpcionArranque(
                icono: Icons.redo_rounded,
                titulo: 'Seguir con lo que quedó',
                bajada: 'Empiezas con ${soles(quedo)}; lo guardado no se toca',
                elegida: _arranque == _Arranque.seguir,
                onTap: () => setState(() => _arranque = _Arranque.seguir),
              ),
              const SizedBox(height: 8),
            ],
            _OpcionArranque(
              icono: Icons.savings_outlined,
              titulo: 'Empezar de cero',
              bajada: quedo > 0
                  ? 'Los ${soles(quedo)} pasan a lo guardado y la caja '
                        'arranca vacía'
                  : 'La caja arranca vacía y todo sigue guardado',
              elegida: _arranque == _Arranque.cero,
              onTap: () => setState(() => _arranque = _Arranque.cero),
            ),
            const SizedBox(height: 8),
            _OpcionArranque(
              icono: Icons.edit_outlined,
              titulo: 'Con otro monto',
              bajada: 'Lo sacas de lo que tienes: hasta ${soles(total)}',
              elegida: _arranque == _Arranque.otro,
              onTap: () => setState(() => _arranque = _Arranque.otro),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _arranque == _Arranque.otro
                  ? Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: _MontoApertura(
                        monto: _monto,
                        contar: _contar,
                        conteo: _conteo,
                        disponible: total,
                        onContar: (v) => setState(() => _contar = v),
                        onConteo: (c) => setState(() => _conteo = c),
                        onCambio: () => setState(() => _error = null),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 18),
            const _Rotulo('Responsable de caja'),
            TextField(
              controller: _responsable,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Quién queda a cargo',
                prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                errorText: _intento && _responsable.text.trim().isEmpty
                    ? 'Escribe quién queda a cargo de la caja'
                    : null,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _TextoError(_error!),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _abriendo ? null : _abrir,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              icon: _abriendo
                  ? const _Girando()
                  : const Icon(Icons.lock_open_rounded, size: 20),
              label: const Text('Abrir caja'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lo que hay para abrir: lo que quedó en la caja y lo guardado aparte.
/// Lado a lado si hay ancho; en el celular, uno debajo del otro, para que
/// los rótulos no se corten.
class _Disponible extends StatelessWidget {
  const _Disponible({required this.quedo, required this.guardado});

  final int quedo;
  final int guardado;

  @override
  Widget build(BuildContext context) {
    final datos = [
      ('Quedó en la caja', quedo, false),
      ('Guardado aparte', guardado, false),
      ('Tienes en total', quedo + guardado, true),
    ];

    TextStyle monto(bool fuerte) => TextStyle(
      fontSize: fuerte ? 16 : 14.5,
      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w600,
      color: Tokens.texto,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    const rotulo = TextStyle(fontSize: 11.5, color: Tokens.texto2);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
      ),
      child: LayoutBuilder(
        builder: (context, medidas) {
          if (medidas.maxWidth < 420) {
            return Column(
              children: [
                for (final (texto, centavos, fuerte) in datos)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            texto,
                            style: rotulo.copyWith(
                              fontSize: 12.5,
                              fontWeight: fuerte ? FontWeight.w600 : null,
                              color: fuerte ? Tokens.texto : null,
                            ),
                          ),
                        ),
                        Text(
                          Formato.soles(centavos / 100),
                          style: monto(fuerte),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < datos.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: Tokens.borde,
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        datos[i].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rotulo,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formato.soles(datos[i].$2 / 100),
                          style: monto(datos[i].$3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MontoApertura extends StatelessWidget {
  const _MontoApertura({
    required this.monto,
    required this.contar,
    required this.conteo,
    required this.disponible,
    required this.onContar,
    required this.onConteo,
    required this.onCambio,
  });

  final TextEditingController monto;
  final bool contar;
  final Conteo conteo;

  /// Todo el efectivo del negocio: de ahí sale lo que se pone.
  final int disponible;

  final ValueChanged<bool> onContar;
  final ValueChanged<Conteo> onConteo;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final puesto = contar ? conteo.total : Importe.leer(monto.text.trim());
    final queda = puesto == null ? null : disponible - puesto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Rotulo('¿Con cuánto empieza la caja?'),
        if (contar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Tokens.fondo,
              borderRadius: BorderRadius.circular(Tokens.radio),
              border: Border.all(color: Tokens.borde),
            ),
            child: Text(
              Formato.soles(conteo.total / 100),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          )
        else ...[
          TextField(
            controller: monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => onCambio(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              prefixText: 'S/ ',
              hintText: '0.00',
            ),
          ),
          if (disponible > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.all_inclusive_rounded, size: 16),
                label: Text('Todo · ${Formato.soles(disponible / 100)}'),
                onPressed: () {
                  monto.text = (disponible / 100).toStringAsFixed(2);
                  onCambio();
                },
              ),
            ),
          ],
        ],
        if (queda != null) ...[
          const SizedBox(height: 8),
          Text(
            queda >= 0
                ? 'Quedan guardados ${Formato.soles(queda / 100)}.'
                : 'Son ${Formato.soles(-queda / 100)} más de lo que tienes: '
                      'se suman como plata que entra de afuera.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: queda >= 0 ? FontWeight.w400 : FontWeight.w600,
              color: queda >= 0 ? Tokens.texto2 : const Color(0xFF8A6A1F),
            ),
          ),
        ],
        const SizedBox(height: 4),
        // Con su propio Material: la tarjeta tiene fondo, y sin esto el
        // efecto del toque quedaría tapado.
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            value: contar,
            onChanged: onContar,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Contar billete por billete',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Así, al cerrar, la app te dice cuántos de cada uno debería haber',
              style: TextStyle(fontSize: 11.5, color: Tokens.texto2),
            ),
          ),
        ),
        if (contar) ...[
          const SizedBox(height: 6),
          ConteoEditor(conteo: conteo, onCambiar: onConteo),
        ],
      ],
    );
  }
}

class _OpcionArranque extends StatelessWidget {
  const _OpcionArranque({
    required this.icono,
    required this.titulo,
    required this.bajada,
    required this.elegida,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String bajada;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: elegida ? Tokens.marcaSuave : Tokens.superficie,
      borderRadius: BorderRadius.circular(Tokens.radio),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radio),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radio),
            border: Border.all(
              color: elegida ? Tokens.marca : Tokens.borde,
              width: elegida ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icono,
                size: 20,
                color: elegida ? Tokens.marca : Tokens.texto2,
              ),
              const SizedBox(width: 12),
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
                      bajada,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Tokens.texto2,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: elegida ? 1 : 0,
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: Tokens.marca,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Abierta
// ---------------------------------------------------------------------------

class _CajaAbierta extends StatelessWidget {
  const _CajaAbierta({
    super.key,
    required this.caja,
    required this.movimientos,
    required this.onCerrar,
  });

  final Jornada caja;
  final List<Movimiento> movimientos;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TarjetaCaja(caja: caja, onCerrar: onCerrar),
        const SizedBox(height: 16),
        _MovimientosDeCaja(movimientos: movimientos),
      ],
    );
  }
}

/// La tarjeta grafito de la caja abierta: cuánto debería haber, y de dónde
/// sale ese número.
class _TarjetaCaja extends StatelessWidget {
  const _TarjetaCaja({required this.caja, required this.onCerrar});

  final Jornada caja;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    Widget dato(String rotulo, int centavos, {IconData? icono, Color? color}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icono != null) ...[
                  Icon(icono, size: 14, color: color),
                  const SizedBox(width: 4),
                ],
                Text(
                  rotulo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Tokens.cromoTexto2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Formato.soles(centavos / 100),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Tokens.cromoTexto,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: Tokens.degradadoCromo,
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        boxShadow: Tokens.sombraTarjeta,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Tokens.marca.withValues(alpha: 0.10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
                      decoration: BoxDecoration(
                        color: Tokens.entroVivo.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _Punto(),
                          const SizedBox(width: 7),
                          Text(
                            'CAJA N° ${caja.numero} ABIERTA',
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w700,
                              color: Tokens.entroVivo,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'desde ${_cuando(caja.abiertaEn)} · ${caja.responsable}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Tokens.cromoTexto2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Debería haber en la caja',
                  style: TextStyle(fontSize: 13, color: Tokens.cromoTexto2),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Formato.soles(caja.esperado / 100),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(Tokens.radio),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: dato('Empezó con', caja.apertura)),
                      Expanded(
                        child: dato(
                          'Entró',
                          caja.entradas,
                          icono: Icons.arrow_upward_rounded,
                          color: Tokens.entroVivo,
                        ),
                      ),
                      Expanded(
                        child: dato(
                          'Salió',
                          caja.salidas,
                          icono: Icons.arrow_downward_rounded,
                          color: Tokens.salioVivo,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        caja.operaciones == 0
                            ? 'Todavía sin movimientos en efectivo'
                            : '${caja.operaciones} '
                                  '${caja.operaciones == 1 ? 'movimiento' : 'movimientos'}'
                                  ' en efectivo',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Tokens.cromoTexto2,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onCerrar,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      icon: const Icon(Icons.lock_rounded, size: 19),
                      label: const Text('Cerrar caja'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El puntito verde con su halo: la caja está abierta, ahora.
class _Punto extends StatelessWidget {
  const _Punto();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Tokens.entroVivo,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Tokens.entroVivo.withValues(alpha: 0.55),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Lo que entró y salió en efectivo desde que se abrió. Sólo se mira: se
/// anota solo al registrar, y no se toca desde acá.
class _MovimientosDeCaja extends StatelessWidget {
  const _MovimientosDeCaja({required this.movimientos});

  final List<Movimiento> movimientos;

  @override
  Widget build(BuildContext context) {
    return TarjetaClara(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Movimientos en efectivo de esta caja',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Tokens.texto,
                    ),
                  ),
                ),
                Tooltip(
                  message:
                      'Entran solos al registrar en efectivo con "Entró" o '
                      '"Salió". Desde acá no se editan.',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Tokens.fondo,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Tokens.borde),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 13,
                          color: Tokens.texto2,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Automático',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Tokens.texto2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (movimientos.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                'Cuando registres algo en efectivo con "Entró" o "Salió", '
                'aparece acá solo.',
                style: TextStyle(fontSize: 13, color: Tokens.texto2),
              ),
            )
          else
            for (final m in movimientos.reversed) _FilaCaja(movimiento: m),
        ],
      ),
    );
  }
}

class _FilaCaja extends StatelessWidget {
  const _FilaCaja({required this.movimiento});

  final Movimiento movimiento;

  @override
  Widget build(BuildContext context) {
    final m = movimiento;
    final entro = m.tipo == Tipo.entro;
    final color = entro ? Tokens.entro : Tokens.salio;
    final detalle = m.detalleEfectivo == null
        ? null
        : medioConDetalle(m).replaceFirst('Efectivo · ', '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Tokens.borde)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              Formato.hora(m.creadoEn),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Tokens.texto2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              entro ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.descripcionFormato,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Tokens.texto,
                  ),
                ),
                Text(
                  detalle ?? 'N° ${m.numero} · sin detalle de billetes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Tokens.texto2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${entro ? '+' : '−'} ${Formato.soles(m.centavos / 100)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cerrar
// ---------------------------------------------------------------------------

class _CerrarCaja extends StatefulWidget {
  const _CerrarCaja({
    super.key,
    required this.caja,
    required this.amplio,
    required this.onCancelar,
    required this.onCerrada,
  });

  final Jornada caja;
  final bool amplio;
  final VoidCallback onCancelar;
  final VoidCallback onCerrada;

  @override
  State<_CerrarCaja> createState() => _CerrarCajaState();
}

class _CerrarCajaState extends State<_CerrarCaja> {
  Conteo _conteo = Conteo.vacio;
  final _supervisor = TextEditingController();
  final _observacion = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _supervisor.dispose();
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _cerrar() async {
    if (_guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final estado = context.read<EstadoCaja>();
    final navegador = Navigator.of(context);
    final Jornada cerrada;
    try {
      cerrada = await estado.cerrarCaja(
        conteo: _conteo,
        supervisor: _supervisor.text,
        observacion: _observacion.text,
      );
    } on ArgumentError catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = '${e.message}';
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo cerrar. $e';
        });
      }
      return;
    }
    HapticFeedback.mediumImpact();
    // La página vuelve a "abrir caja" por debajo y el resultado se muestra
    // encima. Con la caja cerrada este formulario ya no existe: la ventana
    // se abre desde el navegador, que sigue ahí.
    widget.onCerrada();
    final contexto = navegador.context;
    if (!contexto.mounted) return;
    await _CajaCerrada.abrir(contexto, cerrada);
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final caja = widget.caja;
    final estimado = estado.estimadoDe(caja);

    final conteo = TarjetaClara(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _Titulo(
                    icono: Icons.calculate_outlined,
                    titulo: 'Cuenta la plata del cajón',
                    bajada:
                        'Billete por billete y moneda por moneda: lo que hay '
                        'de verdad.',
                  ),
                ),
                if (!_conteo.estaVacio)
                  TextButton.icon(
                    onPressed: () => setState(() => _conteo = Conteo.vacio),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Empezar de nuevo'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _NotaEstimado(estimado: estimado),
            const SizedBox(height: 14),
            ConteoEditor(
              conteo: _conteo,
              estimado: estimado?.conteo,
              onCambiar: (c) => setState(() => _conteo = c),
            ),
          ],
        ),
      ),
    );

    final resumen = _ResumenCierre(
      caja: caja,
      contado: _conteo.total,
      supervisor: _supervisor,
      observacion: _observacion,
      guardando: _guardando,
      error: _error,
      onCerrar: _cerrar,
      onCancelar: widget.onCancelar,
    );

    return widget.amplio
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: conteo),
              const SizedBox(width: 20),
              SizedBox(width: 360, child: resumen),
            ],
          )
        : Column(children: [resumen, const SizedBox(height: 16), conteo]);
  }
}

class _NotaEstimado extends StatelessWidget {
  const _NotaEstimado({required this.estimado});

  final EstimadoCaja? estimado;

  @override
  Widget build(BuildContext context) {
    final e = estimado;
    final (icono, texto, aviso) = e == null
        ? (
            Icons.lightbulb_outline_rounded,
            'Esta caja se abrió sin contar billetes, así que no se sabe '
                'cuántos de cada uno debería haber. La próxima vez, al abrir, '
                'activa "Contar billete por billete".',
            false,
          )
        : e.completo
        ? (
            Icons.fact_check_outlined,
            'Debajo de cada ficha va cuántos debería haber: los que había al '
                'abrir, más lo que entró y menos lo que salió.',
            false,
          )
        : (
            Icons.info_outline_rounded,
            'El "debería" es aproximado: ${e.sinDetalle} '
                '${e.sinDetalle == 1 ? 'movimiento' : 'movimientos'} de esta '
                'caja no ${e.sinDetalle == 1 ? 'anotó' : 'anotaron'} sus '
                'billetes.',
            true,
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: aviso ? const Color(0xFFFFF6E5) : Tokens.fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(
          color: aviso ? const Color(0xFFF0DCB4) : Tokens.borde,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icono,
            size: 17,
            color: aviso ? const Color(0xFF8A6A1F) : Tokens.texto2,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: aviso ? const Color(0xFF6B520F) : Tokens.texto2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// De dónde sale lo que debería haber, lo contado y la diferencia, en vivo.
class _ResumenCierre extends StatelessWidget {
  const _ResumenCierre({
    required this.caja,
    required this.contado,
    required this.supervisor,
    required this.observacion,
    required this.guardando,
    required this.error,
    required this.onCerrar,
    required this.onCancelar,
  });

  final Jornada caja;
  final int contado;
  final TextEditingController supervisor;
  final TextEditingController observacion;
  final bool guardando;
  final String? error;
  final VoidCallback onCerrar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final esperado = caja.esperado;
    final diferencia = contado - esperado;
    // Mientras no se cuenta nada no hay faltante que marcar: va neutro.
    final sinContar = contado == 0 && esperado != 0;
    final (color, icono, titulo) = sinContar
        ? (
            Tokens.texto2,
            Icons.calculate_outlined,
            'Empieza a contar para ver la diferencia',
          )
        : diferencia == 0
        ? (Tokens.entro, Icons.check_circle_rounded, 'La caja cuadra')
        : diferencia < 0
        ? (
            Tokens.salio,
            Icons.trending_down_rounded,
            'Faltan ${Formato.soles(-diferencia / 100)}',
          )
        : (
            Tokens.marcaOscura,
            Icons.trending_up_rounded,
            'Sobran ${Formato.soles(diferencia / 100)}',
          );

    Widget cifra(
      String rotulo,
      int centavos, {
      bool grande = false,
      String signo = '',
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rotulo,
              style: TextStyle(
                fontSize: 13,
                color: grande ? Tokens.texto : Tokens.texto2,
                fontWeight: grande ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            '$signo${Formato.soles(centavos / 100)}',
            style: TextStyle(
              fontSize: grande ? 22 : 14.5,
              fontWeight: grande ? FontWeight.w800 : FontWeight.w600,
              color: Tokens.texto,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return TarjetaClara(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cierre de la caja N° ${caja.numero}',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Tokens.texto,
              ),
            ),
            const SizedBox(height: 10),
            cifra('Empezó con', caja.apertura),
            cifra('Entró en efectivo', caja.entradas, signo: '+ '),
            cifra('Salió en efectivo', caja.salidas, signo: '− '),
            const Divider(height: 18),
            cifra('Debería haber', esperado),
            cifra('Contado', contado, grande: true),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Tokens.radio),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(icono, color: color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _Rotulo('Supervisor (opcional)'),
            TextField(
              controller: supervisor,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Quién presenció el conteo',
              ),
            ),
            const SizedBox(height: 12),
            const _Rotulo('Observación (opcional)'),
            TextField(
              controller: observacion,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ej. Cierre del día, cambio de turno…',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Tokens.salio,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: guardando ? null : onCerrar,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              icon: guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_rounded, size: 20),
              label: const Text('Cerrar caja y ver el acta'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: guardando ? null : onCancelar,
              child: const Text('Todavía no, seguir con la caja abierta'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Después de cerrar: con cuánto terminó, el acta para imprimir y, si no
/// cuadró, la opción de llevar la diferencia al libro.
class _CajaCerrada extends StatefulWidget {
  const _CajaCerrada({required this.caja});

  final Jornada caja;

  static Future<void> abrir(BuildContext context, Jornada caja) {
    return showDialog<void>(
      context: context,
      barrierColor: Tokens.cromo.withValues(alpha: 0.40),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: _CajaCerrada(caja: caja),
        ),
      ),
    );
  }

  @override
  State<_CajaCerrada> createState() => _CajaCerradaState();
}

class _CajaCerradaState extends State<_CajaCerrada> {
  late Jornada _caja = widget.caja;
  bool _ocupado = false;
  String? _mensaje;
  bool _error = false;

  Future<void> _hacer(Future<String> Function() accion) async {
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
    } on ArgumentError catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _mensaje = '${e.message}';
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
    final c = _caja;
    final color = c.cuadra
        ? Tokens.entro
        : c.hayFaltante
        ? Tokens.salio
        : Tokens.marcaOscura;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Caja N° ${c.numero} cerrada',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Tokens.texto,
                      ),
                    ),
                    Text(
                      c.estadoTexto,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Tokens.fondo,
              borderRadius: BorderRadius.circular(Tokens.radio),
              border: Border.all(color: Tokens.borde),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Terminaste con',
                    style: TextStyle(fontSize: 13.5, color: Tokens.texto2),
                  ),
                ),
                Text(
                  Formato.soles(c.contado / 100),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Tokens.texto,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'El acta queda guardada. Imprímela para que la firmen el '
            'responsable y, si hubo, el supervisor.',
            style: TextStyle(fontSize: 12.5, color: Tokens.texto2),
          ),
          if (!c.cuadra && c.ajusteId == null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Tokens.radio),
                border: Border.all(color: Tokens.borde),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    c.hayFaltante
                        ? 'Para que el libro diga lo que hay en la caja, '
                              'registra el faltante como una salida (cuenta '
                              '659, otros gastos de gestión).'
                        : 'Para que el libro diga lo que hay en la caja, '
                              'registra el sobrante como una entrada (cuenta '
                              '7599, otros ingresos de gestión).',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Tokens.texto2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _ocupado
                        ? null
                        : () => _hacer(() async {
                            final conAjuste = await context
                                .read<EstadoCaja>()
                                .llevarDiferenciaAlLibro(c);
                            setState(() => _caja = conAjuste);
                            return 'Listo: el '
                                '${c.hayFaltante ? 'faltante' : 'sobrante'} '
                                'quedó en el libro';
                          }),
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: Text(
                      c.hayFaltante
                          ? 'Registrar el faltante en el libro'
                          : 'Registrar el sobrante en el libro',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_mensaje != null) ...[
            const SizedBox(height: 12),
            Text(
              _mensaje!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _error ? Tokens.salio : Tokens.entro,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Listo'),
              ),
              OutlinedButton.icon(
                onPressed: () => ActaCierre.abrir(context, c),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Ver acta'),
              ),
              FilledButton.icon(
                onPressed: _ocupado
                    ? null
                    : () => _hacer(() async {
                        final estado = context.read<EstadoCaja>();
                        await Impresion.imprimir(
                          await ExportadorPdf.actaCierre(
                            c,
                            estado.movimientosDeCaja(c),
                            direccion: estado.negocio.direccion,
                          ),
                          ExportadorPdf.nombreActa(c),
                        );
                        return 'Acta enviada a imprimir';
                      }),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Imprimir acta'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas
// ---------------------------------------------------------------------------

/// "hoy a las 08:15", "ayer a las 21:10", "el 24/09/2026 a las 20:00".
String _cuando(DateTime d) {
  final relativa = Formato.fechaRelativa(d);
  final dia = relativa.contains('/') ? 'el $relativa' : relativa.toLowerCase();
  return '$dia a las ${Formato.hora(d)}';
}

class _Titulo extends StatelessWidget {
  const _Titulo({
    required this.icono,
    required this.titulo,
    required this.bajada,
  });

  final IconData icono;
  final String titulo;
  final String bajada;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Tokens.marcaSuave,
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 20, color: Tokens.marca),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Tokens.texto,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                bajada,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Tokens.texto2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Tokens.texto,
        ),
      ),
    );
  }
}
