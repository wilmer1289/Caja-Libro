@Tags(['captura'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/core/tema.dart';
import 'package:mi_caja/datos/auth/autenticador_local.dart';
import 'package:mi_caja/datos/local/evidencias.dart';
import 'package:mi_caja/datos/local/selector_voucher.dart';
import 'package:mi_caja/datos/ocr/lector_voucher.dart';
import 'package:mi_caja/datos/repositorio/repositorio_demo.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/efectivo.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/fondo.dart';
import 'package:mi_caja/dominio/jornada.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/estado/estado_caja.dart';
import 'package:mi_caja/ui/inicio.dart';
import 'package:mi_caja/ui/login/login_pagina.dart';
import 'package:provider/provider.dart';

/// Fotos de la app entera —no de piezas sueltas— para mirar cómo quedó cada
/// pantalla sin compilar: el login, el resumen, caja y bancos, el menú
/// plegado y las ventanas de registro y de datos del negocio.
///
/// Igual que `captura_test.dart`, no corre de rutina:
///
///   flutter test test/captura_app_test.dart --tags captura --run-skipped
///
/// El límite de repintado envuelve a toda la app, no a la página: así la
/// foto incluye lo que se abre encima (diálogos, menús), que vive en el
/// `Overlay` del navegador.

/// El voucher de prueba (`test/recursos/voucher_prueba.png`), sin cámara ni
/// diálogo de archivos.
class _SelectorDePrueba implements SelectorVoucher {
  _SelectorDePrueba({this.camara = false});

  final bool camara;
  final archivo = ArchivoVoucher(
    bytes: File('test/recursos/voucher_prueba.png').readAsBytesSync(),
    extension: 'png',
  );

  @override
  bool get puedeTomarFoto => camara;

  @override
  Future<ArchivoVoucher?> tomarFoto() async => archivo;

  @override
  Future<ArchivoVoucher?> elegirArchivo() async => archivo;
}

/// Lo que el lector de Windows devolvió con esa imagen.
class _LectorDePrueba implements LectorTexto {
  @override
  Future<String> leer(Uint8List imagen, String extension) async => '''
Constancia de transferencia
Operacion exitosa
Monto transferido
S/ 1,250.50
Fecha
N de operacion
Cliente
Banco de origen
Comision
15/10/2026 10:38
04512378
Fernandez E.I.R.L.
BCP
S/ 0.00''';
}

/// Para que la miniatura del voucher salga en la foto: la imagen se decodifica
/// fuera del reloj falso de la prueba.
Future<void> _precargarVoucher(WidgetTester tester, Finder dentro) async {
  final selector = SelectorVoucher.instancia as _SelectorDePrueba;
  await tester.runAsync(
    () => precacheImage(
      MemoryImage(selector.archivo.bytes),
      tester.element(dentro),
    ),
  );
  await tester.pump();
}

void _usarVoucherDePrueba({bool camara = false}) {
  AlmacenEvidencias.instancia = AlmacenEnMemoria();
  SelectorVoucher.instancia = _SelectorDePrueba(camara: camara);
  LectorVoucher.instancia = _LectorDePrueba();
}

/// Un repositorio en memoria: la app se arma igual que la de verdad, pero sin
/// SQLite, que en las pruebas de widgets no responde.
class _RepositorioEnMemoria extends RepositorioDemo {
  _RepositorioEnMemoria(
    this._datos,
    this._negocio, {
    List<Jornada>? cajas,
    this.fondo,
  }) : _cajas = [...?cajas];

  /// De la más vieja a la más nueva.
  final List<Jornada> _cajas;
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

  final List<Movimiento> _datos;
  Negocio _negocio;

  @override
  Future<Negocio> leerNegocio() async => _negocio;

  @override
  Future<List<Categoria>> leerCategoriasPropias() async => const [];

  @override
  Future<List<Jornada>> leerJornadas() async => List.of(_cajas.reversed);

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
      id: 'caja-${_cajas.length + 1}',
      numero: _cajas.length + 1,
      abiertaEn: DateTime.now(),
      apertura: apertura,
      conteoApertura: conteo,
      inicio: inicio,
      anterior: anterior,
      responsable: responsable,
      usuario: usuario,
      negocio: _negocio.razonSocial,
      documento: _negocio.documento,
    );
    _cajas.add(caja);
    return caja;
  }

  @override
  Future<void> guardarCierre(Jornada caja) async =>
      _cajas[_cajas.indexWhere((c) => c.id == caja.id)] = caja;

  @override
  Future<void> guardarNegocio(Negocio negocio) async => _negocio = negocio;

  @override
  Future<List<Movimiento>> listar({Cuenta? cuenta}) async => [
    for (final m in _datos)
      if (cuenta == null || m.cuenta == cuenta) m,
  ]..sort((a, b) => b.fecha.compareTo(a.fecha));
}

