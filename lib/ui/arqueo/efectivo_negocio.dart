part of 'arqueo_pagina.dart';

// ---------------------------------------------------------------------------
// El efectivo del negocio
// ---------------------------------------------------------------------------

/// El primer paso, antes de la primera caja: contar, billete por billete,
/// toda la plata que tiene el negocio. De ahí sale lo que se pone en la caja
/// cada día; lo que no se pone queda guardado aparte.
class _ContarFondo extends StatefulWidget {
  const _ContarFondo({super.key, required this.usuario});

  final String usuario;

  @override
  State<_ContarFondo> createState() => _ContarFondoState();
}

class _ContarFondoState extends State<_ContarFondo> {
  Conteo _conteo = Conteo.vacio;
  bool _guardando = false;
  String? _error;

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await context.read<EstadoCaja>().contarFondo(
        _conteo,
        usuario: widget.usuario,
      );
      HapticFeedback.mediumImpact();
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo guardar. $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previa = context.watch<EstadoCaja>().ultimaCajaCerrada;
    final total = _conteo.total;

    return TarjetaClara(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PasosApertura(actual: 0),
            const SizedBox(height: 18),
            const _Titulo(
              icono: Icons.savings_outlined,
              titulo: 'Primero, cuenta el efectivo del negocio',
              bajada:
                  'Toda la plata que tiene el negocio, billete por billete. '
                  'Queda guardada, y de ahí sale lo que pones en la caja cada '
                  'día.',
            ),
            if (previa != null && previa.cierre > 0) ...[
              const SizedBox(height: 14),
              _Nota(
                icono: Icons.info_outline_rounded,
                texto:
                    'Cuenta también los '
                    '${Formato.soles(previa.cierre / 100)} con que cerró la '
                    'caja N° ${previa.numero}: son parte del negocio.',
              ),
            ],
            const SizedBox(height: 18),
            ConteoEditor(
              conteo: _conteo,
              onCambiar: (c) => setState(() {
                _conteo = c;
                _error = null;
              }),
            ),
            const SizedBox(height: 18),
            _Cifra(
              rotulo: 'El negocio tiene',
              centavos: total,
              detalle: _conteo.estaVacio
                  ? 'Marca cuántos billetes y monedas de cada uno tienes'
                  : _conteo.resumen,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _TextoError(_error!),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              icon: _guardando
                  ? const _Girando()
                  : const Icon(Icons.lock_rounded, size: 20),
              label: Text(
                total == 0
                    ? 'Empezar sin efectivo (S/ 0.00)'
                    : 'Guardar el efectivo del negocio',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Queda bloqueado para que nadie lo cambie sin querer. Si ves que '
              'contaste mal, lo corriges desde "Efectivo del negocio".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Tokens.texto2),
            ),
          ],
        ),
      ),
    );
  }
}

/// "1 Cuenta el efectivo — 2 Abre la caja": en qué paso se está la primera
/// vez.
class _PasosApertura extends StatelessWidget {
  const _PasosApertura({required this.actual});

  final int actual;

  @override
  Widget build(BuildContext context) {
    Widget paso(int i, String texto) {
      final hecho = i < actual;
      final activo = i == actual;
      final color = hecho || activo ? Tokens.marca : Tokens.bordeFuerte;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hecho || activo ? color : Tokens.superficie,
              border: Border.all(color: color),
            ),
            child: hecho
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: activo ? Colors.white : Tokens.texto2,
                    ),
                  ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo ? Tokens.texto : Tokens.texto2,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Flexible(child: paso(0, 'Cuenta el efectivo')),
        Container(
          width: 28,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: actual > 0 ? Tokens.marca : Tokens.borde,
        ),
        Flexible(child: paso(1, 'Abre la caja')),
      ],
    );
  }
}

/// Cuánto efectivo tiene el negocio y dónde está: en la caja o guardado.
/// El conteo queda bloqueado; sólo se corrige, por si se contó mal.
class _EfectivoNegocioTarjeta extends StatelessWidget {
  const _EfectivoNegocioTarjeta({required this.usuario});

  final String usuario;

  @override
  Widget build(BuildContext context) {
    final efectivo = context.watch<EstadoCaja>().efectivoNegocio;
    if (efectivo == null) return const SizedBox.shrink();
    final fondo = efectivo.fondo;
    final caja = efectivo.caja;

    final dondeCaja = caja == null
        ? 'En la caja'
        : caja.abierta
        ? 'En la caja N° ${caja.numero} (abierta)'
        : 'En la caja (así cerró la N° ${caja.numero})';

    final contado =
        '${_cuando(fondo.contadoEn)}'
        '${fondo.usuario.isEmpty ? '' : ' · ${fondo.usuario}'}';

    return TarjetaClara(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Efectivo del negocio',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Tokens.texto,
                    ),
                  ),
                ),
                Tooltip(
                  message:
                      'El conteo no se edita: la app sigue sola lo que entra '
                      'y sale de la caja. Si contaste mal, corrígelo abajo.',
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
                          'Bloqueado',
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
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Formato.soles(efectivo.total / 100),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: Tokens.texto,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Reparto(enCaja: efectivo.enCaja, guardado: efectivo.guardado),
            const SizedBox(height: 12),
            _LineaReparto(
              color: Tokens.marca,
              rotulo: dondeCaja,
              centavos: efectivo.enCaja,
            ),
            _LineaReparto(
              color: Tokens.cromo,
              rotulo: 'Guardado aparte',
              centavos: efectivo.guardado,
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Conteo inicial',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Tokens.texto,
                        ),
                      ),
                      Text(
                        contado,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Tokens.texto2,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Formato.soles(fondo.total / 100),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Tokens.texto,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              fondo.conteo.estaVacio ? 'Sin efectivo' : fondo.conteo.resumen,
              style: const TextStyle(fontSize: 12, color: Tokens.texto2),
            ),
            if (fondo.corregido) ...[
              const SizedBox(height: 4),
              Text(
                'Corregido ${_cuando(fondo.corregidoEn!)}'
                '${fondo.corregidoPor.isEmpty ? '' : ' por ${fondo.corregidoPor}'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Tokens.texto2,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _CorregirFondo.abrir(context, fondo, usuario),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Corregir conteo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La barra partida en dos: la parte naranja es lo que está en la caja, la
/// grafito lo guardado.
class _Reparto extends StatelessWidget {
  const _Reparto({required this.enCaja, required this.guardado});

  final int enCaja;
  final int guardado;

  @override
  Widget build(BuildContext context) {
    final total = enCaja + guardado;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: total <= 0
            ? const ColoredBox(color: Tokens.borde)
            // Estirada: sin hijo, cada tramo mediría cero de alto.
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (enCaja > 0)
                    Expanded(
                      flex: enCaja,
                      child: const ColoredBox(color: Tokens.marca),
                    ),
                  if (enCaja > 0 && guardado > 0) const SizedBox(width: 2),
                  if (guardado > 0)
                    Expanded(
                      flex: guardado,
                      child: const ColoredBox(color: Tokens.cromo),
                    ),
                ],
              ),
      ),
    );
  }
}

