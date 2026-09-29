@Tags(['captura'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/core/tema.dart';
import 'package:mi_caja/datos/export/exportador_pdf.dart';
import 'package:mi_caja/dominio/boleta.dart';
import 'package:mi_caja/dominio/efectivo.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/jornada.dart';
import 'package:mi_caja/dominio/libro_oficial.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/dominio/recibo.dart';
import 'package:mi_caja/ui/formatos/bloque_asiento.dart';
import 'package:mi_caja/ui/formatos/hoja_formato.dart';
import 'package:mi_caja/ui/formatos/recibo_hoja.dart';
import 'package:mi_caja/ui/widgets/logo.dart';

/// Renderiza los documentos a PNG para poder mirarlos.
///
/// No es una prueba de comportamiento: es la forma de ver cómo queda el
/// Formato 1.1 sin tener que entrar a la app. Encontró los dos desbordes que
/// tenía la tabla —altura infinita y dos píxeles de más— que leyendo el código
/// no se ven.
///
/// Monta los widgets sueltos y no la app entera: acá lo que se quiere mirar es
/// el documento, y armar la app completa sólo agrega animaciones que esperar.
///
/// Va con etiqueta propia para que `flutter test` no la corra de rutina.
/// Se lanza con `flutter test test/captura_test.dart --tags captura`.

/// Movimientos en efectivo de un día, con su detalle de billetes.
List<Movimiento> movimientosDeCaja() {
  Movimiento m(int n, int hora, Tipo tipo, int centavos, String cat, String c) {
    final f = DateTime(2026, 9, 26, hora, 10 + n);
    return Movimiento(
      id: 'c$n',
      numero: 40 + n,
      tipo: tipo,
      centavos: centavos,
      categoriaId: cat,
      concepto: c,
      medio: MedioPago.efectivo,
      fecha: f,
      creadoEn: f,
      actualizadoEn: f,
      sync: EstadoSync.local,
    );
  }

  return [
    m(1, 9, Tipo.entro, 3750, 'ventas', 'Venta de abarrotes'),
    m(2, 10, Tipo.entro, 12000, 'ventas', 'Venta de gaseosas por mayor'),
    m(3, 12, Tipo.salio, 4500, 'mercaderia', 'Compra de pan'),
    m(4, 15, Tipo.entro, 20000, 'cobros_fiado', 'Cobro de fiado a Rosa'),
    m(5, 18, Tipo.salio, 1500, 'otros_egresos', 'Movilidad'),
    m(6, 20, Tipo.entro, 8940, 'ventas', ''),
  ];
}

/// La caja del 26: empezó con S/ 100 y al contar faltaron S/ 0.50.
Jornada cajaDePrueba() {
  final movs = movimientosDeCaja();
  final abierta = Jornada(
    id: 'j2',
    numero: 4,
    abiertaEn: DateTime(2026, 9, 26, 8, 2),
    apertura: 10000,
    conteoApertura: Conteo.sugerir(10000),
    inicio: InicioCaja.otroMonto,
    anterior: 82000,
    responsable: 'Ana Ruiz',
    usuario: 'usuario',
    negocio: 'LIBERTAD SA',
    documento: '20304050601',
  );
  final esperado = abierta.conTotales(movs).esperado;
  return abierta.cerrar(
    cerradaEn: DateTime(2026, 9, 26, 21, 14),
    movimientos: movs,
    conteo: Conteo.sugerir(esperado - 50),
    supervisor: 'Luis Torres',
    observacion: 'Cierre del día',
  );
}

/// Un mes con algo de todo: ventas, un cobro de fiado, compras, servicios,
/// planilla, y movimientos por banco además de los de efectivo.
List<Movimiento> datosDePrueba() {
  var n = 0;

  Movimiento m(
    int dia,
    Tipo tipo,
    int centavos,
    String categoria, {
    MedioPago medio = MedioPago.efectivo,
    String concepto = '',
    String? quien,
    String? documento,
    String? transaccion,
  }) {
    final fecha = DateTime(2026, 9, dia);
    n++;
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
      documentoContraparte: documento,
      numeroTransaccion: transaccion,
      numeroRecibo: medio == MedioPago.efectivo ? n : null,
      sync: EstadoSync.local,
    );
  }

  return [
    m(
      2,
      Tipo.entro,
      177000,
      'ventas',
      concepto: 'Venta de 50 unidades de ponchos artesanales',
      quien: 'Valera Malca, Diana',
      documento: '10203040',
    ),
    m(3, Tipo.salio, 52400, 'mercaderia', quien: 'Distribuidora El Sol SAC'),
    m(5, Tipo.salio, 8990, 'luz'),
    m(6, Tipo.entro, 64000, 'cobros_fiado', quien: 'Bodega Santa Rosa'),
    m(8, Tipo.salio, 2124, 'suministros', quien: 'Librería Cortéz S.A.'),
    m(10, Tipo.salio, 120000, 'sueldos', quien: 'Gonzáles Gálvez, Belén'),
    m(12, Tipo.salio, 15600, 'essalud'),
    m(
      14,
      Tipo.entro,
      230000,
      'ventas',
      medio: MedioPago.transferencia,
      quien: 'Comercial Andina EIRL',
      transaccion: '0092-448713',
    ),
    m(
      18,
      Tipo.salio,
      90000,
      'proveedores',
      medio: MedioPago.deposito,
      quien: 'Textiles del Norte SA',
      transaccion: '0092-451020',
    ),
    m(20, Tipo.salio, 4500, 'agua'),
    m(22, Tipo.entro, 98500, 'ventas', medio: MedioPago.yape),
    m(25, Tipo.salio, 30000, 'alquiler', quien: 'Inmobiliaria Chan Chan'),
  ];
}

final negocioDePrueba = Negocio(
  razonSocial: 'LIBERTAD SA',
  documento: '20304050601',
  direccion: 'Calle Industrial 2429 - Trujillo',
  entidadFinanciera: 'BBVA',
  cuentaCorriente: '0011-0234-0200123456',
  saldoInicialCaja: 43600,
  saldoInicialBanco: 218390,
  inicioPeriodo: DateTime(2026, 9),
);

LibroOficial libroDe(Cuenta cuenta) => LibroOficial.armar(
  cuenta: cuenta,
  negocio: negocioDePrueba,
  movimientos: datosDePrueba(),
  desde: DateTime(2026, 9),
  hasta: DateTime(2026, 9, 30),
);

Future<void> cargarFuentes() async {
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

/// Lo que se va a fotografiar va dentro de un límite de repintado: es lo único
/// que sabe entregarse como imagen.
final lienzo = GlobalKey();

Future<void> capturar(WidgetTester tester, String nombre) async {
  final limite =
      lienzo.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  // `runAsync` es obligatorio: `toImage` se resuelve en el hilo de rasterizado
  // del motor, y dentro del reloj falso de las pruebas esa promesa no llega a
  // completarse nunca. Sin esto, la captura se cuelga en silencio.
  await tester.runAsync(() async {
    final imagen = await limite.toImage(pixelRatio: 1.5);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();

    final salida = Directory(Platform.environment['CAPTURAS'] ?? 'capturas');
    if (!await salida.exists()) await salida.create(recursive: true);
    await File('${salida.path}/$nombre.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
}

/// Un documento sobre el fondo de la app, con su margen, como se ve de verdad.
Widget escena(Widget hijo) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: construirTema(),
    locale: const Locale('es', 'PE'),
    supportedLocales: const [Locale('es', 'PE'), Locale('es')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // El `Scaffold` no es decorativo: sin un `Material` encima, el texto no
    // hereda la tipografia del tema y sale con la de relleno de las pruebas,
    // que dibuja cada letra como un cuadradito negro.
    home: Scaffold(
      backgroundColor: Tokens.fondo,
      body: RepaintBoundary(
        key: lienzo,
        child: ColoredBox(
          color: Tokens.fondo,
          child: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(24), child: hijo),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    // El enlace tiene que existir antes de registrar fuentes: si no, el
    // `FontLoader` no hace nada y todo el texto sale como cuadraditos negros,
    // que es la tipografia de relleno de las pruebas.
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_PE');
    await cargarFuentes();
    final crudo = File('assets/pcge.json').readAsStringSync();
    Pcge.cargarDePrueba(
      (jsonDecode(crudo) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
    );
  });

  Future<void> montar(
    WidgetTester tester,
    Widget hijo, {
    Size tamanio = const Size(1180, 1200),
  }) async {
    tester.view.physicalSize = tamanio;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(escena(hijo));
    await tester.pump();
  }

  testWidgets('formato 1.1 en escritorio', (tester) async {
    await montar(tester, HojaFormato(libro: libroDe(Cuenta.caja)));
    await capturar(tester, 'formato-1-1');
  });

  testWidgets('formato 1.2 en escritorio', (tester) async {
    // 984 es lo que queda de una ventana de 1280 con la barra lateral y el
    // margen de la pagina: el 1.2 tiene que entrar entero ahi, sin que haya
    // que arrastrar la tabla para ver los importes.
    await montar(
      tester,
      HojaFormato(libro: libroDe(Cuenta.banco)),
      tamanio: const Size(1032, 900),
    );
    await capturar(tester, 'formato-1-2');
  });

  testWidgets('formato 1.1 angosto, como en el celular', (tester) async {
    await montar(
      tester,
      HojaFormato(libro: libroDe(Cuenta.caja)),
      tamanio: const Size(390, 1100),
    );
    await capturar(tester, 'formato-1-1-celular');
  });

  testWidgets('asientos del libro diario', (tester) async {
    final libro = libroDe(Cuenta.caja);
    await montar(
      tester,
      Column(
        children: [
          for (final a in libro.asientos)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: BloqueAsiento(asiento: a, periodo: 'septiembre de 2026'),
            ),
        ],
      ),
      tamanio: const Size(900, 700),
    );
    await capturar(tester, 'asientos');
  });

  // Los PDF no se miran en pantalla: se generan y se guardan al lado de las
  // capturas, para abrirlos con el visor y ver como quedaron impresos.
  testWidgets('los PDF se generan', (tester) async {
    await tester.runAsync(() async {
      final salida = Directory(Platform.environment['CAPTURAS'] ?? 'capturas');
      if (!await salida.exists()) await salida.create(recursive: true);

      for (final cuenta in Cuenta.values) {
        final bytes = await ExportadorPdf.formato(libroDe(cuenta));
        await File('${salida.path}/formato-${cuenta.name}.pdf')
            .writeAsBytes(bytes);
        expect(bytes.length, greaterThan(1000));
      }

      final recibo = Recibo(
        negocio: negocioDePrueba,
        movimiento: datosDePrueba().first,
      );
      final bytes = await ExportadorPdf.recibo(recibo);
      await File('${salida.path}/recibo.pdf').writeAsBytes(bytes);
      expect(bytes.length, greaterThan(1000));

      // La boleta de control interno y el acta de arqueo.
      final venta = datosDePrueba().first.copiarCon(
        numeroRecibo: 1,
        tesorero: 'Ana Ruiz',
      );
      final boleta = await ExportadorPdf.boleta(
        Boleta(
          negocio: negocioDePrueba,
          movimiento: Movimiento(
            id: 'b',
            numero: 1,
            tipo: Tipo.entro,
            centavos: venta.centavos,
            categoriaId: 'ventas',
            concepto: venta.concepto,
            medio: MedioPago.efectivo,
            fecha: venta.fecha,
            creadoEn: venta.fecha,
            actualizadoEn: venta.fecha,
            igvCentavos: 27000,
            contraparte: venta.contraparte,
            documentoContraparte: venta.documentoContraparte,
            numeroBoleta: 37,
            detalleEfectivo: DetalleEfectivo(
              entregado: const Conteo({20000: 9}),
              vuelto: Conteo.sugerir(180000 - 177000),
            ),
          ),
        ),
      );
      await File('${salida.path}/boleta.pdf').writeAsBytes(boleta);
      final caja = cajaDePrueba();
      final acta = await ExportadorPdf.actaCierre(
        caja,
        movimientosDeCaja(),
        direccion: negocioDePrueba.direccion,
      );
      await File('${salida.path}/acta.pdf').writeAsBytes(acta);

      final resumen = await ExportadorPdf.resumenCajas(
        ResumenCajas.de([
          caja,
          Jornada(
            id: 'j1',
            numero: 3,
            abiertaEn: DateTime(2026, 9, 25, 8),
            apertura: 10000,
            inicio: InicioCaja.primera,
            responsable: 'Ana Ruiz',
            usuario: 'usuario',
            cerradaEn: DateTime(2026, 9, 25, 21),
            entradas: 84000,
            salidas: 12000,
            operaciones: 9,
            conteoCierre: Conteo.sugerir(82000),
          ),
        ], PeriodoCajas.todo),
        negocio: negocioDePrueba,
      );
      await File('${salida.path}/resumen-cajas.pdf').writeAsBytes(resumen);
    });
  });

  // El logo a tamano grande, para sacar de ahi los iconos de la app: el del
  // lanzador de Android y el del ejecutable de Windows. Nace del mismo dibujo
  // que se ve en la barra lateral y en el login, asi que el icono y la app son
  // la misma cara.
  testWidgets('logo para los iconos', (tester) async {
    await montar(
      tester,
      const Center(child: LogoMiCaja(tamano: 512)),
      tamanio: const Size(560, 560),
    );
    await capturar(tester, 'logo');
  });

  testWidgets('recibo de ingreso', (tester) async {
    await montar(
      tester,
      Center(
        child: SizedBox(
          width: 560,
          child: ReciboHoja(
            recibo: Recibo(
              negocio: negocioDePrueba,
              movimiento: datosDePrueba().first,
            ),
          ),
        ),
      ),
      tamanio: const Size(660, 780),
    );
    await capturar(tester, 'recibo');
  });
}
