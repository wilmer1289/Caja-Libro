import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/tema.dart';
import '../../estado/estado_caja.dart';
import 'campo_costo.dart';
import 'nueva_mercaderia.dart';

/// El paso "¿Qué mercadería?" del registro.
///
/// En una compra el tipo es obligatorio: de ahí sale el saldo que después se
/// descuenta al vender. En una venta se elige el tipo o "No es mercadería",
/// porque también se cobran servicios. Con un tipo elegido aparece el costo,
/// que es obligatorio y se compara con el saldo disponible sin bloquear.
class PasoMercaderia extends StatelessWidget {
  const PasoMercaderia({
    super.key,
    required this.venta,
    required this.seleccionada,
    required this.esServicio,
    required this.costo,
    required this.fecha,
    required this.onSeleccionar,
    required this.onServicio,
    required this.onCosto,
    this.errorTipo,
    this.errorCosto,
  });

  final bool venta;
  final String? seleccionada;
  final bool esServicio;
  final TextEditingController costo;
  final DateTime fecha;
  final ValueChanged<String?> onSeleccionar;
  final ValueChanged<bool> onServicio;
  final VoidCallback onCosto;
  final String? errorTipo;
  final String? errorCosto;

  Future<void> _agregar(BuildContext context) async {
    final nueva = await NuevaMercaderiaDialogo.abrir(context);
    if (context.mounted && nueva != null) onSeleccionar(nueva.id);
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final sinTipo = seleccionada == null && !(venta && esServicio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Tokens.marcaSuave,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: Tokens.marcaOscura,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '¿Qué mercadería?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Tokens.texto,
                    ),
                  ),
                  Text(
                    venta
                        ? 'Elige qué vendiste, o marca que es un servicio.'
                        : 'Elige qué compraste para llevar su saldo.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Tokens.texto2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (venta) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('No es mercadería'),
                selected: esServicio,
                // Se puede volver a tocar para elegir un tipo después.
                onSelected: onServicio,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (!venta || !esServicio) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('mercaderia-$seleccionada-$esServicio'),
            initialValue: seleccionada,
            isExpanded: true,
            menuMaxHeight: 280,
            decoration: InputDecoration(
              labelText: 'Tipo de mercadería',
              hintText: venta
                  ? 'Elige el tipo o "No es mercadería"'
                  : 'Elige el tipo',
              errorText: sinTipo && errorTipo != null ? errorTipo : null,
            ),
            items: [
              for (final m in estado.mercaderias)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(m.nombre, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onSeleccionar,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Tooltip(
              message: 'Agregar mercadería',
              child: TextButton.icon(
                key: const ValueKey('agregar-mercaderia'),
                onPressed: () => _agregar(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nuevo tipo'),
              ),
            ),
          ),
        ],
        if (venta && esServicio)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Tokens.fondo,
              borderRadius: BorderRadius.circular(Tokens.radio),
              border: Border.all(color: Tokens.borde),
            ),
            child: const Row(
              children: [
                Icon(Icons.storefront_outlined, size: 18, color: Tokens.texto2),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'No se descuenta mercadería ni se pide costo.',
                    style: TextStyle(fontSize: 12, color: Tokens.texto2),
                  ),
                ),
              ],
            ),
          ),
        if (venta && seleccionada != null && !esServicio) ...[
          const SizedBox(height: 4),
          CampoCosto(
            mercaderiaId: seleccionada!,
            fecha: fecha,
            costo: costo,
            error: errorCosto,
            onCambio: onCosto,
          ),
        ],
      ],
    );
  }
}
