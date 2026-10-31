import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/export/abrir_archivo.dart';
import '../../datos/export/exportador.dart';
import '../../datos/export/exportador_pdf.dart';
import '../../dominio/inventario.dart';
import '../../dominio/libro_diario.dart';
import '../../dominio/periodo.dart';
import '../../estado/estado_caja.dart';
import '../negocio/negocio_pagina.dart';
import '../historial/barra_filtros.dart';
import '../widgets/aparece.dart';
import '../widgets/esqueleto.dart';
import 'panel_mercaderias.dart';
import 'resumen_libro.dart';
import 'tarjeta_operacion.dart';
import 'entender_codigos.dart';
import 'entender_pasos.dart';

/// El Libro Diario (Formato 5.1): cada movimiento convertido en sus asientos.
///
/// Esta página sólo elige el período y pide el libro a [EstadoCaja]; el
/// dibujo está en [LibroDiarioVista], que no sabe de estado y por eso se
/// puede probar con los asientos de los 4 ejemplos.
class LibroDiarioPagina extends StatefulWidget {
  const LibroDiarioPagina({super.key});

  @override
  State<LibroDiarioPagina> createState() => _LibroDiarioPaginaState();
}

class _LibroDiarioPaginaState extends State<LibroDiarioPagina> {
  /// El atajo elegido; null si el rango es a medida.
  Periodo? _periodo = Periodo.mes;
  DateTimeRange? _aMedida;

  (DateTime, DateTime) get _rango {
    final medida = _aMedida;
    if (_periodo == null && medida != null) return (medida.start, medida.end);
    return (_periodo ?? Periodo.mes).rango();
  }

  Future<void> _elegirFechas() async {
    final (desde, hasta) = _rango;
    final elegido = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => DialogoRango(
        inicial: DateTimeRange(start: desde, end: hasta),
      ),
    );
    if (elegido == null || !mounted) return;
    setState(() {
      _periodo = null;
      _aMedida = elegido;
    });
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

    final (desde, hasta) = _rango;
    return LibroDiarioVista(
      libro: estado.libroDiario(desde: desde, hasta: hasta),
      inventario: estado.inventarioHasta(fecha: hasta),
      periodo: _periodo,
      onPeriodo: (p) => setState(() => _periodo = p),
      onElegirFechas: _elegirFechas,
    );
  }
}

/// El Libro Diario ya armado, listo para dibujar. Celular: una columna.
/// Escritorio: las operaciones a la izquierda y el panel de mercaderías al
/// lado.
class LibroDiarioVista extends StatelessWidget {
  const LibroDiarioVista({
    super.key,
    required this.libro,
    required this.inventario,
    required this.periodo,
    required this.onPeriodo,
    required this.onElegirFechas,
  });

  final LibroDiario libro;
  final InventarioMercaderias inventario;

  /// El atajo activo; null cuando el rango es a medida.
  final Periodo? periodo;
  final ValueChanged<Periodo> onPeriodo;
  final VoidCallback onElegirFechas;

  /// A partir de este ancho el panel de mercaderías pasa al costado.
  static const anchoLateral = 860.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        final lateral = medidas.maxWidth >= anchoLateral;
        final margen = medidas.maxWidth >= 720 ? 24.0 : 16.0;

        final operaciones = _Operaciones(libro: libro);
        final panel = PanelMercaderias(
          inventario: inventario,
          hasta: libro.hasta,
        );

        return ListView(
          padding: EdgeInsets.fromLTRB(
            margen,
            margen,
            margen,
            // Aire para que los botones flotantes del celular no tapen la
            // última tarjeta.
            lateral ? margen : 120,
          ),
          children: [
            SelectorPeriodo(
              periodo: periodo,
              desde: libro.desde,
              hasta: libro.hasta,
              onPeriodo: onPeriodo,
              onElegirFechas: onElegirFechas,
            ),
            const SizedBox(height: 12),
            _AccionesDiario(libro: libro),
            const SizedBox(height: 12),
            const EntenderPasos(),
            const SizedBox(height: 8),
            EntenderCodigos(libro: libro),
            const SizedBox(height: 16),
            Aparece(child: ResumenLibro(libro: libro)),
            const SizedBox(height: 16),
            if (lateral)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: operaciones),
                  const SizedBox(width: 16),
                  SizedBox(width: 340, child: panel),
                ],
              )
            else ...[
              panel,
              const SizedBox(height: 20),
              operaciones,
            ],
          ],
        );
      },
    );
  }
}

class _AccionesDiario extends StatelessWidget {
  const _AccionesDiario({required this.libro});
  final LibroDiario libro;

