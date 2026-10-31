import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/igv.dart';
import 'package:mi_caja/dominio/inventario.dart';
import 'package:mi_caja/dominio/libro_diario.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/dominio/reglas_asiento.dart';

/// El motor del Libro Diario. Los 4 ejemplos de la exposición (compra, venta,
/// alquiler y luz, en `Ejemplos hechos en la exposición.xlsx`) son el
/// resultado esperado: mismas cuentas y mismos importes, con la cadena de
/// cuentas hasta la cuenta final.
///
/// Se comparan códigos e importes, no nombres: el catálogo va a pasar al PCGE
/// 2026 y algunos nombres cambian (91 deja de ser "Costos por distribuir").
void main() {
  setUpAll(() {
    Pcge.cargarDeTexto(File('assets/pcge.json').readAsStringSync());
  });

  setUp(() => Categoria.registrarPropias(const []));

  const negocio = Negocio(razonSocial: 'LIBERTAD SA', documento: '11902816511');
  final dia = DateTime(2026, 10, 15, 10);

  Movimiento mov(
    String id,
    Tipo tipo,
    int centavos,
    String categoria, {
    int numero = 1,
    MedioPago medio = MedioPago.efectivo,
    DateTime? fecha,
    String? cuentaAsociada,
    int? numeroBoleta,
    int? numeroRecibo,
    DateTime? eliminadoEn,
  }) {
    final cat = Categoria.porId(categoria);
    final cuando = fecha ?? dia;
    return Movimiento(
      id: id,
      numero: numero,
      tipo: tipo,
      centavos: centavos,
      categoriaId: categoria,
      concepto: '',
      medio: medio,
      fecha: cuando,
      creadoEn: cuando,
      actualizadoEn: cuando,
      // Como el repositorio: la cuenta de la categoría, salvo que se elija
      // otra, y el IGV desagregado si la categoría lo lleva.
      cuentaAsociada: cuentaAsociada ?? cat.cuentaAsociada,
      igvCentavos: cat.afectoIgv ? Igv.desagregar(centavos).igv : 0,
      numeroBoleta: numeroBoleta,
      numeroRecibo: numeroRecibo,
      eliminadoEn: eliminadoEn,
      sync: EstadoSync.local,
    );
  }

  /// Arma el libro de un día con estos movimientos.
  LibroDiario libro(
    List<Movimiento> movimientos, {
    LeerMercaderia mercaderia = sinDatoDeMercaderia,
    Set<String> ajustes = const {},
  }) => LibroDiario.armar(
    negocio: negocio,
    movimientos: movimientos,
    desde: DateTime(2026, 10, 1),
    hasta: DateTime(2026, 10, 31),
    mercaderia: mercaderia,
    ajustes: ajustes,
  );

  /// Cada línea como (código, debe, haber).
  List<(String, int, int)> lineas(EtapaAsiento e) => [
    for (final l in e.lineas) (l.codigo, l.debe, l.haber),
  ];

  List<String> cadena(LineaDiario l) => [for (final c in l.cadena) c.codigo];

  DatoMercaderia? tela(Movimiento m) =>
      DatoMercaderia(id: 'tela', nombre: 'tela', costoCentavos: 100000);

  group('los 4 ejemplos de la exposición', () {
    test('001 · compra de mercadería: S/ 1,180 con IGV, pagada en caja', () {
      final a = libro([
        mov('c', Tipo.salio, 118000, 'mercaderia'),
      ], mercaderia: tela).asientos.single;

      expect(a.etapas.map((e) => e.tipo), [
        EtapaTipo.reconocimiento,
        EtapaTipo.variacionInventarios,
        EtapaTipo.pagoOCobro,
      ]);
      expect(lineas(a.etapas[0]), [
        ('6011', 100000, 0),
        ('40111', 18000, 0),
        ('4212', 0, 118000),
      ]);
      expect(lineas(a.etapas[1]), [('20111', 100000, 0), ('6111', 0, 100000)]);
      expect(lineas(a.etapas[2]), [('4212', 118000, 0), ('101', 0, 118000)]);

      expect(a.etapas.map((e) => e.glosa), [
        'Por la compra de tela',
        'Por la variación de inventarios (tela)',
        'Por el pago de la mercadería',
      ]);
      expect(a.numero, '001');
      expect(a.codigoLibro, '08');
      expect(a.totalDebe, 336000);
      expect(a.cuadra, isTrue);
      // La cadena completa, como se escribe en el Formato 5.1.
      expect(cadena(a.etapas[0].lineas[0]), ['60', '601', '6011']);
      expect(cadena(a.etapas[0].lineas[1]), ['40', '401', '4011', '40111']);
      expect(cadena(a.etapas[1].lineas[0]), ['20', '201', '2011', '20111']);
      expect(cadena(a.etapas[2].lineas[1]), ['10', '101']);
    });

    test('002 · venta: S/ 2,360 con IGV y costo S/ 1,000, cobrada en caja', () {
      final a = libro([
        mov('v', Tipo.entro, 236000, 'ventas'),
      ], mercaderia: tela).asientos.single;

      expect(a.etapas.map((e) => e.tipo), [
        EtapaTipo.reconocimiento,
        EtapaTipo.costoDeVenta,
        EtapaTipo.pagoOCobro,
      ]);
      expect(lineas(a.etapas[0]), [
        ('1212', 236000, 0),
        ('40111', 0, 36000),
        ('70121', 0, 200000),
      ]);
      expect(lineas(a.etapas[1]), [('69121', 100000, 0), ('20111', 0, 100000)]);
      expect(lineas(a.etapas[2]), [('101', 236000, 0), ('1212', 0, 236000)]);
      expect(a.glosa, 'Por la venta de tela');
      expect(a.etapas[1].glosa, 'Por el costo de venta (tela)');
      expect(a.faltaCosto, isFalse);
      expect(a.totalDebe, 572000);
      expect(cadena(a.etapas[0].lineas[2]), ['70', '701', '7012', '70121']);
      expect(cadena(a.etapas[1].lineas[0]), ['69', '691', '6912', '69121']);
    });

    test('003 · alquiler: S/ 944 (800 más IGV 144), deuda en 4699', () {
      final a = libro([mov('a', Tipo.salio, 94400, 'alquiler')])
          .asientos
          .single;

      expect(a.etapas.map((e) => e.tipo), [
        EtapaTipo.reconocimiento,
        EtapaTipo.destinoDelGasto,
        EtapaTipo.pagoOCobro,
      ]);
      expect(lineas(a.etapas[0]), [
        ('6352', 80000, 0),
        ('40111', 14400, 0),
        ('4699', 0, 94400),
      ]);
      expect(lineas(a.etapas[1]), [('91', 80000, 0), ('791', 0, 80000)]);
      expect(lineas(a.etapas[2]), [('4699', 94400, 0), ('101', 0, 94400)]);
      expect(a.etapas.map((e) => e.glosa), [
        'Por el registro del alquiler',
        'Por el destino del gasto',
        'Por el pago del alquiler',
      ]);
      expect(cadena(a.etapas[0].lineas[2]), ['46', '469', '4699']);
      expect(cadena(a.etapas[1].lineas[1]), ['79', '791']);
      expect(a.totalDebe, 268800);
    });

    test('004 · luz: S/ 177 (150 más IGV 27)', () {
      final a = libro([mov('l', Tipo.salio, 17700, 'luz')]).asientos.single;

      expect(lineas(a.etapas[0]), [
        ('6361', 15000, 0),
        ('40111', 2700, 0),
        ('4699', 0, 17700),
      ]);
      expect(lineas(a.etapas[1]), [('91', 15000, 0), ('791', 0, 15000)]);
      expect(lineas(a.etapas[2]), [('4699', 17700, 0), ('101', 0, 17700)]);
      expect(a.glosa, 'Por el registro del servicio de luz');
      expect(a.totalDebe, 50400);
    });

    test('las reglas de los ejemplos vienen marcadas del Excel', () {
      for (final (tipo, categoria) in [
        (Tipo.salio, 'mercaderia'),
        (Tipo.entro, 'ventas'),
        (Tipo.salio, 'alquiler'),
        (Tipo.salio, 'luz'),
      ]) {
        final regla = ReglasAsiento.para(mov('x', tipo, 1000, categoria));
        expect(regla.delExcel, isTrue, reason: categoria);
      }
      expect(
        ReglasAsiento.para(mov('x', Tipo.salio, 1000, 'agua')).delExcel,
        isFalse,
      );
    });
  });

  group('el asiento 2 de las ventas', () {
    test('sin dato de mercadería no se inventa el costo: queda marcado', () {
      final a = libro([mov('v', Tipo.entro, 236000, 'ventas')]).asientos.single;

      expect(a.etapas.map((e) => e.tipo), [
        EtapaTipo.reconocimiento,
        EtapaTipo.pagoOCobro,
      ]);
      expect(a.faltaCosto, isTrue);
      expect(a.glosa, 'Por la venta de mercadería');
      expect(a.cuadra, isTrue);
    });

    test('un servicio no tiene costo de venta y no falta nada', () {
      final a = libro([
        mov('v', Tipo.entro, 11800, 'ventas'),
      ], mercaderia: (_) => const DatoMercaderia.servicio()).asientos.single;

      expect(a.etapas.length, 2);
      expect(a.faltaCosto, isFalse);
      expect(a.glosa, 'Por la venta del servicio');
    });
  });

  group('las demás reglas', () {
    test('lo que entra o sale por el banco va en 104 › 1041', () {
      final a = libro([
        mov('v', Tipo.entro, 236000, 'ventas', medio: MedioPago.yape),
      ], mercaderia: tela).asientos.single;

      final cobro = a.etapas.last.lineas.first;
      expect(cobro.codigo, '1041');
      expect(cadena(cobro), ['10', '104', '1041']);
      expect(cobro.porQue, 'Entra plata al banco.');
    });

    test('sueldos: la deuda va en su cuenta (4111) y el gasto se destina', () {
      final a = libro([mov('s', Tipo.salio, 150000, 'sueldos')])
          .asientos
          .single;

      expect(lineas(a.etapas[0]), [('6211', 150000, 0), ('4111', 0, 150000)]);
      expect(lineas(a.etapas[1]), [('91', 150000, 0), ('791', 0, 150000)]);
      expect(lineas(a.etapas[2]), [('4111', 150000, 0), ('101', 0, 150000)]);
    });

    test('pagos y cobros de algo ya anotado van en un solo asiento', () {
      final asientos = libro([
        mov('p', Tipo.salio, 50000, 'proveedores', numero: 1),
        mov('f', Tipo.entro, 3000, 'cobros_fiado', numero: 2),
        mov('d', Tipo.entro, 20000, 'anticipos', numero: 3),
      ]).asientos;

      expect(asientos.map((a) => a.etapas.length), [1, 1, 1]);
      expect(lineas(asientos[0].etapas.single), [
        ('4212', 50000, 0),
        ('101', 0, 50000),
      ]);
      expect(asientos[0].glosa, 'Por el pago al proveedor');
      expect(lineas(asientos[1].etapas.single), [
        ('101', 3000, 0),
        ('1212', 0, 3000),
      ]);
      expect(asientos[1].glosa, 'Por el cobro del fiado');
      expect(lineas(asientos[2].etapas.single), [
        ('101', 20000, 0),
        ('122', 0, 20000),
      ]);
    });

    test('"Otros" usa la cuenta que se eligió en el formulario', () {
      final asientos = libro([
        mov('i', Tipo.entro, 30000, 'otros_ingresos', cuentaAsociada: '754'),
        mov(
          'e',
          Tipo.salio,
          2000,
          'otros_egresos',
          cuentaAsociada: '6311',
          numero: 2,
        ),
      ]).asientos;

      // Un ingreso se reconoce y se cobra; no se destina.
      expect(asientos[0].etapas.map((e) => e.tipo), [
        EtapaTipo.reconocimiento,
        EtapaTipo.pagoOCobro,
      ]);
      expect(lineas(asientos[0].etapas[0]), [
        ('1212', 30000, 0),
        ('754', 0, 30000),
      ]);
      // Un gasto se reconoce, se destina y se paga, con la deuda en 4699.
      expect(lineas(asientos[1].etapas[0]), [
        ('6311', 2000, 0),
        ('4699', 0, 2000),
      ]);
      expect(asientos[1].etapas[1].tipo, EtapaTipo.destinoDelGasto);
    });

    test('el faltante de un cierre de caja va en un solo asiento', () {
      final faltante = mov(
        'aj',
        Tipo.salio,
        50,
        'otros_egresos',
        cuentaAsociada: '659',
      );

      final ajuste = libro([faltante], ajustes: {'aj'}).asientos.single;
      expect(lineas(ajuste.etapas.single), [('659', 50, 0), ('101', 0, 50)]);
      expect(ajuste.glosa, 'Por el faltante de caja');

      // Sin marcarlo como ajuste, es un gasto cualquiera.
      expect(libro([faltante]).asientos.single.etapas.length, 3);
    });

    test('el sobrante de un cierre de caja va contra 7599', () {
      final sobrante = mov(
        'aj',
        Tipo.entro,
        100,
        'otros_ingresos',
        cuentaAsociada: '7599',
      );
      final ajuste = libro([sobrante], ajustes: {'aj'}).asientos.single;
      expect(lineas(ajuste.etapas.single), [('101', 100, 0), ('7599', 0, 100)]);
      expect(ajuste.glosa, 'Por el sobrante de caja');
    });

    test('el documento es la boleta o el recibo del movimiento', () {
      final asientos = libro([
        mov('v', Tipo.entro, 1000, 'ventas', numeroBoleta: 12),
        mov('r', Tipo.entro, 1000, 'cobros_fiado', numeroRecibo: 7, numero: 2),
        mov('n', Tipo.salio, 1000, 'luz', numero: 3),
      ]).asientos;

      expect(asientos.map((a) => a.documento), [
        'B001-00000012',
        'Recibo 000007',
        null,
      ]);
    });
  });

  group('el libro', () {
    test('todo asiento cuadra, sea cual sea la categoría y el medio', () {
      final movimientos = <Movimiento>[];
      var n = 0;
      for (final categoria in Categoria.todas) {
        for (final medio in [MedioPago.efectivo, MedioPago.transferencia]) {
          // Un monto impar, para que el redondeo del IGV se note si falla.
          movimientos.add(
            mov(
              '${categoria.id}-${medio.name}',
              categoria.tipo,
              12345,
              categoria.id,
              medio: medio,
              numero: ++n,
            ),
          );
        }
      }
      final conCosto = libro(
        movimientos,
        mercaderia: (m) =>
            DatoMercaderia(id: 'x', nombre: 'x', costoCentavos: 5000),
      );
      final sinDato = libro(movimientos);

      for (final l in [conCosto, sinDato]) {
        expect(l.asientos.length, movimientos.length);
        for (final a in l.asientos) {
          expect(a.cuadra, isTrue, reason: a.origen.id);
          for (final e in a.etapas) {
            expect(
              e.totalDebe,
              e.totalHaber,
              reason: '${a.origen.id} ${e.glosa}',
            );
            expect(e.lineas.every((x) => x.porQue.isNotEmpty), isTrue);
          }
        }
        expect(l.cuadra, isTrue);
        expect(l.totalDebe, l.totalHaber);
      }
    });

    test('ordena por fecha, numera desde 1 y deja afuera lo que no va', () {
      final l = LibroDiario.armar(
        negocio: Negocio(
          razonSocial: 'LIBERTAD SA',
          inicioPeriodo: DateTime(2026, 10, 3),
        ),
        movimientos: [
          mov(
            'tarde',
            Tipo.salio,
            1000,
            'luz',
            fecha: DateTime(2026, 10, 20),
            numero: 5,
          ),
          mov(
            'temprano',
            Tipo.salio,
            1000,
            'agua',
            fecha: DateTime(2026, 10, 10),
            numero: 9,
          ),
          mov(
            'mismo-dia-2',
            Tipo.salio,
            1000,
            'luz',
            fecha: DateTime(2026, 10, 20),
            numero: 7,
          ),
          // Antes de la apertura del negocio.
          mov('antes', Tipo.salio, 1000, 'luz', fecha: DateTime(2026, 10, 2)),
          // Fuera del rango.
          mov(
            'noviembre',
            Tipo.salio,
            1000,
            'luz',
            fecha: DateTime(2026, 11, 1),
          ),
          mov(
            'borrado',
            Tipo.salio,
            1000,
            'luz',
            eliminadoEn: DateTime(2026, 10, 21),
          ),
        ],
        desde: DateTime(2026, 10, 1),
        hasta: DateTime(2026, 10, 31),
      );

      expect(l.asientos.map((a) => a.origen.id), [
        'temprano',
        'tarde',
        'mismo-dia-2',
      ]);
      expect(l.asientos.map((a) => a.numero), ['001', '002', '003']);
      expect(l.desde, DateTime(2026, 10, 1));
      expect(l.hasta.day, 31);
    });

    test('un período sin movimientos da un libro vacío que cuadra', () {
      final l = libro(const []);
      expect(l.vacio, isTrue);
      expect(l.totalDebe, 0);
      expect(l.cuadra, isTrue);
    });
  });

  group('el inventario por tipo de mercadería', () {
    test('compras suman su base, ventas restan su costo', () {
      DatoMercaderia? dato(Movimiento m) => switch (m.id) {
        'c-tela' => const DatoMercaderia(id: 'tela', nombre: 'Tela'),
        'c-pintura' => const DatoMercaderia(id: 'pintura', nombre: 'Pintura'),
        'v-tela' => const DatoMercaderia(
          id: 'tela',
          nombre: 'Tela',
          costoCentavos: 40000,
        ),
        'c-borrada' => const DatoMercaderia(id: 'tela', nombre: 'Tela'),
        _ => null,
      };

      final inventario = InventarioMercaderias.de([
        mov('c-tela', Tipo.salio, 118000, 'mercaderia'),
        mov('c-pintura', Tipo.salio, 59000, 'mercaderia'),
        mov('v-tela', Tipo.entro, 70800, 'ventas'),
        // Una compra sin tipo no tiene a qué sumarse.
        mov('c-sin-tipo', Tipo.salio, 11800, 'mercaderia'),
        mov(
          'c-borrada',
          Tipo.salio,
          118000,
          'mercaderia',
          eliminadoEn: DateTime(2026, 10, 16),
        ),
        // Un gasto no es mercadería aunque se lea con dato.
        mov('luz', Tipo.salio, 17700, 'luz'),
      ], leer: dato);

      expect(inventario.comprado('tela'), 100000);
      expect(inventario.costoVendido('tela'), 40000);
      expect(inventario.saldo('tela'), 60000);
      expect(inventario.saldo('pintura'), 50000);
      expect(inventario.tipos.map((t) => t.nombre), ['Pintura', 'Tela']);
      expect(inventario.saldo('no-existe'), 0);
    });

    test('sin datos de mercadería el inventario queda vacío', () {
      final inventario = InventarioMercaderias.de([
        mov('c', Tipo.salio, 118000, 'mercaderia'),
      ]);
      expect(inventario.vacio, isTrue);
    });
  });

  test('el motor no depende de las pantallas', () {
    for (final archivo in [
      'lib/dominio/libro_diario.dart',
      'lib/dominio/reglas_asiento.dart',
      'lib/dominio/inventario.dart',
    ]) {
      final codigo = File(archivo).readAsStringSync();
      expect(
        codigo.contains("import 'package:flutter/"),
        isFalse,
        reason: archivo,
      );
      expect(codigo.contains('/ui/'), isFalse, reason: archivo);
    }
  });
}