class _LineaReparto extends StatelessWidget {
  const _LineaReparto({
    required this.color,
    required this.rotulo,
    required this.centavos,
  });

  final Color color;
  final String rotulo;
  final int centavos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              rotulo,
              style: const TextStyle(fontSize: 13, color: Tokens.texto2),
            ),
          ),
          Text(
            Formato.soles(centavos / 100),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Tokens.texto,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quien ya tenía una caja abierta al actualizar la app todavía no contó el
/// efectivo del negocio. Con la caja abierta no se puede: la plata se está
/// moviendo. Se avisa para hacerlo al cerrarla.
class _FaltaFondo extends StatelessWidget {
  const _FaltaFondo();

  @override
  Widget build(BuildContext context) {
    return const TarjetaClara(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: _Nota(
          icono: Icons.savings_outlined,
          texto:
              'Falta contar el efectivo del negocio. Cuando cierres esta caja, '
              'la app te lo va a pedir antes de abrir la siguiente.',
        ),
      ),
    );
  }
}

/// Corregir el conteo del efectivo del negocio, por si se contó mal.
class _CorregirFondo extends StatefulWidget {
  const _CorregirFondo({required this.fondo, required this.usuario});

  final FondoNegocio fondo;
  final String usuario;

  static Future<void> abrir(
    BuildContext context,
    FondoNegocio fondo,
    String usuario,
  ) {
    return showDialog<void>(
      context: context,
      barrierColor: Tokens.cromo.withValues(alpha: 0.40),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _CorregirFondo(fondo: fondo, usuario: usuario),
        ),
      ),
    );
  }

  @override
  State<_CorregirFondo> createState() => _CorregirFondoState();
}

class _CorregirFondoState extends State<_CorregirFondo> {
  late Conteo _conteo = widget.fondo.conteo;
  bool _guardando = false;
  String? _error;

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final navegador = Navigator.of(context);
    try {
      await context.read<EstadoCaja>().corregirFondo(
        _conteo,
        usuario: widget.usuario,
      );
      HapticFeedback.mediumImpact();
      navegador.pop();
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo guardar. $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final antes = widget.fondo.total;
    final ahora = _conteo.total;
    final cambio = ahora - antes;
    final igual = _conteo == widget.fondo.conteo;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Titulo(
            icono: Icons.edit_outlined,
            titulo: 'Corregir el efectivo del negocio',
            bajada:
                'Sólo si contaste mal. Pon lo que había de verdad '
                '${_cuando(widget.fondo.contadoEn)}; lo guardado se '
                'recalcula solo.',
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: ConteoEditor(
                conteo: _conteo,
                onCambiar: (c) => setState(() {
                  _conteo = c;
                  _error = null;
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Tokens.fondo,
              borderRadius: BorderRadius.circular(Tokens.radio),
              border: Border.all(color: Tokens.borde),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Antes ${Formato.soles(antes / 100)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Tokens.texto2,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
                if (cambio != 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      '${cambio > 0 ? '+' : '−'} '
                      '${Formato.soles(cambio.abs() / 100)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: cambio > 0 ? Tokens.entro : Tokens.salio,
                      ),
                    ),
                  ),
                Text(
                  Formato.soles(ahora / 100),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Tokens.texto,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _TextoError(_error!),
          ],
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _guardando
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: _guardando || igual ? null : _guardar,
                icon: _guardando
                    ? const _Girando()
                    : const Icon(Icons.check_rounded, size: 19),
                label: const Text('Guardar corrección'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Piezas chicas que se repiten en el paso de contar y en el de abrir ---

/// Un monto grande con su rótulo, en un recuadro claro.
class _Cifra extends StatelessWidget {
  const _Cifra({required this.rotulo, required this.centavos, this.detalle});

  final String rotulo;
  final int centavos;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rotulo,
                  style: const TextStyle(fontSize: 13, color: Tokens.texto2),
                ),
                if (detalle != null)
                  Text(
                    detalle!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Tokens.texto2,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Formato.soles(centavos / 100),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Tokens.texto,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 17, color: Tokens.texto2),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Tokens.texto2,
            ),
          ),
        ),
      ],
    );
  }
}

class _TextoError extends StatelessWidget {
  const _TextoError(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Tokens.salio,
      ),
    );
  }
}

class _Girando extends StatelessWidget {
  const _Girando();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
