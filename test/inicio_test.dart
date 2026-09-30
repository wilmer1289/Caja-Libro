import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/core/tema.dart';

import 'dart:convert';
import 'dart:io';

import 'package:mi_caja/datos/export/impresion.dart';
import 'package:mi_caja/datos/repositorio/repositorio_movimientos.dart';
import 'package:mi_caja/dominio/boleta.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/efectivo.dart';
import 'package:mi_caja/dominio/fondo.dart';
import 'package:mi_caja/dominio/jornada.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/estado/estado_caja.dart';
import 'package:mi_caja/ui/inicio.dart';
import 'package:mi_caja/ui/negocio/negocio_pagina.dart';
import 'package:mi_caja/ui/registro/registro_hoja.dart';
import 'package:provider/provider.dart';

/// Repositorio de mentira: responde desde una lista en memoria, sin SQLite.
///
/// Se puede extender la clase real porque el DAO se crea pero no se usa hasta
/// la primera consulta, y acá esas consultas nunca llegan a la base.
class RepositorioFalso extends RepositorioMovimientos {
  RepositorioFalso(this._datos, {Negocio? negocio})
    : _negocio = negocio ?? Negocio.vacio;

  final List<Movimiento> _datos;
  Negocio _negocio;

  // Sin esto, la carga se queda esperando a SQLite: en una prueba de widgets
  // los canales de plataforma no responden.
  @override
  Future<Negocio> leerNegocio() async => _negocio;

  @override
  Future<void> guardarNegocio(Negocio negocio) async => _negocio = negocio;

  @override
  Future<List<Movimiento>> listar({Cuenta? cuenta}) async {
    if (cuenta == null) return _datos;
    return _datos.where((m) => m.cuenta == cuenta).toList();
  }

  final categorias = <Categoria>[];

  /// Lo que se guardó desde el formulario, para revisarlo en la prueba.
  final registrados = <Movimiento>[];

  @override
  Future<List<Categoria>> leerCategoriasPropias() async => List.of(categorias);

  /// Las cajas, de la más vieja a la más nueva.
  final cajas = <Jornada>[];

  /// El efectivo del negocio; null mientras no se cuente.
  FondoNegocio? fondo;

  @override
  Future<FondoNegocio?> leerFondo() async => fondo;

  @override
  Future<FondoNegocio> contarFondo({
    required Conteo conteo,
    required String usuario,
  }) async => fondo = FondoNegocio(
    conteo: conteo,
    contadoEn: DateTime.now(),
    usuario: usuario,
  );

  @override
  Future<FondoNegocio> corregirFondo({
    required Conteo conteo,
    required String usuario,
  }) async =>
      fondo = fondo!.corregir(conteo, usuario: usuario, en: DateTime.now());

  /// Una caja abierta desde hace un rato, para registrar en efectivo.
  void abrirUnaCaja() {
    fondo ??= FondoNegocio(
      conteo: const Conteo({10000: 5}),
      contadoEn: DateTime.now().subtract(const Duration(hours: 3)),
      usuario: 'usuario',
    );
    cajas.add(
      Jornada(
        id: 'caja-${cajas.length + 1}',
        numero: cajas.length + 1,
        abiertaEn: DateTime.now().subtract(const Duration(hours: 2)),
        apertura: 10000,
        inicio: InicioCaja.primera,
        responsable: 'Ana Ruiz',
        usuario: 'usuario',
      ),
    );
  }

  @override
  Future<List<Jornada>> leerJornadas() async => List.of(cajas.reversed);

  @override
  Future<Jornada> abrirCaja({
    required int apertura,
    required InicioCaja inicio,
    required String responsable,
    required String usuario,
    Conteo? conteo,
    int anterior = 0,
  }) async {
    final caja = Jornada(
      id: 'caja-${cajas.length + 1}',
      numero: cajas.length + 1,
      abiertaEn: DateTime.now(),
      apertura: apertura,
      conteoApertura: conteo,
      inicio: inicio,
      anterior: anterior,
      responsable: responsable.trim(),
      usuario: usuario,
    );
    cajas.add(caja);
    return caja;
  }

  @override
  Future<void> guardarCierre(Jornada caja) async => _reemplazar(caja);

  @override
  Future<void> guardarAjuste(Jornada caja) async => _reemplazar(caja);

  void _reemplazar(Jornada caja) {
    final i = cajas.indexWhere((c) => c.id == caja.id);
    cajas[i] = caja;
  }

  @override
  Future<Movimiento> emitirRecibo(
    Movimiento movimiento, {
    required String tesorero,
  }) async => movimiento.copiarCon(numeroRecibo: 99, tesorero: tesorero);

