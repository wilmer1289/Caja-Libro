import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/core/tema.dart';
import 'package:mi_caja/datos/repositorio/repositorio_demo.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/estado/estado_caja.dart';
import 'package:mi_caja/ui/registro/registro_hoja.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_PE');
    if (const String.fromEnvironment('P4_CAPTURAS').isNotEmpty) {
      final fuente = FontLoader(Tokens.tipografia);
      for (final peso in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
      ]) {
        fuente.addFont(
          rootBundle.load('assets/fonts/PlusJakartaSans-$peso.ttf'),
        );
      }
      await fuente.load();
      final iconos = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await iconos.load();
    }
    Pcge.cargarDeTexto(File('assets/pcge.json').readAsStringSync());
  });

  Future<void> abrir(WidgetTester tester, EstadoCaja estado, Tipo tipo) async {
    tester.view.physicalSize = const Size(933, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: estado,
        child: MaterialApp(
          theme: construirTema(),
          locale: const Locale('es', 'PE'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('es', 'PE')],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => RegistroHoja.abrir(context, tipo),
                  child: const Text('Abrir registro'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir registro'));
    await tester.pumpAndSettle();
  }

  Future<void> alVoucher(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final numero = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText ?? '').startsWith('El número del voucher'),
    );
    await tester.ensureVisible(numero);
    await tester.enterText(numero, '04512378');
    await tester.pumpAndSettle();
  }

  testWidgets('el botón + crea un producto con unidad de compra', (
    tester,
  ) async {
    final repo = RepositorioDemo();
    final estado = EstadoCaja(repo);
    await estado.cargar();
    estado.ultimoMedio = MedioPago.yape;
    estado.ultimaCategoriaEgreso = 'mercaderia';

    await abrir(tester, estado, Tipo.salio);
    final monto = find.byType(TextField).first;
    await tester.ensureVisible(monto);
    await tester.enterText(monto, '118');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Productos'), findsWidgets);
    expect(find.text('¿Qué mercadería?'), findsNothing);
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agregar producto'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo producto'), findsOneWidget);
    final nombre = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Nombre del producto',
    );
    await tester.enterText(nombre, 'Tela');

    final unidadCompra = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField &&
          w.decoration.labelText == 'Unidad en que se compra (opcional)',
    );
    await tester.tap(unidadCompra);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Cajas').last);
    await tester.pumpAndSettle();

    final factor = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.labelText ?? '').startsWith('Cuánto trae cada'),
    );
    await tester.enterText(factor, '12');
    final precio = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.labelText == 'Precio sugerido de venta',
    );
    await tester.enterText(precio, '20');
    await tester.tap(find.text('Agregar producto').last);
    await tester.pumpAndSettle();

    final producto = estado.productosActivos.single;
    expect(producto.nombre, 'Tela');
    expect(producto.unidadCompra, '12');
    expect(producto.factorCompra, 12000);
    expect(producto.precioSugerido, 2000);
    expect(
      find.textContaining('El inventario recibirá 12 und'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    estado.dispose();
  });

  testWidgets('No es mercadería sigue permitiendo registrar servicios', (
    tester,
  ) async {
    final repo = RepositorioDemo();
    final estado = EstadoCaja(repo);
    await estado.cargar();
    estado.ultimoMedio = MedioPago.yape;
    estado.ultimaCategoriaIngreso = 'ventas';

    await abrir(tester, estado, Tipo.entro);
    final monto = find.byType(TextField).first;
    await tester.ensureVisible(monto);
    await tester.enterText(monto, '100');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('No es mercadería'), findsOneWidget);
    await tester.tap(find.text('No es mercadería'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Es un servicio'), findsOneWidget);
    expect(find.text('Agregar producto'), findsNothing);

    await alVoucher(tester);
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final venta = (await repo.listar()).single;
    expect(venta.costoCentavos, 0);
    expect(venta.mercaderiaId, isNull);
    expect(estado.leerMercaderia(venta)!.esMercaderia, isFalse);
    expect(await repo.leerLineasAlmacen(), isEmpty);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    estado.dispose();
  });
}
