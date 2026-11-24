import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/almacen.dart';
import '../../dominio/mercaderia.dart';
import '../../dominio/registro_inventario.dart';

/// El modo «Entender» del kardex: de dónde salió cada número de una fila.
///
/// Los pasos se arman aparte de la ventana para poder probarlos: son la
/// misma cuenta que hace el motor del kardex, dicha en palabras.
class EntenderKardex {
  EntenderKardex._();

  // Con espacio que no se corta: "S/" nunca queda solo al final de una línea.
  static String _soles(int centavos) =>
      Formato.soles(centavos / 100).replaceFirst('S/ ', 'S/ ');
  static String _unit(double? soles) =>
      'S/ ${RegistroInventario.unitario(soles)}';

  /// La explicación de una fila. `anterior` es la fila de arriba: su saldo
  /// es lo que había antes de esta operación.
  static List<String> pasos(
    FilaRegistro f, {
    FilaRegistro? anterior,
    required Mercaderia producto,
  }) {
    final u = producto.abreviaturaUnidad;
    String cant(int milesimas) => '${Cantidad.texto(milesimas)} $u';
    final habiaCantidad = anterior?.saldoCantidad ?? 0;
    final habiaCosto = anterior?.saldoCosto ?? 0;
    final linea = f.fila?.linea;
    final operacion = linea?.operacion;
    final quedan =
        'Quedan ${cant(f.saldoCantidad)} por ${_soles(f.saldoCosto)}'
        '${f.saldoCantidad == 0 ? '' : ', a ${_unit(f.saldoUnitario)} cada una'}.';

    if (f.arrastrado) {
      return [
        'Es lo que quedó del período anterior: ${cant(f.saldoCantidad)} por '
            '${_soles(f.saldoCosto)}.',
        'El formato de cada período empieza con ese saldo, como saldo '
            'inicial (operación 16).',
      ];
    }
    if (operacion == OperacionAlmacen.saldoInicial) {
      return [
        'Es el inventario inicial: ${cant(f.saldoCantidad)} a '
            '${_unit(f.saldoUnitario)} = ${_soles(f.saldoCosto)}.',
        'Desde aquí corre el kardex. No cuenta como entrada del período: va '
            'sólo en el saldo.',
      ];
    }

    final pasos = <String>[
      'Antes había ${cant(habiaCantidad)} por ${_soles(habiaCosto)}'
          '${habiaCantidad == 0 ? '' : ' (${_unit(anterior?.saldoUnitario)} cada una)'}.',
    ];

    if (f.entradaCantidad != null) {
      final entra = f.entradaCantidad!;
      final costo = f.entradaCosto!;
      switch (operacion) {
        case OperacionAlmacen.compra:
          pasos.add(
            'Entran ${cant(entra)} por ${_soles(costo)}: el valor sin IGV de '
            'la compra, ya con su descuento.',
          );
        case OperacionAlmacen.devolucionRecibida:
          pasos.add(
            'El cliente devuelve ${cant(entra)}. Vuelven al mismo costo con '
            'que salieron en su venta: ${_soles(costo)}.',
          );
        case OperacionAlmacen.ajuste when habiaCantidad > 0:
          pasos.add(
            'Sobran ${cant(entra)} en el conteo. Entran al costo promedio del '
            'momento: ${Cantidad.texto(entra)} × ${_soles(habiaCosto)} ÷ '
            '${Cantidad.texto(habiaCantidad)} = ${_soles(costo)}.',
          );
        default:
          pasos.add('Entran ${cant(entra)} por ${_soles(costo)}.');
      }
      pasos.add(
        'Ahora hay ${Cantidad.texto(habiaCantidad)} + ${Cantidad.texto(entra)} '
        '= ${cant(f.saldoCantidad)} por ${_soles(habiaCosto)} + '
        '${_soles(costo)} = ${_soles(f.saldoCosto)}.',
      );
      pasos.add(
        'El promedio nuevo es ${_soles(f.saldoCosto)} ÷ '
        '${Cantidad.texto(f.saldoCantidad)} = ${_unit(f.saldoUnitario)}.',
      );
      return pasos;
    }

    final sale = f.salidaCantidad!;
    final costo = f.salidaCosto!;
    final motivo = switch (operacion) {
      OperacionAlmacen.venta => 'Se venden',
      OperacionAlmacen.merma => 'Se pierden por merma',
      OperacionAlmacen.desmedro => 'Se dan de baja por desmedro',
      OperacionAlmacen.ajuste => 'Faltan en el conteo',
      OperacionAlmacen.devolucionEntregada => 'Se devuelven al proveedor',
      _ => 'Salen',
    };
    if (operacion == OperacionAlmacen.devolucionEntregada) {
      pasos.add(
        '$motivo ${cant(sale)}. Salen al costo de su compra, no al promedio: '
        '${_soles(costo)}.',
      );
    } else if (sale == habiaCantidad) {
      pasos.add(
        '$motivo ${cant(sale)}: todo lo que había. Sale todo el saldo, '
        '${_soles(costo)}, sin redondear.',
      );
    } else {
      pasos.add(
        '$motivo ${cant(sale)}. Salen al costo promedio: '
        '${Cantidad.texto(sale)} × ${_soles(habiaCosto)} ÷ '
        '${Cantidad.texto(habiaCantidad)} = ${_soles(costo)}, redondeado al '
        'centavo.',
      );
    }
    if (operacion == OperacionAlmacen.venta && linea?.importe != null) {
      pasos.add(
        'El precio de venta (${_soles(linea!.importe!)} sin IGV) no entra '
        'al kardex: aquí va el costo. La diferencia es la ganancia de la '
        'venta.',
      );
    }
    pasos.add(quedan);
    if (operacion != OperacionAlmacen.devolucionEntregada &&
        f.saldoCantidad > 0) {
      pasos.add('El promedio no cambia al salir: sólo cambia al entrar.');
    }
    if ((linea?.glosa ?? '').isNotEmpty) {
      pasos.add('Motivo anotado: ${linea!.glosa}.');
    }
    return pasos;
  }

  static Future<void> abrir(
    BuildContext context,
    FilaRegistro fila, {
    FilaRegistro? anterior,
    required Mercaderia producto,
  }) {
    final pasos = EntenderKardex.pasos(
      fila,
      anterior: anterior,
      producto: producto,
    );
    final titulo = fila.arrastrado
        ? 'Saldo del período anterior'
        : '${fila.nombreOperacion} · ${Formato.fecha(fila.fecha)}';
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.lightbulb_outline_rounded,
              color: Tokens.marca,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(titulo, style: const TextStyle(fontSize: 17))),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < pasos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Tokens.marcaSuave,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Tokens.marcaOscura,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pasos[i],
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: Tokens.texto,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