  @override
  Future<Categoria> agregarCategoria({
    required String etiqueta,
    required Tipo tipo,
    required String cuenta,
    bool afectoIgv = false,
  }) async {
    final nueva = Categoria(
      id: 'propia_${categorias.length}',
      etiqueta: etiqueta.trim(),
      tipo: tipo,
      grupo: GrupoCategoria.propias,
      cuentaAsociada: cuenta,
      afectoIgv: afectoIgv,
      comun: true,
      propia: true,
    );
    categorias.add(nueva);
    return nueva;
  }

  @override
  Future<Movimiento> registrar({
    required Tipo tipo,
    required int centavos,
    required String categoriaId,
    required String concepto,
    required MedioPago medio,
    required DateTime fecha,
    String? contraparte,
    String? documentoContraparte,
    String? numeroTransaccion,
    String? cuentaAsociada,
    bool? conIgv,
    String? rutaFoto,
    bool conRecibo = false,
    String? tesorero,
    DetalleEfectivo? detalleEfectivo,
  }) async {
    final categoria = Categoria.porId(categoriaId);
    final m = Movimiento(
      id: 'nuevo-${registrados.length}',
      numero: 100 + registrados.length,
      tipo: tipo,
      centavos: centavos,
      categoriaId: categoriaId,
      concepto: concepto,
      medio: medio,
      fecha: fecha,
      // Como el real: la hora en que se anotó, que es la que decide en qué
      // caja entra.
      creadoEn: DateTime.now(),
      actualizadoEn: DateTime.now(),
      cuentaAsociada: cuentaAsociada,
      contraparte: contraparte,
      documentoContraparte: documentoContraparte,
      numeroRecibo: conRecibo ? registrados.length + 1 : null,
      numeroBoleta: Boleta.corresponde(categoria)
          ? registrados.length + 1
          : null,
      tesorero: conRecibo ? tesorero : null,
      detalleEfectivo: detalleEfectivo,
      sync: EstadoSync.local,
    );
    registrados.add(m);
    return m;
  }
}

Movimiento mov({
  required Tipo tipo,
  required int centavos,
  MedioPago medio = MedioPago.efectivo,
}) {
  final cuando = DateTime.now();
  return Movimiento(
    id: 'id-$centavos-${tipo.name}-${medio.name}',
    numero: 1,
    tipo: tipo,
    centavos: centavos,
    categoriaId: tipo == Tipo.entro ? 'ventas' : 'mercaderia',
    concepto: 'Venta del día',
    medio: medio,
    fecha: cuando,
    creadoEn: cuando,
    actualizadoEn: cuando,
    sync: EstadoSync.local,
  );
}

Widget armar(List<Movimiento> datos, {RepositorioFalso? repo}) {
  return ChangeNotifierProvider(
    create: (_) => EstadoCaja(repo ?? RepositorioFalso(datos)),
    child: MaterialApp(
      theme: construirTema(),
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Inicio(usuario: 'usuario', onSalir: () {}),
    ),
  );
}

