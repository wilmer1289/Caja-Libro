import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/export/abrir_archivo.dart';
import '../../datos/export/exportador.dart';
import '../../datos/export/exportador_pdf.dart';
import '../../dominio/enums.dart';
import '../../dominio/libro_oficial.dart';
import '../../estado/estado_caja.dart';
import '../negocio/negocio_pagina.dart';
import '../widgets/aparece.dart';
import '../widgets/esqueleto.dart';
import '../historial/barra_filtros.dart';
import '../widgets/filtro_monto.dart';
import 'bloque_asiento.dart';
import 'hoja_formato.dart';

/// Los formatos oficiales del libro de caja: el 1.1 para el efectivo y el 1.2
/// para la cuenta corriente.
///
/// Es la sección donde la app deja de hablar como una libreta y empieza a
/// hablar como un libro contable. Todo lo que se ve acá está armado con lo que
/// ya se registró: no se pide ni un dato más.
class FormatosPagina extends StatefulWidget {
  const FormatosPagina({super.key});

  @override
  State<FormatosPagina> createState() => _FormatosPaginaState();
}

class _FormatosPaginaState extends State<FormatosPagina> {
  Cuenta _cuenta = Cuenta.caja;

  /// El mes que se está viendo, siempre como su día 1.
  late DateTime _mes = _mesDe(DateTime.now());

  // --- Filtros de la vista (no del documento: el PDF sale completo) ---
  Tipo? _tipo;
  final _texto = TextEditingController();
  RangoMonto? _monto;
  String? _montoEtiqueta;

  bool get _hayFiltro =>
      _tipo != null || _texto.text.trim().isNotEmpty || _monto != null;

  bool Function(FilaFormato)? get _filtro {
    if (!_hayFiltro) return null;
    final q = _texto.text.trim().toLowerCase();
    return (f) {
      if (_tipo == Tipo.entro && f.deudor == 0) return false;
      if (_tipo == Tipo.salio && f.acreedor == 0) return false;
      if (q.isNotEmpty) {
        final todo = [
          f.descripcion,
          f.denominacion ?? '',
          f.codigoCuenta ?? '',
          f.contraparte ?? '',
        ].join(' ').toLowerCase();
        if (!todo.contains(q)) return false;
      }
      final monto = _monto;
      if (monto != null &&
          !dentroDelRango(monto, f.deudor > 0 ? f.deudor : f.acreedor)) {
        return false;
      }
      return true;
    };
  }

  void _limpiarFiltros() => setState(() {
    _tipo = null;
    _texto.clear();
    _monto = null;
    _montoEtiqueta = null;
  });

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  static DateTime _mesDe(DateTime d) => DateTime(d.year, d.month);

  /// El último día del mes: el día 0 del siguiente.
  DateTime get _finDeMes => DateTime(_mes.year, _mes.month + 1, 0);