/// Un mes parecido al del libro de prueba: ventas en efectivo y por Yape, una
/// venta grande por transferencia, pagos con tarjeta, Yape y transferencia.
/// Las fechas van hacia atrás desde hoy para que siempre caigan en el mes.
List<Movimiento> _datos() {
  final hoy = DateTime.now();
  var n = 0;
  Movimiento m(
    int haceDias,
    Tipo tipo,
    int centavos,
    String categoria,
    MedioPago medio, {
    String concepto = '',
    String? quien,
  }) {
    n++;
    final fecha = DateTime(hoy.year, hoy.month, hoy.day - haceDias, 10 + n);
    return Movimiento(
      id: 'm$n',
      numero: n,
      tipo: tipo,
      centavos: centavos,
      categoriaId: categoria,
      concepto: concepto,
      medio: medio,
      fecha: fecha,
      creadoEn: fecha,
      actualizadoEn: fecha,
      contraparte: quien,
      sync: EstadoSync.local,
    );
  }

  return [
    m(
      16,
      Tipo.entro,
      3000000,
      'ventas',
      MedioPago.transferencia,
      concepto: 'Venta al por mayor',
      quien: 'Comercial Andina EIRL',
    ),
    m(9, Tipo.entro, 9000, 'ventas', MedioPago.yape, concepto: 'Zapatos'),
    m(8, Tipo.entro, 9000, 'ventas', MedioPago.efectivo),
    m(8, Tipo.entro, 1000, 'ventas', MedioPago.efectivo),
    m(
      5,
      Tipo.entro,
      100000,
      'cobros_fiado',
      MedioPago.efectivo,
      concepto: 'Abastecimiento',
      quien: 'Bodega Santa Rosa',
    ),
    m(
      5,
      Tipo.salio,
      50000,
      'mercaderia',
      MedioPago.transferencia,
      quien: 'Distribuidora El Sol SAC',
    ),
    m(
      3,
      Tipo.salio,
      500000,
      'suministros',
      MedioPago.yape,
      concepto: 'Suministros de oficina',
    ),
    m(
      2,
      Tipo.salio,
      800000,
      'proveedores',
      MedioPago.tarjeta,
      quien: 'Textiles del Norte SA',
    ),
  ];
}

final _negocio = Negocio(
  razonSocial: 'LIBERTAD SA',
  documento: '11902816511',
  direccion: 'Calle Industrial 2429 - Trujillo',
  entidadFinanciera: 'BCP',
  cuentaCorriente: '193-2468101-0-12',
  saldoInicialCaja: 4000000,
  saldoInicialBanco: 300000,
  inicioPeriodo: DateTime(DateTime.now().year, DateTime.now().month),
  tesorero: 'Ana Ruiz',
);

/// El efectivo del negocio, contado antes de la primera caja: cinco de
/// S/ 100 y diez de S/ 50.
FondoNegocio _fondo() => FondoNegocio(
  conteo: const Conteo({10000: 5, 5000: 10}),
  contadoEn: DateTime.now().subtract(const Duration(days: 4)),
  usuario: 'usuario',
);

/// Una caja abierta desde temprano, para poder registrar en efectivo.
List<Jornada> _unaCajaAbierta() => [
  Jornada(
    id: 'c1',
    numero: 1,
    abiertaEn: DateTime.now().subtract(const Duration(hours: 3)),
    apertura: 10000,
    conteoApertura: const Conteo({10000: 1}),
    inicio: InicioCaja.primera,
    responsable: 'Ana Ruiz',
    usuario: 'usuario',
  ),
];

final _lienzo = GlobalKey();