/// Va a una sección. En el celular primero hay que abrir el menú de la
/// derecha; en escritorio la barra lateral ya está a la vista.
Future<void> irA(WidgetTester tester, String seccion) async {
  if (find.byTooltip('Secciones').evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('Secciones'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(seccion).last);
  await tester.pumpAndSettle();
}

/// Sin datos, el Resumen muestra a los personajes, que animan en bucle:
/// `pumpAndSettle` nunca terminaría, así que se avanza el reloj a mano.
Future<void> avanzar(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_PE');
    final mapa = jsonDecode(
      File('assets/pcge.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    Pcge.cargarDePrueba(mapa.map((k, v) => MapEntry(k, v as String)));
  });

  // Las categorías propias viven en una lista global: que una prueba no le
  // deje las suyas a la siguiente.
  setUp(() => Categoria.registrarPropias(const []));

  testWidgets(
    'sin datos muestra la invitación a registrar, no una lista vacía',
    (tester) async {
      await tester.pumpWidget(armar([]));
      await avanzar(tester);

      expect(find.text('Aún no registraste nada'), findsOneWidget);
      expect(find.text('Registrar mi primera venta'), findsOneWidget);
    },
  );

  testWidgets('el Resumen saluda por nombre', (tester) async {
    await tester.pumpWidget(armar([]));
    await avanzar(tester);

    expect(find.textContaining(', usuario'), findsOneWidget);
  });

  testWidgets('los dos botones de registro están siempre a la vista', (
    tester,
  ) async {
    await tester.pumpWidget(armar([]));
    await avanzar(tester);

    expect(find.text('Entró'), findsOneWidget);
    expect(find.text('Salió'), findsOneWidget);
  });

  testWidgets('con datos el resumen muestra el saldo y los movimientos', (
    tester,
  ) async {
    await tester.pumpWidget(
      armar([
        mov(tipo: Tipo.entro, centavos: 25000),
        mov(tipo: Tipo.salio, centavos: 5000),
        mov(tipo: Tipo.entro, centavos: 10000, medio: MedioPago.yape),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lo que tienes ahora'), findsOneWidget);
    // El saldo anima al entrar, así que se comprueba al final de la animación.
    // 250 + 100 de ingresos − 50 de egreso = 300.
    expect(find.textContaining('300.00'), findsWidgets);

    // La lista de recientes va al pie del resumen: en el alto del test queda
    // fuera de pantalla y hay que bajar para que se construya.
    await tester.scrollUntilVisible(
      find.text('Movimientos recientes'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Movimientos recientes'), findsOneWidget);
    expect(find.text('Venta del día'), findsWidgets);
  });

  testWidgets('el historial lista los movimientos y permite filtrar', (
    tester,
  ) async {
    await tester.pumpWidget(
      armar([
        mov(tipo: Tipo.entro, centavos: 25000),
        mov(tipo: Tipo.salio, centavos: 5000),
      ]),
    );
    await tester.pumpAndSettle();

    await irA(tester, 'Historial');

    expect(find.text('2 movimientos'), findsOneWidget);

    // El filtro es un menú anclado al botón, no una hoja ni un chip suelto.
    await tester.tap(find.text('Entró / Salió'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('↓  Salió'));
    await tester.pumpAndSettle();

    expect(find.text('1 movimiento'), findsOneWidget);
    expect(find.text('Quitar filtros'), findsWidgets);

    // Y "Quitar filtros" devuelve todo.
    await tester.tap(find.text('Quitar filtros').first);
    await tester.pumpAndSettle();
    expect(find.text('2 movimientos'), findsOneWidget);
  });

  testWidgets('el filtro de fechas ofrece períodos de un toque', (
    tester,
  ) async {
    await tester.pumpWidget(armar([mov(tipo: Tipo.entro, centavos: 25000)]));
    await tester.pumpAndSettle();

    await irA(tester, 'Historial');
    await tester.tap(find.text('Fechas'));
    await tester.pumpAndSettle();

    for (final periodo in ['Hoy', 'Esta semana', 'Este mes', 'Mes pasado']) {
      expect(find.text(periodo), findsOneWidget);
    }

    // Al elegirlo, el botón pasa a llamarse como el período.
    await tester.tap(find.text('Este mes'));
    await tester.pumpAndSettle();
    expect(find.text('Este mes'), findsOneWidget);
    expect(find.text('1 movimiento'), findsOneWidget);
  });

  /// En escritorio: ventana ancha, con barra lateral y botones arriba.
  void escritorio(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  final variados = [
    mov(tipo: Tipo.entro, centavos: 25000),
    mov(tipo: Tipo.entro, centavos: 9000, medio: MedioPago.yape),
    mov(tipo: Tipo.salio, centavos: 5000, medio: MedioPago.yape),
    mov(tipo: Tipo.entro, centavos: 100000, medio: MedioPago.transferencia),
  ];

  testWidgets(
    'caja y banco están juntos, con el total y el desglose por medio',
    (tester) async {
      escritorio(tester);
      await tester.pumpWidget(armar(variados));
      await tester.pumpAndSettle();

      // Ya no hay dos secciones separadas: hay una sola.
      expect(
        find.text('Banco / Digital'),
        findsOneWidget,
      ); // la tarjeta del resumen
      await tester.tap(find.text('Caja y bancos'));
      await tester.pumpAndSettle();

      expect(find.text('Lo que tienes en total'), findsOneWidget);
      expect(find.text('Dónde está tu plata'), findsOneWidget);
      // 250 + 90 − 50 + 1,000 = 1,290 en total.
      expect(find.textContaining('1,290.00'), findsWidgets);
      // Yape / Plin aparece con lo que dejó: 90 − 50 = 40.
      expect(find.text('Yape / Plin'), findsWidgets);
      expect(find.text('S/ 40.00'), findsWidgets);

      // Tocar un medio deja en el libro sólo sus movimientos.
      // El libro va al pie: hay que bajar hasta los filtros.
      final filtro = find.widgetWithText(ChoiceChip, 'Yape / Plin');
      await tester.ensureVisible(filtro);
      await tester.pumpAndSettle();
      await tester.tap(filtro);
      await tester.pumpAndSettle();
      expect(find.text('Saldo · Yape / Plin'), findsOneWidget);
    },
  );

  testWidgets('el menú lateral se oculta y se vuelve a mostrar', (
    tester,
  ) async {
    escritorio(tester);
    await tester.pumpWidget(armar(variados));
    await tester.pumpAndSettle();

    expect(find.text('Reportes'), findsOneWidget);

    await tester.tap(find.byTooltip('Ocultar el menú (Ctrl+B)'));
    await tester.pumpAndSettle();
    // Plegado quedan sólo los íconos: los nombres se ven al pasar el mouse.
    expect(find.text('Reportes'), findsNothing);
    expect(find.byIcon(Icons.insert_chart_outlined_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Mostrar el menú (Ctrl+B)'));
    await tester.pumpAndSettle();
    expect(find.text('Reportes'), findsOneWidget);
  });

  testWidgets('entró y salió se abren en una ventana ancha, a dos columnas', (
    tester,
  ) async {
    escritorio(tester);
    await tester.pumpWidget(armar(variados));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entró'));
    await tester.pumpAndSettle();

    expect(find.text('Entró plata'), findsOneWidget);
    // En efectivo sigue al paso de billetes y vuelto.
    expect(find.text('Continuar'), findsOneWidget);
    // Más ancha que la de antes (470): entra el formulario en dos columnas.
    final ventana = tester.getSize(find.byType(RegistroHoja));
    expect(ventana.width, greaterThan(800));
    // El monto y el detalle quedan lado a lado, no uno debajo del otro.
    final monto = tester.getTopLeft(find.text('¿Cuánto fue?'));
    final cuando = tester.getTopLeft(find.text('¿Cuándo?'));
    expect(cuando.dx, greaterThan(monto.dx + 300));
    expect((cuando.dy - monto.dy).abs(), lessThan(10));
  });

  testWidgets(
    'los datos del negocio se abren en una ventana, no en otra pantalla',
    (tester) async {
      escritorio(tester);
      await tester.pumpWidget(armar(variados));
      await tester.pumpAndSettle();

      await tester.tap(find.text('usuario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Datos del negocio'));
      await tester.pumpAndSettle();

      expect(find.byType(NegocioPagina), findsOneWidget);
      expect(find.text('Guardar datos'), findsOneWidget);
      // La app sigue debajo: es una ventana encima, no una ruta que la tapa.
      expect(find.byType(Inicio, skipOffstage: false), findsOneWidget);
      expect(find.text('Lo que tienes ahora'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(NegocioPagina), findsNothing);
    },
  );

  Future<void> abrirRegistro(WidgetTester tester, String boton) async {
    await tester.tap(find.widgetWithText(FilledButton, boton));
    await tester.pumpAndSettle();
  }

  Finder chip(String texto) => find.widgetWithText(ChoiceChip, texto);

  testWidgets('entró ofrece sólo cuatro categorías y los seis medios', (
    tester,
  ) async {
    escritorio(tester);
    await tester.pumpWidget(armar(variados));
    await tester.pumpAndSettle();
    await abrirRegistro(tester, 'Entró');

    for (final c in [
      'Ventas',
      'Cobros de fiado',
      'Adelanto de cliente',
      'Otros',
    ]) {
      expect(chip(c), findsOneWidget, reason: c);
    }
    // Sin menú "Otra" ni "+": cuatro opciones y nada más.
    expect(find.widgetWithText(ActionChip, 'Otra'), findsNothing);
    expect(find.byTooltip('Agregar una categoría nueva'), findsNothing);

    for (final m in [
      'Efectivo',
      'Yape / Plin',
      'Transferencia',
      'Depósito en cuenta',
      'Tarjeta de débito',
      'Tarjeta de crédito',
    ]) {
      expect(chip(m), findsOneWidget, reason: m);
    }
    expect(find.text('Otro'), findsNothing);
    expect(find.text('Otro medio'), findsNothing);
  });

  testWidgets('"Otros" pide la cuenta del plan contable y la guarda', (
    tester,
  ) async {
    escritorio(tester);
    final repo = RepositorioFalso(variados);
    await tester.pumpWidget(armar(variados, repo: repo));
    await tester.pumpAndSettle();
    await abrirRegistro(tester, 'Entró');

    await tester.tap(chip('Yape / Plin'));
    await tester.enterText(find.byType(TextField).first, '300');
    await tester.tap(chip('Otros'));
    await tester.pumpAndSettle();
    expect(find.text('¿En qué exactamente?'), findsOneWidget);

    // Sin cuenta no se guarda.
    await tester.tap(find.text('Guardar entrada'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Elige la cuenta de la lista'), findsOneWidget);
    expect(repo.registrados, isEmpty);

    final buscador = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText ?? '').startsWith('Escribe y elige'),
    );
    await tester.enterText(buscador, 'alquiler');
    await tester.pumpAndSettle();
    await tester.tap(find.text('754').first);
    await tester.pumpAndSettle();
    expect(find.text('Así sale en el Formato 1.1 / 1.2'), findsOneWidget);

    await tester.tap(find.text('Guardar entrada'));
    await tester.pumpAndSettle();
    final guardado = repo.registrados.single;
    expect(guardado.cuentaDelFormato, '754');
    expect(guardado.concepto, 'Alquileres');
  });

  testWidgets('desde S/ 2,000 en efectivo no deja guardar', (tester) async {
    escritorio(tester);
    await tester.pumpWidget(armar(variados));
    await tester.pumpAndSettle();
    await abrirRegistro(tester, 'Entró');

    await tester.tap(chip('Efectivo'));
    await tester.enterText(find.byType(TextField).first, '2000');
    await tester.pumpAndSettle();

    FilledButton boton(String texto) => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(texto),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );

    expect(find.textContaining('no se puede en efectivo'), findsOneWidget);
    expect(boton('Continuar').onPressed, isNull);

    // Con Yape se puede.
    await tester.tap(chip('Yape / Plin'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no se puede en efectivo'), findsNothing);
    expect(boton('Guardar entrada').onPressed, isNotNull);
  });

  testWidgets('salió tiene el "+" y agrega una categoría con su cuenta', (
    tester,
  ) async {
    escritorio(tester);
    final repo = RepositorioFalso(variados);
    await tester.pumpWidget(armar(variados, repo: repo));
    await tester.pumpAndSettle();
    await abrirRegistro(tester, 'Salió');

    // "Otros" ya no es ficha: después de Sueldos viene "Otra" y el "+".
    expect(chip('Sueldos'), findsOneWidget);
    expect(chip('Otros'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Otra'), findsOneWidget);

    await tester.tap(find.byTooltip('Agregar una categoría nueva'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva categoría'), findsOneWidget);

    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '').startsWith('Ej. Movilidad'),
      ),
      'Movilidad',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '').startsWith(
              'Escribe y elige, ej. tr',
            ),
      ),
      'transporte',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('6311').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva categoría'), findsNothing);
    expect(repo.categorias.single.cuentaAsociada, '6311');
    // Queda como ficha, ya elegida.
    final nueva = tester.widget<ChoiceChip>(chip('Movilidad'));
    expect(nueva.selected, isTrue);
  });

  // --- Comprobantes, pasos, historial y arqueo ---

  /// Lo que se mandó a imprimir: en las pruebas no hay impresora.
  late List<String> impresos;
  setUp(() {
    impresos = [];
    Impresion.imprimir = (pdf, nombre) async => impresos.add(nombre);
  });

  testWidgets(
    'con recibo, "Continuar" lleva al comprobante y se imprime al guardar',
    (tester) async {
      escritorio(tester);
      final repo = RepositorioFalso(
        variados,
        negocio: const Negocio(
          razonSocial: 'LIBERTAD SA',
          documento: '11902816511',
          tesorero: 'Ana Ruiz',
        ),
      );
      await tester.pumpWidget(armar(variados, repo: repo));
      await tester.pumpAndSettle();
      await abrirRegistro(tester, 'Entró');

      await tester.tap(chip('Transferencia'));
      await tester.enterText(find.byType(TextField).first, '50');
      await tester.tap(chip('Cobros de fiado'));
      await tester.tap(find.text('Recibo interno'));
      await tester.pumpAndSettle();

      // Con recibo, el botón ya no guarda: sigue.
      expect(find.text('Guardar entrada'), findsNothing);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      // El recibo, con la forma de un comprobante: el recuadro con el RUC,
      // el tipo y el número, que se pone al guardar.
      expect(find.text('RECIBO DE INGRESO'), findsOneWidget);
      expect(find.text('R.U.C. 11902816511'), findsOneWidget);
      expect(find.text('N° al guardar'), findsOneWidget);
      // El responsable viene de los datos del negocio.
      expect(find.text('Ana Ruiz'), findsWidgets);

      await tester.runAsync(() async {
        await tester.tap(find.text('Guardar e imprimir'));
        for (var i = 0; i < 40 && repo.registrados.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        for (var i = 0; i < 40 && impresos.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pumpAndSettle();

      final guardado = repo.registrados.single;
      expect(guardado.numeroRecibo, isNotNull);
      expect(guardado.tesorero, 'Ana Ruiz');
      expect(impresos.single, startsWith('Recibo ingreso'));
    },
  );

  testWidgets(
    'en efectivo siempre se anota con cuánto pagó: sin billetes no guarda',
    (tester) async {
      escritorio(tester);
      final repo = RepositorioFalso(variados)..abrirUnaCaja();
      await tester.pumpWidget(armar(variados, repo: repo));
      await tester.pumpAndSettle();
      await abrirRegistro(tester, 'Entró');

      await tester.tap(chip('Efectivo'));
      await tester.tap(chip('Cobros de fiado'));
      await tester.enterText(find.byType(TextField).first, '102.40');
      await tester.pumpAndSettle();
      // Ya no hay interruptor: en efectivo el paso va siempre.
      expect(find.text('Billetes y vuelto'), findsNothing);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Con cuánto pagó el cliente?'), findsOneWidget);
      // Los pagos de un toque: el exacto y los billetes que redondean.
      for (final t in ['Exacto', 'S/ 110.00', 'S/ 120.00', 'S/ 150.00']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }

      // Sin billetes marcados no se puede guardar.
      await tester.tap(find.text('Guardar entrada'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Marca con qué billetes'), findsOneWidget);
      expect(repo.registrados, isEmpty);

      // Pagó con 110: el vuelto se calcula solo.
      await tester.tap(find.text('S/ 110.00'));
      await tester.pumpAndSettle();
      expect(find.text('Vuelto que le diste'), findsOneWidget);
      await tester.tap(find.text('Guardar entrada'));
      await tester.pumpAndSettle();

      final detalle = repo.registrados.single.detalleEfectivo!;
      expect(detalle.entregado.total, 11000);
      expect(detalle.vuelto.total, 760);
    },
  );

  testWidgets('una venta desde S/ 700 pide nombre y DNI del cliente', (
    tester,
  ) async {
    escritorio(tester);
    final repo = RepositorioFalso(variados);
    await tester.pumpWidget(armar(variados, repo: repo));
    await tester.pumpAndSettle();
    await abrirRegistro(tester, 'Entró');

    await tester.tap(chip('Yape / Plin'));
    await tester.tap(chip('Ventas'));
    await tester.enterText(find.byType(TextField).first, '700');
    await tester.pumpAndSettle();
    expect(find.text('Cliente (obligatorio desde S/ 700)'), findsOneWidget);

    await tester.tap(find.text('Guardar entrada'));
    await tester.pumpAndSettle();
    expect(
      find.text('Desde S/ 700 la boleta lleva el nombre del cliente'),
      findsOneWidget,
    );
    expect(repo.registrados, isEmpty);

    // Con 699.99 es opcional.
    await tester.enterText(find.byType(TextField).first, '699.99');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar entrada'));
    await tester.pumpAndSettle();
    expect(repo.registrados.single.numeroBoleta, isNotNull);
  });

  testWidgets('el ⋮ del historial abre sus papeles, sin opción de eliminar', (
    tester,
  ) async {
    escritorio(tester);
    await tester.pumpWidget(armar(variados));
    await tester.pumpAndSettle();
    await irA(tester, 'Historial');

    // Ya no se desliza para eliminar.
    expect(find.byType(Dismissible), findsNothing);

    await tester.tap(find.byTooltip('Recibo y boleta').first);
    await tester.pumpAndSettle();
    expect(find.text('Recibo interno'), findsOneWidget);
    expect(find.text('Emitir recibo'), findsOneWidget);
    expect(find.textContaining('Eliminar'), findsNothing);
  });

  Finder campo(String pista) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == pista,
  );

  /// Toca algo que puede estar más abajo en la página: primero lo trae a la
  /// vista.
  Future<void> tocar(WidgetTester tester, Finder algo) async {
    await tester.ensureVisible(algo);
    await tester.pumpAndSettle();
    await tester.tap(algo);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'la caja se abre con un monto, el efectivo entra solo y se cierra contando',
    (tester) async {
      escritorio(tester);
      final repo = RepositorioFalso(variados);
      await tester.pumpWidget(armar(variados, repo: repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arqueo de caja'));
      await tester.pumpAndSettle();

      // La primera vez, antes que nada: cuánto efectivo tiene el negocio,
      // billete por billete. Cinco de S/ 100.
      expect(
        find.text('Primero, cuenta el efectivo del negocio'),
        findsOneWidget,
      );
      expect(find.text('Abre tu primera caja'), findsNothing);
      await tester.enterText(campo('0').at(1), '5'); // S/ 100
      await tester.pumpAndSettle();
      expect(find.text('S/ 500.00'), findsWidgets);
      await tocar(tester, find.text('Guardar el efectivo del negocio'));
      expect(repo.fondo!.total, 50000);

      // Después se abre la caja: lo que se pone sale de ahí.
      expect(find.text('Abre tu primera caja'), findsOneWidget);
      expect(find.text('Tienes en total'), findsOneWidget);
      // No quedó nada en una caja anterior: no hay "seguir".
      expect(find.text('Seguir con lo que quedó'), findsNothing);
      await tester.enterText(campo('0.00'), '100');
      await tester.pumpAndSettle();
      expect(find.text('Quedan guardados S/ 400.00.'), findsOneWidget);
      await tester.enterText(campo('Quién queda a cargo'), 'Ana Ruiz');
      await tocar(tester, find.text('Abrir caja'));

      expect(find.text('CAJA N° 1 ABIERTA'), findsOneWidget);
      // Al costado, el efectivo del negocio repartido: 100 en la caja y 400
      // guardados.
      expect(find.text('Efectivo del negocio'), findsOneWidget);
      expect(find.text('En la caja N° 1 (abierta)'), findsOneWidget);
      expect(find.text('S/ 400.00'), findsWidgets);
      expect(find.text('Debería haber en la caja'), findsOneWidget);
      // Lo registrado antes de abrir no es de esta caja.
      expect(find.textContaining('Todavía sin movimientos'), findsOneWidget);

      // Un cobro en efectivo entra solo.
      await abrirRegistro(tester, 'Entró');
      await tester.tap(chip('Efectivo'));
      await tester.tap(chip('Cobros de fiado'));
      await tester.enterText(find.byType(TextField).first, '20');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exacto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar entrada'));
      await tester.pumpAndSettle();

      expect(find.text('S/ 120.00'), findsWidgets);
      expect(find.text('+ S/ 20.00'), findsOneWidget);
      // El total del negocio sube con lo que entró.
      expect(find.text('S/ 520.00'), findsOneWidget);

      // Se cierra contando: uno de 100 y uno de 20. Cuadra.
      await tester.tap(find.text('Cerrar caja'));
      await tester.pumpAndSettle();
      final fichas = campo('0');
      await tester.enterText(fichas.at(1), '1'); // S/ 100
      await tester.enterText(fichas.at(3), '1'); // S/ 20
      await tester.pumpAndSettle();
      expect(find.text('La caja cuadra'), findsOneWidget);

      await tocar(tester, find.text('Cerrar caja y ver el acta'));
      expect(find.text('Caja N° 1 cerrada'), findsOneWidget);
      expect(find.text('Terminaste con'), findsOneWidget);

      final cerrada = repo.cajas.single;
      expect(cerrada.abierta, isFalse);
      expect(cerrada.entradas, 2000);
      expect(cerrada.contado, 12000);
      expect(cerrada.cuadra, isTrue);

      // El acta: con la forma de un documento, igual que el PDF.
      await tester.tap(find.text('Ver acta'));
      await tester.pumpAndSettle();
      expect(find.text('CIERRE DE CAJA'), findsOneWidget);
      expect(find.text('CAJA N° 1'), findsOneWidget);
    },
  );

  testWidgets(
    'la caja siguiente ofrece seguir con lo que quedó o empezar de cero',
    (tester) async {
      escritorio(tester);
      final repo = RepositorioFalso(variados);
      final ayer = DateTime.now().subtract(const Duration(days: 1));
      // El negocio tenía S/ 300: la caja de ayer empezó con 100 y cerró con
      // lo mismo; quedaron 200 guardados.
      repo.fondo = FondoNegocio(
        conteo: const Conteo({10000: 3}),
        contadoEn: ayer.subtract(const Duration(hours: 11)),
        usuario: 'usuario',
      );
      repo.cajas.add(
        Jornada(
          id: 'ayer',
          numero: 1,
          abiertaEn: ayer.subtract(const Duration(hours: 10)),
          apertura: 10000,
          inicio: InicioCaja.primera,
          responsable: 'Ana Ruiz',
          usuario: 'usuario',
        ).cerrar(
          cerradaEn: ayer,
          movimientos: const [],
          conteo: const Conteo({10000: 1}),
        ),
      );
      await tester.pumpWidget(armar(variados, repo: repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arqueo de caja'));
      await tester.pumpAndSettle();

      expect(find.text('Seguir con lo que quedó'), findsOneWidget);
      expect(find.text('Empezar de cero'), findsOneWidget);
      expect(find.text('Con otro monto'), findsOneWidget);
      // Lo que hay para abrir: 100 en la caja y 200 guardados.
      expect(find.text('Quedó en la caja'), findsOneWidget);
      expect(
        find.text('Lo sacas de lo que tienes: hasta S/ 300.00'),
        findsOneWidget,
      );

      await tester.tap(find.text('Empezar de cero'));
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Abrir caja'));

      final nueva = repo.cajas.last;
      expect(nueva.numero, 2);
      expect(nueva.apertura, 0);
      expect(nueva.inicio, InicioCaja.desdeCero);
      expect(nueva.apartado, 10000);
      // Los 100 de la caja pasaron a lo guardado: 300 guardados, 0 en caja.
      expect(find.text('Tus cajas'), findsOneWidget);
      expect(find.text('Guardado aparte'), findsWidgets);
      expect(find.text('S/ 300.00'), findsWidgets);
    },
  );

  testWidgets('el resumen avisa que la caja está cerrada y lleva a abrirla', (
    tester,
  ) async {
    escritorio(tester);
    await tester.pumpWidget(armar(variados));
    await tester.pumpAndSettle();

    expect(find.text('La caja está cerrada'), findsOneWidget);
    expect(
      find.text('Primero cuenta el efectivo del negocio y ábrela'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Abrir caja'));
    await tester.pumpAndSettle();
    expect(
      find.text('Primero, cuenta el efectivo del negocio'),
      findsOneWidget,
    );
  });

  testWidgets(
    'con la caja cerrada no se registra en efectivo y lleva a abrirla',
    (tester) async {
      escritorio(tester);
      final repo = RepositorioFalso(variados);
      await tester.pumpWidget(armar(variados, repo: repo));
      await tester.pumpAndSettle();
      await abrirRegistro(tester, 'Entró');

      await tester.tap(chip('Efectivo'));
      await tester.tap(chip('Ventas'));
      await tester.enterText(find.byType(TextField).first, '20');
      await tester.pumpAndSettle();

      FilledButton boton(String texto) => tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(texto),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );

      // No se puede seguir.
      expect(find.textContaining('primero ábrela'), findsOneWidget);
      expect(boton('Continuar').onPressed, isNull);
      expect(
        find.text('Abre la caja para registrar en efectivo'),
        findsOneWidget,
      );

      // Con Yape sí: no pasa por la caja.
      await tester.tap(chip('Yape / Plin'));
      await tester.pumpAndSettle();
      expect(find.textContaining('primero ábrela'), findsNothing);
      expect(boton('Guardar entrada').onPressed, isNotNull);

      // En efectivo, "Abrir la caja" cierra el formulario y lleva al arqueo.
      await tester.tap(chip('Efectivo'));
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Abrir la caja'));
      expect(find.byType(RegistroHoja), findsNothing);
      expect(
        find.text('Primero, cuenta el efectivo del negocio'),
        findsOneWidget,
      );
      expect(repo.registrados, isEmpty);
    },
  );

  testWidgets('el conteo del negocio queda bloqueado, pero se corrige', (
    tester,
  ) async {
    escritorio(tester);
    final repo = RepositorioFalso(variados)
      ..fondo = FondoNegocio(
        conteo: const Conteo({10000: 5, 5000: 10}),
        contadoEn: DateTime.now().subtract(const Duration(hours: 1)),
        usuario: 'usuario',
      );
    await tester.pumpWidget(armar(variados, repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arqueo de caja'));
    await tester.pumpAndSettle();

    // Contado y bloqueado: ya no se pide, se muestra.
    expect(find.text('Primero, cuenta el efectivo del negocio'), findsNothing);
    expect(find.text('Efectivo del negocio'), findsOneWidget);
    expect(find.text('Bloqueado'), findsOneWidget);
    expect(find.text('5 × S/ 100 · 10 × S/ 50'), findsOneWidget);
    expect(find.text('S/ 1,000.00'), findsWidgets);

    // Contó mal: eran nueve de 50, no diez.
    await tocar(tester, find.text('Corregir conteo'));
    expect(find.text('Corregir el efectivo del negocio'), findsOneWidget);
    final fichas = find.descendant(
      of: find.byType(Dialog),
      matching: campo('0'),
    );
    await tester.enterText(fichas.at(2), '9'); // S/ 50
    await tester.pumpAndSettle();
    expect(find.text('− S/ 50.00'), findsOneWidget);
    await tester.tap(find.text('Guardar corrección'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(repo.fondo!.total, 95000);
    expect(repo.fondo!.corregido, isTrue);
    expect(find.text('S/ 950.00'), findsWidgets);
    expect(find.textContaining('Corregido'), findsOneWidget);
  });

  testWidgets('en el celular las secciones salen por la derecha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(armar(variados));
    await tester.pumpAndSettle();

    // Ya no hay barra abajo.
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byTooltip('Secciones'));
    await tester.pumpAndSettle();

    final menu = find.byType(Drawer);
    expect(menu, findsOneWidget);
    // Sale del lado derecho de la pantalla.
    expect(tester.getTopRight(menu).dx, closeTo(390, 1));
    expect(find.text('Arqueo de caja'), findsOneWidget);

    await tester.tap(find.text('Formatos oficiales'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Formatos oficiales'), findsOneWidget);
  });
}