  Future<void> _exportar(BuildContext context, {required bool pdf}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (libro.negocio.documento.trim().isEmpty ||
        libro.negocio.razonSocial.trim().isEmpty) {
      final completar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Faltan los datos del negocio'),
          content: const Text(
            'El Libro Diario necesita el RUC o DNI y la razón social para completar su encabezado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Completar'),
            ),
          ],
        ),
      );
      if (completar == true && context.mounted) {
        await NegocioPagina.abrir(context);
      }
      return;
    }
    final desbalanceados = libro.asientos.where((a) => !a.cuadra).toList();
    if (desbalanceados.isNotEmpty) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hay asientos que no cuadran'),
          content: Text(
            'Correlativos: ${desbalanceados.map((a) => a.numero).join(', ')}. Puedes revisar los datos o exportar de todos modos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Exportar'),
            ),
          ],
        ),
      );
      if (continuar != true || !context.mounted) return;
    }
    try {
      if (kIsWeb) {
        if (!pdf) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('La descarga CSV no está disponible en la web.'),
            ),
          );
          return;
        }
        await Printing.sharePdf(
          bytes: await ExportadorPdf.diario(libro),
          filename: ExportadorPdf.nombreDiario(libro),
        );
        if (context.mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Guardado en tu carpeta de descargas'),
            ),
          );
        }
        return;
      }
      final ruta = pdf
          ? await ExportadorPdf.guardar(
              await ExportadorPdf.diario(libro),
              ExportadorPdf.nombreDiario(libro),
            )
          : await Exportador.guardarDiario(libro);
      if (!context.mounted) return;
      messenger.showSnackBar(
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
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('No se pudo exportar. $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: () => _exportar(context, pdf: true),
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('PDF'),
      ),
      OutlinedButton.icon(
        onPressed: () => _exportar(context, pdf: false),
        icon: const Icon(Icons.table_view_outlined),
        label: const Text('CSV'),
      ),
    ],
  );
}

class _Operaciones extends StatelessWidget {
  const _Operaciones({required this.libro});

  final LibroDiario libro;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              const Text(
                'Operaciones',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Tokens.texto,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                libro.asientos.length == 1
                    ? '1 operación'
                    : '${libro.asientos.length} operaciones',
                style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
              ),
            ],
          ),
        ),
        if (libro.vacio)
          const _SinOperaciones()
        else
          for (var i = 0; i < libro.asientos.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaOperacion(
                key: ValueKey('operacion-${libro.asientos[i].numero}'),
                asiento: libro.asientos[i],
              ),
            ),
      ],
    );
  }
}

class _SinOperaciones extends StatelessWidget {
  const _SinOperaciones();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Tokens.superficie,
        borderRadius: BorderRadius.circular(Tokens.radioGrande),
        border: Border.all(color: Tokens.borde),
      ),
      child: const Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 32, color: Tokens.texto2),
          SizedBox(height: 10),
          Text(
            'Sin operaciones en este período',
            style: TextStyle(fontWeight: FontWeight.w700, color: Tokens.texto),
          ),
          SizedBox(height: 4),
          Text(
            'Prueba con otro período o con un rango de fechas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Tokens.texto2),
          ),
        ],
      ),
    );
  }
}

/// Los atajos de período (Hoy, Esta semana…) y el rango a medida, en una fila
/// que se desliza de costado en el celular.
class SelectorPeriodo extends StatelessWidget {
  const SelectorPeriodo({
    super.key,
    required this.periodo,
    required this.desde,
    required this.hasta,
    required this.onPeriodo,
    required this.onElegirFechas,
  });

  final Periodo? periodo;
  final DateTime desde;
  final DateTime hasta;
  final ValueChanged<Periodo> onPeriodo;
  final VoidCallback onElegirFechas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in Periodo.values) ...[
                _Chip(
                  texto: p.etiqueta,
                  activo: periodo == p,
                  onTap: () => onPeriodo(p),
                ),
                const SizedBox(width: 8),
              ],
              _Chip(
                texto: 'Elegir fechas',
                icono: Icons.date_range_rounded,
                activo: periodo == null,
                onTap: onElegirFechas,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Del ${Formato.fecha(desde)} al ${Formato.fecha(hasta)}',
            style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.texto,
    required this.activo,
    required this.onTap,
    this.icono,
  });

  final String texto;
  final bool activo;
  final VoidCallback onTap;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final color = activo ? Tokens.cromoTexto : Tokens.texto2;
    return Material(
      color: activo ? Tokens.cromo : Tokens.superficie,
      shape: StadiumBorder(
        side: BorderSide(color: activo ? Tokens.cromo : Tokens.borde),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                texto,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
