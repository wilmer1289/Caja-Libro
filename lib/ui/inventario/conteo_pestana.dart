import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/acta_conteo.dart';
import '../../dominio/almacen.dart';
import '../../dominio/conteo_fisico.dart';
import '../../dominio/importe.dart';
import '../../estado/estado_caja.dart';
import 'acta_conteo_vista.dart';
import 'conteo_anual_dialogo.dart';
import 'fila_conteo.dart';

/// Conteo físico de todos los productos activos y ajuste de las diferencias.
class ConteoPestana extends StatefulWidget {
  const ConteoPestana({super.key});

  @override
  State<ConteoPestana> createState() => _ConteoPestanaState();
}

class _ConteoPestanaState extends State<ConteoPestana> {
  final Map<String, TextEditingController> _cantidades = {};
  final Map<String, TextEditingController> _costosSobrante = {};
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _cantidades.values) {
      c.dispose();
    }
    for (final c in _costosSobrante.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _cantidad(String id, int stock) =>
      _cantidades.putIfAbsent(
        id,
        () => TextEditingController(text: Cantidad.texto(stock)),
      );

  TextEditingController _costo(String id) =>
      _costosSobrante.putIfAbsent(id, TextEditingController.new);

  int? _valorDiferencia(EstadoCaja estado, String id, int diferencia) {
    if (diferencia == 0) return 0;
    final saldo = estado.kardex.saldo(id);
    final cantidad = diferencia.abs();
    if (diferencia < 0) {
      if (cantidad > saldo.cantidad) return null;
      return estado.kardex.costoDeSalida(id, cantidad, DateTime.now());
    }
    if (saldo.cantidad == 0) {
      final unitario = Importe.leer(_costo(id).text);
      if (unitario == null || unitario <= 0) return null;
      final total =
          (BigInt.from(cantidad) * BigInt.from(unitario) +
              BigInt.from(Cantidad.escala ~/ 2)) ~/
          BigInt.from(Cantidad.escala);
      if (total > BigInt.from(Importe.maximoCentavos)) return null;
      return total.toInt();
    }
    final total =
        (BigInt.from(saldo.costo) * BigInt.from(cantidad) +
            BigInt.from(saldo.cantidad ~/ 2)) ~/
        BigInt.from(saldo.cantidad);
    if (total > BigInt.from(Importe.maximoCentavos)) return null;
    return total.toInt();
  }

  ConteoFisico _previsualizar(EstadoCaja estado) {
    final productos = estado.productosActivos;
    return ConteoFisico(
      fecha: DateTime.now(),
      filas: [
        for (final producto in productos)
          if (Cantidad.leer(
                _cantidad(producto.id, estado.stockDe(producto.id)).text,
              )
              case final int contado)
            if (_valorDiferencia(
                  estado,
                  producto.id,
                  contado - estado.stockDe(producto.id),
                )
                case final int valor)
              FilaConteoFisico(
                productoId: producto.id,
                codigo: producto.codigo,
                producto: producto.nombre,
                unidad: producto.abreviaturaUnidad,
                cantidadSistema: estado.stockDe(producto.id),
                valorSistema: estado.kardex.saldo(producto.id).costo,
                cantidadContada: contado,
                diferenciaValor: contado >= estado.stockDe(producto.id)
                    ? valor
                    : -valor,
              ),
      ],
    );
  }

  String? _validar(EstadoCaja estado) {
    for (final producto in estado.productosActivos) {
      final cantidad = Cantidad.leer(
        _cantidad(producto.id, estado.stockDe(producto.id)).text,
      );
      if (cantidad == null) {
        return 'Revisa la cantidad contada de ${producto.nombre}.';
      }
      if (producto.cantidadesEnteras && !Cantidad.esEntera(cantidad)) {
        return '${producto.nombre}: la unidad ${producto.abreviaturaUnidad} no admite decimales.';
      }
      final diferencia = cantidad - estado.stockDe(producto.id);
      if (diferencia > 0 && estado.kardex.saldo(producto.id).cantidad == 0) {
        final costo = Importe.leer(_costo(producto.id).text);
        if (costo == null || costo <= 0) {
          return 'Escribe el costo unitario del sobrante de ${producto.nombre}.';
        }
      }
      if (diferencia < 0 && -diferencia > estado.stockDe(producto.id)) {
        return 'El conteo de ${producto.nombre} no puede ser menor que cero.';
      }
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
    final fecha = DateTime.now();
    if (estado.mesCerrado(fecha)) {
      setState(
        () => _error =
            'El mes actual está cerrado: no se puede registrar el conteo.',
      );
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar conteo'),
        content: const Text(
          'Se registrará un ajuste por cada producto con diferencia y se generará el acta. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar y ajustar'),
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
      final filas = <FilaConteoFisico>[];
      for (final producto in estado.productosActivos) {
        final sistema = estado.stockDe(producto.id);
        final contado = Cantidad.leer(_cantidad(producto.id, sistema).text)!;
        final diferencia = contado - sistema;
        final saldo = estado.kardex.saldo(producto.id);
        int? valor;
        if (diferencia > 0 && saldo.cantidad == 0) {
          final unitario = Importe.leer(_costo(producto.id).text)!;
          final total =
              (BigInt.from(diferencia) * BigInt.from(unitario) +
                  BigInt.from(Cantidad.escala ~/ 2)) ~/
              BigInt.from(Cantidad.escala);
          valor = total.toInt();
        }
        final costoDiferencia = diferencia == 0
            ? 0
            : _valorDiferencia(estado, producto.id, diferencia)!;
        filas.add(
          FilaConteoFisico(
            productoId: producto.id,
            codigo: producto.codigo,
            producto: producto.nombre,
            unidad: producto.abreviaturaUnidad,
            cantidadSistema: sistema,
            valorSistema: saldo.costo,
            cantidadContada: contado,
            diferenciaValor: diferencia < 0
                ? -costoDiferencia
                : costoDiferencia,
          ),
        );
        if (diferencia != 0) {
          await estado.registrarEnAlmacen(
            operacion: OperacionAlmacen.ajuste,
            mercaderiaId: producto.id,
            fecha: fecha,
            cantidad: diferencia.abs(),
            entrada: diferencia > 0,
            costoTotal: valor,
            glosa: 'Conteo físico de inventario',
          );
        }
      }
      final acta = ActaConteo(
        negocio: estado.negocio,
        conteo: ConteoFisico(fecha: fecha, filas: filas),
        responsable: estado.usuario.trim(),
        registradaEn: DateTime.now(),
      );
      if (mounted) {
        setState(() => _guardando = false);
        await ActaConteoVista.abrir(context, acta);
        for (final producto in estado.productosActivos) {
          _cantidades[producto.id]?.text = Cantidad.texto(
            estado.stockDe(producto.id),
          );
          _costosSobrante[producto.id]?.clear();
        }
        setState(() {});
      }
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo completar el conteo. $e');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final productos = estado.productosActivos;
    final conteo = _previsualizar(estado);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: LayoutBuilder(
            builder: (context, medidas) {
              final confirmar = FilledButton.icon(
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
                label: const Text('Confirmar conteo y generar acta'),
              );
              final resumen = Text(
                'Sistema ${Formato.soles(conteo.valorSistema / 100)} · '
                'Contado ${Formato.soles(conteo.valorContado / 100)} · '
                'Diferencia ${Formato.soles(conteo.diferenciaValor / 100)}',
                style: const TextStyle(fontSize: 12, color: Tokens.texto2),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  medidas.maxWidth < 650
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Conteo físico',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Tokens.texto,
                              ),
                            ),
                            const SizedBox(height: 6),
                            resumen,
                            const SizedBox(height: 10),
                            confirmar,
                          ],
                        )
                      : Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Conteo físico',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: Tokens.texto,
                                ),
                              ),
                            ),
                            resumen,
                            const SizedBox(width: 14),
                            confirmar,
                          ],
                        ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _guardando
                          ? null
                          : () => ConteoAnualDialogo.abrir(context),
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Conteo anual al 31 de diciembre'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
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
              );
            },
          ),
        ),
        const Divider(height: 1, color: Tokens.borde),
        Expanded(
          child: productos.isEmpty
              ? const Center(
                  child: Text(
                    'Crea productos para iniciar el conteo.',
                    style: TextStyle(color: Tokens.texto2),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: productos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final producto = productos[index];
                    final saldo = estado.kardex.saldo(producto.id);
                    final cantidadController = _cantidad(
                      producto.id,
                      saldo.cantidad,
                    );
                    final cantidad = Cantidad.leer(cantidadController.text);
                    final delta = cantidad == null
                        ? null
                        : cantidad - saldo.cantidad;
                    final costo = delta == null
                        ? null
                        : _valorDiferencia(estado, producto.id, delta.abs()) ==
                              null
                        ? null
                        : _valorDiferencia(estado, producto.id, delta);
                    return FilaConteo(
                      producto: producto.nombre,
                      codigo: producto.codigo,
                      unidad: producto.abreviaturaUnidad,
                      stock: saldo.cantidad,
                      valor: saldo.costo,
                      cantidad: cantidadController,
                      costoSobrante:
                          delta != null && delta > 0 && saldo.cantidad == 0
                          ? _costo(producto.id)
                          : null,
                      diferencia: delta,
                      diferenciaValor: costo,
                      onCambiar: () => setState(() => _error = null),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