  /// Guarda el formato y avisa dónde quedó, con un botón para abrirlo.
  ///
  /// Dice la ruta completa y no sólo "listo": el archivo se va a buscar desde
  /// el explorador o para adjuntarlo a un correo, y sin la ruta hay que salir a
  /// buscarlo a mano.
  Future<void> _exportar(LibroOficial libro, {required bool pdf}) async {
    final mensajero = ScaffoldMessenger.of(context);
    if (!libro.negocio.completo ||
        (libro.cuenta == Cuenta.banco && !libro.negocio.completoParaBanco)) {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text(
            'Completa los datos del negocio y, para bancos, la entidad y la cuenta.',
          ),
        ),
      );
      return;
    }
    // La web no tiene carpeta de documentos: el PDF se descarga con el
    // diálogo del navegador, y el CSV —que se escribe con dart:io— todavía
    // no tiene ese camino.
    if (kIsWeb) {
      if (!pdf) {
        mensajero.showSnackBar(
          const SnackBar(
            content: Text(
              'La descarga en CSV todavía no está disponible en la web. '
              'Pruébala en Windows o Android.',
            ),
          ),
        );
        return;
      }
      await Printing.sharePdf(
        bytes: await ExportadorPdf.formato(libro),
        filename: ExportadorPdf.nombreFormato(libro),
      );
      if (mounted) {
        mensajero.showSnackBar(
          const SnackBar(content: Text('Guardado en tu carpeta de descargas')),
        );
      }
      return;
    }
    try {
      final ruta = pdf
          ? await ExportadorPdf.guardar(
              await ExportadorPdf.formato(libro),
              ExportadorPdf.nombreFormato(libro),
            )
          : await Exportador.guardarFormato(libro);

      if (!mounted) return;
      mensajero
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Guardado en $ruta'),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Abrir',
              onPressed: () => abrirArchivo(ruta),
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo guardar el archivo. $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();

    if (estado.cargando) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Esqueleto(ancho: double.infinity, alto: 320, radio: 20),
      );
    }

    final libro = LibroOficial.armar(
      cuenta: _cuenta,
      negocio: estado.negocio,
      movimientos: estado.movimientos,
      desde: _mes,
      hasta: _finDeMes,
    );

    return LayoutBuilder(
      builder: (context, limites) {
        final amplio = limites.maxWidth >= 720;
        final margen = amplio ? 24.0 : 16.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(margen, margen, margen, margen + 80),
          children: [
            _Controles(
              cuenta: _cuenta,
              mes: _mes,
              meses: _mesesDisponibles(estado),
              amplio: amplio,
              onCuenta: (c) => setState(() => _cuenta = c),
              onMes: (m) => setState(() => _mes = m),
              onExportar: (pdf) => _exportar(libro, pdf: pdf),
            ),
            const SizedBox(height: 16),

            if (estado.faltaPerfil) ...[
              const Aparece(child: _PerfilIncompleto()),
              const SizedBox(height: 16),
            ] else if (_cuenta == Cuenta.banco &&
                !estado.negocio.completoParaBanco) ...[
              const Aparece(child: _FaltaBanco()),
              const SizedBox(height: 16),
            ],

            Aparece(child: _Cuadre(libro: libro)),
            const SizedBox(height: 16),

            Aparece(
              retraso: const Duration(milliseconds: 40),
              child: _FiltrosVista(
                tipo: _tipo,
                texto: _texto,
                monto: _monto,
                montoEtiqueta: _montoEtiqueta,
                onTipo: (t) => setState(() => _tipo = t),
                onTexto: () => setState(() {}),
                onMonto: (r, e) => setState(() {
                  _monto = r;
                  _montoEtiqueta = e;
                }),
                onLimpiarMonto: () => setState(() {
                  _monto = null;
                  _montoEtiqueta = null;
                }),
                onLimpiar: _hayFiltro ? _limpiarFiltros : null,
                mostradas: _hayFiltro
                    ? libro.filas.skip(1).where(_filtro!).length
                    : null,
                total: libro.filas.length - 1,
              ),
            ),
            const SizedBox(height: 12),

            Aparece(
              retraso: const Duration(milliseconds: 70),
              child: HojaFormato(libro: libro, filtro: _filtro),
            ),

            if (libro.asientos.isNotEmpty) ...[
              const SizedBox(height: 26),
              Aparece(
                retraso: const Duration(milliseconds: 140),
                child: _TituloSeccion(
                  titulo: 'Para el Libro Diario',
                  bajada:
                      'El mes entero resumido en un asiento por lado. Es '
                      'lo que el contador pasa a los libros.',
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < libro.asientos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Aparece(
                    retraso: Duration(milliseconds: 180 + i * 70),
                    child: BloqueAsiento(
                      asiento: libro.asientos[i],
                      periodo: Formato.mes(_mes),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  /// Los meses que se pueden ver: desde el más antiguo registrado hasta el
  /// actual, sin huecos.
  ///
  /// Sin huecos a propósito: un mes sin movimientos igual tiene formato —lleva
  /// su saldo inicial y su cuadre—, y si no estuviera en la lista parecería
  /// que la app perdió algo.
  List<DateTime> _mesesDisponibles(EstadoCaja estado) {
    final hoy = _mesDe(DateTime.now());
    var primero = hoy;

    for (final m in estado.movimientos) {
      final suyo = _mesDe(m.fecha);
      if (suyo.isBefore(primero)) primero = suyo;
    }
    final apertura = estado.negocio.inicioPeriodo;
    if (apertura != null && _mesDe(apertura).isBefore(primero)) {
      primero = _mesDe(apertura);
    }

    final meses = <DateTime>[];
    var cursor = hoy;
    while (!cursor.isBefore(primero)) {
      meses.add(cursor);
      cursor = DateTime(cursor.year, cursor.month - 1);
    }
    return meses;
  }
}

/// La barra de arriba: qué formato, de qué mes, y el botón de exportar.
class _Controles extends StatelessWidget {
  const _Controles({
    required this.cuenta,
    required this.mes,
    required this.meses,
    required this.amplio,
    required this.onCuenta,
    required this.onMes,
    required this.onExportar,
  });

  final Cuenta cuenta;
  final DateTime mes;
  final List<DateTime> meses;
  final bool amplio;
  final ValueChanged<Cuenta> onCuenta;
  final ValueChanged<DateTime> onMes;

  /// Recibe `true` para PDF y `false` para la planilla.
  final ValueChanged<bool> onExportar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Alternador(cuenta: cuenta, onCambiar: onCuenta, amplio: amplio),
        _SelectorMes(mes: mes, meses: meses, onElegir: onMes),
        _BotonExportar(onExportar: onExportar),
      ],
    );
  }
}

/// Exportar, con las dos salidas que tiene sentido ofrecer.
///
/// El PDF va primero porque es el documento terminado —el que se imprime, se
/// firma y se archiva—. La planilla es para el contador que todavía va a
/// trabajar el dato.
class _BotonExportar extends StatelessWidget {
  const _BotonExportar({required this.onExportar});

  final ValueChanged<bool> onExportar;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Tokens.superficie),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(
          Tokens.cromo.withValues(alpha: 0.25),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radio),
            side: const BorderSide(color: Tokens.borde),
          ),
        ),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          onPressed: () => onExportar(true),
          child: const Text('PDF, para imprimir y firmar'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.table_chart_outlined, size: 18),
          onPressed: () => onExportar(false),
          child: const Text('Planilla, para seguir trabajándolo'),
        ),
      ],
      builder: (context, menu, _) => FilledButton.icon(
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        style: FilledButton.styleFrom(
          backgroundColor: Tokens.marca,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        icon: const Icon(Icons.file_download_outlined, size: 18),
        label: const Text('Exportar'),
      ),
    );
  }
}

