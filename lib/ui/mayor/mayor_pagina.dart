import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/enums.dart';
import '../../dominio/mayor.dart';
import '../../estado/estado_caja.dart';
import '../widgets/aparece.dart';
import '../widgets/distintivo.dart';
import '../widgets/esqueleto.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/icono_medio.dart';
import '../widgets/tarjeta_cuenta.dart';
import '../widgets/tarjeta_saldo.dart';

/// Caja y bancos en una sola pantalla, como un libro mayor (§4.2).
///
/// Responde tres preguntas, en este orden:
///
/// 1. **¿Cuánto tengo en total?** — la tarjeta grafito.
/// 2. **¿Cuánto es efectivo y cuánto está en el banco?** — las dos tarjetas
///    de al lado, y el desglose por medio: cuánto dejó Yape / Plin, cuánto
///    las transferencias, cuánto la tarjeta.
/// 3. **¿Cómo se llegó a ese número?** — el libro: cada movimiento con el
///    saldo que dejó, del más nuevo al más viejo, como un estado de cuenta.
///
/// Todo lo de arriba sirve también de filtro: tocar "Yape / Plin" deja en el
/// libro sólo lo que pasó por Yape / Plin, con su propio saldo.
class MayorPagina extends StatefulWidget {
  const MayorPagina({super.key});

  @override
  State<MayorPagina> createState() => _MayorPaginaState();
}

class _MayorPaginaState extends State<MayorPagina> {
  /// Cuántos renglones del libro se dibujan. Un año de una bodega son miles:
  /// se muestran de a tandas, y lo más nuevo —lo que se mira— va primero.
  static const _tanda = 60;
  int _visibles = _tanda;

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    if (estado.cargando) return const EsqueletoLista();

    final mayor = estado.mayor;
    final bolsillo = estado.bolsillo;

    void alternar(Bolsillo b) {
      setState(() => _visibles = _tanda);
      estado.verBolsillo(bolsillo == b ? Bolsillo.todo : b);
    }

