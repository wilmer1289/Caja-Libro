import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/core/tema.dart';
import 'package:mi_caja/datos/repositorio/repositorio_demo.dart';
import 'package:mi_caja/dominio/almacen.dart';
import 'package:mi_caja/dominio/kardex.dart';
import 'package:mi_caja/dominio/mercaderia.dart';
import 'package:mi_caja/dominio/reglas_mercaderia.dart';
import 'package:mi_caja/estado/estado_caja.dart';
import 'package:mi_caja/ui/inventario/inventario_ventana.dart';
import 'package:mi_caja/ui/inventario/importar_productos.dart';
import 'package:provider/provider.dart';

void main() {
  group('Inventario y catálogo', () {
    test('el catálogo sugiere códigos correlativos y conserva la unidad', () {
      final existente = Mercaderia(
        id: 'p9',
        nombre: 'Tela',
        creadoEn: DateTime(2026, 1, 1),
        codigo: 'P009',
        unidad: '07',
        unidadCompra: '12',
        factorCompra: Cantidad.de(12),
      );

      expect(ReglasMercaderia.codigoSugerido([existente]), 'P010');
      expect(existente.aStock(Cantidad.de(10)), Cantidad.de(120));
    });


    test('el Excel se previsualiza por filas y marca las unidades inválidas', () {
      final archivo = Archive()
        ..addFile(
          ArchiveFile.string(
            'xl/worksheets/sheet1.xml',
            '''
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row r="1">
                  <c r="A1" t="inlineStr"><is><t>Código</t></is></c>
                  <c r="B1" t="inlineStr"><is><t>Descripción</t></is></c>
                  <c r="C1" t="inlineStr"><is><t>Unidad</t></is></c>
                  <c r="D1" t="inlineStr"><is><t>Cantidad</t></is></c>
                  <c r="E1" t="inlineStr"><is><t>Costo unitario</t></is></c>
                </row>
                <row r="2">
                  <c r="A2" t="inlineStr"><is><t>P001</t></is></c>
                  <c r="B2" t="inlineStr"><is><t>Tela</t></is></c>
                  <c r="C2" t="inlineStr"><is><t>07</t></is></c>
                  <c r="D2"><v>10</v></c>
                  <c r="E2"><v>2.50</v></c>
                </row>
                <row r="3">
                  <c r="A3" t="inlineStr"><is><t>P002</t></is></c>
                  <c r="B3" t="inlineStr"><is><t>Pintura</t></is></c>
                  <c r="C3" t="inlineStr"><is><t>XX</t></is></c>
                  <c r="D3"><v>4</v></c>
                  <c r="E3"><v>5.00</v></c>
                </row>
              </sheetData>
            </worksheet>
            ''',
          ),
        );
      final bytes = Uint8List.fromList(ZipEncoder().encode(archivo));
      final filas = ImportadorProductosExcel.leer(bytes, const []);

      expect(filas, hasLength(2));
      expect(filas.first.valida, isTrue);
      expect(filas.first.cantidad, Cantidad.de(10));
      expect(filas.first.costoTotal, 2500);
      expect(filas.last.valida, isFalse);
      expect(
        filas.last.errores.any((e) => e.contains('Tabla 6')),
        isTrue,
      );
    });

    test('el valor y costo promedio salen del kardex y generan alertas', () {
      final producto = Mercaderia(
        id: 'tela',
        nombre: 'Tela',
        creadoEn: DateTime(2026, 1, 1),
        codigo: 'P001',
        unidad: '07',
        stockMinimo: Cantidad.de(11),
      );
      final compra = LineaAlmacen(
        id: 'compra-1',
        mercaderiaId: producto.id,
        fecha: DateTime(2026, 1, 2),
        numero: 1,
        operacion: OperacionAlmacen.compra,
        entrada: true,
        cantidad: Cantidad.de(10),
        costoTotal: 10000,
      );

      final kardex = Kardex.de([compra]);
      final saldo = kardex.saldo(producto.id);

      expect(saldo.cantidad, Cantidad.de(10));
      expect(saldo.costo, 10000);
      expect(saldo.costoUnitario, 10);
      expect(kardex.valorTotal(), 10000);
      expect(
        kardex.alertas([producto], minimos: {producto.id: producto.stockMinimo}),
        hasLength(1),
      );
    });

    testWidgets('la ventana muestra las cuatro secciones y vuelve a Mi Caja', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(933, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => EstadoCaja(RepositorioDemo()),
          child: MaterialApp(
            theme: construirTema(),
            home: const Scaffold(body: InventarioVentana()),
          ),
        ),
      );

      expect(find.text('Inventario'), findsOneWidget);
      expect(find.text('Mi Caja'), findsOneWidget);
      expect(find.text('Productos'), findsWidgets);
      expect(find.text('Kardex'), findsOneWidget);
      expect(find.text('Operaciones'), findsOneWidget);
      expect(find.text('Conteo'), findsOneWidget);
      expect(find.text('Nuevo producto'), findsOneWidget);
    });

    testWidgets('la ventana se adapta a 390 px', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => EstadoCaja(RepositorioDemo()),
          child: MaterialApp(
            theme: construirTema(),
            home: const Scaffold(body: InventarioVentana()),
          ),
        ),
      );

      expect(find.text('Mi Caja'), findsOneWidget);
      expect(find.text('Productos'), findsWidgets);
      expect(find.text('Registrar compra'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