/// Caja 1.1 / Banco 1.2, en un alternador de dos casillas.
///
/// No es un menú: son dos, siempre, y verlos juntos deja claro que el libro
/// tiene dos mitades que se llevan por separado.
class _Alternador extends StatelessWidget {
  const _Alternador({
    required this.cuenta,
    required this.onCambiar,
    required this.amplio,
  });

  final Cuenta cuenta;
  final ValueChanged<Cuenta> onCambiar;
  final bool amplio;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Tokens.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in Cuenta.values)
            _Casilla(
              texto: amplio
                  ? '${c.formato.replaceAll('FORMATO ', '')}  ·  '
                        '${c == Cuenta.caja ? 'Caja' : 'Banco'}'
                  : c.formato.replaceAll('FORMATO ', ''),
              activa: cuenta == c,
              onTap: () => onCambiar(c),
            ),
        ],
      ),
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: activa ? Tokens.cromo : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                color: activa ? Tokens.cromoTexto : Tokens.texto2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El mes, en un menú agrupado por año.
///
/// Agrupado por año y no en una lista larga porque a los dos años de uso serían
/// veinticuatro renglones, y porque comparar el mismo mes de dos años es
/// justamente lo que se quiere poder hacer.
class _SelectorMes extends StatelessWidget {
  const _SelectorMes({
    required this.mes,
    required this.meses,
    required this.onElegir,
  });

  final DateTime mes;
  final List<DateTime> meses;
  final ValueChanged<DateTime> onElegir;

  @override
  Widget build(BuildContext context) {
    final porAnio = <int, List<DateTime>>{};
    for (final m in meses) {
      porAnio.putIfAbsent(m.year, () => []).add(m);
    }

    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Tokens.superficie),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(
          Tokens.cromo.withValues(alpha: 0.25),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radio),
            side: const BorderSide(color: Tokens.borde),
          ),
        ),
      ),
      menuChildren: [
        for (final anio in porAnio.keys)
          SubmenuButton(
            menuChildren: [
              for (final m in porAnio[anio]!)
                MenuItemButton(
                  onPressed: () => onElegir(m),
                  trailingIcon: m == mes
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Tokens.entro,
                        )
                      : null,
                  child: Text(Formato.capitalizar(Formato.mesSolo(m))),
                ),
            ],
            child: Text('$anio'),
          ),
      ],
      builder: (context, menu, _) => Container(
        height: 44,
        decoration: BoxDecoration(
          color: Tokens.superficie,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Tokens.borde),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => menu.isOpen ? menu.close() : menu.open(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: Tokens.texto2,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Formato.capitalizar(Formato.mes(mes)),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Tokens.texto,
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: Tokens.texto2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La franja que dice si el formato cuadra.
///
/// Es lo primero que mira un contador al recibir un libro de caja, así que va
/// arriba del documento y no escondida al pie.
class _Cuadre extends StatelessWidget {
  const _Cuadre({required this.libro});

  final LibroOficial libro;

  @override
  Widget build(BuildContext context) {
    final cuadra = libro.cuadra;
    final color = cuadra ? Tokens.entro : Tokens.salio;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Icon(
            cuadra ? Icons.verified_rounded : Icons.error_outline_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cuadra ? 'El formato cuadra' : 'El formato no cuadra',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cuadra
                      ? 'Las dos columnas suman '
                            '${Formato.soles(libro.totalDeudor / 100)}. '
                            'Al cierre queda '
                            '${Formato.soles(libro.saldoDeCierre / 100)}.'
                      : 'Deudor ${Formato.soles(libro.totalDeudor / 100)} '
                            'contra acreedor '
                            '${Formato.soles(libro.totalAcreedor / 100)}.',
                  style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
                ),
              ],
            ),
          ),
          if (libro.sinOperaciones)
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text(
                'Sin movimientos este mes',
                style: TextStyle(fontSize: 12, color: Tokens.texto2),
              ),
            ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.titulo, required this.bajada});

  final String titulo;
  final String bajada;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
          style: const TextStyle(fontSize: 13, color: Tokens.texto2),
        ),
      ],
    );
  }
}

