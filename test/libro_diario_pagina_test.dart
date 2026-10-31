import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/core/tema.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/igv.dart';
import 'package:mi_caja/dominio/inventario.dart';
import 'package:mi_caja/dominio/libro_diario.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/ui/libro_diario/libro_diario_pagina.dart';
import 'package:mi_caja/ui/shell/secciones.dart';

/// La pantalla del Libro Diario, con los 4 ejemplos de la exposición como
/// datos: compra de tela, venta, alquiler y luz.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_PE');
    // Sin la tipografía de la app, el texto de las pruebas mide mucho más
    // ancho que el real y los desbordes que aparecen no existen en el celular.
    final cargador = FontLoader('Jakarta');
    for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      cargador.addFont(
        File('assets/fonts/PlusJakartaSans-$peso.ttf')
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)),
      );
    }
    await cargador.load();
    Pcge.cargarDeTexto(File('assets/pcge.json').readAsStringSync());
  });

  setUp(() => Categoria.registrarPropias(const []));

  const negocio = Negocio(razonSocial: 'LIBERTAD SA', documento: '11902816511');

  Movimiento mov(int n, Tipo tipo, int centavos, String categoria) {
    final cat = Categoria.porId(categoria);
    final f = DateTime(2026, 10, 10 + n, 10);
    return Movimiento(
      id: 'm$n',
      numero: n,
      tipo: tipo,
      centavos: centavos,
      categoriaId: categoria,
      concepto: '',
      medio: MedioPago.efectivo,
      fecha: f,
      creadoEn: f,
      actualizadoEn: f,
      cuentaAsociada: cat.cuentaAsociada,
      igvCentavos: cat.afectoIgv ? Igv.desagregar(centavos).igv : 0,
      sync: EstadoSync.local,
    );
  }

  final ejemplos = [
    mov(1, Tipo.salio, 118000, 'mercaderia'),
    mov(2, Tipo.entro, 236000, 'ventas'),
    mov(3, Tipo.salio, 94400, 'alquiler'),
    mov(4, Tipo.salio, 17700, 'luz'),
  ];

  DatoMercaderia? tela(Movimiento m) =>
      DatoMercaderia(id: 'tela', nombre: 'tela', costoCentavos: 100000);

  LibroDiario armar(List<Movimiento> movs, LeerMercaderia leer) =>
      LibroDiario.armar(
        negocio: negocio,
        movimientos: movs,
        desde: DateTime(2026, 10, 1),
        hasta: DateTime(2026, 10, 31),
        mercaderia: leer,
      );

  Future<void> montar(
    WidgetTester tester,
    List<Movimiento> movs,
    LeerMercaderia leer, {
    required Size tamanio,
  }) async {
    tester.view.physicalSize = tamanio;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: construirTema(),
        locale: const Locale('es', 'PE'),
        supportedLocales: const [Locale('es', 'PE'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: LibroDiarioVista(
            libro: armar(movs, leer),
            inventario: InventarioMercaderias.de(movs, leer: leer),
            periodo: null,
            onPeriodo: (_) {},
            onElegirFechas: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('el menú', () {
    test('Libro diario es una sección, antes de Formatos oficiales', () {
      expect(Seccion.todas[Seccion.iLibroDiario], Seccion.libroDiario);
      expect(Seccion.todas[Seccion.iFormatos], Seccion.formatos);
      expect(Seccion.iLibroDiario, lessThan(Seccion.iFormatos));
      expect(Seccion.libroDiario.etiqueta, 'Libro diario');
      expect(Seccion.libroDiario.bajada, isNotEmpty);
    });
  });

  group('en celular de 390 px', () {
    // Alta a propósito: así la lista construye todas las tarjetas.
    const celular = Size(390, 2600);

    testWidgets('muestra los 4 ejemplos, el resumen y el sello', (t) async {
      await montar(t, ejemplos, tela, tamanio: celular);

      expect(t.takeException(), isNull);
      for (final n in ['001', '002', '003', '004']) {
        expect(find.text(n, skipOffstage: false), findsOneWidget);
      }
      expect(find.text('Cuadra'), findsOneWidget);
      expect(find.text('Operaciones'), findsWidgets);
      expect(find.text('12'), findsOneWidget); // 4 operaciones × 3 asientos
      expect(find.text('S/ 12,272.00', skipOffstage: false), findsNWidgets(2));
    });

    testWidgets('una tarjeta se despliega en sus 3 asientos', (t) async {
      await montar(t, ejemplos, tela, tamanio: celular);

      await t.ensureVisible(find.text('Por la compra de tela'));
      await t.tap(find.text('Por la compra de tela'));
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.text('Asiento 1'), findsOneWidget);
      expect(find.text('Asiento 2'), findsOneWidget);
      expect(find.text('Asiento 3'), findsOneWidget);
      expect(find.text('40 › 401 › 4011 › 40111'), findsOneWidget);
      expect(find.text('20 › 201 › 2011 › 20111'), findsOneWidget);
      expect(
        find.text('Por la variación de inventarios (tela)'),
        findsOneWidget,
      );
    });

    testWidgets('avisa cuando una venta antigua no tiene costo', (t) async {
      await montar(t, [ejemplos[1]], sinDatoDeMercaderia, tamanio: celular);

      expect(find.text('Sin asiento 2'), findsOneWidget);
      expect(find.textContaining('1 venta sin costo anotado'), findsOneWidget);
    });

    testWidgets('el panel de mercaderías da comprado, costo y saldo', (
      t,
    ) async {
      await montar(t, ejemplos, tela, tamanio: celular);

      expect(find.text('Mercaderías'), findsOneWidget);
      expect(find.text('tela'), findsWidgets);
      expect(find.text('Comprado'), findsOneWidget);
      expect(find.text('Costo vendido'), findsOneWidget);
      // Compró 1,000 sin IGV y vendió con costo 1,000: el saldo queda en cero.
      expect(find.text('S/ 0.00'), findsOneWidget);
    });
  });

  group('en escritorio', () {
    testWidgets('pone el panel al costado y no desborda', (t) async {
      await montar(t, ejemplos, tela, tamanio: const Size(1280, 800));

      expect(t.takeException(), isNull);
      final panel = t.getTopLeft(find.text('Mercaderías'));
      final primera = t.getTopLeft(find.text('001'));
      expect(panel.dx, greaterThan(primera.dx));
    });

    testWidgets('sin operaciones lo dice', (t) async {
      await montar(
        t,
        const [],
        sinDatoDeMercaderia,
        tamanio: const Size(1280, 800),
      );

      expect(find.text('Sin operaciones en este período'), findsOneWidget);
    });
  });

  group('Formatos oficiales', () {
    test('ya no trae el bloque del Libro Diario', () {
      final fuente = File('lib/ui/formatos/formatos_pagina.dart')
          .readAsStringSync();
      expect(fuente, isNot(contains('Para el Libro Diario')));
      expect(fuente, isNot(contains('BloqueAsiento')));
      expect(fuente, isNot(contains('AsientoResumen')));
    });
  });
}
