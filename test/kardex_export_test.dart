import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/core/tema.dart';
import 'package:mi_caja/datos/export/exportador_kardex.dart';
import 'package:mi_caja/datos/export/exportador_kardex_pdf.dart';
import 'package:mi_caja/datos/export/impresion.dart';
import 'package:mi_caja/datos/repositorio/repositorio_demo.dart';
import 'package:mi_caja/dominio/almacen.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/kardex.dart';
import 'package:mi_caja/dominio/mercaderia.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/dominio/registro_inventario.dart';
import 'package:mi_caja/dominio/reglas_mercaderia.dart';
import 'package:mi_caja/estado/estado_caja.dart';
import 'package:mi_caja/ui/inventario/entender_kardex.dart';
import 'package:mi_caja/ui/inventario/kardex_pestana.dart';
import 'package:provider/provider.dart';

/// P7: el kardex en pantalla, el Formato 13.1 y el 12.1 (PDF y CSV), y el
/// modo «Entender». Con el ejercicio del Excel: 1,200 ponchos de saldo
/// inicial y las 15 facturas de octubre de 2026.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_PE');
    Pcge.cargarDeTexto(File('assets/pcge.json').readAsStringSync());
  });

  final ponchos = Mercaderia(
    id: 'posa',
    nombre: 'Ponchos artesanales talla estándar',
    codigo: 'POSA 001',
    creadoEn: DateTime(2026, 9, 30),
  );
  const negocio = Negocio(
    razonSocial: 'LIBERTAD S.A.',
    documento: '20304050601',
    direccion: 'Av. España 123, Trujillo',
  );

  // (día, serie, número, cantidad, valor unitario, compra, exportación)
  const ejercicio = <(int, String, String, int, num, bool, bool)>[
    (1, 'FE01', '112', 800, 70, false, false),
    (2, 'FE01', '234', 1600, 52, true, false),
    (4, 'FE01', '113', 550, 80, false, true),
    (7, 'FE01', '114', 450, 70, false, false),
    (8, 'FE01', '346', 1000, 54, true, false),
    (10, 'BE01', '15', 20, 75, false, false),
    (13, 'FE01', '115', 880, 70, false, false),
    (15, 'FE01', '453', 1400, 50.3, true, false),
    (16, 'BE01', '16', 30, 75, false, false),
    (17, 'FE01', '116', 1170, 80, false, true),
    (18, 'FE01', '535', 1700, 52, true, false),
    (20, 'FE01', '117', 1250, 70, false, false),
    (21, 'FE01', '118', 1400, 70, false, false),
    (24, 'FE01', '692', 1650, 48.6, true, false),
    (28, 'FE01', '119', 1100, 70, false, false),
  ];

  final lineas = <LineaAlmacen>[
    LineaAlmacen(
      id: 'inicial',
      mercaderiaId: 'posa',
      fecha: DateTime(2026, 10, 1),
      numero: 1,
      operacion: OperacionAlmacen.saldoInicial,
      entrada: true,
      cantidad: Cantidad.de(1200),
      costoTotal: 6000000,
    ),
    for (var i = 0; i < ejercicio.length; i++)
      () {
        final (dia, serie, numero, cantidad, unitario, compra, exp) =
            ejercicio[i];
        final importe = (cantidad * unitario * 100).round();
        return LineaAlmacen(
          id: 'L$i',
          mercaderiaId: 'posa',
          fecha: DateTime(2026, 10, dia),
          numero: i + 2,
          operacion: compra ? OperacionAlmacen.compra : OperacionAlmacen.venta,
          entrada: compra,
          cantidad: Cantidad.de(cantidad),
          costoTotal: compra ? importe : null,
          importe: importe,
          docTipo: serie.startsWith('B') ? '03' : '01',
          docSerie: serie,
          docNumero: numero,
          cuentaCosto: compra ? null : (exp ? '69111' : '69121'),
        );
      }(),
  ];
  final kardex = Kardex.de(lineas);

  RegistroInventario registro({DateTime? desde, DateTime? hasta}) =>
      RegistroInventario.de(
        kardex,
        negocio: negocio,
        producto: ponchos,
        desde: desde ?? DateTime(2026, 10, 1),
        hasta: hasta ?? DateTime(2026, 10, 31),
      );

  group('Formato 13.1', () {
    test('el ejercicio de octubre cierra con 900 unidades y S/ 44,234.55', () {
      final r = registro();
      expect(r.periodo, 'OCTUBRE 2026');
      expect(r.filas, hasLength(16));

      // El saldo inicial va sólo en el saldo, no como entrada.
      final inicial = r.filas.first;
      expect(inicial.esSaldoInicial, isTrue);
      expect(inicial.entradaCantidad, isNull);
      expect(inicial.saldoCantidad, Cantidad.de(1200));
      expect(inicial.saldoCosto, 6000000);
      expect(r.inicialCantidad, Cantidad.de(1200));
      expect(r.inicialCosto, 6000000);

      expect(r.entradasCantidad, Cantidad.de(7350));
      expect(r.entradasCosto, 37621000);
      expect(r.salidasCantidad, Cantidad.de(7650));
      expect(r.salidasCosto, 39197545);
      expect(r.saldoFinalCantidad, Cantidad.de(900));
      expect(r.saldoFinalCosto, 4423455);
      expect(r.inicialCosto + r.entradasCosto - r.salidasCosto, 4423455);
      expect(
        RegistroInventario.unitario(r.filas.last.saldoUnitario),
        '49.1495',
      );

      // La venta del 4 sale al promedio de 51.60.
      final exportacion = r.filas.firstWhere((f) => f.numero == '113');
      expect(exportacion.salidaCosto, 2838000);
      expect(RegistroInventario.unitario(exportacion.salidaUnitario), '51.60');
      expect(exportacion.operacion, '01');
      expect(exportacion.tipoDocumento, '01');

      final cabecera = {for (final (k, v) in r.encabezado()) k: v};
      expect(cabecera['RUC'], '20304050601');
      expect(cabecera['CÓDIGO DE LA EXISTENCIA'], 'POSA 001');
      expect(cabecera['TIPO (TABLA 5)'], '01 Mercadería');
      expect(
        cabecera['CÓDIGO DE LA UNIDAD DE MEDIDA (TABLA 6)'],
        '07 Unidades',
      );
      expect(cabecera['MÉTODO DE VALUACIÓN'], 'PROMEDIO PONDERADO');
      expect(
        r.encabezado(valorizado: false).map((e) => e.$1),
        isNot(contains('MÉTODO DE VALUACIÓN')),
      );
    });

    test('un período a la mitad empieza con el saldo que arrastra', () {
      final r = registro(desde: DateTime(2026, 10, 10));
      expect(r.periodo, '10/10/2026 AL 31/10/2026');
      final arrastre = r.filas.first;
      expect(arrastre.arrastrado, isTrue);
      expect(arrastre.operacion, '16');
      // Al 9 de octubre: 1,200 + 1,600 + 1,000 − 800 − 550 − 450 = 2,000.
      expect(arrastre.saldoCantidad, Cantidad.de(2000));
      expect(r.saldoFinalCosto, 4423455);
      expect(r.inicialCantidad, Cantidad.de(2000));

      final noviembre = registro(
        desde: DateTime(2026, 11, 1),
        hasta: DateTime(2026, 11, 30),
      );
      expect(noviembre.filas, hasLength(1));
      expect(noviembre.entradasCantidad, 0);
      expect(noviembre.saldoFinalCantidad, Cantidad.de(900));

      // Antes del inventario no hay nada que mostrar.
      expect(
        registro(
          desde: DateTime(2026, 9, 1),
          hasta: DateTime(2026, 9, 30),
        ).vacio,
        isTrue,
      );
    });

    test('el CSV trae el encabezado, las filas y los totales', () {
      final csv = ExportadorKardex.csv131([registro()]);
      final lineasCsv = csv.split('\r\n');
      expect(lineasCsv.first, RegistroInventario.titulo131);
      expect(lineasCsv, contains('PERÍODO:;OCTUBRE 2026'));
      expect(lineasCsv, contains('MÉTODO DE VALUACIÓN:;PROMEDIO PONDERADO'));
      expect(
        lineasCsv,
        contains('01/10/2026;00;;;16;;;;;;;1200;50.00;60000.00'),
      );
      expect(
        lineasCsv,
        contains(
          '04/10/2026;01;FE01;113;01;;;;550;51.60;28380.00;1450;51.60;74820.00',
        ),
      );
      expect(
        lineasCsv.last,
        ';;;;TOTALES;7350;;376210.00;7650;;391975.45;900;;44234.55',
      );

      final csv121 = ExportadorKardex.csv121([registro()]);
      expect(csv121.split('\r\n').first, RegistroInventario.titulo121);
      expect(csv121, isNot(contains('MÉTODO DE VALUACIÓN')));
      expect(csv121.split('\r\n').last, ';;;;TOTALES;7350;7650;900');
      expect(
        ExportadorKardex.nombre('13.1', [registro()]),
        'Formato 13.1 - POSA 001 - 2026-10.csv',
      );
    });

    test(
      'el PDF del 13.1 y del 12.1, también de todos los productos',
      () async {
        final mantas = Mercaderia(
          id: 'mantas',
          nombre: 'Mantas',
          codigo: 'P002',
          creadoEn: DateTime(2026, 9, 30),
        );
        final otro = Kardex.de([
          ...lineas,
          LineaAlmacen(
            id: 'mantas-inicial',
            mercaderiaId: 'mantas',
            fecha: DateTime(2026, 10, 3),
            numero: 99,
            operacion: OperacionAlmacen.saldoInicial,
            entrada: true,
            cantidad: Cantidad.de(10),
            costoTotal: 50000,
          ),
        ]);
        final todos = RegistroInventario.deTodos(
          otro,
          negocio: negocio,
          productos: [mantas, ponchos],
          desde: DateTime(2026, 10, 1),
          hasta: DateTime(2026, 10, 31),
        );
        expect(todos.map((r) => r.producto.codigo), ['P002', 'POSA 001']);

        for (final pdf in [
          await ExportadorKardexPdf.formato131([registro()]),
          await ExportadorKardexPdf.formato121([registro()]),
          await ExportadorKardexPdf.formato131(todos),
        ]) {
          expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
          expect(pdf.length, greaterThan(2000));
        }
      },
    );
  });

  group('Entender', () {
    String pasos(String numero) {
      final r = registro();
      final i = r.filas.indexWhere((f) => f.numero == numero);
      return EntenderKardex.pasos(
        r.filas[i],
        anterior: i == 0 ? null : r.filas[i - 1],
        producto: ponchos,
      ).join(' ').replaceAll(' ', ' ');
    }

    test('explica la compra, la venta al promedio y la que se lleva todo', () {
      final inicial = EntenderKardex.pasos(
        registro().filas.first,
        producto: ponchos,
      ).join(' ').replaceAll(' ', ' ');
      expect(inicial, contains('inventario inicial'));
      expect(inicial, contains('S/ 60,000.00'));

      final compra = pasos('234');
      expect(compra, contains('Entran 1,600 und por S/ 83,200.00'));
      expect(compra, contains('S/ 103,200.00 ÷ 2,000 = S/ 51.60'));

      final venta = pasos('113');
      expect(venta, contains('550 × S/ 103,200.00 ÷ 2,000 = S/ 28,380.00'));
      expect(venta, contains('no entra al kardex'));

      final ultima = pasos('119');
      expect(ultima, contains('1,100 × S/ 98,299.00 ÷ 2,000 = S/ 54,064.45'));
      expect(ultima, contains('Quedan 900 und por S/ 44,234.55'));
    });
  });

  testWidgets('la sección Kardex muestra el producto, sus totales y explica '
      'una fila', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = RepositorioDemo();
    await repo.guardarNegocio(negocio);
    final p = await repo.guardarProducto(nombre: 'Ponchos', codigo: 'POSA 001');
    await repo.registrarEnAlmacen(
      operacion: OperacionAlmacen.saldoInicial,
      mercaderiaId: p.id,
      fecha: DateTime(2026, 10, 1),
      cantidad: Cantidad.de(100),
      costoTotal: 500000,
    );
    await repo.registrar(
      tipo: Tipo.entro,
      centavos: ReglasMercaderia.montoParaLineas(70000, conIgv: true),
      categoriaId: 'ventas',
      concepto: '',
      medio: MedioPago.transferencia,
      fecha: DateTime(2026, 10, 5),
      contraparte: 'Cliente',
      documentoContraparte: '20304050811',
      numeroTransaccion: '123',
      lineas: [
        LineaNueva(
          mercaderiaId: p.id,
          cantidad: Cantidad.de(10),
          importe: 70000,
        ),
      ],
    );
    final estado = EstadoCaja(repo);
    await estado.cargar();

    final descargas = <String>[];
    final antes = Impresion.descargar;
    Impresion.descargar = (Uint8List pdf, String nombre) async {
      descargas.add(nombre);
      return 'C:/prueba/$nombre';
    };
    addTearDown(() => Impresion.descargar = antes);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: estado,
        child: MaterialApp(
          theme: construirTema(),
          locale: const Locale('es', 'PE'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('es', 'PE')],
          home: const Scaffold(body: KardexPestana()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kardex'), findsOneWidget);
    expect(find.text('POSA 001 · Ponchos'), findsOneWidget);
    // El mes del último movimiento, con la venta de la factura F001-1.
    expect(find.text('Octubre de 2026'), findsOneWidget);
    expect(find.text('F001'), findsOneWidget);
    expect(find.text('S/ 4,500.00'), findsOneWidget); // saldo final
    expect(find.text('90'), findsWidgets);

    await tester.tap(find.text('Entender'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('F001'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('10 × S/ 5,000.00 ÷ 100 = S/ 500.00'),
      findsOneWidget,
    );
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Descargar formatos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Formato 13.1 en PDF'));
    await tester.pumpAndSettle();
    expect(descargas, ['Formato 13.1 - POSA 001 - 2026-10.pdf']);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    estado.dispose();
  });
}
