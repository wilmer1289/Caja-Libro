import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/datos/repositorio/repositorio_demo.dart';
import 'package:mi_caja/dominio/inventario.dart';
import 'package:mi_caja/dominio/kardex.dart';
import 'package:mi_caja/dominio/mercaderia.dart';
import 'package:mi_caja/dominio/periodo.dart';
import 'package:mi_caja/estado/estado_caja.dart';

const compra = OperacionAlmacen.compra;
const venta = OperacionAlmacen.venta;
const inicial = OperacionAlmacen.saldoInicial;
final octubre = DateTime(2026, 10, 31);

LineaAlmacen linea(
  int n,
  OperacionAlmacen op,
  int cantidad, {
  int? costo,
  int? precio,
  int? dia,
  String producto = 'POSA 001',
  String? origen,
  String? cuenta,
  bool anulada = false,
  int gasto = 0,
  DateTime? fecha,
  bool? entrada,
}) => LineaAlmacen(
  id: 'L$n',
  mercaderiaId: producto,
  numero: n,
  fecha: fecha ?? DateTime(2026, 10, dia ?? n + 1),
  operacion: op,
  cantidad: cantidad,
  costoTotal: costo,
  importe: precio,
  entrada:
      entrada ??
      (op == compra ||
          op == inicial ||
          op == OperacionAlmacen.devolucionRecibida),
  cuentaCosto: cuenta,
  origenId: origen,
  anulada: anulada,
  gastoCompraAsignado: gasto,
);

void main() {
  test(
    'EstadoCaja reconstruye el inventario al insertar una compra anterior',
    () {
      final lineas = [
        linea(0, inicial, 1000, costo: 100),
        linea(2, venta, 1000, dia: 3),
      ];
      final estado = EstadoCaja(
        RepositorioDemo(),
        leerLineasAlmacen: () => lineas,
      );
      addTearDown(estado.dispose);
      expect(estado.kardex.costoDe('L2'), 100);
      lineas.add(linea(1, compra, 1000, dia: 2, costo: 300));
      expect(estado.kardex.costoDe('L2'), 200);
      expect(
        estado.inventarioHasta(fecha: DateTime(2026, 10, 2)).saldo('POSA 001'),
        400,
      );
      expect(estado.inventarioHasta(fecha: octubre).saldo('POSA 001'), 200);
    },
  );
  test('POSA 001: apertura y los 15 comprobantes en orden contable', () {
    final ejercicio = [
      // Día, operación, unidades y valor esperado de la fila en centavos.
      (1, inicial, 1200, 6000000), (1, venta, 800, 4000000),
      (2, compra, 1600, 8320000), (4, venta, 550, 2838000),
      (7, venta, 450, 2322000), (8, compra, 1000, 5400000),
      (10, venta, 20, 105600), (13, venta, 880, 4646400),
      (15, compra, 1400, 7042000), (16, venta, 30, 154200),
      (17, venta, 1170, 6013800), (18, compra, 1700, 8840000),
      (20, venta, 1250, 6467500), (21, venta, 1400, 7243600),
      (24, compra, 1650, 8019000), (28, venta, 1100, 5406445),
    ];
    final k = Kardex.de([
      for (final (i, (dia, op, uds, monto))
          in ejercicio.indexed.toList().reversed)
        linea(
          i,
          op,
          uds * 1000,
          dia: dia,
          costo: op == venta ? null : monto,
          cuenta: [4, 17].contains(dia) ? '69111' : '69121',
        ),
    ]);
    final filas = k.filas('POSA 001');
    expect(filas.map((f) => f.costoTotal), ejercicio.map((e) => e.$4));
    expect(filas.last.saldoCantidad, 900000);
    expect(filas.last.saldoCosto, 4423455);
    expect(filas.last.costoUnitario, closeTo(49.1495, 0.000001));
    expect(k.costoDeVentas(Periodo.mes, referencia: octubre), {
      '69111': 8851800,
      '69121': 30345745,
    });
    expect(k.saldo('POSA 001', al: DateTime(2026, 10, 1)).cantidad, 400000);
    final inventario = InventarioMercaderias.desdeKardex(k);
    expect(inventario.saldo('POSA 001'), 4423455);
    expect(inventario.costoVendido('POSA 001'), 39197545);
  });

  test('milésimas, redondeo acumulado en devoluciones y agotamiento', () {
    final origen = [
      linea(0, compra, 3, costo: 100),
      linea(1, venta, 3, cuenta: '69111'),
    ];
    final k = Kardex.de([
      ...origen,
      for (var n = 2; n < 5; n++)
        linea(n, OperacionAlmacen.devolucionRecibida, 1, origen: 'L1'),
    ]);
    expect(k.filas('POSA 001').map((f) => f.costoTotal), [
      100,
      100,
      33,
      34,
      33,
    ]);
    expect(k.costoDeVentas(Periodo.mes, referencia: octubre)['69111'], 0);
    expect(k.costoDeSalida('POSA 001', 3, octubre), 100);
    expect(() => k.costoDeSalida('POSA 001', 4, octubre), throwsStateError);
    expect(
      () => Kardex.de([origen.first, linea(1, venta, 4)]),
      throwsStateError,
    );
    expect(
      () => Kardex.de([
        ...origen,
        linea(3, OperacionAlmacen.devolucionRecibida, 4, origen: 'L1'),
      ]),
      throwsStateError,
    );
  });

  test(
    'devolución al proveedor al costo original, merma y ajuste al promedio',
    () {
      final k = Kardex.de([
        linea(0, compra, 2000, costo: 200),
        linea(1, compra, 2000, costo: 400),
        linea(2, OperacionAlmacen.devolucionEntregada, 1000, origen: 'L0'),
        linea(3, OperacionAlmacen.merma, 1000),
        linea(4, OperacionAlmacen.ajuste, 1000, entrada: true),
        linea(5, OperacionAlmacen.desmedro, 3000),
      ]);
      expect(k.costoDe('L2'), 100);
      expect(k.costoDe('L3'), 167);
      expect(k.costoDe('L4'), 167);
      expect(k.costoDe('L5'), 500);
      expect(k.valorTotal(), 0);
    },
  );

  test('flete, corte anual, márgenes, mínimos y productos sin movimiento', () {
    final a = Mercaderia(id: 'A', nombre: 'A', creadoEn: octubre);
    final b = Mercaderia(id: 'B', nombre: 'B', creadoEn: octubre);
    final k = Kardex.de([
      linea(0, compra, 3000, producto: 'A', costo: 280, gasto: 20),
      linea(1, venta, 1000, producto: 'A', precio: 150),
      linea(2, venta, 9000, producto: 'A', anulada: true),
      linea(3, inicial, 1000, producto: 'B', costo: 90, fecha: DateTime(2027)),
    ]);
    expect(k.saldosFinDeAnio(2026).keys, ['A']);
    expect(k.valorTotal(al: DateTime(2026, 12, 31)), 200);
    expect(k.saldosFinDeAnio(2026)['A']!.costo, 200);
    expect(k.margenPorProducto('A', Periodo.mes, referencia: octubre), 50);
    expect(k.sinMovimiento([a, b], Periodo.mes, referencia: octubre), [b]);
    expect(
      k.alertas([a, b], minimos: {'A': 2000}).single.mensaje,
      'Queda poco',
    );
    expect(Kardex.de([]).alertas([a]).single.mensaje, 'Sin stock');
  });
}
