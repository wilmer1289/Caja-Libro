import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/core/tema.dart';
import 'package:mi_caja/datos/repositorio/repositorio_demo.dart';
import 'package:mi_caja/dominio/almacen.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/dominio/reglas_asiento.dart';
import 'package:mi_caja/dominio/reglas_mercaderia.dart';
import 'package:mi_caja/estado/estado_caja.dart';
import 'package:mi_caja/ui/historial/acciones_movimiento.dart';
import 'package:mi_caja/ui/registro/linea_producto.dart';
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

  Future<void> montar(
    WidgetTester tester,
    EstadoCaja estado, {
    required Widget home,
  }) async {
    tester.view.physicalSize = const Size(933, 760);
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
          home: home,
        ),
      ),
    );
  }

  Future<void> abrirRegistro(WidgetTester tester) async {
    await tester.tap(find.text('Abrir registro'));
    await tester.pumpAndSettle();
  }

  Finder campo(String etiqueta) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == etiqueta,
  );

  Finder campoPorHint(String prefijo) => find.byWidgetPredicate(
    (w) => w is TextField && (w.decoration?.hintText ?? '').startsWith(prefijo),
  );

  Finder selectorProducto() => find.byWidgetPredicate(
    (w) => w is DropdownButtonFormField && w.decoration.labelText == 'Producto',
  );

  Future<void> elegirProducto(
    WidgetTester tester,
    String nombre, {
    bool ultimaLinea = false,
  }) async {
    final selector = selectorProducto();
    await tester.ensureVisible(ultimaLinea ? selector.last : selector.first);
    await tester.tap(ultimaLinea ? selector.last : selector.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(nombre).last);
    await tester.pumpAndSettle();
  }

  Future<void> completarVoucher(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    final numero = campoPorHint('El número del voucher');
    await tester.ensureVisible(numero);
    if (tester.widget<TextField>(numero).controller?.text.isEmpty ?? true) {
      await tester.enterText(numero, '04512378');
    }
    await tester.pumpAndSettle();
  }

  Future<void> guardarDesdeVoucher(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'compra dos productos, aplica descuento y convierte 10 cajas en 120 unidades; luego vende cantidad con costo de kardex',
    (tester) async {
      final repo = RepositorioDemo();
      final tela = await repo.guardarProducto(
        nombre: 'Tela',
        unidad: '07',
        unidadCompra: '12',
        factorCompra: 12000,
        precioSugerido: 2000,
      );
      await repo.guardarProducto(nombre: 'Pintura', precioSugerido: 3000);
      final estado = EstadoCaja(repo);
      await estado.cargar();
      estado.ultimoMedio = MedioPago.yape;
      estado.ultimaCategoriaEgreso = 'mercaderia';
      // Primero una compra (Salió) y después una venta (Entró).
      var tipo = Tipo.salio;

      await montar(
        tester,
        estado,
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
      );
      await abrirRegistro(tester);

      await tester.enterText(find.byType(TextField).first, '200');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Productos'), findsWidgets);

      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      await elegirProducto(tester, 'Tela');
      await tester.enterText(campo('Cantidad').first, '10');
      await tester.enterText(campo('Importe de la línea').first, '100');
      await tester.enterText(campo('Descuento').first, '10');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('El inventario recibirá 120 und'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Costo unitario resultante: S/ 0.75'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Agregar producto'));
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      await elegirProducto(tester, 'Pintura', ultimaLinea: true);
      await tester.enterText(campo('Cantidad').last, '2');
      await tester.enterText(campo('Importe de la línea').last, '50');
      await tester.pumpAndSettle();
      expect(find.text('Usar S/ 165.20 como monto'), findsOneWidget);
      await tester.ensureVisible(find.text('Usar S/ 165.20 como monto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar S/ 165.20 como monto'));
      await tester.pumpAndSettle();
      expect(find.text('Las líneas cuadran con el monto.'), findsOneWidget);

      await tester.enterText(campo('Serie').first, 'F001');
      await tester.enterText(campo('Número').first, '123');
      await completarVoucher(tester);
      await guardarDesdeVoucher(tester);

      final compra = (await repo.listar()).single;
      expect(compra.baseCentavos, 14000);
      expect(compra.igvCentavos, 2520);
      expect(compra.centavos, 16520);
      expect(compra.comprobante?.tipo, '01');
      expect(compra.comprobante?.serie, 'F001');
      expect(compra.comprobante?.numero, '123');
      expect(compra.costoCentavos, isNull);
      final entradas = await repo.leerLineasAlmacen();
      expect(entradas.length, 2);
      final lineaTela = entradas.singleWhere((l) => l.mercaderiaId == tela.id);
      expect(lineaTela.cantidad, 120000);
      expect(lineaTela.importe, 9000);
      expect(lineaTela.descuento, 1000);
      expect(estado.stockDisponible(tela.id), 120000);

      // La venta usa el precio sugerido, el stock del kardex y su costo
      // promedio; no se escribe un costo manual.
      estado.ultimaCategoriaIngreso = 'ventas';
      tipo = Tipo.entro;
      await tester.tap(find.text('Abrir registro'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '47.20');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      await elegirProducto(tester, 'Tela');
      expect(
        tester
            .widget<TextField>(campo('Precio por unidad').first)
            .controller!
            .text,
        '20.00',
      );
      await tester.enterText(campo('Cantidad').first, '2');
      await tester.pumpAndSettle();
      expect(find.textContaining('Stock disponible'), findsOneWidget);
      expect(
        find.textContaining('Costo S/ 1.50, lo calcula el kardex'),
        findsOneWidget,
      );
      expect(find.text('Las líneas cuadran con el monto.'), findsOneWidget);

      await completarVoucher(tester);
      await guardarDesdeVoucher(tester);
      final movimientos = await repo.listar();
      final venta = movimientos.singleWhere((m) => m.tipo == Tipo.entro);
      expect(venta.centavos, 4720);
      expect(venta.baseCentavos, 4000);
      // El costo de una venta con líneas se consulta al kardex; no se guarda
      // una copia en el movimiento que pueda quedar obsoleta.
      expect(venta.costoCentavos, isNull);
      expect(venta.comprobante?.tipo, '03');
      expect(estado.stockDisponible(tela.id), 118000);
      expect(estado.leerMercaderia(venta)?.costoCentavos, 150);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      estado.dispose();
    },
  );

  testWidgets(
    'una compra con una sola línea toma el monto, incluso después de quitar otra línea',
    (tester) async {
      final repo = RepositorioDemo();
      await repo.guardarProducto(nombre: 'Tela');
      await repo.guardarProducto(nombre: 'Pintura');
      final estado = EstadoCaja(repo);
      await estado.cargar();
      estado.ultimoMedio = MedioPago.yape;
      estado.ultimaCategoriaEgreso = 'mercaderia';

      await montar(
        tester,
        estado,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => RegistroHoja.abrir(context, Tipo.salio),
                child: const Text('Abrir registro'),
              ),
            ),
          ),
        ),
      );
      await abrirRegistro(tester);
      await tester.enterText(find.byType(TextField).first, '118');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      await elegirProducto(tester, 'Tela');
      expect(
        tester
            .widget<TextField>(campo('Importe de la línea').first)
            .controller!
            .text,
        '100.00',
      );

      await tester.ensureVisible(find.text('Agregar producto'));
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      await elegirProducto(tester, 'Pintura', ultimaLinea: true);
      expect(find.byTooltip('Quitar producto'), findsNWidgets(2));

      await tester.ensureVisible(find.byTooltip('Quitar producto').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar producto').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Quitar producto'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(campo('Importe de la línea').first)
            .controller!
            .text,
        '100.00',
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      estado.dispose();
    },
  );

  testWidgets('una venta mayor que el stock no permite continuar ni guardar', (
    tester,
  ) async {
    final repo = RepositorioDemo();
    await repo.guardarProducto(nombre: 'Sin stock', precioSugerido: 1000);
    final estado = EstadoCaja(repo);
    await estado.cargar();
    estado.ultimoMedio = MedioPago.yape;
    estado.ultimaCategoriaIngreso = 'ventas';

    await montar(
      tester,
      estado,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => RegistroHoja.abrir(context, Tipo.entro),
              child: const Text('Abrir registro'),
            ),
          ),
        ),
      ),
    );
    await abrirRegistro(tester);
    await tester.enterText(find.byType(TextField).first, '11.80');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    await elegirProducto(tester, 'Sin stock');
    expect(find.textContaining('Stock disponible'), findsOneWidget);
    expect(
      find.textContaining('No hay suficiente Sin stock: hay 0'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Productos'), findsWidgets);
    expect(
      find.textContaining('No hay suficiente Sin stock: hay 0'),
      findsWidgets,
    );
    expect(await repo.listar(), isEmpty);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    estado.dispose();
  });

  testWidgets(
    'el paso Productos recibe líneas ya preparadas por el almacenero',
    (tester) async {
      final repo = RepositorioDemo();
      final producto = await repo.guardarProducto(
        nombre: 'Tela',
        unidad: '07',
        unidadCompra: '12',
        factorCompra: 12000,
      );
      final estado = EstadoCaja(repo);
      await estado.cargar();
      estado.ultimoMedio = MedioPago.yape;
      estado.ultimaCategoriaEgreso = 'mercaderia';

      await montar(
        tester,
        estado,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => RegistroHoja.abrir(
                  context,
                  Tipo.salio,
                  lineasIniciales: [
                    LineaNueva(
                      mercaderiaId: producto.id,
                      cantidad: 10000,
                      importe: 10000,
                      enUnidadDeCompra: true,
                    ),
                  ],
                ),
                child: const Text('Abrir registro'),
              ),
            ),
          ),
        ),
      );
      await abrirRegistro(tester);
      await tester.enterText(find.byType(TextField).first, '118');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('El inventario recibirá 120 und'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Costo unitario resultante: S/ 0.83'),
        findsOneWidget,
      );
      expect(find.text('Agregar producto'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      estado.dispose();
    },
  );

  testWidgets('una compra marcada sin IGV cuadra el importe con las líneas', (
    tester,
  ) async {
    final repo = RepositorioDemo();
    await repo.guardarProducto(nombre: 'Pintura');
    final estado = EstadoCaja(repo);
    await estado.cargar();
    estado.ultimoMedio = MedioPago.yape;
    estado.ultimaCategoriaEgreso = 'mercaderia';

    await montar(
      tester,
      estado,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => RegistroHoja.abrir(context, Tipo.salio),
              child: const Text('Abrir registro'),
            ),
          ),
        ),
      ),
    );
    await abrirRegistro(tester);
    await tester.enterText(find.byType(TextField).first, '50');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Esta compra no tiene IGV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    await elegirProducto(tester, 'Pintura');
    await tester.enterText(campo('Importe de la línea').first, '50');
    await tester.pumpAndSettle();
    expect(find.text('Las líneas cuadran con el monto.'), findsOneWidget);
    expect(find.textContaining('Costo unitario resultante'), findsOneWidget);

    await completarVoucher(tester);
    await guardarDesdeVoucher(tester);
    final compra = (await repo.listar()).single;
    expect(compra.centavos, 5000);
    expect(compra.igvCentavos, 0);
    expect(compra.sinIgv, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    estado.dispose();
  });

  testWidgets(
    'avisa cuando la fecha es anterior al último movimiento del producto',
    (tester) async {
      final repo = RepositorioDemo();
      final producto = await repo.guardarProducto(nombre: 'Tela');
      final ayer = DateTime.now().subtract(const Duration(days: 1));
      await repo.registrar(
        tipo: Tipo.salio,
        centavos: 11800,
        categoriaId: 'mercaderia',
        concepto: 'Compra de Tela',
        medio: MedioPago.yape,
        fecha: ayer,
        lineas: [
          LineaNueva(
            mercaderiaId: producto.id,
            cantidad: 10000,
            importe: 10000,
          ),
        ],
      );
      final estado = EstadoCaja(repo);
      await estado.cargar();
      final fechaAnterior = DateTime.now().subtract(const Duration(days: 2));
      final borrador = LineaProductoBorrador(
        mercaderiaId: producto.id,
        cantidad: '1',
        valor: '10',
      );

      await montar(
        tester,
        estado,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: LineaProducto(
              indice: 0,
              borrador: borrador,
              productos: estado.productosActivos,
              compra: false,
              fecha: fechaAnterior,
              stockDisponible: (id) =>
                  estado.stockDisponible(id, fecha: fechaAnterior),
              ultimaFecha: (id) => estado.ultimaFechaDe(id),
              costoDeSalida: (id, cantidad) {
                try {
                  return estado.kardex.costoDeSalida(
                    id,
                    cantidad,
                    fechaAnterior,
                  );
                } on StateError {
                  return null;
                }
              },
              onCambio: () {},
              onSeleccionar: (_) {},
              onQuitar: () {},
            ),
          ),
        ),
      );

      expect(
        find.textContaining('La fecha es anterior al último movimiento'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      borrador.dispose();
      estado.dispose();
    },
  );

  test('la venta de exportación no lleva IGV y usa la cuenta 70111', () async {
    final repo = RepositorioDemo();
    final producto = await repo.guardarProducto(nombre: 'Cacao');
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    await repo.registrar(
      tipo: Tipo.salio,
      centavos: 11800,
      categoriaId: 'mercaderia',
      concepto: 'Compra de Cacao',
      medio: MedioPago.yape,
      fecha: ayer,
      lineas: [
        LineaNueva(mercaderiaId: producto.id, cantidad: 10000, importe: 10000),
      ],
    );
    final venta = await repo.registrar(
      tipo: Tipo.entro,
      centavos: 2000,
      categoriaId: 'ventas',
      concepto: 'Exportación de Cacao',
      medio: MedioPago.yape,
      fecha: DateTime.now(),
      lineas: [
        LineaNueva(mercaderiaId: producto.id, cantidad: 1000, importe: 2000),
      ],
      exportacion: true,
    );

    expect(venta.exportacion, isTrue);
    expect(venta.igvCentavos, 0);
    expect(venta.comprobante?.tipo, '01');
    expect(ReglasAsiento.para(venta).resultado, '70111');
    expect(
      ReglasMercaderia.comprobanteDeVenta(
        documentoCliente: null,
        exportacion: true,
      ).tipo,
      '01',
    );
    expect(
      ReglasMercaderia.comprobanteDeVenta(
        documentoCliente: '12345678',
        exportacion: false,
      ).tipo,
      '03',
    );
    expect(
      ReglasMercaderia.comprobanteDeVenta(
        documentoCliente: '20123456789',
        exportacion: false,
      ).tipo,
      '01',
    );
    expect(
      () => ReglasMercaderia.comprobanteDeVenta(
        documentoCliente: '123456789',
        exportacion: false,
      ),
      throwsArgumentError,
    );
    expect(
      () => ReglasMercaderia.validarComprobanteDeVenta(
        const Comprobante(tipo: '03', serie: 'B001', numero: '1'),
        documentoCliente: '20123456789',
        exportacion: false,
      ),
      throwsArgumentError,
    );
  });

  testWidgets('la opción Venta de exportación guarda la venta sin IGV', (
    tester,
  ) async {
    final repo = RepositorioDemo();
    final producto = await repo.guardarProducto(
      nombre: 'Cacao',
      precioSugerido: 2000,
    );
    await repo.registrar(
      tipo: Tipo.salio,
      centavos: 11800,
      categoriaId: 'mercaderia',
      concepto: 'Compra de Cacao',
      medio: MedioPago.yape,
      fecha: DateTime.now().subtract(const Duration(days: 1)),
      lineas: [
        LineaNueva(mercaderiaId: producto.id, cantidad: 10000, importe: 10000),
      ],
    );
    final estado = EstadoCaja(repo);
    await estado.cargar();
    estado.ultimoMedio = MedioPago.yape;
    estado.ultimaCategoriaIngreso = 'ventas';

    await montar(
      tester,
      estado,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => RegistroHoja.abrir(context, Tipo.entro),
              child: const Text('Abrir registro'),
            ),
          ),
        ),
      ),
    );
    await abrirRegistro(tester);
    await tester.enterText(find.byType(TextField).first, '20');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    await elegirProducto(tester, 'Cacao');
    await tester.ensureVisible(find.text('Venta de exportación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Venta de exportación'));
    await tester.pumpAndSettle();
    expect(find.text('Las líneas cuadran con el monto.'), findsOneWidget);

    await completarVoucher(tester);
    await guardarDesdeVoucher(tester);
    final venta = (await repo.listar()).singleWhere(
      (m) => m.tipo == Tipo.entro,
    );
    expect(venta.exportacion, isTrue);
    expect(venta.igvCentavos, 0);
    expect(venta.comprobante?.tipo, '01');
    expect(ReglasAsiento.para(venta).resultado, '70111');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    estado.dispose();
  });

  testWidgets(
    'Historial permite anular y volver a registrar en un mes abierto',
    (tester) async {
      final repo = RepositorioDemo();
      final producto = await repo.guardarProducto(
        nombre: 'Tela',
        unidadCompra: '12',
        factorCompra: 12000,
      );
      final original = await repo.registrar(
        tipo: Tipo.salio,
        centavos: 11800,
        categoriaId: 'mercaderia',
        concepto: 'Compra original',
        medio: MedioPago.yape,
        fecha: DateTime.now(),
        numeroTransaccion: '04512378',
        lineas: [
          LineaNueva(
            mercaderiaId: producto.id,
            cantidad: 10000,
            importe: 10000,
            enUnidadDeCompra: true,
          ),
        ],
      );
      final estado = EstadoCaja(repo);
      await estado.cargar();

      await montar(
        tester,
        estado,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => AccionesMovimiento.abrir(context, original),
                child: const Text('Abrir acciones'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir acciones'));
      await tester.pumpAndSettle();
      expect(find.text('Anular y volver a registrar'), findsOneWidget);
      await tester.tap(find.text('Anular y volver a registrar'));
      await tester.pumpAndSettle();

      // El original abre el formulario con el monto, el producto y las cajas.
      // El detalle está en el primer paso (Datos); los productos, en el
      // segundo.
      expect(find.text('Productos'), findsWidgets);
      final detalle = campoPorHint('Ej. Venta del día');
      await tester.enterText(detalle, 'Compra corregida');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('El inventario recibirá 120 und'),
        findsOneWidget,
      );
      await completarVoucher(tester);
      await guardarDesdeVoucher(tester);

      expect(estado.anulados.any((m) => m.id == original.id), isTrue);
      final nueva = estado.movimientos.single;
      expect(nueva.id, isNot(original.id));
      expect(nueva.concepto, 'Compra corregida');
      expect(estado.stockDisponible(producto.id), 120000);
      expect(find.text('Anular y volver a registrar'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      estado.dispose();
    },
  );

  testWidgets('Historial no ofrece corrección en un mes cerrado', (
    tester,
  ) async {
    final repo = RepositorioDemo();
    final producto = await repo.guardarProducto(nombre: 'Pintura');
    final original = await repo.registrar(
      tipo: Tipo.salio,
      centavos: 11800,
      categoriaId: 'mercaderia',
      concepto: 'Compra de septiembre',
      medio: MedioPago.yape,
      fecha: DateTime(2026, 9, 10),
      lineas: [
        LineaNueva(mercaderiaId: producto.id, cantidad: 1000, importe: 10000),
      ],
    );
    final estado = EstadoCaja(repo);
    await estado.cargar();
    await estado.cerrarMes(2026, 9);

    await montar(
      tester,
      estado,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => AccionesMovimiento.abrir(context, original),
              child: const Text('Abrir acciones'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir acciones'));
    await tester.pumpAndSettle();
    expect(find.text('Anular y volver a registrar'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    estado.dispose();
  });
}
