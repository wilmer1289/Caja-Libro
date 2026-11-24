import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/core/tema.dart';
import 'package:mi_caja/datos/repositorio/repositorio_demo.dart';
import 'package:mi_caja/dominio/almacen.dart';
import 'package:mi_caja/dominio/mercaderia.dart';
import 'package:mi_caja/estado/estado_caja.dart';
import 'package:mi_caja/ui/inventario/importar_productos.dart';
import 'package:mi_caja/ui/inventario/inventario_ventana.dart';
import 'package:provider/provider.dart';

/// Pruebas de P3 que completan `inventario_productos_test.dart`: lo que toca
/// el estado (usuario, desactivar, alertas) y la navegación de la ventana.
Uint8List _excel(List<List<String>> filas) {
  final sb = StringBuffer(
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
  );
  const col = ['A', 'B', 'C', 'D', 'E'];
  for (var i = 0; i < filas.length; i++) {
    sb.write('<row r="${i + 1}">');
    for (var j = 0; j < filas[i].length; j++) {
      sb.write(
        '<c r="${col[j]}${i + 1}" t="inlineStr"><is><t>${filas[i][j]}</t></is></c>',
      );
    }
    sb.write('</row>');
  }
  sb.write('</sheetData></worksheet>');
  final archivo = Archive()
    ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sb.toString()));
  return Uint8List.fromList(ZipEncoder().encode(archivo));
}

void main() {
  setUpAll(() async => initializeDateFormatting('es_PE'));

  group('P3 · catálogo y avisos', () {
    test('cada línea del almacén guarda quién la registró', () async {
      final estado = EstadoCaja(RepositorioDemo())..usuario = 'Ana';
      final p = await estado.guardarProducto(nombre: 'Tela', codigo: 'P001');
      await estado.registrarEnAlmacen(
        operacion: OperacionAlmacen.saldoInicial,
        mercaderiaId: p.id,
        fecha: DateTime.now(),
        cantidad: Cantidad.de(10),
        costoTotal: 10000,
      );

      expect(estado.lineasAlmacen.single.registradoPor, 'Ana');
    });

    test('desactivar un producto no lo borra, solo deja de ofrecerse', () async {
      final estado = EstadoCaja(RepositorioDemo())..usuario = 'Ana';
      final p = await estado.guardarProducto(nombre: 'Tela', codigo: 'P001');

      await estado.guardarProducto(
        id: p.id,
        nombre: p.nombre,
        codigo: p.codigo,
        activo: false,
      );

      expect(estado.productos.map((m) => m.id), contains(p.id));
      expect(estado.productosActivos.map((m) => m.id), isNot(contains(p.id)));
    });

    test('no se repite el código de un producto', () async {
      final estado = EstadoCaja(RepositorioDemo())..usuario = 'Ana';
      await estado.guardarProducto(nombre: 'Tela', codigo: 'P001');

      expect(
        () => estado.guardarProducto(nombre: 'Pintura', codigo: 'P001'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('el aviso aparece cuando el stock baja al mínimo', () async {
      final estado = EstadoCaja(RepositorioDemo())..usuario = 'Ana';
      final p = await estado.guardarProducto(
        nombre: 'Tela',
        codigo: 'P001',
        stockMinimo: Cantidad.de(5),
      );
      await estado.registrarEnAlmacen(
        operacion: OperacionAlmacen.saldoInicial,
        mercaderiaId: p.id,
        fecha: DateTime.now(),
        cantidad: Cantidad.de(20),
        costoTotal: 20000,
      );
      expect(estado.alertasInventario, isEmpty);

      await estado.registrarEnAlmacen(
        operacion: OperacionAlmacen.merma,
        mercaderiaId: p.id,
        fecha: DateTime.now(),
        cantidad: Cantidad.de(15),
        entrada: false,
        glosa: 'Prueba de aviso',
      );

      expect(estado.alertasInventario, hasLength(1));
    });

    test('un producto desactivado no genera aviso', () async {
      final estado = EstadoCaja(RepositorioDemo())..usuario = 'Ana';
      final p = await estado.guardarProducto(
        nombre: 'Tela',
        codigo: 'P001',
        stockMinimo: Cantidad.de(5),
      );
      await estado.guardarProducto(
        id: p.id,
        nombre: p.nombre,
        codigo: p.codigo,
        stockMinimo: Cantidad.de(5),
        activo: false,
      );

      expect(estado.alertasInventario, isEmpty);
    });

    test('la importación marca el código que ya existe en el catálogo', () {
      final existente = Mercaderia(
        id: 'p1',
        nombre: 'Tela',
        creadoEn: DateTime(2026, 1, 1),
        codigo: 'P001',
      );
      final bytes = _excel([
        ['Código', 'Descripción', 'Unidad', 'Cantidad', 'Costo unitario'],
        ['P001', 'Pintura', '07', '4', '5.00'],
        ['P002', 'Cuerda', '07', '3', '2.00'],
      ]);

      final filas = ImportadorProductosExcel.leer(bytes, [existente]);

      expect(filas, hasLength(2));
      expect(filas.first.valida, isFalse);
      expect(filas.last.valida, isTrue);
    });
  });

  group('P3 · ventana', () {
    testWidgets('«Mi Caja» cierra el inventario y deja la pantalla de abajo', (
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
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => InventarioVentana.abrir(context),
                    child: const Text('Abrir inventario'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir inventario'));
      await tester.pumpAndSettle();
      expect(find.byType(InventarioVentana), findsOneWidget);

      await tester.tap(find.text('Mi Caja'));
      await tester.pumpAndSettle();

      expect(find.byType(InventarioVentana), findsNothing);
      expect(find.text('Abrir inventario'), findsOneWidget);
    });
  });
}
