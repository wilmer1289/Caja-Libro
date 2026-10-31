import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/core/tema.dart';
import 'package:mi_caja/datos/local/evidencias.dart';
import 'package:mi_caja/datos/local/selector_voucher.dart';
import 'package:mi_caja/datos/ocr/lector_voucher.dart';
import 'package:mi_caja/datos/repositorio/repositorio_demo.dart';
import 'package:mi_caja/dominio/banco.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/estado/estado_caja.dart';
import 'package:mi_caja/ui/historial/historial_pagina.dart';
import 'package:mi_caja/ui/registro/registro_hoja.dart';
import 'package:provider/provider.dart';

/// En las pruebas no hay cámara ni diálogo de archivos: el voucher es la
/// imagen de `test/recursos`.
class SelectorFalso implements SelectorVoucher {
  SelectorFalso(this.archivo);

  final ArchivoVoucher archivo;

  @override
  bool get puedeTomarFoto => false;

  @override
  Future<ArchivoVoucher?> tomarFoto() async => archivo;

  @override
  Future<ArchivoVoucher?> elegirArchivo() async => archivo;
}

/// Y no se llama al lector de Windows: devuelve lo que devolvió con esa
/// imagen.
class LectorFalso implements LectorTexto {
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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_PE');
    Pcge.cargarDeTexto(File('assets/pcge.json').readAsStringSync());
  });

  setUp(() {
    Categoria.registrarPropias(const []);
    AlmacenEvidencias.instancia = AlmacenEnMemoria();
    SelectorVoucher.instancia = SelectorFalso(
      ArchivoVoucher(
        bytes: File('test/recursos/voucher_prueba.png').readAsBytesSync(),
        extension: 'png',
      ),
    );
    LectorVoucher.instancia = LectorFalso();
  });

  Widget envolver(EstadoCaja estado, Widget hijo) =>
      ChangeNotifierProvider.value(
        value: estado,
        child: MaterialApp(
          theme: construirTema(),
          locale: const Locale('es', 'PE'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('es', 'PE')],
          home: Scaffold(body: hijo),
        ),
      );

  Future<void> abrir(
    WidgetTester tester,
    EstadoCaja estado,
    Size tamano,
  ) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      envolver(
        estado,
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => RegistroHoja.abrir(context, Tipo.entro),
              child: const Text('Abrir registro'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir registro'));
    await tester.pumpAndSettle();
  }

  Finder campo(String pista) => find.byWidgetPredicate(
    (w) => w is TextField && (w.decoration?.hintText ?? '').startsWith(pista),
  );

  Future<void> tocar(WidgetTester tester, Finder algo) async {
    await tester.ensureVisible(algo);
    await tester.pumpAndSettle();
    await tester.tap(algo);
    await tester.pumpAndSettle();
  }

  Finder ficha(String texto) => find.widgetWithText(ChoiceChip, texto);

  for (final tamano in [const Size(933, 600), const Size(390, 844)]) {
    testWidgets(
      'el voucher se adjunta, se lee y arma la cuenta (${tamano.width.toInt()}px)',
      (tester) async {
        final repo = RepositorioDemo();
        final estado = EstadoCaja(repo);
        await estado.cargar();
        estado.ultimoMedio = MedioPago.transferencia;
        estado.ultimaCategoriaIngreso = 'cobros_fiado';
        await abrir(tester, estado, tamano);

        await tester.enterText(find.byType(TextField).first, '1250.50');
        await tocar(tester, find.text('Continuar'));
        expect(find.text('Datos del voucher'), findsOneWidget);
        expect(find.text('Adjunta el voucher'), findsOneWidget);

        // Sin N° de operación ni voucher, desde S/ 700 no se guarda.
        await tocar(tester, find.text('Guardar'));
        expect(
          find.text('Escribe el N° de operación que trae el voucher'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Desde S/ 700 adjunta el voucher: es la prueba de la operación.',
          ),
          findsOneWidget,
        );
        expect(await repo.listar(), isEmpty);

        // Se adjunta y se lee: llena el N°, el cliente y el banco.
        await tocar(tester, find.text('Elegir imagen o PDF'));
        expect(find.text('Voucher adjunto'), findsOneWidget);
        expect(find.text('Leído del voucher'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(campo('El número del voucher'))
              .controller!
              .text,
          '04512378',
        );
        expect(
          tester
              .widget<TextField>(campo('Nombre o razón social'))
              .controller!
              .text,
          'Fernandez E.I.R.L.',
        );
        expect(tester.widget<ChoiceChip>(ficha('BCP')).selected, isTrue);
        // El monto coincide; la fecha no: se puede usar la del voucher.
        expect(find.text('Usar este monto'), findsNothing);
        await tocar(tester, find.text('Usar esta fecha'));

        // Una letra de la sucursal que el banco tenía en cobranza.
        await tocar(tester, ficha('Sucursal'));
        await tocar(tester, ficha('Letra'));
        await tocar(tester, ficha('En cobranza'));
        expect(find.textContaining('1333 · '), findsOneWidget);

        await tocar(tester, find.text('Guardar'));
        expect(find.byType(RegistroHoja), findsNothing);
        final m = (await repo.listar()).single;
        expect(m.numeroTransaccion, '04512378');
        expect(m.bancoTercero, 'BCP');
        expect(m.contraparte, 'Fernandez E.I.R.L.');
        expect(m.vinculo, Vinculo.sucursal);
        expect(m.documentoPago, DocumentoPago.letra);
        expect(m.situacion, Situacion.cobranza);
        expect(m.cuentaDelFormato, '1333');
        expect(m.fecha, DateTime(2026, 10, 15));
        expect(
          m.descripcionFormato,
          'Cobro de fiado, sucursal, letra en cobranza',
        );
        final guardado = await AlmacenEvidencias.instancia.leer(m.rutaFoto!);
        expect(guardado!.bytes.length, greaterThan(1000));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        estado.dispose();
      },
    );
  }

  testWidgets('avisa si el N° de operación ya se anotó', (tester) async {
    final repo = RepositorioDemo();
    await repo.registrar(
      tipo: Tipo.entro,
      centavos: 5000,
      categoriaId: 'ventas',
      concepto: '',
      medio: MedioPago.yape,
      fecha: DateTime.now(),
      numeroTransaccion: '04512378',
    );
    final estado = EstadoCaja(repo);
    await estado.cargar();
    estado.ultimoMedio = MedioPago.yape;
    estado.ultimaCategoriaIngreso = 'cobros_fiado';
    await abrir(tester, estado, const Size(933, 600));

    await tester.enterText(find.byType(TextField).first, '50');
    await tocar(tester, find.text('Continuar'));
    // Por Yape, las fichas son las apps.
    expect(ficha('Yape'), findsOneWidget);
    expect(ficha('BCP'), findsNothing);
    await tester.enterText(campo('El número del voucher'), '04512378');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Ya anotaste una operación con este número'),
      findsOneWidget,
    );
    // Es un aviso, no un bloqueo: menos de S/ 700, sin voucher, se guarda.
    await tocar(tester, find.text('Guardar'));
    expect(await repo.listar(), hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    estado.dispose();
  });

  testWidgets(
    'en el historial: falta el voucher, se adjunta y se ve, con su ITF',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = RepositorioDemo();
      await repo.registrar(
        tipo: Tipo.entro,
        centavos: 5286400,
        categoriaId: 'cobros_fiado',
        concepto: '',
        medio: MedioPago.transferencia,
        fecha: DateTime.now(),
        contraparte: 'Fernández E.I.R.L.',
      );
      final estado = EstadoCaja(repo);
      await estado.cargar();
      await tester.pumpWidget(envolver(estado, const HistorialPagina()));
      await tester.pumpAndSettle();

      expect(find.text('Falta el voucher'), findsOneWidget);
      expect(find.textContaining('ITF estimado: '), findsOneWidget);
      expect(find.textContaining('S/ 2.60 en 1 operación'), findsOneWidget);

      await tocar(tester, find.byTooltip('Recibo, boleta y voucher'));
      expect(find.text('Voucher del banco · sin adjuntar'), findsOneWidget);
      expect(
        find.textContaining('N° de operación: falta anotarlo'),
        findsOneWidget,
      );
      await tocar(tester, find.text('Adjuntar'));
      expect(
        find.textContaining('Voucher adjunto; se completó el N° de operación'),
        findsOneWidget,
      );
      // El voucher dice otro monto: se avisa, no se cambia el libro.
      expect(
        find.textContaining('ojo: el voucher dice S/ 1,250.50'),
        findsOneWidget,
      );
      final m = estado.movimientos.single;
      expect(m.tieneVoucher, isTrue);
      expect(m.numeroTransaccion, '04512378');
      expect(m.centavos, 5286400);
      expect(find.text('Voucher del banco'), findsOneWidget);

      await tocar(tester, find.text('Ver'));
      expect(find.text('Voucher · Oper. 04512378'), findsOneWidget);
      await tocar(tester, find.byTooltip('Cerrar').last);

      // "Completar datos": el DNI que el voucher no traía.
      await tocar(tester, find.text('Completar datos'));
      await tester.enterText(
        find.widgetWithText(TextField, 'DNI o RUC'),
        '20102030401',
      );
      await tocar(tester, find.widgetWithText(FilledButton, 'Guardar'));
      expect(estado.movimientos.single.documentoContraparte, '20102030401');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      estado.dispose();
    },
  );
}
