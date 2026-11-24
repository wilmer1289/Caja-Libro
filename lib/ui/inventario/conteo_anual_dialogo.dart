import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/acta_conteo.dart';
import '../../dominio/almacen.dart';
import '../../dominio/conteo_fisico.dart';
import '../../dominio/importe.dart';
import '../../dominio/mercaderia.dart';
import '../../estado/estado_caja.dart';
import 'acta_conteo_vista.dart';
import 'fila_conteo.dart';

/// Conteo de cierre anual. Lee el saldo del kardex al 31 de diciembre y deja
/// los ajustes con esa misma fecha para conservar la historia del período.
class ConteoAnualDialogo extends StatefulWidget {
  const ConteoAnualDialogo({super.key});

  static Future<void> abrir(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Tokens.cromo.withValues(alpha: .4),
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: const ConteoAnualDialogo(),
      ),
    ),
  );

  @override
  State<ConteoAnualDialogo> createState() => _ConteoAnualDialogoState();
}

class _ConteoAnualDialogoState extends State<ConteoAnualDialogo> {
  final Map<String, TextEditingController> _cantidades = {};
  final Map<String, TextEditingController> _costos = {};
  late int _anio;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _anio = DateTime.now().year - 1;
  }

  @override
  void dispose() {
    for (final controller in _cantidades.values) {
      controller.dispose();
    }
    for (final controller in _costos.values) {
      controller.dispose();
    }
    super.dispose();
  }

  DateTime get _fecha => DateTime(_anio, 12, 31);

  List<Mercaderia> _productosParaConteo(EstadoCaja estado) {
    final saldos = estado.kardex.saldosFinDeAnio(_anio);
    return estado.productos.where((producto) {
      final saldo = saldos[producto.id];
      return producto.activo ||
          (saldo?.cantidad ?? 0) != 0 ||
          (saldo?.costo ?? 0) != 0;
    }).toList();
  }

  TextEditingController _cantidad(String id, int inicial) =>
      _cantidades.putIfAbsent(
        id,
        () => TextEditingController(text: Cantidad.texto(inicial)),
      );

  TextEditingController _costo(String id) =>
      _costos.putIfAbsent(id, TextEditingController.new);

  void _cambiarAnio(int anio) {
    for (final controller in _cantidades.values) {
      controller.dispose();
    }
    for (final controller in _costos.values) {
      controller.dispose();
    }
    _cantidades.clear();
    _costos.clear();
    setState(() {
      _anio = anio;
      _error = null;
    });
  }

  int? _valorDiferencia(
    int diferencia,
    int cantidadSistema,
    int valorSistema,
    String productoId,
  ) {
    if (diferencia == 0) return 0;
    final unidades = diferencia.abs();
    if (diferencia < 0 && unidades > cantidadSistema) return null;
    if (cantidadSistema == 0) {
      final unitario = Importe.leer(_costo(productoId).text);
      if (diferencia < 0 || unitario == null || unitario <= 0) return null;
      final total =
          (BigInt.from(unidades) * BigInt.from(unitario) +
              BigInt.from(Cantidad.escala ~/ 2)) ~/
          BigInt.from(Cantidad.escala);
      return total > BigInt.from(Importe.maximoCentavos) ? null : total.toInt();
    }
    final total =
        (BigInt.from(valorSistema) * BigInt.from(unidades) +
            BigInt.from(cantidadSistema ~/ 2)) ~/
        BigInt.from(cantidadSistema);
    return total > BigInt.from(Importe.maximoCentavos) ? null : total.toInt();
  }

  List<FilaConteoFisico> _filas(EstadoCaja estado) {
    final saldos = estado.kardex.saldosFinDeAnio(_anio);
    return [
      for (final producto in _productosParaConteo(estado))
        if (Cantidad.leer(
              _cantidad(producto.id, saldos[producto.id]?.cantidad ?? 0).text,
            )
            case final int contado)
          if (_valorDiferencia(
                contado - (saldos[producto.id]?.cantidad ?? 0),
                saldos[producto.id]?.cantidad ?? 0,
                saldos[producto.id]?.costo ?? 0,
                producto.id,
              )
              case final int valor)
            FilaConteoFisico(
              productoId: producto.id,
              codigo: producto.codigo,
              producto: producto.nombre,
              unidad: producto.abreviaturaUnidad,
              cantidadSistema: saldos[producto.id]?.cantidad ?? 0,
              valorSistema: saldos[producto.id]?.costo ?? 0,
              cantidadContada: contado,
              diferenciaValor: contado < (saldos[producto.id]?.cantidad ?? 0)
                  ? -valor
                  : valor,
            ),
    ];
  }

  String? _validar(EstadoCaja estado) {
    final saldos = estado.kardex.saldosFinDeAnio(_anio);
    for (final producto in _productosParaConteo(estado)) {
      final sistema = saldos[producto.id]?.cantidad ?? 0;
      final contado = Cantidad.leer(_cantidad(producto.id, sistema).text);
      if (contado == null) {
        return 'Revisa la cantidad contada de ${producto.nombre}.';
      }
      if (producto.cantidadesEnteras && !Cantidad.esEntera(contado)) {
        return '${producto.nombre}: la unidad ${producto.abreviaturaUnidad} no admite decimales.';
      }
      final diferencia = contado - sistema;
      if (diferencia > 0 && sistema == 0) {
        final costo = Importe.leer(_costo(producto.id).text);
        if (costo == null || costo <= 0) {
          return 'Escribe el costo unitario del sobrante de ${producto.nombre}.';
        }
      }
      if (diferencia < 0 && -diferencia > sistema) {
        return 'El conteo de ${producto.nombre} no puede ser menor que cero.';
      }
    }
    if (_filas(estado).any((fila) => fila.tieneDiferencia) &&
        estado.mesCerrado(_fecha)) {
      return 'Diciembre de $_anio está cerrado: no se pueden registrar los ajustes anuales.';
    }
    return null;
  }

  Future<void> _confirmar(EstadoCaja estado) async {
    if (_guardando) return;
    final problema = _validar(estado);
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar conteo anual $_anio'),
        content: const Text(
          'Se registrará en el kardex, al 31 de diciembre, un ajuste por cada producto con diferencia y se generará el acta anual. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar y generar acta'),
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
      final filas = _filas(estado);
      for (final fila in filas.where((f) => f.tieneDiferencia)) {
        final diferencia = fila.diferenciaCantidad;
        final saldo = estado.kardex.saldo(fila.productoId, al: _fecha);
        final valor = _valorDiferencia(
          diferencia,
          saldo.cantidad,
          saldo.costo,
          fila.productoId,
        );
        if (valor == null) {
          throw ArgumentError('No se pudo valorar ${fila.producto}.');
        }
        await estado.registrarEnAlmacen(
          operacion: OperacionAlmacen.ajuste,
          mercaderiaId: fila.productoId,
          fecha: _fecha,
          cantidad: diferencia.abs(),
          entrada: diferencia > 0,
          costoTotal: diferencia > 0 && saldo.cantidad == 0 ? valor : null,
          glosa: 'Conteo anual al 31/12/$_anio',
          permitirDesactivado: true,
        );
      }
      final acta = ActaConteo(
        negocio: estado.negocio,
        conteo: ConteoFisico(fecha: _fecha, filas: filas),
        responsable: estado.usuario.trim(),
        registradaEn: DateTime.now(),
        anual: true,
      );
      if (mounted) {
        setState(() => _guardando = false);
        await ActaConteoVista.abrir(context, acta);
      }
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo completar el conteo anual. $e');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final productos = _productosParaConteo(estado);
    final saldos = estado.kardex.saldosFinDeAnio(_anio);
    final conteo = ConteoFisico(fecha: _fecha, filas: _filas(estado));
    final ultimoAnio = DateTime.now().year - 1;

    return Material(
      color: Tokens.superficie,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  color: Tokens.marcaOscura,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Conteo anual de inventario',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Tokens.texto,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _guardando ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Tokens.borde),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _anio,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Año del conteo anual',
                    isDense: true,
                  ),
                  items: [
                    for (var anio = ultimoAnio; anio >= ultimoAnio - 15; anio--)
                      DropdownMenuItem(value: anio, child: Text('$anio')),
                  ],
                  onChanged: _guardando
                      ? null
                      : (anio) {
                          if (anio != null) _cambiarAnio(anio);
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  'Saldos del kardex al 31/12/$_anio · '
                  'Sistema ${Formato.soles(conteo.valorSistema / 100)} · '
                  'Contado ${Formato.soles(conteo.valorContado / 100)} · '
                  'Diferencia ${Formato.soles(conteo.diferenciaValor / 100)}',
                  style: const TextStyle(fontSize: 12, color: Tokens.texto2),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Tokens.salio,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Tokens.borde),
          Expanded(
            child: productos.isEmpty
                ? const Center(
                    child: Text('Crea productos para iniciar el conteo.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: productos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final producto = productos[index];
                      final saldo = saldos[producto.id];
                      final cantidad = _cantidad(
                        producto.id,
                        saldo?.cantidad ?? 0,
                      );
                      final contado = Cantidad.leer(cantidad.text);
                      final diferencia = contado == null
                          ? null
                          : contado - (saldo?.cantidad ?? 0);
                      final valor = diferencia == null
                          ? null
                          : _valorDiferencia(
                              diferencia,
                              saldo?.cantidad ?? 0,
                              saldo?.costo ?? 0,
                              producto.id,
                            );
                      return FilaConteo(
                        producto: producto.nombre,
                        codigo: producto.codigo,
                        unidad: producto.abreviaturaUnidad,
                        stock: saldo?.cantidad ?? 0,
                        valor: saldo?.costo ?? 0,
                        cantidad: cantidad,
                        costoSobrante:
                            diferencia != null &&
                                diferencia > 0 &&
                                (saldo?.cantidad ?? 0) == 0
                            ? _costo(producto.id)
                            : null,
                        diferencia: diferencia,
                        diferenciaValor: valor == null
                            ? null
                            : diferencia! < 0
                            ? -valor
                            : valor,
                        onCambiar: () => setState(() => _error = null),
                      );
                    },
                  ),
          ),
          const Divider(height: 1, color: Tokens.borde),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _guardando ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: _guardando || productos.isEmpty
                      ? null
                      : () => _confirmar(estado),
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Confirmar conteo anual y generar acta'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
