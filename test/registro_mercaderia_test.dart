import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    if (const String.fromEnvironment('P2_CAPTURAS').isNotEmpty) {
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

  Future<void> abrir(
    WidgetTester tester,
    EstadoCaja estado,
    Tipo tipo,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: estado,
        child: RepaintBoundary(
          key: const ValueKey('p2-captura'),
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
      ),
    );
    await tester.tap(find.text('Abrir registro'));
    await tester.pumpAndSettle();
  }

  /// Por Yape, después de la mercadería viene el voucher: lleva su N° de
  /// operación.
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

  testWidgets('crear mercadería y guardar compra desde el formulario', (
    tester,
  ) async {
    final repo = RepositorioDemo();
    final estado = EstadoCaja(repo);
    await estado.cargar();
    estado.ultimoMedio = MedioPago.yape;
    estado.ultimaCategoriaEgreso = 'mercaderia';
    await abrir(tester, estado, Tipo.salio, const Size(933, 600));
    final monto = find.byType(TextField).first;
    await tester.ensureVisible(monto);
    await tester.enterText(monto, '118,00');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // El paso de mercadería va entre los datos y el pago.
    expect(find.text('¿Qué mercadería?'), findsOneWidget);
    await tester.ensureVisible(find.text('Nuevo tipo'));
    await tester.tap(find.text('Nuevo tipo'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva mercadería'), findsOneWidget);
    final nombre = find.byType(TextField).last;
    await tester.enterText(nombre, 'Pintura');
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(estado.mercaderias.single.nombre, 'Pintura');
    await alVoucher(tester);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byType(RegistroHoja), findsNothing);
    final compra = (await repo.listar()).single;
    expect(compra.descripcionFormato, 'Compra de Pintura');
    expect(compra.baseCentavos, 10000);
    expect(compra.costoCentavos, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    estado.dispose();
  });

  for (final size in [const Size(933, 600), const Size(390, 844)]) {
    testWidgets(
      'venta con costo, advertencia y servicio en ${size.width.toInt()}px',
      (tester) async {
        final repo = RepositorioDemo();
        final tela = await repo.agregarMercaderia('Tela');
        final estado = EstadoCaja(repo);
        await estado.cargar();
        estado.ultimoMedio = MedioPago.yape;
        estado.ultimaCategoriaIngreso = 'ventas';
        await abrir(tester, estado, Tipo.entro, size);
        final monto = find.byType(TextField).first;
        await tester.ensureVisible(monto);
        await tester.enterText(monto, '59');
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(find.text('¿Qué mercadería?'), findsOneWidget);
        expect(find.text('No es mercadería'), findsOneWidget);
        final tipo = find.byType(DropdownButtonFormField<String>);
        await tester.ensureVisible(tipo);
        await tester.tap(tipo);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tela').last);
        await tester.pumpAndSettle();
        final costo = find.byKey(const ValueKey('costo-mercaderia'));
        await tester.ensureVisible(costo);
        await tester.enterText(costo, '40,50');
        await tester.pumpAndSettle();
        expect(find.text('Saldo disponible'), findsOneWidget);
        expect(find.textContaining('El costo supera'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Solo genera vistas cuando se pide; la prueba normal no escribe imágenes.
        const capturas = String.fromEnvironment('P2_CAPTURAS');
        if (capturas.isNotEmpty) {
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('p2-captura')),
          );
          await tester.runAsync(() async {
            final imagen = await boundary.toImage(pixelRatio: 1);
            final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
            await Directory(capturas).create(recursive: true);
            await File('$capturas/venta-${size.width.toInt()}.png')
                .writeAsBytes(png!.buffer.asUint8List());
            imagen.dispose();
          });
        }

        // "No es mercadería" no pide costo ni descuenta inventario.
        await tester.ensureVisible(find.text('No es mercadería'));
        await tester.tap(find.text('No es mercadería'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('costo-mercaderia')), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        await alVoucher(tester);
        await tester.ensureVisible(find.text('Guardar'));
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        final venta = (await repo.listar()).single;
        expect(venta.costoCentavos, 0);
        expect(venta.mercaderiaId, isNull);
        expect(estado.leerMercaderia(venta)!.esMercaderia, isFalse);
        expect(await repo.mercaderiaPorId(tela.id), isNotNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        estado.dispose();
      },
    );
  }
}