    return LayoutBuilder(
      builder: (context, medidas) {
        final amplio = medidas.maxWidth >= 760;
        final margen = amplio ? 28.0 : 16.0;
        final separacion = amplio ? 20.0 : 14.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            margen,
            margen,
            margen,
            // Aire para los botones flotantes del celular.
            amplio ? margen : 120,
          ),
          children: [
            Aparece(
              child: _Totales(
                mayor: mayor,
                bolsillo: bolsillo,
                amplio: amplio,
                onElegir: alternar,
              ),
            ),
            SizedBox(height: separacion),
            Aparece(
              retraso: const Duration(milliseconds: 80),
              child: _DondeEsta(
                mayor: mayor,
                bolsillo: bolsillo,
                amplio: amplio,
                onElegir: alternar,
              ),
            ),
            SizedBox(height: separacion),
            Aparece(
              retraso: const Duration(milliseconds: 160),
              child: _Libro(
                mayor: mayor,
                bolsillo: bolsillo,
                amplio: amplio,
                visibles: _visibles,
                onElegir: (b) {
                  setState(() => _visibles = _tanda);
                  estado.verBolsillo(b);
                },
                onVerMas: () => setState(() => _visibles += _tanda),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// El total grande y, al lado, cuánto es efectivo y cuánto banco.
class _Totales extends StatelessWidget {
  const _Totales({
    required this.mayor,
    required this.bolsillo,
    required this.amplio,
    required this.onElegir,
  });

  final LibroMayor mayor;
  final Bolsillo bolsillo;
  final bool amplio;
  final ValueChanged<Bolsillo> onElegir;

  @override
  Widget build(BuildContext context) {
    final total = mayor.total;

    final saldo = TarjetaSaldo(
      titulo: 'Lo que tienes en total',
      centavos: total,
      destacada: true,
      oscura: true,
      distintivo: Distintivo(
        sobreOscuro: true,
        icono: Icons.account_balance_wallet_outlined,
        texto: total < 0 ? 'En negativo' : 'Efectivo + banco y digital',
        color: total < 0 ? Tokens.salioVivo : Tokens.marca,
      ),
    );

    final caja = TarjetaCuenta(
      icono: Icons.payments_outlined,
      titulo: Cuenta.caja.etiqueta,
      bajada: 'Billetes y monedas en el negocio',
      centavos: mayor.saldoCaja,
      elegida: bolsillo == Bolsillo.caja,
      conFlecha: false,
      onTap: () => onElegir(Bolsillo.caja),
    );

    final banco = TarjetaCuenta(
      icono: Icons.account_balance_outlined,
      titulo: Cuenta.banco.etiqueta,
      bajada: 'Yape, Plin, transferencia y más',
      centavos: mayor.saldoBanco,
      elegida: bolsillo == Bolsillo.banco,
      conFlecha: false,
      onTap: () => onElegir(Bolsillo.banco),
    );

    if (!amplio) {
      return Column(
        children: [
          saldo,
          const SizedBox(height: 14),
          caja,
          const SizedBox(height: 10),
          banco,
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: saldo),
          const SizedBox(width: 20),
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [caja, const SizedBox(height: 14), banco],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dónde está la plata: el efectivo, el saldo con que abrió el banco, y lo
/// que dejó cada medio digital. Los renglones suman exactamente el total.
class _DondeEsta extends StatelessWidget {
  const _DondeEsta({
    required this.mayor,
    required this.bolsillo,
    required this.amplio,
    required this.onElegir,
  });

  final LibroMayor mayor;
  final Bolsillo bolsillo;
  final bool amplio;
  final ValueChanged<Bolsillo> onElegir;

  @override
  Widget build(BuildContext context) {
    final efectivo = mayor.efectivo;
    final digitales = mayor.mediosBanco;

    String detalle(TotalMedio? t, {int apertura = 0}) {
      final conMovimientos = t != null && t.cantidad > 0;
      final partes = <String>[
        if (conMovimientos) 'Entró ${Formato.soles(t.entro / 100)}',
        if (conMovimientos) 'Salió ${Formato.soles(t.salio / 100)}',
        if (apertura != 0) 'Abriste con ${Formato.soles(apertura / 100)}',
      ];
      return partes.isEmpty ? 'Sin movimientos todavía' : partes.join('  ·  ');
    }

    return TarjetaClara(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 6),
            child: _Titulo(
              titulo: 'Dónde está tu plata',
              bajada:
                  'Lo que dejó cada medio de pago desde que abriste el '
                  'libro. Toca uno para ver sólo sus movimientos.',
            ),
          ),
          _Grupo(texto: 'En efectivo', centavos: mayor.saldoCaja),
          _RenglonMedio(
            icono: iconoDeMedio(MedioPago.efectivo),
            titulo: 'Efectivo',
            detalle: detalle(efectivo, apertura: mayor.saldoInicialCaja),
            centavos: mayor.saldoCaja,
            elegido: bolsillo == Bolsillo.caja,
            amplio: amplio,
            onTap: () => onElegir(Bolsillo.caja),
          ),
          _Grupo(texto: 'En banco y digital', centavos: mayor.saldoBanco),
          if (mayor.saldoInicialBanco != 0)
            _RenglonMedio(
              icono: Icons.flag_outlined,
              titulo: 'Saldo con que abriste',
              detalle:
                  'Lo que tenías en el banco y en billeteras el '
                  '${mayor.negocio.inicioPeriodo == null ? 'primer día' : Formato.fecha(mayor.negocio.inicioPeriodo!)}',
              centavos: mayor.saldoInicialBanco,
              amplio: amplio,
            ),
          for (final t in digitales)
            _RenglonMedio(
              icono: iconoDeMedio(t.medio),
              titulo: t.medio.etiqueta,
              detalle: detalle(t),
              centavos: t.neto,
              cantidad: t.cantidad == 0 ? null : t.cantidad,
              elegido: bolsillo == Bolsillo.deMedio(t.medio),
              amplio: amplio,
              onTap: () => onElegir(Bolsillo.deMedio(t.medio)),
            ),
          if (digitales.isEmpty && mayor.saldoInicialBanco == 0)
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 4, 22, 14),
              child: Text(
                'Todavía no se movió plata por Yape, Plin, transferencia ni '
                'tarjeta.',
                style: TextStyle(fontSize: 12.5, color: Tokens.texto2),
              ),
            ),
          // El total al pie: los renglones de arriba suman exactamente esto.
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
            decoration: const BoxDecoration(
              color: Tokens.fondo,
              border: Border(top: BorderSide(color: Tokens.borde)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Tokens.texto,
                    ),
                  ),
                ),
                Text(
                  Formato.soles(mayor.total / 100),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: mayor.total < 0 ? Tokens.salio : Tokens.texto,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.texto, required this.centavos});

  final String texto;
  final int centavos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
      child: Row(
        children: [
          Text(
            texto.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
              color: Tokens.texto2,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
          const SizedBox(width: 10),
          Text(
            Formato.soles(centavos / 100),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Tokens.texto2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RenglonMedio extends StatefulWidget {
  const _RenglonMedio({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.centavos,
    required this.amplio,
    this.cantidad,
    this.elegido = false,
    this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final int centavos;
  final bool amplio;
  final int? cantidad;
  final bool elegido;
  final VoidCallback? onTap;

  @override
  State<_RenglonMedio> createState() => _RenglonMedioState();
}

class _RenglonMedioState extends State<_RenglonMedio> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final elegido = widget.elegido;
    final tocable = widget.onTap != null;

    final fondo = elegido
        ? Tokens.marcaSuave
        : (_encima && tocable ? Tokens.fondo : Colors.transparent);

    return MouseRegion(
      cursor: tocable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(Tokens.radio),
            border: Border.all(
              color: elegido
                  ? Tokens.marca.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: elegido ? Tokens.marca : Tokens.marcaSuave,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icono,
                  size: 18,
                  color: elegido ? Colors.white : Tokens.marca,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Tokens.texto,
                            ),
                          ),
                        ),
                        if (widget.cantidad != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            widget.cantidad == 1
                                ? '1 mov.'
                                : '${widget.cantidad} mov.',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Tokens.texto2,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.detalle,
                      maxLines: widget.amplio ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Tokens.texto2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Formato.soles(widget.centavos / 100),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: widget.centavos < 0 ? Tokens.salio : Tokens.texto,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El libro: los movimientos del bolsillo elegido, cada uno con su saldo.
class _Libro extends StatelessWidget {
  const _Libro({
    required this.mayor,
    required this.bolsillo,
    required this.amplio,
    required this.visibles,
    required this.onElegir,
    required this.onVerMas,
  });

  final LibroMayor mayor;
  final Bolsillo bolsillo;
  final bool amplio;
  final int visibles;
  final ValueChanged<Bolsillo> onElegir;
  final VoidCallback onVerMas;

  @override
  Widget build(BuildContext context) {
    final lineas = mayor.lineas(bolsillo);
    final mostradas = lineas.take(visibles).toList();
    final faltan = lineas.length - mostradas.length;
    final inicial = bolsillo.saldoInicial(mayor.negocio);

    // Los filtros: todo, las dos cuentas y cada medio digital que se usó.
    final opciones = <Bolsillo>[
      Bolsillo.todo,
      Bolsillo.caja,
      Bolsillo.banco,
      for (final t in mayor.mediosBanco) Bolsillo.deMedio(t.medio),
    ];

    return TarjetaClara(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
            child: _Titulo(
              titulo: 'Movimientos y saldo',
              bajada:
                  'Como un libro mayor: cada movimiento y cómo quedó la '
                  'plata después. Lo más nuevo, arriba.',
              accion: _SaldoDelFiltro(
                etiqueta: bolsillo.etiqueta,
                centavos: mayor.saldoDe(bolsillo),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in opciones)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: b.medio == null
                        ? null
                        : Icon(
                            iconoDeMedio(b.medio!),
                            size: 16,
                            color: b == bolsillo
                                ? Tokens.marcaOscura
                                : Tokens.texto2,
                          ),
                    label: Text(b.etiqueta),
                    selected: b == bolsillo,
                    onSelected: (_) => onElegir(b),
                  ),
              ],
            ),
          ),
          if (amplio) const _CabeceraTabla(),
          if (lineas.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EstadoVacio(
                icono: Icons.menu_book_outlined,
                titulo: 'Sin movimientos en ${bolsillo.etiqueta.toLowerCase()}',
                mensaje:
                    'Cuando entre o salga plata por acá, aparece en '
                    'este libro con el saldo que dejó.',
              ),
            )
          else ...[
            for (var i = 0; i < mostradas.length; i++)
              _RenglonLibro(linea: mostradas[i], amplio: amplio, par: i.isEven),
            if (faltan > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: TextButton.icon(
                    onPressed: onVerMas,
                    icon: const Icon(Icons.expand_more_rounded, size: 18),
                    label: Text(
                      faltan > 60
                          ? 'Ver 60 más (quedan $faltan)'
                          : 'Ver los $faltan que faltan',
                    ),
                  ),
                ),
              ),
          ],
          // El renglón de apertura, al pie: es de donde arranca el saldo.
          // Para un medio digital suelto no va: arranca de cero por diseño,
          // y un "Saldo inicial S/ 0.00" haría pensar que falta un dato.
          if (faltan <= 0 && bolsillo.medio == null)
            _RenglonApertura(
              fecha: mayor.negocio.inicioPeriodo,
              centavos: inicial,
              amplio: amplio,
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _SaldoDelFiltro extends StatelessWidget {
  const _SaldoDelFiltro({required this.etiqueta, required this.centavos});

  final String etiqueta;
  final int centavos;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey('$etiqueta$centavos'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Tokens.marcaSuave,
          borderRadius: BorderRadius.circular(Tokens.radio),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              etiqueta == 'Todo' ? 'Saldo total' : 'Saldo · $etiqueta',
              style: const TextStyle(fontSize: 11.5, color: Tokens.texto2),
            ),
            const SizedBox(height: 1),
            Text(
              Formato.soles(centavos / 100),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: centavos < 0 ? Tokens.salio : Tokens.texto,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anchos de las columnas del libro en escritorio. El detalle se lleva lo
/// que sobra.
const _anchoFecha = 96.0;
const _anchoMedio = 150.0;
const _anchoMonto = 118.0;
const _anchoSaldo = 132.0;

class _CabeceraTabla extends StatelessWidget {
  const _CabeceraTabla();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
      fontSize: 10.5,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w700,
      color: Tokens.texto2,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: const BoxDecoration(
        color: Tokens.fondo,
        border: Border.symmetric(horizontal: BorderSide(color: Tokens.borde)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: _anchoFecha,
            child: Text('FECHA', style: estilo),
          ),
          Expanded(child: Text('DETALLE', style: estilo)),
          SizedBox(
            width: _anchoMedio,
            child: Text('MEDIO', style: estilo),
          ),
          SizedBox(
            width: _anchoMonto,
            child: Text('ENTRÓ', textAlign: TextAlign.right, style: estilo),
          ),
          SizedBox(
            width: _anchoMonto,
            child: Text('SALIÓ', textAlign: TextAlign.right, style: estilo),
          ),
          SizedBox(
            width: _anchoSaldo,
            child: Text('SALDO', textAlign: TextAlign.right, style: estilo),
          ),
        ],
      ),
    );
  }
}

class _RenglonLibro extends StatelessWidget {
  const _RenglonLibro({
    required this.linea,
    required this.amplio,
    required this.par,
  });

  final LineaMayor linea;
  final bool amplio;
  final bool par;

  @override
  Widget build(BuildContext context) {
    final m = linea.movimiento;
    final entro = m.tipo == Tipo.entro;
    final color = entro ? Tokens.entro : Tokens.salio;
    final detalle = m.concepto.trim().isEmpty
        ? m.categoria.etiqueta
        : m.concepto;
    const cifras = [FontFeature.tabularFigures()];

    final saldo = Text(
      Formato.soles(linea.saldo / 100),
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: linea.saldo < 0 ? Tokens.salio : Tokens.texto,
        fontFeatures: cifras,
      ),
    );

    if (!amplio) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Tokens.borde)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Text(
                m.tipo.flecha,
                style: TextStyle(
                  color: color,
                  fontSize: 17,
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
                    detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Tokens.texto,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${m.medio.etiqueta} · ${Formato.fechaRelativa(m.fecha)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Tokens.texto2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entro ? '+' : '−'} ${Formato.soles(m.monto)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontFeatures: cifras,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Saldo ${Formato.soles(linea.saldo / 100)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Tokens.texto2,
                    fontFeatures: cifras,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
      decoration: BoxDecoration(
        color: par ? Tokens.superficie : const Color(0xFFFCFBFA),
        border: const Border(bottom: BorderSide(color: Tokens.borde)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _anchoFecha,
            child: Text(
              Formato.fecha(m.fecha),
              style: const TextStyle(
                fontSize: 13,
                color: Tokens.texto2,
                fontFeatures: cifras,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Tokens.texto,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    [
                      m.categoria.etiqueta,
                      if ((m.contraparte ?? '').trim().isNotEmpty)
                        m.contraparte!.trim(),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Tokens.texto2),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: _anchoMedio,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _PastillaMedio(medio: m.medio),
            ),
          ),
          SizedBox(
            width: _anchoMonto,
            child: Text(
              entro ? Formato.soles(m.monto) : '',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Tokens.entro,
                fontFeatures: cifras,
              ),
            ),
          ),
          SizedBox(
            width: _anchoMonto,
            child: Text(
              entro ? '' : Formato.soles(m.monto),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Tokens.salio,
                fontFeatures: cifras,
              ),
            ),
          ),
          SizedBox(width: _anchoSaldo, child: saldo),
        ],
      ),
    );
  }
}

class _RenglonApertura extends StatelessWidget {
  const _RenglonApertura({
    required this.fecha,
    required this.centavos,
    required this.amplio,
  });

  final DateTime? fecha;
  final int centavos;
  final bool amplio;

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Tokens.texto2,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: amplio ? 22 : 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Tokens.fondo,
        border: Border(top: BorderSide(color: Tokens.borde)),
      ),
      child: Row(
        children: [
          if (amplio)
            SizedBox(
              width: _anchoFecha,
              child: Text(
                fecha == null ? '—' : Formato.fecha(fecha!),
                style: estilo.copyWith(fontWeight: FontWeight.w400),
              ),
            ),
          const Icon(Icons.flag_outlined, size: 16, color: Tokens.texto2),
          const SizedBox(width: 8),
          const Expanded(child: Text('Saldo con que abriste', style: estilo)),
          Text(
            Formato.soles(centavos / 100),
            style: estilo.copyWith(color: Tokens.texto),
          ),
        ],
      ),
    );
  }
}

class _PastillaMedio extends StatelessWidget {
  const _PastillaMedio({required this.medio});

  final MedioPago medio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Tokens.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconoDeMedio(medio), size: 14, color: Tokens.texto2),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              medio.etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Tokens.texto),
            ),
          ),
        ],
      ),
    );
  }
}

/// Título y bajada de una tarjeta de contenido, con algo opcional a la
/// derecha.
class _Titulo extends StatelessWidget {
  const _Titulo({required this.titulo, required this.bajada, this.accion});

  final String titulo;
  final String bajada;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
        if (accion != null) ...[const SizedBox(width: 12), accion!],
      ],
    );
  }
}