/// Sin RUC ni razón social el formato sale con huecos. Se muestra igual: ver el
/// documento incompleto explica mejor qué falta que cualquier mensaje.
class _PerfilIncompleto extends StatelessWidget {
  const _PerfilIncompleto();

  @override
  Widget build(BuildContext context) {
    return _Aviso(
      icono: Icons.storefront_outlined,
      titulo: 'Faltan los datos del negocio',
      mensaje:
          'El encabezado del formato pide el RUC o DNI, la razón social y '
          'el saldo con que abre el período.',
      accion: 'Completar',
      onAccion: () => NegocioPagina.abrir(context),
    );
  }
}

class _FaltaBanco extends StatelessWidget {
  const _FaltaBanco();

  @override
  Widget build(BuildContext context) {
    return _Aviso(
      icono: Icons.account_balance_outlined,
      titulo: 'Falta la cuenta bancaria',
      mensaje:
          'El Formato 1.2 pide la entidad financiera y el código de la '
          'cuenta corriente.',
      accion: 'Agregar',
      onAccion: () => NegocioPagina.abrir(context),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.mensaje,
    required this.accion,
    required this.onAccion,
  });

  final IconData icono;
  final String titulo;
  final String mensaje;
  final String accion;
  final VoidCallback onAccion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tokens.marca.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        border: Border.all(color: Tokens.marca.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Tokens.marca.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icono, size: 19, color: Tokens.marca),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Tokens.texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mensaje,
                  style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onAccion,
            style: FilledButton.styleFrom(backgroundColor: Tokens.marca),
            child: Text(accion),
          ),
        ],
      ),
    );
  }
}

/// Los filtros de la vista del formato: entró o salió, buscar en la
/// descripción, y el monto. Filtran lo que se ve, no el documento: el cuadre,
/// el PDF y el CSV salen siempre completos, y la franja de abajo lo dice.
class _FiltrosVista extends StatelessWidget {
  const _FiltrosVista({
    required this.tipo,
    required this.texto,
    required this.monto,
    required this.montoEtiqueta,
    required this.onTipo,
    required this.onTexto,
    required this.onMonto,
    required this.onLimpiarMonto,
    required this.onLimpiar,
    required this.mostradas,
    required this.total,
  });

  final Tipo? tipo;
  final TextEditingController texto;
  final RangoMonto? monto;
  final String? montoEtiqueta;
  final ValueChanged<Tipo?> onTipo;
  final VoidCallback onTexto;
  final void Function(RangoMonto, String) onMonto;
  final VoidCallback onLimpiarMonto;
  final VoidCallback? onLimpiar;

  /// Cuántas operaciones pasan el filtro; null si no hay filtro.
  final int? mostradas;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              height: 44,
              child: TextField(
                controller: texto,
                onChanged: (_) => onTexto(),
                decoration: InputDecoration(
                  hintText: 'Buscar en la descripción o la cuenta…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Tokens.borde),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Tokens.borde),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(
                      color: Tokens.marca,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
            ),
            BotonFiltro(
              etiqueta: 'Entró / Salió',
              icono: Icons.swap_vert_rounded,
              valor: tipo?.etiqueta,
              onLimpiar: () => onTipo(null),
              opciones: [
                for (final t in Tipo.values)
                  OpcionFiltro(
                    texto: '${t.flecha}  ${t.etiqueta}',
                    elegida: tipo == t,
                    onPressed: () => onTipo(t),
                  ),
              ],
            ),
            FiltroMonto(
              actual: monto,
              etiqueta: montoEtiqueta,
              onElegir: onMonto,
              onLimpiar: onLimpiarMonto,
            ),
            if (onLimpiar != null)
              TextButton.icon(
                onPressed: onLimpiar,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Quitar filtros'),
              ),
          ],
        ),
        if (mostradas != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: Tokens.marcaSuave,
              borderRadius: BorderRadius.circular(Tokens.radio),
              border: Border.all(color: Tokens.marca.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_alt_rounded,
                  size: 18,
                  color: Tokens.marca,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vista filtrada: se muestran $mostradas de $total '
                    'operaciones. El cuadre, el PDF y el CSV salen siempre '
                    'completos.',
                    style: const TextStyle(fontSize: 12.5, color: Tokens.texto),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
