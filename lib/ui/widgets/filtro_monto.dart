import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/importe.dart';
import '../historial/barra_filtros.dart';

/// Un rango de montos, en centavos. Null en un extremo = sin límite.
typedef RangoMonto = ({int? min, int? max});

bool dentroDelRango(RangoMonto rango, int centavos) =>
    (rango.min == null || centavos >= rango.min!) &&
    (rango.max == null || centavos <= rango.max!);

String etiquetaRango(RangoMonto r) {
  String s(int c) => Formato.soles(c / 100).replaceAll('.00', '');
  if (r.min == null && r.max != null) return 'Hasta ${s(r.max!)}';
  if (r.min != null && r.max == null) return 'Desde ${s(r.min!)}';
  return '${s(r.min ?? 0)} a ${s(r.max ?? 0)}';
}

/// El botón "Monto" de los filtros: unos rangos de un toque —pensados para
/// una bodega, y con los dos umbrales que importan: S/ 700 y S/ 2,000— y
/// "Otro rango…" para escribir uno a medida.
class FiltroMonto extends StatelessWidget {
  const FiltroMonto({
    super.key,
    required this.actual,
    required this.etiqueta,
    required this.onElegir,
    required this.onLimpiar,
  });

  final RangoMonto? actual;
  final String? etiqueta;
  final void Function(RangoMonto rango, String etiqueta) onElegir;
  final VoidCallback onLimpiar;

  static const rapidos = <RangoMonto>[
    (min: null, max: 5000),
    (min: 5000, max: 20000),
    (min: 20000, max: 70000),
    (min: 70000, max: 200000),
    (min: 200000, max: null),
  ];

  @override
  Widget build(BuildContext context) {
    return BotonFiltro(
      etiqueta: 'Monto',
      icono: Icons.payments_outlined,
      valor: actual == null ? null : etiqueta,
      onLimpiar: onLimpiar,
      opciones: [
        for (final r in rapidos)
          OpcionFiltro(
            texto: etiquetaRango(r),
            elegida: actual == r,
            onPressed: () => onElegir(r, etiquetaRango(r)),
          ),
        OpcionFiltro(
          texto: 'Otro rango…',
          elegida: actual != null && !rapidos.contains(actual),
          onPressed: () async {
            final r = await pedirRangoMonto(context, inicial: actual);
            if (r != null) onElegir(r, etiquetaRango(r));
          },
        ),
      ],
    );
  }
}

/// Una ventanita con "desde" y "hasta".
Future<RangoMonto?> pedirRangoMonto(
  BuildContext context, {
  RangoMonto? inicial,
}) {
  return showDialog<RangoMonto>(
    context: context,
    barrierColor: Tokens.cromo.withValues(alpha: 0.35),
    builder: (_) => _RangoDialogo(inicial: inicial),
  );
}

class _RangoDialogo extends StatefulWidget {
  const _RangoDialogo({this.inicial});

  final RangoMonto? inicial;

  @override
  State<_RangoDialogo> createState() => _RangoDialogoState();
}

class _RangoDialogoState extends State<_RangoDialogo> {
  late final _desde = TextEditingController(text: _texto(widget.inicial?.min));
  late final _hasta = TextEditingController(text: _texto(widget.inicial?.max));
  String? _error;

  static String _texto(int? c) => c == null ? '' : (c / 100).toStringAsFixed(2);

  @override
  void dispose() {
    _desde.dispose();
    _hasta.dispose();
    super.dispose();
  }

  void _aplicar() {
    final d = _desde.text.trim().isEmpty ? null : Importe.leer(_desde.text);
    final h = _hasta.text.trim().isEmpty ? null : Importe.leer(_hasta.text);
    if ((_desde.text.trim().isNotEmpty && d == null) ||
        (_hasta.text.trim().isNotEmpty && h == null)) {
      setState(() => _error = 'Algún monto no se entiende. Ejemplo: 25.50');
      return;
    }
    if (d == null && h == null) {
      setState(() => _error = 'Escribe al menos uno de los dos');
      return;
    }
    if (d != null && h != null && d > h) {
      setState(() => _error = '"Desde" no puede ser mayor que "hasta"');
      return;
    }
    Navigator.of(context).pop((min: d, max: h));
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String etiqueta) => InputDecoration(
      labelText: etiqueta,
      prefixText: 'S/ ',
      hintText: '0.00',
    );
    final formato = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    return AlertDialog(
      title: const Text('Filtrar por monto'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _desde,
                    autofocus: true,
                    inputFormatters: formato,
                    decoration: deco('Desde'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hasta,
                    inputFormatters: formato,
                    decoration: deco('Hasta'),
                    onSubmitted: (_) => _aplicar(),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12.5, color: Tokens.salio),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _aplicar, child: const Text('Aplicar')),
      ],
    );
  }
}