Widget _app(
  Widget inicio, {
  Negocio? negocio,
  List<Movimiento>? datos,
  List<Jornada>? cajas,
  FondoNegocio? fondo,
}) {
  return RepaintBoundary(
    key: _lienzo,
    child: ChangeNotifierProvider(
      create: (_) => EstadoCaja(
        _RepositorioEnMemoria(
          datos ?? _datos(),
          negocio ?? _negocio,
          cajas: cajas,
          fondo: fondo ?? (cajas == null ? null : _fondo()),
        ),
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: construirTema(),
        locale: const Locale('es', 'PE'),
        supportedLocales: const [Locale('es', 'PE'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: inicio,
      ),
    ),
  );
}

Future<void> _cargarFuentes() async {
  Future<void> familia(String nombre, List<String> rutas) async {
    final cargador = FontLoader(nombre);
    for (final ruta in rutas) {
      cargador.addFont(
        File(ruta).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await cargador.load();
  }

  await familia('Jakarta', [
    'assets/fonts/PlusJakartaSans-Regular.ttf',
    'assets/fonts/PlusJakartaSans-Medium.ttf',
    'assets/fonts/PlusJakartaSans-SemiBold.ttf',
    'assets/fonts/PlusJakartaSans-Bold.ttf',
    'assets/fonts/PlusJakartaSans-ExtraBold.ttf',
  ]);

  // Sin esto los íconos salen como cuadraditos vacíos. La ruta del SDK cambia
  // de máquina en máquina, así que si no está, se sigue sin ellos.
  for (final base in const [r'C:\SDK\flutter', r'C:\flutter']) {
    final carpeta = Directory('$base/bin/cache/artifacts/material_fonts');
    if (!await carpeta.exists()) continue;
    final fuentes = await carpeta
        .list()
        .where((e) => e.path.toLowerCase().contains('materialicons'))
        .toList();
    if (fuentes.isNotEmpty) {
      await familia('MaterialIcons', [fuentes.first.path]);
    }
    break;
  }
}

Future<void> _capturar(WidgetTester tester, String nombre) async {
  final limite =
      _lienzo.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  // `runAsync` es obligatorio: `toImage` se resuelve en el hilo de rasterizado
  // y, dentro del reloj falso de las pruebas, esa promesa nunca llega.
  await tester.runAsync(() async {
    final imagen = await limite.toImage(pixelRatio: 1);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();

    final salida = Directory(Platform.environment['CAPTURAS'] ?? 'capturas');
    if (!await salida.exists()) await salida.create(recursive: true);
    await File('${salida.path}/$nombre.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
}

/// Los personajes animan en bucle: `pumpAndSettle` no terminaría nunca, así
/// que se avanza el reloj a mano hasta que todo entró.
Future<void> _esperar(WidgetTester tester, {int pasos = 50}) async {
  for (var i = 0; i < pasos; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void _tamano(WidgetTester tester, Size tamano) {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_PE');
    await _cargarFuentes();
    Pcge.cargarDeTexto(File('assets/pcge.json').readAsStringSync());
  });

  const escritorio = Size(1366, 860);
  final inicio = Inicio(usuario: 'usuario', onSalir: () {});

  testWidgets('login en escritorio', (tester) async {
    _tamano(tester, const Size(1280, 720));
    await tester.pumpWidget(
      _app(
        LoginPagina(autenticador: const AutenticadorLocal(), onEntrar: (_) {}),
      ),
    );
    await _esperar(tester);
    await _capturar(tester, 'app-login');
  });

  testWidgets('login en el celular', (tester) async {
    _tamano(tester, const Size(390, 844));
    await tester.pumpWidget(
      _app(
        LoginPagina(autenticador: const AutenticadorLocal(), onEntrar: (_) {}),
      ),
    );
    await _esperar(tester);
    await _capturar(tester, 'app-login-celular');
  });

  testWidgets('resumen en escritorio', (tester) async {
    _tamano(tester, escritorio);
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester);
    await _capturar(tester, 'app-resumen');
  });

  testWidgets('caja y bancos en escritorio', (tester) async {
    _tamano(tester, const Size(1366, 1320));
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Caja y bancos'));
    await _esperar(tester);
    await _capturar(tester, 'app-caja-y-bancos');

    // Con un medio elegido: sólo Yape / Plin, con su propio saldo.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Yape / Plin'));
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-caja-y-bancos-yape');
  });

  testWidgets('menú plegado', (tester) async {
    _tamano(tester, escritorio);
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.byTooltip('Ocultar el menú (Ctrl+B)'));
    await _esperar(tester);
    await _capturar(tester, 'app-menu-plegado');
  });

  testWidgets('ventana de entró', (tester) async {
    _tamano(tester, escritorio);
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Entró'));
    await _esperar(tester, pasos: 20);
    // Con una categoría con IGV y un monto, para ver el desglose.
    await tester.enterText(find.byType(TextField).first, '1180');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ventas'));
    await _esperar(tester, pasos: 10);
    expect(find.text('Incluye IGV S/ 180.00'), findsOneWidget);
    expect(find.text('El monto incluye IGV'), findsNothing);
    await _capturar(tester, 'app-registro-entro');
  });

  testWidgets('ventana de salió', (tester) async {
    _tamano(tester, escritorio);
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Salió'));
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-registro-salio');
  });

  testWidgets('pie del registro en el celular', (tester) async {
    _tamano(tester, const Size(390, 1500));
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Entró'));
    await _esperar(tester, pasos: 20);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Yape / Plin'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cobros de fiado'));
    await tester.enterText(find.byType(TextField).first, '50');
    await tester.ensureVisible(find.text('Recibo interno'));
    await tester.tap(find.text('Recibo interno'));
    await _esperar(tester, pasos: 10);

    expect(find.text('Atrás'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await _esperar(tester, pasos: 10);
    // Por Yape pasa por el voucher antes del recibo.
    expect(find.text('Datos del voucher'), findsOneWidget);
    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '').startsWith('El número del voucher'),
      ),
      '04512378',
    );
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await _esperar(tester, pasos: 10);
    expect(find.text('Atrás'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.byTooltip('Guardar e imprimir'), findsOneWidget);
    await _capturar(tester, 'app-registro-celular-pie');
  });

  testWidgets('ventana de datos del negocio', (tester) async {
    _tamano(tester, escritorio);
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('usuario'));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Datos del negocio'));
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-negocio');
  });

  testWidgets('resumen en el celular', (tester) async {
    _tamano(tester, const Size(390, 1500));
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester);
    await _capturar(tester, 'app-resumen-celular');
  });

  testWidgets('caja y bancos en el celular', (tester) async {
    _tamano(tester, const Size(390, 1900));
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.byTooltip('Secciones'));
    await _esperar(tester, pasos: 20);
    await tester.tap(find.text('Caja y bancos'));
    await _esperar(tester);
    await _capturar(tester, 'app-caja-y-bancos-celular');
  });

  for (final (seccion, archivo) in const [
    ('Historial', 'app-historial'),
    ('Reportes', 'app-reportes'),
    ('Formatos oficiales', 'app-formatos'),
  ]) {
    testWidgets('$seccion en escritorio', (tester) async {
      _tamano(tester, escritorio);
      await tester.pumpWidget(_app(inicio));
      await _esperar(tester, pasos: 10);
      await tester.tap(find.text(seccion));
      await _esperar(tester);
      await _capturar(tester, archivo);
    });
  }

  // Una laptop con el texto de Windows al 150%: 1400×900 píxeles son unos
  // 933×600 lógicos. Es el caso más apretado del escritorio.
  testWidgets('resumen con el texto al 150%', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Caja y bancos'));
    await _esperar(tester);
    await _capturar(tester, 'app-150-caja-y-bancos');
    await tester.tap(find.text('Resumen'));
    await _esperar(tester);
    await _capturar(tester, 'app-150-resumen');
  });

  // --- Los ajustes del formulario ---

  Finder buscador(String inicio) => find.byWidgetPredicate(
    (w) => w is TextField && (w.decoration?.hintText ?? '').startsWith(inicio),
  );

  testWidgets('entró: las cuatro categorías y los seis medios', (tester) async {
    _tamano(tester, escritorio);
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Entró'));
    await _esperar(tester, pasos: 20);
    await tester.enterText(find.byType(TextField).first, '300');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Otros'));
    await _esperar(tester, pasos: 10);
    await tester.enterText(buscador('Escribe y elige'), 'alquiler');
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-entro-otros-buscando');
    await tester.tap(find.text('754').first);
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-entro-otros-elegida');
  });

  testWidgets('entró: 2,000 en efectivo no se guarda', (tester) async {
    _tamano(tester, escritorio);
    await tester.pumpWidget(_app(inicio, cajas: _unaCajaAbierta()));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Entró'));
    await _esperar(tester, pasos: 20);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Efectivo'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ventas'));
    await tester.enterText(find.byType(TextField).first, '2000');
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-entro-2000-efectivo');
  });

  testWidgets('salió: fichas, "Otra" y el "+"', (tester) async {
    _tamano(tester, escritorio);
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Salió'));
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-salio-categorias');
    await tester.tap(find.byTooltip('Agregar una categoría nueva'));
    await _esperar(tester, pasos: 20);
    expect(find.text('El monto trae IGV'), findsOneWidget);
    await tester.enterText(buscador('Ej. Movilidad'), 'Movilidad');
    await tester.enterText(buscador('Escribe y elige, ej. tr'), 'transporte');
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-nueva-categoria');
  });

  // --- Comprobantes, pasos, historial, arqueo y filtros ---

  Movimiento conPapeles() {
    final hoy = DateTime.now();
    final fecha = DateTime(hoy.year, hoy.month, hoy.day, 11);
    return Movimiento(
      id: 'papeles',
      numero: 9,
      tipo: Tipo.entro,
      centavos: 10240,
      categoriaId: 'ventas',
      concepto: 'Venta de abarrotes',
      medio: MedioPago.efectivo,
      fecha: fecha,
      creadoEn: fecha,
      actualizadoEn: fecha,
      igvCentavos: 1562,
      contraparte: 'Valera Malca, Diana',
      documentoContraparte: '10203040',
      numeroRecibo: 12,
      numeroBoleta: 37,
      tesorero: 'Ana Ruiz',
      detalleEfectivo: DetalleEfectivo(
        entregado: const Conteo({5000: 2, 1000: 1}),
        vuelto: Conteo.sugerir(760),
      ),
      sync: EstadoSync.local,
    );
  }

  testWidgets('registro: comprobantes, pago en efectivo y recibo', (
    tester,
  ) async {
    _tamano(tester, escritorio);
    await tester.pumpWidget(_app(inicio, cajas: _unaCajaAbierta()));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Entró'));
    await _esperar(tester, pasos: 20);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Efectivo'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ventas'));
    await _esperar(tester, pasos: 5);
    await tester.enterText(find.byType(TextField).first, '102.40');
    await tester.tap(find.text('Recibo interno'));
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-registro-paso1');

    await tester.tap(find.text('Continuar'));
    await _esperar(tester, pasos: 10);
    // El paso de mercadería: esta venta es un servicio, sin costo de venta.
    await tester.tap(find.text('No es mercadería'));
    await _esperar(tester, pasos: 5);
    await tester.tap(find.text('Continuar'));
    await _esperar(tester, pasos: 10);
    // Registra manualmente S/ 110 y el vuelto de S/ 7.60.
    Finder campoConteo(int indice) => find
        .byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '0',
        )
        .at(indice);

    Future<void> ponerConteo(int indice) async {
      final campo = campoConteo(indice);
      await tester.ensureVisible(campo);
      await tester.enterText(campo, '1');
      await _esperar(tester, pasos: 5);
    }

    await ponerConteo(1); // S/ 100
    await ponerConteo(4); // S/ 10
    await ponerConteo(16); // S/ 5 de vuelto
    await ponerConteo(17); // S/ 2 de vuelto
    await ponerConteo(19); // S/ 0.50 de vuelto
    await ponerConteo(21); // S/ 0.10 de vuelto
    await _capturar(tester, 'app-registro-paso2');

    await tester.tap(find.text('Continuar'));
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-registro-paso3');
  });

  testWidgets('historial: la miniventana de papeles y los documentos', (
    tester,
  ) async {
    _tamano(tester, escritorio);
    await tester.pumpWidget(_app(inicio, datos: [..._datos(), conPapeles()]));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Historial'));
    await _esperar(tester);
    await _capturar(tester, 'app-historial-menu');

    await tester.tap(find.byTooltip('Recibo, boleta y voucher').first);
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-papeles');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ver').first);
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-recibo');
    await tester.tap(find.text('Cerrar').last);
    await _esperar(tester, pasos: 20);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ver').last);
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-boleta');
  });

  /// El paso "Voucher": vacío, con lo que falta, y leído.
  Future<void> pasoVoucher(
    WidgetTester tester,
    Size tamano,
    String prefijo, {
    bool camara = false,
  }) async {
    _usarVoucherDePrueba(camara: camara);
    _tamano(tester, tamano);
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Entró').first);
    await _esperar(tester, pasos: 20);
    await tester.enterText(find.byType(TextField).first, '1250.50');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cobros de fiado'));
    await tester.ensureVisible(
      find.widgetWithText(ChoiceChip, 'Transferencia'),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Transferencia'));
    await _esperar(tester, pasos: 10);
    await _capturar(tester, '$prefijo-datos');

    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await _esperar(tester, pasos: 20);
    await _capturar(tester, '$prefijo-vacio');

    await tester.tap(find.text('Guardar'));
    await _esperar(tester, pasos: 10);
    await _capturar(tester, '$prefijo-faltan');

    await tester.ensureVisible(find.text('Elegir imagen o PDF'));
    await tester.tap(find.text('Elegir imagen o PDF'));
    await _esperar(tester, pasos: 20);
    await _precargarVoucher(tester, find.text('Voucher adjunto'));
    for (final ficha in ['Sucursal', 'Letra', 'En cobranza']) {
      final f = find.widgetWithText(ChoiceChip, ficha);
      await tester.ensureVisible(f);
      await tester.tap(f);
      await _esperar(tester, pasos: 6);
    }
    await tester.ensureVisible(find.text('Datos del voucher'));
    await _esperar(tester, pasos: 10);
    await _capturar(tester, '$prefijo-leido');
    await tester.ensureVisible(find.textContaining('Cuenta del formato'));
    await _esperar(tester, pasos: 10);
    await _capturar(tester, '$prefijo-leido-abajo');
  }

  testWidgets('voucher: el paso del registro en escritorio', (tester) async {
    await pasoVoucher(tester, escritorio, 'app-voucher');
  });

  testWidgets('voucher: el paso del registro en el celular', (tester) async {
    await pasoVoucher(
      tester,
      const Size(390, 844),
      'app-voucher-celular',
      camara: true,
    );
  });

  testWidgets('historial: falta el voucher, el ITF y el voucher adjunto', (
    tester,
  ) async {
    _usarVoucherDePrueba();
    _tamano(tester, escritorio);
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Historial'));
    await _esperar(tester);
    expect(find.text('Falta el voucher'), findsWidgets);
    expect(find.textContaining('ITF estimado: '), findsOneWidget);
    await _capturar(tester, 'app-historial-voucher');

    // El primero es el pago a proveedor de S/ 8,000 con tarjeta.
    await tester.tap(find.byTooltip('Recibo, boleta y voucher').first);
    await _esperar(tester, pasos: 20);
    expect(find.text('Voucher del banco · sin adjuntar'), findsOneWidget);
    await _capturar(tester, 'app-historial-papel-voucher');

    await tester.tap(find.text('Adjuntar'));
    await _esperar(tester, pasos: 20);
    expect(find.text('Voucher del banco'), findsOneWidget);
    await _capturar(tester, 'app-historial-voucher-adjunto');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ver'));
    await _esperar(tester, pasos: 10);
    await _precargarVoucher(tester, find.text('Voucher · Oper. 04512378'));
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-visor-voucher');
  });

  /// Tres cajas cerradas —con un faltante y lo de una guardado aparte— y la
  /// de hoy, abierta, con lo que entró y salió en efectivo.
  List<Jornada> cajasDePrueba({bool conAbierta = true}) {
    final hoy = DateTime.now();
    DateTime dia(int hace, int hora, [int minuto = 0]) =>
        DateTime(hoy.year, hoy.month, hoy.day - hace, hora, minuto);
    Jornada cerrada(
      int n,
      int hace,
      InicioCaja inicio,
      int apertura,
      int anterior,
      int entradas,
      int salidas,
      int contado,
    ) => Jornada(
      id: 'c$n',
      numero: n,
      abiertaEn: dia(hace, 8, 2),
      apertura: apertura,
      inicio: inicio,
      anterior: anterior,
      responsable: 'Ana Ruiz',
      usuario: 'usuario',
      negocio: 'LIBERTAD SA',
      documento: '11902816511',
      cerradaEn: dia(hace, 21, 10),
      entradas: entradas,
      salidas: salidas,
      operaciones: 7,
      conteoCierre: Conteo.sugerir(contado),
    );
    return [
      cerrada(1, 3, InicioCaja.primera, 10000, 0, 84000, 12000, 82000),
      cerrada(2, 2, InicioCaja.continua, 82000, 82000, 45000, 6000, 120550),
      cerrada(3, 1, InicioCaja.otroMonto, 10000, 120550, 38000, 0, 48000),
      if (conAbierta)
        Jornada(
          id: 'c4',
          numero: 4,
          abiertaEn: DateTime.now().subtract(const Duration(hours: 9)),
          apertura: 48000,
          conteoApertura: Conteo.sugerir(48000),
          inicio: InicioCaja.continua,
          anterior: 48000,
          responsable: 'Ana Ruiz',
          usuario: 'usuario',
          negocio: 'LIBERTAD SA',
          documento: '11902816511',
        ),
    ];
  }

  /// Lo que entró y salió hoy en efectivo, con sus billetes.
  List<Movimiento> deHoy() {
    final hoy = DateTime.now();
    Movimiento m(
      int n,
      int hora,
      int minuto,
      Tipo tipo,
      int centavos,
      String categoria,
      String concepto,
      Conteo entregado,
    ) {
      // Las horas son de un día de trabajo que termina ahora: así nunca
      // quedan después del momento en que se cierra la caja.
      final f = hoy.subtract(Duration(minutes: (18 - hora) * 60 - minuto));
      return Movimiento(
        id: 'hoy$n',
        numero: 20 + n,
        tipo: tipo,
        centavos: centavos,
        categoriaId: categoria,
        concepto: concepto,
        medio: MedioPago.efectivo,
        fecha: f,
        creadoEn: f,
        actualizadoEn: f,
        numeroBoleta: categoria == 'ventas' ? 40 + n : null,
        detalleEfectivo: DetalleEfectivo(
          entregado: entregado,
          vuelto: Conteo.sugerir(entregado.total - centavos),
        ),
        sync: EstadoSync.local,
      );
    }

    return [
      m(
        1,
        9,
        20,
        Tipo.entro,
        3750,
        'ventas',
        'Venta de abarrotes',
        const Conteo({5000: 1}),
      ),
      m(
        2,
        12,
        10,
        Tipo.salio,
        4500,
        'mercaderia',
        'Compra de pan',
        const Conteo({2000: 2, 500: 1}),
      ),
      m(
        3,
        15,
        5,
        Tipo.entro,
        20000,
        'cobros_fiado',
        'Cobro de fiado a Rosa',
        const Conteo({10000: 2}),
      ),
      m(
        4,
        17,
        40,
        Tipo.entro,
        1850,
        'ventas',
        'Gaseosas',
        const Conteo({2000: 1}),
      ),
    ];
  }

  testWidgets('caja del día: abierta, cerrando, cerrada y el acta', (
    tester,
  ) async {
    _tamano(tester, const Size(1366, 1000));
    await tester.pumpWidget(
      _app(inicio, datos: [..._datos(), ...deHoy()], cajas: cajasDePrueba()),
    );
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Arqueo de caja'));
    await _esperar(tester);
    await _capturar(tester, 'app-caja-abierta');

    await tester.tap(find.text('Cerrar caja'));
    await _esperar(tester, pasos: 20);
    final fichas = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '0',
    );
    // Debería haber 691.00; se cuentan 690.50: faltan 0.50.
    await tester.enterText(fichas.at(0), '3'); // S/ 200
    await tester.enterText(fichas.at(2), '1'); // S/ 50
    await tester.enterText(fichas.at(3), '2'); // S/ 20
    await tester.enterText(fichas.at(8), '1'); // S/ 0.50
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-caja-cerrando');

    await tester.tap(find.text('Cerrar caja y ver el acta'));
    await _esperar(tester, pasos: 20);
    // Primero la confirmación, con si cuadra y cuánto falta.
    await _capturar(tester, 'app-caja-confirmar-cierre');
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar caja'));
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-caja-cerrada');
    await tester.tap(find.text('Ver acta'));
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-acta');
  });

  testWidgets('caja del día: abrir la siguiente y el resumen', (tester) async {
    _tamano(tester, const Size(1366, 1000));
    await tester.pumpWidget(
      _app(inicio, cajas: cajasDePrueba(conAbierta: false)),
    );
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Arqueo de caja'));
    await _esperar(tester);
    await tester.tap(find.text('Con otro monto'));
    await _esperar(tester, pasos: 10);
    final fichas = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '0',
    );
    await tester.enterText(fichas.at(1), '1'); // S/ 100
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-caja-abrir');

    await tester.tap(find.text('Todas'));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Imprimir'));
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-resumen-cajas');
  });

  testWidgets('caja del día: contar el efectivo y abrir la primera', (
    tester,
  ) async {
    _tamano(tester, const Size(1366, 1100));
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Arqueo de caja'));
    await _esperar(tester);
    final fichas = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '0',
    );
    await tester.enterText(fichas.at(1), '5'); // S/ 100
    await tester.enterText(fichas.at(2), '10'); // S/ 50
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-caja-contar');

    await tester.tap(find.text('Guardar el efectivo del negocio'));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Con otro monto'));
    await _esperar(tester, pasos: 10);
    await tester.enterText(fichas.at(1), '3'); // S/ 300
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-caja-primera');

    await tester.tap(find.text('Corregir conteo'));
    await _esperar(tester, pasos: 20);
    await tester.enterText(
      find.descendant(of: find.byType(Dialog), matching: fichas).at(2),
      '9',
    );
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-caja-corregir');
  });

  testWidgets('registro en efectivo con la caja cerrada', (tester) async {
    _tamano(tester, escritorio);
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Entró'));
    await _esperar(tester, pasos: 20);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Efectivo'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ventas'));
    await tester.enterText(find.byType(TextField).first, '25');
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-registro-caja-cerrada');
  });

  testWidgets('caja del día en el celular: contar y abrir', (tester) async {
    _tamano(tester, const Size(390, 1700));
    await tester.pumpWidget(
      _app(inicio, cajas: cajasDePrueba(conAbierta: false)),
    );
    await _esperar(tester, pasos: 10);
    await tester.tap(find.byTooltip('Secciones'));
    await _esperar(tester, pasos: 20);
    await tester.tap(find.text('Arqueo de caja'));
    await _esperar(tester);
    await _capturar(tester, 'app-caja-abrir-celular');
  });

  testWidgets('caja del día y documentos en el celular', (tester) async {
    _tamano(tester, const Size(390, 1500));
    await tester.pumpWidget(
      _app(
        inicio,
        datos: [..._datos(), ...deHoy(), conPapeles()],
        cajas: cajasDePrueba(),
      ),
    );
    await _esperar(tester, pasos: 10);
    await tester.tap(find.byTooltip('Secciones'));
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-menu-celular');
    await tester.tap(find.text('Arqueo de caja'));
    await _esperar(tester);
    await _capturar(tester, 'app-caja-celular');
  });

  testWidgets('la boleta en el celular', (tester) async {
    _tamano(tester, const Size(390, 844));
    await tester.pumpWidget(_app(inicio, datos: [..._datos(), conPapeles()]));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.byTooltip('Secciones'));
    await _esperar(tester, pasos: 20);
    await tester.tap(find.text('Historial'));
    await _esperar(tester);
    await tester.tap(find.byTooltip('Recibo, boleta y voucher').first);
    await _esperar(tester, pasos: 20);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Ver').last);
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-boleta-celular');
  });

  testWidgets('formatos con filtros', (tester) async {
    _tamano(tester, const Size(1366, 1000));
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Formatos oficiales'));
    await _esperar(tester);
    await tester.tap(find.text('Entró / Salió'));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('↑  Entró').last);
    await _esperar(tester, pasos: 20);
    await _capturar(tester, 'app-formatos-filtro');
  });

  testWidgets('datos del negocio con el responsable de caja', (tester) async {
    _tamano(tester, const Size(1366, 1000));
    await tester.pumpWidget(_app(inicio));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('usuario'));
    await _esperar(tester, pasos: 10);
    await tester.tap(find.text('Datos del negocio'));
    await _esperar(tester, pasos: 20);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -500),
    );
    await _esperar(tester, pasos: 10);
    await _capturar(tester, 'app-negocio-tesorero');
  });
}
