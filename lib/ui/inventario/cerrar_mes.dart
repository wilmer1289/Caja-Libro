import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/cierre_mes.dart';
import '../../dominio/enums.dart';
import '../../estado/estado_caja.dart';

/// Resume el período y confirma su cierre usando la barrera común del estado.
class CerrarMes {
  static Future<void> abrir(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Tokens.cromo.withValues(alpha: .4),
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: _DialogoCerrarMes(),
      ),
    ),
  );
}

class _DialogoCerrarMes extends StatefulWidget {
  const _DialogoCerrarMes();

  @override
  State<_DialogoCerrarMes> createState() => _DialogoCerrarMesState();
}

class _DialogoCerrarMesState extends State<_DialogoCerrarMes> {
  late int _anio;
  late int _mes;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    final anterior = DateTime(ahora.year, ahora.month - 1);
    _anio = anterior.year;
    _mes = anterior.month;
  }

  String? _problema(EstadoCaja estado) => CierreMes.problemaAlCerrar(
    estado.cierres,
    _anio,
    _mes,
    hoy: DateTime.now(),
  );

  Future<void> _cerrar(EstadoCaja estado) async {
    final problema = _problema(estado);
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    final mes = CierreMes.nombreDe(_anio, _mes);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar mes'),
        content: Text(
          'Se cerrará $mes y todos los meses anteriores. No se podrán '
          'registrar operaciones con fechas de esos períodos. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar período'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final cierre = await estado.cerrarMes(_anio, _mes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Se cerró ${cierre.nombre}.')));
        Navigator.of(context).pop();
      }
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo cerrar el mes. $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final desde = DateTime(_anio, _mes);
    final hasta = DateTime(_anio, _mes + 1);
    final movimientos = estado.movimientos
        .where(
          (m) =>
              !m.eliminado &&
              !m.fecha.isBefore(desde) &&
              m.fecha.isBefore(hasta),
        )
        .toList();
    final entradas = movimientos
        .where((m) => m.tipo == Tipo.entro)
        .fold<int>(0, (total, m) => total + m.centavos);
    final salidas = movimientos
        .where((m) => m.tipo == Tipo.salio)
        .fold<int>(0, (total, m) => total + m.centavos);
    final lineas = estado.lineasAlmacen
        .where(
          (l) =>
              !l.anulada && !l.fecha.isBefore(desde) && l.fecha.isBefore(hasta),
        )
        .toList();
    final valorInventarioAlCierre = estado.kardex.productos.fold<int>(
      0,
      (total, id) =>
          total +
          estado.kardex
              .saldo(id, al: hasta.subtract(const Duration(days: 1)))
              .costo,
    );
    final cierreActual = _problema(estado);

    return Material(
      color: Tokens.superficie,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_clock_outlined,
                  color: Tokens.marcaOscura,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cerrar mes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Tokens.texto,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _guardando
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Tokens.borde),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _anio,
                    decoration: const InputDecoration(labelText: 'Año'),
                    items: [
                      for (
                        var year = DateTime.now().year;
                        year >= DateTime.now().year - 15;
                        year--
                      )
                        DropdownMenuItem(value: year, child: Text('$year')),
                    ],
                    onChanged: _guardando
                        ? null
                        : (v) => setState(() {
                            _anio = v ?? _anio;
                            _error = null;
                          }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _mes,
                    decoration: const InputDecoration(labelText: 'Mes'),
                    items: [
                      for (var month = 1; month <= 12; month++)
                        DropdownMenuItem(
                          value: month,
                          child: Text(
                            CierreMes.nombreDe(2000, month).split(' ').first,
                          ),
                        ),
                    ],
                    onChanged: _guardando
                        ? null
                        : (v) => setState(() {
                            _mes = v ?? _mes;
                            _error = null;
                          }),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Tokens.fondo,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Tokens.borde),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          CierreMes.nombreDe(_anio, _mes),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Tokens.texto,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DatoCierre(
                          etiqueta: 'Movimientos de caja',
                          valor: '${movimientos.length}',
                        ),
                        _DatoCierre(
                          etiqueta: 'Entradas',
                          valor: Formato.soles(entradas / 100),
                        ),
                        _DatoCierre(
                          etiqueta: 'Salidas',
                          valor: Formato.soles(salidas / 100),
                        ),
                        _DatoCierre(
                          etiqueta: 'Movimientos de inventario',
                          valor: '${lineas.length}',
                        ),
                        _DatoCierre(
                          etiqueta: 'Valor del inventario al cierre',
                          valor: Formato.soles(valorInventarioAlCierre / 100),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Al cerrar este período también quedan cerrados los anteriores. '
                    'El sistema no permitirá registrar después operaciones con '
                    'fechas de este mes ni de los anteriores.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Tokens.texto2,
                    ),
                  ),
                  if (cierreActual != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      cierreActual,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Tokens.salio,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Tokens.salio,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Tokens.borde),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                const Spacer(),
                OutlinedButton(
                  onPressed: _guardando
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _guardando || cierreActual != null
                      ? null
                      : () => _cerrar(estado),
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Text('Cerrar período'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatoCierre extends StatelessWidget {
  const _DatoCierre({required this.etiqueta, required this.valor});

  final String etiqueta, valor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: const TextStyle(fontSize: 12, color: Tokens.texto2),
          ),
        ),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Tokens.texto,
          ),
        ),
      ],
    ),
  );
}
