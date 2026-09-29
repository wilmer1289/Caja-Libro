import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/datos/db/base_datos.dart';
import 'package:mi_caja/datos/db/esquema.dart';
import 'package:mi_caja/datos/export/exportador_pdf.dart';
import 'package:mi_caja/datos/local/categoria_dao.dart';
import 'package:mi_caja/datos/local/jornada_dao.dart';
import 'package:mi_caja/datos/local/movimiento_dao.dart';
import 'package:mi_caja/datos/local/negocio_dao.dart';
import 'package:mi_caja/datos/repositorio/repositorio_movimientos.dart';
import 'package:mi_caja/dominio/boleta.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/efectivo.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/jornada.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/dominio/recibo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Recibo interno, boleta de control interno, billetes y vuelto, y la caja
/// del día.
void main() {
  late Database db;
  late RepositorioMovimientos repo;

  setUpAll(() async {
    // Los PDF cargan la tipografía de los assets: hace falta el enlace.
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_PE');
    sqfliteFfiInit();
    final mapa = jsonDecode(
      File('assets/pcge.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    Pcge.cargarDePrueba(mapa.map((k, v) => MapEntry(k, v as String)));
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: BaseDatos.opciones,
    );
    repo = RepositorioMovimientos(
      dao: MovimientoDao(database: db),
      negocioDao: NegocioDao(database: db),
      categoriaDao: CategoriaDao(database: db),
      jornadaDao: JornadaDao(database: db),
    );
    Categoria.registrarPropias(const []);
  });

  tearDown(() => db.close());

  Future<Movimiento> registrar({
    int centavos = 1000,
    String categoria = 'ventas',
    Tipo tipo = Tipo.entro,
    MedioPago medio = MedioPago.efectivo,
    bool conRecibo = false,
    String? cliente,
    String? documento,
    String? tesorero,
    DetalleEfectivo? detalle,
  }) => repo.registrar(
    tipo: tipo,
    centavos: centavos,
    categoriaId: categoria,
    concepto: '',
    medio: medio,
    fecha: DateTime.now(),
    contraparte: cliente,
    documentoContraparte: documento,
    conRecibo: conRecibo,
    tesorero: tesorero,
    detalleEfectivo: detalle,
  );

  group('Billetes y vuelto', () {
    test('el vuelto sugerido usa la menor cantidad de billetes y monedas', () {
      // Pagó 110 por 102.40: vuelto 7.60 = 5 + 2 + 0.50 + 0.10.
      final vuelto = Conteo.sugerir(760);
      expect(vuelto.total, 760);
      expect(vuelto.cantidades, {500: 1, 200: 1, 50: 1, 10: 1});
    });

    test('lo entregado menos el vuelto tiene que ser el monto', () {
      final pago = DetalleEfectivo(
        entregado: const Conteo({5000: 2, 1000: 1}),
        vuelto: Conteo.sugerir(760),
      );
      expect(pago.cuadraCon(10240), isTrue);
      expect(pago.cuadraCon(10000), isFalse);
      // Se guarda y se lee igual.
      final leido = DetalleEfectivo.desdeTexto(pago.aTexto())!;
      expect(leido.entregado, pago.entregado);
      expect(leido.vuelto, pago.vuelto);
    });

    test('un detalle que no cuadra no se guarda', () async {
      await expectLater(
        registrar(
          centavos: 10240,
          categoria: 'cobros_fiado',
          detalle: const DetalleEfectivo(
            entregado: Conteo({5000: 2}),
            vuelto: Conteo.vacio,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Boleta de control interno', () {
    test('toda venta lleva boleta, numerada sin huecos', () async {
      final a = await registrar(centavos: 1000);
      final b = await registrar(centavos: 2500);
      final fiado = await registrar(centavos: 500, categoria: 'cobros_fiado');
      expect(a.numeroBoleta, 1);
      expect(b.numeroBoleta, 2);
      expect(fiado.numeroBoleta, isNull);
      expect(
        Boleta(negocio: Negocio.vacio, movimiento: b).numero,
        'B001-00000002',
      );
    });

    test(
      'desde S/ 700 exige nombre y DNI o RUC; por debajo, opcional',
      () async {
        final chica = await registrar(centavos: 69999);
        expect(
          Boleta(negocio: Negocio.vacio, movimiento: chica).cliente,
          'Clientes varios',
        );

        await expectLater(
          registrar(centavos: 70000, medio: MedioPago.yape),
          throwsA(isA<ArgumentError>()),
        );
        final grande = await registrar(
          centavos: 70000,
          medio: MedioPago.yape,
          cliente: 'Valera Malca, Diana',
          documento: '10203040',
        );
        expect(grande.numeroBoleta, isNotNull);
      },
    );

    test('la boleta separa el IGV de lo que se cobró', () async {
      final m = await registrar(centavos: 11800);
      final boleta = Boleta(negocio: Negocio.vacio, movimiento: m);
      expect(boleta.desglose.base + boleta.desglose.igv, 11800);
      expect(boleta.desglose.igv, 1800);
    });
  });

  group('Recibo interno', () {
    test('sólo lo tienen los movimientos para los que se pidió', () async {
      final sin = await registrar(categoria: 'cobros_fiado');
      final con = await registrar(
        categoria: 'cobros_fiado',
        conRecibo: true,
        tesorero: 'Ana Ruiz',
      );
      expect(sin.numeroRecibo, isNull);
      expect(con.numeroRecibo, 1);
      expect(con.tesorero, 'Ana Ruiz');
    });

    test(
      'una venta también puede llevar recibo, además de su boleta',
      () async {
        final m = await registrar(conRecibo: true);
        expect(m.numeroRecibo, isNotNull);
        expect(m.numeroBoleta, isNotNull);
      },
    );

    test('se puede emitir después, con el siguiente número', () async {
      await registrar(categoria: 'cobros_fiado', conRecibo: true);
      final sin = await registrar(categoria: 'cobros_fiado');
      final emitido = await repo.emitirRecibo(sin, tesorero: 'Luis');
      expect(emitido.numeroRecibo, 2);
      expect(
        (await repo.listar()).firstWhere((m) => m.id == sin.id).numeroRecibo,
        2,
      );
    });

    test('firma el tesorero del recibo, aunque cambie el del negocio', () {
      final m = Movimiento(
        id: 'x',
        numero: 1,
        tipo: Tipo.entro,
        centavos: 1000,
        categoriaId: 'ventas',
        concepto: '',
        medio: MedioPago.efectivo,
        fecha: DateTime(2026, 9, 26),
        creadoEn: DateTime(2026, 9, 26),
        actualizadoEn: DateTime(2026, 9, 26),
        numeroRecibo: 1,
        tesorero: 'Ana Ruiz',
        detalleEfectivo: DetalleEfectivo(
          entregado: const Conteo({2000: 1}),
          vuelto: Conteo.sugerir(1000),
        ),
      );
      const negocio = Negocio(tesorero: 'Nuevo Tesorero');
      final recibo = Recibo(negocio: negocio, movimiento: m);
      expect(recibo.tesorero, 'Ana Ruiz');
      expect(recibo.medioDetallado, contains('Pagó con S/ 20.00'));
      expect(recibo.medioDetallado, contains('Vuelto S/ 10.00'));
    });

    test(
      'los PDF del recibo, la boleta, el acta y el resumen se generan',
      () async {
        final m = await registrar(
          conRecibo: true,
          centavos: 1180,
          cliente: 'Cliente',
        );
        const negocio = Negocio(
          razonSocial: 'LIBERTAD SA',
          documento: '11902816511',
        );
        expect(
          (await ExportadorPdf.recibo(Recibo(negocio: negocio, movimiento: m)))
              .length,
          greaterThan(1000),
        );
        expect(
          (await ExportadorPdf.boleta(Boleta(negocio: negocio, movimiento: m)))
              .length,
          greaterThan(1000),
        );
        final caja = cajaAbierta(DateTime(2026, 9, 26, 8)).cerrar(
          cerradaEn: DateTime(2026, 9, 26, 20),
          movimientos: [m],
          conteo: const Conteo({2000: 2, 500: 1}),
        );
        expect(
          (await ExportadorPdf.actaCierre(caja, [m])).length,
          greaterThan(1000),
        );
        expect(
          (await ExportadorPdf.resumenCajas(
            ResumenCajas.de([caja], PeriodoCajas.todo),
            negocio: negocio,
          )).length,
          greaterThan(1000),
        );
      },
    );
  });

  group('Caja del día', () {
    Movimiento mov(
      String id,
      DateTime cuando, {
      Tipo tipo = Tipo.entro,
      int centavos = 10240,
      MedioPago medio = MedioPago.efectivo,
      DetalleEfectivo? detalle,
    }) => Movimiento(
      id: id,
      numero: 1,
      tipo: tipo,
      centavos: centavos,
      categoriaId: tipo == Tipo.entro ? 'ventas' : 'mercaderia',
      concepto: '',
      medio: medio,
      // La fecha puede ser de otro día: cuenta cuándo se registró.
      fecha: DateTime(2026, 9, 1),
      creadoEn: cuando,
      actualizadoEn: cuando,
      detalleEfectivo: detalle,
    );

    test('entra sólo el efectivo registrado mientras estuvo abierta', () {
      final caja = cajaAbierta(DateTime(2026, 9, 26, 8));
      final antes = mov('antes', DateTime(2026, 9, 26, 7));
      final venta = mov('venta', DateTime(2026, 9, 26, 9));
      final yape = mov(
        'yape',
        DateTime(2026, 9, 26, 10),
        medio: MedioPago.yape,
      );
      final compra = mov(
        'compra',
        DateTime(2026, 9, 26, 11),
        tipo: Tipo.salio,
        centavos: 3000,
      );
      final ajuste = mov('ajuste', DateTime(2026, 9, 26, 12));

      final dentro = caja.movimientosDe(
        [compra, yape, venta, antes, ajuste],
        ajustes: {'ajuste'},
      );
      expect(dentro.map((m) => m.id), ['venta', 'compra']);

      final conTotales = caja.conTotales(dentro);
      expect(conTotales.entradas, 10240);
      expect(conTotales.salidas, 3000);
      // Empezó con S/ 100.
      expect(conTotales.esperado, 10000 + 10240 - 3000);
    });

    test(
      'al cerrar, la diferencia es lo contado menos lo que debería haber',
      () {
        final venta = mov('venta', DateTime(2026, 9, 26, 9), centavos: 5000);
        final cerrada = cajaAbierta(DateTime(2026, 9, 26, 8)).cerrar(
          cerradaEn: DateTime(2026, 9, 26, 20),
          movimientos: [venta],
          conteo: const Conteo({10000: 1, 2000: 2}),
        );
        expect(cerrada.abierta, isFalse);
        expect(cerrada.esperado, 15000);
        expect(cerrada.contado, 14000);
        expect(cerrada.diferencia, -1000);
        expect(cerrada.hayFaltante, isTrue);
        expect(cerrada.estadoTexto, 'Faltan S/ 10.00');
        // Un movimiento registrado después del cierre ya no es de esta caja.
        expect(
          cerrada.incluye(mov('tarde', DateTime(2026, 9, 26, 21))),
          isFalse,
        );
      },
    );

    test('lo que no pasa a la caja nueva se guarda aparte', () {
      Jornada abre(InicioCaja inicio, int apertura) => Jornada(
        id: inicio.name,
        numero: 2,
        abiertaEn: DateTime(2026, 9, 27, 8),
        apertura: apertura,
        inicio: inicio,
        anterior: 48640,
        responsable: 'Ana',
        usuario: 'usuario',
      );
      expect(abre(InicioCaja.continua, 48640).apartado, 0);
      expect(abre(InicioCaja.desdeCero, 0).apartado, 48640);
      expect(abre(InicioCaja.otroMonto, 10000).apartado, 38640);
      expect(
        abre(InicioCaja.otroMonto, 10000).descripcionInicio,
        contains('se guardaron aparte S/ 386.40'),
      );
    });

    test('el estimado parte de lo contado al abrir y suma lo anotado', () {
      final caja = Jornada(
        id: 'j',
        numero: 1,
        abiertaEn: DateTime(2026, 9, 26, 8),
        apertura: 5000,
        conteoApertura: const Conteo({5000: 1}),
        inicio: InicioCaja.primera,
        responsable: 'Ana',
        usuario: 'usuario',
      );
      final conDetalle = mov(
        'v1',
        DateTime(2026, 9, 26, 10),
        detalle: DetalleEfectivo(
          entregado: const Conteo({5000: 2, 1000: 1}),
          vuelto: Conteo.sugerir(760),
        ),
      );
      final completo = EstimadoCaja.de(caja, [conDetalle])!;
      expect(completo.completo, isTrue);
      // 1×50 del inicio + 2×50 y 1×10 que entraron; salió el vuelto.
      expect(completo.conteo.cantidadDe(5000), 3);
      expect(completo.conteo.cantidadDe(1000), 1);
      expect(completo.conteo.cantidadDe(500), -1);

      final incompleto = EstimadoCaja.de(caja, [
        conDetalle,
        mov('v2', DateTime(2026, 9, 26, 11)),
      ])!;
      expect(incompleto.sinDetalle, 1);
      // Sin contar al abrir, no hay de dónde partir.
      expect(EstimadoCaja.de(cajaAbierta(DateTime(2026, 9, 26)), []), isNull);
    });

    test('se abre una sola a la vez, numerada, y se cierra', () async {
      final primera = await repo.abrirCaja(
        apertura: 10000,
        inicio: InicioCaja.primera,
        responsable: 'Ana Ruiz',
        usuario: 'usuario',
      );
      expect(primera.numero, 1);
      await expectLater(
        repo.abrirCaja(
          apertura: 0,
          inicio: InicioCaja.primera,
          responsable: 'Ana Ruiz',
          usuario: 'usuario',
        ),
        throwsA(isA<ArgumentError>()),
      );

      final cerrada = primera.cerrar(
        cerradaEn: DateTime.now(),
        movimientos: const [],
        conteo: const Conteo({10000: 1}),
      );
      await repo.guardarCierre(cerrada);
      final segunda = await repo.abrirCaja(
        apertura: 10000,
        inicio: InicioCaja.continua,
        anterior: 10000,
        conteo: const Conteo({10000: 1}),
        responsable: 'Ana Ruiz',
        usuario: 'usuario',
      );
      expect(segunda.numero, 2);

      final leidas = await repo.leerJornadas();
      expect(leidas.first.id, segunda.id);
      expect(leidas.last.cuadra, isTrue);
      expect(leidas.last.conteoCierre!.cantidadDe(10000), 1);
      expect(leidas.first.conteoApertura!.total, 10000);
    });

    test('los billetes contados al abrir tienen que sumar el monto', () async {
      await expectLater(
        repo.abrirCaja(
          apertura: 10000,
          inicio: InicioCaja.primera,
          conteo: const Conteo({5000: 1}),
          responsable: 'Ana',
          usuario: 'usuario',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('el resumen junta las cajas del período', () {
      final hoy = DateTime(2026, 9, 27, 12);
      Jornada caja(int n, DateTime abre, int entradas, int contado) =>
          cajaAbierta(abre, id: 'c$n', numero: n)
              .conTotales([
                mov(
                  'e$n',
                  abre.add(const Duration(hours: 1)),
                  centavos: entradas,
                ),
              ])
              .cerrar(
                cerradaEn: abre.add(const Duration(hours: 10)),
                movimientos: [
                  mov(
                    'e$n',
                    abre.add(const Duration(hours: 1)),
                    centavos: entradas,
                  ),
                ],
                conteo: Conteo.sugerir(contado),
              );
      final cajas = [
        caja(3, DateTime(2026, 9, 27, 8), 20000, 30000), // hoy, cuadra
        caja(2, DateTime(2026, 9, 22, 8), 10000, 19000), // lunes, falta 10
        caja(1, DateTime(2026, 8, 30, 8), 5000, 15000), // agosto
      ];
      final deHoy = ResumenCajas.de(cajas, PeriodoCajas.hoy, ahora: hoy);
      expect(deHoy.cajas.length, 1);
      final semana = ResumenCajas.de(cajas, PeriodoCajas.semana, ahora: hoy);
      expect(semana.cajas.length, 2);
      expect(semana.entradas, 30000);
      expect(semana.faltantes, 1000);
      expect(semana.ultimaCerrada!.numero, 3);
      expect(
        ResumenCajas.de(cajas, PeriodoCajas.mes, ahora: hoy).cajas.length,
        2,
      );
      expect(
        ResumenCajas.de(cajas, PeriodoCajas.todo, ahora: hoy).cajas.length,
        3,
      );
    });
  });

  test('una base v3 con la tabla de arqueos vieja migra a la última', () async {
    final carpeta = await Directory.systemTemp.createTemp('mi_caja_v3');
    final ruta = '${carpeta.path}/mi_caja.db';
    try {
      // Como la base del usuario: v3, y con la tabla `arqueos` que ya había
      // creado una versión anterior de la app.
      final vieja = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (d, _) async {
            await d.execute(Esquema.crearMovimientosV2);
            await d.execute(Esquema.crearNegocioV2);
            await d.execute(Esquema.crearCategorias);
            await d.execute(Esquema.crearArqueos);
          },
        ),
      );
      await vieja.insert(Esquema.tablaNegocio, {
        'id': 1,
        'razon_social': 'LIBERTAD SA',
      });
      await vieja.close();

      final nueva = await databaseFactoryFfi.openDatabase(
        ruta,
        options: BaseDatos.opciones,
      );
      expect(await nueva.getVersion(), Esquema.version);
      final negocio = await NegocioDao(database: nueva).leer();
      expect(negocio.razonSocial, 'LIBERTAD SA');
      expect(negocio.tesorero, '');
      expect(await JornadaDao(database: nueva).listar(), isEmpty);
      await nueva.close();
    } finally {
      await carpeta.delete(recursive: true);
    }
  });

  test('los arqueos de la v4 pasan a ser cajas cerradas', () async {
    final carpeta = await Directory.systemTemp.createTemp('mi_caja_v4');
    final ruta = '${carpeta.path}/mi_caja.db';
    try {
      final vieja = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (d, _) async {
            await d.execute(Esquema.crearMovimientos);
            await d.execute(Esquema.crearNegocio);
            await d.execute(Esquema.crearCategorias);
            await d.execute(Esquema.crearArqueos);
          },
        ),
      );
      // Como el que guardó el usuario: contra el saldo del libro.
      await vieja.insert(Esquema.tablaArqueos, {
        'id': 'a1',
        'fecha_corte': DateTime(2026, 9, 26, 20).millisecondsSinceEpoch,
        'confirmado_en': DateTime(2026, 9, 26, 20).millisecondsSinceEpoch,
        'esperado': 4240000,
        'contado': 94960,
        'diferencia': 94960 - 4240000,
        'conteo_json': jsonEncode(Conteo.sugerir(94960).aJson()),
        'responsable': 'Ana',
        'usuario': 'usuario',
        'supervisor': '',
        'observacion': '',
        'negocio': 'LIBERTAD SA',
        'documento': '20304050601',
      });
      await vieja.close();

      final nueva = await databaseFactoryFfi.openDatabase(
        ruta,
        options: BaseDatos.opciones,
      );
      final cajas = await JornadaDao(database: nueva).listar();
      expect(cajas.single.inicio, InicioCaja.libro);
      expect(cajas.single.numero, 1);
      expect(cajas.single.abierta, isFalse);
      expect(cajas.single.contado, 94960);
      expect(cajas.single.diferencia, 94960 - 4240000);
      await nueva.close();
    } finally {
      await carpeta.delete(recursive: true);
    }
  });
}

/// Una caja abierta con S/ 100, sin contar billetes.
Jornada cajaAbierta(DateTime abre, {String id = 'j', int numero = 1}) =>
    Jornada(
      id: id,
      numero: numero,
      abiertaEn: abre,
      apertura: 10000,
      inicio: InicioCaja.primera,
      responsable: 'Ana',
      usuario: 'usuario',
    );
