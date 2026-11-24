import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/datos/db/base_datos.dart';
import 'package:mi_caja/datos/db/esquema.dart';
import 'package:mi_caja/datos/local/categoria_dao.dart';
import 'package:mi_caja/datos/local/fondo_dao.dart';
import 'package:mi_caja/datos/local/jornada_dao.dart';
import 'package:mi_caja/datos/local/movimiento_dao.dart';
import 'package:mi_caja/datos/local/negocio_dao.dart';
import 'package:mi_caja/datos/repositorio/repositorio_demo.dart';
import 'package:mi_caja/datos/repositorio/repositorio_movimientos.dart';
import 'package:mi_caja/dominio/almacen.dart';
import 'package:mi_caja/dominio/banco.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/igv.dart';
import 'package:mi_caja/dominio/kardex.dart';
import 'package:mi_caja/dominio/mercaderia.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/dominio/periodo.dart';
import 'package:mi_caja/dominio/reglas_mercaderia.dart';
import 'package:mi_caja/dominio/tablas_sunat.dart';
import 'package:mi_caja/estado/estado_caja.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// La v9: productos, el kardex en la base y las reglas del almacén (P2).
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    Pcge.cargarDeTexto(File('assets/pcge.json').readAsStringSync());
  });
  setUp(() => Categoria.registrarPropias(const []));

  RepositorioMovimientos repositorio(Database db) => RepositorioMovimientos(
    dao: MovimientoDao(database: db),
    negocioDao: NegocioDao(database: db),
    categoriaDao: CategoriaDao(database: db),
    jornadaDao: JornadaDao(database: db),
    fondoDao: FondoDao(database: db),
  );

  group('Tablas y reglas', () {
    test('las tablas de SUNAT traen los códigos del Excel', () {
      expect(TablasSunat.tipoExistencia('01')?.descripcion, 'Mercadería');
      expect(TablasSunat.unidad('07')?.descripcion, 'Unidades');
      expect(TablasSunat.unidad('13')?.descripcion, 'Millares');
      expect(TablasSunat.comprobante('01')?.descripcion, 'Factura');
      expect(TablasSunat.comprobante('03')?.descripcion, 'Boleta de Venta');
      expect(TablasSunat.comprobante('07')?.descripcion, 'Nota de crédito');
      expect(TablasSunat.comprobantes, hasLength(48));
      expect(TablasSunat.operaciones, hasLength(17));
      for (final tabla in [
        TablasSunat.tiposDeExistencia.map((t) => t.codigo),
        TablasSunat.unidades.map((u) => u.codigo),
        TablasSunat.comprobantes.map((c) => c.codigo),
        TablasSunat.operaciones.map((o) => o.codigo),
      ]) {
        expect(tabla.toSet().length, tabla.length);
      }
      // Cada operación del almacén existe en la Tabla 12.
      for (final o in OperacionAlmacen.values) {
        expect(TablasSunat.operacion(o.codigo), isNotNull, reason: o.name);
      }
      expect(TablasSunat.unidadEntera('07'), isTrue);
      expect(TablasSunat.unidadEntera('01'), isFalse);
      expect(TablasSunat.unidadEntera('xx'), isTrue);
    });

    test('las cantidades van en milésimas exactas', () {
      expect(Cantidad.leer('1600'), 1600000);
      expect(Cantidad.leer(' 0,5 '), 500);
      expect(Cantidad.leer('2.125'), 2125);
      expect(Cantidad.leer('1.2345'), isNull);
      expect(Cantidad.leer('-3'), isNull);
      expect(Cantidad.leer('abc'), isNull);
      expect(Cantidad.texto(1600000), '1,600');
      expect(Cantidad.texto(500), '0.5');
      expect(Cantidad.texto(1234567890), '1,234,567.89');
      expect(Cantidad.texto(-2000), '-2');
      expect(Cantidad.de(48.6), 48600);
    });

    test('el comprobante se revisa como lo pide SUNAT', () {
      const factura = Comprobante(tipo: '01', serie: 'fe01 ', numero: '112');
      expect(factura.limpio.problema, isNull);
      expect(factura.limpio.texto, 'FE01-112');
      expect(
        const Comprobante(tipo: '01', serie: 'F1', numero: '1').problema,
        isNotNull,
      );
      expect(
        const Comprobante(tipo: '03', serie: 'BE01', numero: '1A').problema,
        isNotNull,
      );
      expect(const Comprobante(tipo: '00').problema, isNull);
      expect(const Comprobante(tipo: '09', serie: 'T001').problema, isNotNull);
      expect(const Comprobante(tipo: '77', numero: '1').problema, isNotNull);
    });

    test('el monto para unas líneas siempre deja exacto su valor sin IGV', () {
      expect(ReglasMercaderia.montoParaLineas(8320000, conIgv: true), 9817600);
      expect(ReglasMercaderia.montoParaLineas(8840000, conIgv: false), 8840000);
      for (var suma = 1; suma < 30000; suma += 7) {
        final total = ReglasMercaderia.montoParaLineas(suma, conIgv: true);
        expect(Igv.desagregar(total).base, suma, reason: '$suma');
      }
    });

    test('código sugerido, cuenta del costo y descripción', () {
      Mercaderia p(String codigo) => Mercaderia(
        id: codigo,
        nombre: codigo,
        creadoEn: DateTime(2026),
        codigo: codigo,
      );
      expect(ReglasMercaderia.codigoSugerido(const []), 'P001');
      expect(
        ReglasMercaderia.codigoSugerido([p('P001'), p('P009'), p('POSA 001')]),
        'P010',
      );
      expect(
        ReglasMercaderia.cuentaCostoDeVenta(
          exportacion: false,
          vinculo: Vinculo.tercero,
        ),
        '69121',
      );
      expect(
        ReglasMercaderia.cuentaCostoDeVenta(
          exportacion: false,
          vinculo: Vinculo.filial,
        ),
        '69122',
      );
      expect(
        ReglasMercaderia.cuentaCostoDeVenta(
          exportacion: true,
          vinculo: Vinculo.tercero,
        ),
        '69111',
      );
      expect(
        ReglasMercaderia.cuentaCostoDeVenta(
          exportacion: true,
          vinculo: Vinculo.matriz,
        ),
        '69112',
      );
      for (final c in ['69121', '69122', '69111', '69112']) {
        expect(Pcge.instancia.existe(c), isTrue, reason: c);
      }
      expect(ReglasMercaderia.descripcionDe(['Ponchos']), 'Ponchos');
      expect(
        ReglasMercaderia.descripcionDe(['Ponchos', 'Mantas']),
        'Ponchos y Mantas',
      );
      expect(
        ReglasMercaderia.descripcionDe(['Ponchos', 'Mantas', 'Gorros']),
        'Ponchos y 2 productos más',
      );
    });

    test('lo que sale con fecha pasada no deja sin stock a lo de después', () {
      LineaAlmacen l(int dia, int numero, int cantidad, {bool entra = false}) =>
          LineaAlmacen(
            id: '$numero',
            mercaderiaId: 'p',
            fecha: DateTime(2026, 10, dia, 9),
            numero: numero,
            operacion: entra ? OperacionAlmacen.compra : OperacionAlmacen.venta,
            entrada: entra,
            cantidad: Cantidad.de(cantidad),
          );
      final lineas = [l(1, 1, 100, entra: true), l(5, 2, 80)];
      expect(StockAlmacen.saldo(lineas, 'p'), Cantidad.de(20));
      expect(
        StockAlmacen.saldo(lineas, 'p', al: DateTime(2026, 10, 3)),
        100000,
      );
      expect(
        StockAlmacen.disponible(lineas, 'p', DateTime(2026, 10, 3)),
        20000,
      );
      expect(
        StockAlmacen.disponible(lineas, 'p', DateTime(2026, 10, 6)),
        20000,
      );
      expect(StockAlmacen.disponible(lineas, 'q', DateTime(2026, 10, 6)), 0);
      // Una venta del mismo día, anotada a medianoche, va después de la
      // compra de esa mañana: el orden es por día y número.
      final mismaFecha = [
        l(1, 1, 100, entra: true),
        LineaAlmacen(
          id: 'x',
          mercaderiaId: 'p',
          fecha: DateTime(2026, 10, 1),
          numero: 2,
          operacion: OperacionAlmacen.venta,
          entrada: false,
          cantidad: Cantidad.de(100),
        ),
      ];
      expect(StockAlmacen.faltante(const [], mismaFecha), isNull);
      expect(
        StockAlmacen.faltante(lineas, [l(3, 3, 30)])?.disponible,
        Cantidad.de(20),
      );
      expect(StockAlmacen.faltante(lineas, [l(3, 3, 20)]), isNull);
    });
  });

  test('v8 abre en v9: los tipos reciben código y nada se pierde', () async {
    final dir = await Directory.systemTemp.createTemp('mi_caja_v9_');
    final ruta = '${dir.path}/prueba.db';
    Database? db;
    try {
      db = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 8,
          onCreate: (db, _) async {
            for (final sql in [
              Esquema.crearMercaderiasV7,
              Esquema.crearMovimientosV8,
              Esquema.crearNegocioV8,
              Esquema.crearCategorias,
              Esquema.crearJornadas,
              Esquema.crearFondo,
            ]) {
              await db.execute(sql);
            }
          },
        ),
      );
      await db.insert('mercaderias', {
        'id': 'tela',
        'nombre': 'Tela',
        'nombre_clave': 'tela',
        'creado_en': 20,
      });
      await db.insert('mercaderias', {
        'id': 'pintura',
        'nombre': 'Pintura',
        'nombre_clave': 'pintura',
        'creado_en': 10,
      });
      final fecha = DateTime(2026, 10, 1);
      final viejo =
          Movimiento(
              id: 'compra',
              numero: 1,
              tipo: Tipo.salio,
              centavos: 118000,
              categoriaId: 'mercaderia',
              concepto: '',
              medio: MedioPago.transferencia,
              fecha: fecha,
              creadoEn: fecha,
              actualizadoEn: fecha,
              igvCentavos: 18000,
              mercaderiaId: 'tela',
              mercaderiaNombre: 'Tela',
              sync: EstadoSync.local,
            ).aMapa()
            ..remove('doc_tipo')
            ..remove('doc_serie')
            ..remove('doc_numero')
            ..remove('exportacion')
            ..remove('registrado_por')
            ..remove('anulado_en')
            ..remove('reemplazado_por');
      await db.insert('movimientos', viejo);
      await db.insert('negocio', {
        'id': 1,
        'razon_social': 'LIBERTAD S.A.',
        'documento': '20304050601',
      });
      await db.close();

      db = await databaseFactoryFfi.openDatabase(
        ruta,
        options: BaseDatos.opciones,
      );
      expect(await db.getVersion(), 9);

      // La más antigua primero: Pintura es P001.
      final productos = {
        for (final f in await db.query('mercaderias'))
          f['id']: Mercaderia.desdeMapa(f),
      };
      expect(productos['pintura']!.codigo, 'P001');
      expect(productos['tela']!.codigo, 'P002');
      expect(productos['tela']!.unidad, '07');
      expect(productos['tela']!.tipoExistencia, '01');
      expect(productos['tela']!.activo, isTrue);
      expect(productos['tela']!.stockMinimo, 0);
      expect(productos['tela']!.precioSugerido, isNull);
      expect(productos['tela']!.unidadCompra, isNull);
      expect(productos['tela']!.unidadFactura, 'NIU');

      final m = Movimiento.desdeMapa((await db.query('movimientos')).single);
      expect(m.mercaderiaId, 'tela');
      expect(m.comprobante, isNull);
      expect(m.exportacion, isFalse);
      expect(m.sinIgv, isFalse);
      expect(m.descripcionFormato, 'Compra de Tela');
      expect(m.anulado, isFalse);
      expect(m.registradoPor, isNull);
      expect(await db.query('cierres'), isEmpty);

      final negocio = await NegocioDao(database: db).leer();
      expect(negocio.razonSocial, 'LIBERTAD S.A.');
      expect(negocio.metodoValuacion, MetodoValuacion.promedio);
      expect(negocio.kardexDesde, isNull);

      // Lo de antes no entra al kardex: no tiene cantidades.
      expect(await db.query('kardex'), isEmpty);
      // El código es único.
      await expectLater(
        db.update(
          'mercaderias',
          {'codigo': 'P001'},
          where: 'id = ?',
          whereArgs: ['tela'],
        ),
        throwsA(isA<DatabaseException>()),
      );

      // Una base migrada y una nueva quedan con las mismas columnas.
      final nueva = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: BaseDatos.opciones,
      );
      try {
        Future<Set<String>> columnas(Database d, String tabla) async => {
          for (final c in await d.rawQuery('PRAGMA table_info($tabla)'))
            '${c['name']} ${c['type']} ${c['notnull']} ${c['dflt_value']}',
        };
        for (final tabla in [
          'mercaderias',
          'movimientos',
          'negocio',
          'kardex',
          'cierres',
        ]) {
          expect(
            await columnas(db, tabla),
            await columnas(nueva, tabla),
            reason: tabla,
          );
        }
      } finally {
        await nueva.close();
      }
    } finally {
      await db?.close();
      await dir.delete(recursive: true);
    }
  });

  test('si falla una línea, no queda guardado ni el movimiento', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: BaseDatos.opciones,
    );
    try {
      final dao = MovimientoDao(database: db);
      final hoy = DateTime(2026, 10, 1);
      await expectLater(
        dao.insertarNumerado(
          Tipo.salio,
          false,
          (n, _, _) => Movimiento(
            id: 'm',
            numero: n,
            tipo: Tipo.salio,
            centavos: 100,
            categoriaId: 'mercaderia',
            concepto: '',
            medio: MedioPago.transferencia,
            fecha: hoy,
            creadoEn: hoy,
            actualizadoEn: hoy,
            sync: EstadoSync.local,
          ),
          despues: (txn, m) async {
            // Una cantidad en cero: la tabla misma la rechaza.
            await txn.insert('kardex', {
              'id': 'l',
              'mercaderia_id': 'x',
              'fecha': 1,
              'numero': 1,
              'operacion': 'compra',
              'entrada': 1,
              'cantidad': 0,
              'movimiento_id': m.id,
              'creado_en': 1,
            });
          },
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(await dao.listar(), isEmpty);
      expect(await db.query('kardex'), isEmpty);
    } finally {
      await db.close();
    }
  });

  for (final web in [false, true]) {
    group(web ? 'Demo web' : 'SQLite', () {
      late RepositorioMovimientos repo;
      Database? db;
      setUp(() async {
        if (web) {
          repo = RepositorioDemo();
        } else {
          db = await databaseFactoryFfi.openDatabase(
            inMemoryDatabasePath,
            options: BaseDatos.opciones,
          );
          repo = repositorio(db!);
        }
      });
      tearDown(() async => db?.close());

      DateTime dia(int d) => DateTime(2026, 10, d);

      Future<Movimiento> compra(
        List<LineaNueva> lineas, {
        int fecha = 2,
        Comprobante? comprobante,
        bool sinIgv = false,
        int? centavos,
      }) {
        final suma = lineas.fold(0, (t, l) => t + l.importe);
        return repo.registrar(
          tipo: Tipo.salio,
          centavos:
              centavos ??
              ReglasMercaderia.montoParaLineas(suma, conIgv: !sinIgv),
          categoriaId: 'mercaderia',
          concepto: '',
          medio: MedioPago.transferencia,
          fecha: dia(fecha),
          lineas: lineas,
          comprobante: comprobante,
          sinIgv: sinIgv,
        );
      }

      Future<Movimiento> venta(
        List<LineaNueva> lineas, {
        int fecha = 5,
        Comprobante? comprobante,
        bool exportacion = false,
        Vinculo vinculo = Vinculo.tercero,
      }) {
        final suma = lineas.fold(0, (t, l) => t + l.importe);
        return repo.registrar(
          tipo: Tipo.entro,
          centavos: ReglasMercaderia.montoParaLineas(
            suma,
            conIgv: !exportacion,
          ),
          categoriaId: 'ventas',
          concepto: '',
          medio: MedioPago.transferencia,
          fecha: dia(fecha),
          contraparte: 'Cliente',
          documentoContraparte: '20304050811',
          lineas: lineas,
          comprobante: comprobante,
          exportacion: exportacion,
          vinculo: vinculo,
        );
      }

      Future<LineaAlmacen> inicial(
        Mercaderia p,
        num cantidad,
        int costo, {
        int fecha = 1,
      }) => repo.registrarEnAlmacen(
        operacion: OperacionAlmacen.saldoInicial,
        mercaderiaId: p.id,
        fecha: dia(fecha),
        cantidad: Cantidad.de(cantidad),
        costoTotal: costo,
      );

      LineaNueva linea(Mercaderia p, num cantidad, int importe) => LineaNueva(
        mercaderiaId: p.id,
        cantidad: Cantidad.de(cantidad),
        importe: importe,
      );

      test('productos: código sugerido, sin repetir y unidad fija', () async {
        final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
        expect(ponchos.codigo, 'P001');
        expect(ponchos.unidad, TablasSunat.unidadesSueltas);
        expect(ponchos.tipoExistencia, TablasSunat.mercaderia);
        expect(ponchos.activo, isTrue);
        final mantas = await repo.agregarMercaderia('Mantas');
        expect(mantas.codigo, 'P002');

        await expectLater(
          repo.guardarProducto(nombre: 'Gorros', codigo: 'p001'),
          throwsArgumentError,
        );
        await expectLater(
          repo.guardarProducto(nombre: '  ponchos '),
          throwsArgumentError,
        );
        await expectLater(
          repo.guardarProducto(nombre: 'Gorros', unidad: '77'),
          throwsArgumentError,
        );
        await expectLater(
          repo.guardarProducto(nombre: 'Gorros', stockMinimo: Cantidad.de(1.5)),
          throwsArgumentError,
        );
        final azucar = await repo.guardarProducto(
          nombre: 'Azúcar',
          codigo: ' posa   001 ',
          unidad: '01',
          stockMinimo: Cantidad.de(2.5),
        );
        expect(azucar.codigo, 'POSA 001');

        final editado = await repo.guardarProducto(
          id: ponchos.id,
          nombre: 'Ponchos artesanales talla estándar',
          stockMinimo: Cantidad.de(100),
          precioSugerido: 7000,
        );
        expect(editado.id, ponchos.id);
        expect(editado.codigo, 'P001');
        expect(editado.creadoEn, ponchos.creadoEn);
        expect(editado.precioSugerido, 7000);

        // Con movimientos, la unidad ya no cambia; lo demás sí.
        await inicial(editado, 10, 50000);
        await expectLater(
          repo.guardarProducto(
            id: ponchos.id,
            nombre: editado.nombre,
            unidad: '01',
          ),
          throwsArgumentError,
        );
        final apagado = await repo.guardarProducto(
          id: ponchos.id,
          nombre: editado.nombre,
          stockMinimo: editado.stockMinimo,
          activo: false,
        );
        expect(apagado.activo, isFalse);
        expect(apagado.precioSugerido, isNull);

        final todos = await repo.leerMercaderias();
        expect(todos.map((m) => m.codigo).toSet(), {
          'P001',
          'P002',
          'POSA 001',
        });
        expect(todos.firstWhere((m) => m.id == ponchos.id).activo, isFalse);
      });

      test('saldo inicial: una sola vez, antes de todo, y fija desde cuándo '
          'corre el kardex', () async {
        final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
        await expectLater(
          repo.registrarEnAlmacen(
            operacion: OperacionAlmacen.saldoInicial,
            mercaderiaId: ponchos.id,
            fecha: dia(1),
            cantidad: Cantidad.de(1200),
          ),
          throwsArgumentError,
        );
        await expectLater(inicial(ponchos, 1.5, 100), throwsArgumentError);

        final l = await inicial(ponchos, 1200, 6000000, fecha: 3);
        expect(l.operacion, OperacionAlmacen.saldoInicial);
        expect(l.entrada, isTrue);
        expect(l.cantidad, 1200000);
        expect(l.costoTotal, 6000000);
        expect(l.numero, 1);
        expect((await repo.leerNegocio()).kardexDesde, dia(3));

        await expectLater(inicial(ponchos, 10, 500), throwsArgumentError);

        final mantas = await repo.guardarProducto(nombre: 'Mantas');
        await inicial(mantas, 5, 1000, fecha: 1);
        expect((await repo.leerNegocio()).kardexDesde, dia(1));
        expect((await repo.leerLineasAlmacen()).map((l) => l.mercaderiaId), [
          mantas.id,
          ponchos.id,
        ]);
      });

      test('una compra con dos productos guarda el movimiento y sus líneas '
          'juntos', () async {
        final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
        final mantas = await repo.guardarProducto(nombre: 'Mantas');
        final m = await compra(
          [linea(ponchos, 10, 50000), linea(mantas, 2, 30000)],
          comprobante: const Comprobante(
            tipo: '01',
            serie: 'fe01',
            numero: '234',
          ),
        );
        expect(m.centavos, 94400);
        expect(m.igvCentavos, 14400);
        expect(
          m.comprobante,
          const Comprobante(tipo: '01', serie: 'FE01', numero: '234'),
        );
        expect(m.mercaderiaId, isNull);
        expect(m.mercaderiaNombre, 'Ponchos y Mantas');
        expect(m.descripcionFormato, 'Compra de Ponchos y Mantas');

        final lineas = await repo.lineasDeMovimiento(m.id);
        expect(lineas, hasLength(2));
        expect(lineas.map((l) => l.numero), [1, 2]);
        for (final l in lineas) {
          expect(l.operacion, OperacionAlmacen.compra);
          expect(l.entrada, isTrue);
          expect(l.costoTotal, l.importe);
          expect(l.movimientoId, m.id);
          expect(l.comprobante?.texto, 'FE01-234');
          expect(l.cuentaCosto, isNull);
        }
        expect(lineas.first.cantidad, 10000);
        expect((await repo.leerLineasAlmacen()), hasLength(2));
        final leido = (await repo.listar()).single;
        expect(leido.comprobante?.texto, 'FE01-234');
      });

      test('una compra que no cuadra no deja nada guardado', () async {
        final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
        final otro = await repo.guardarProducto(nombre: 'Gorros');
        await repo.guardarProducto(
          id: otro.id,
          nombre: otro.nombre,
          activo: false,
        );
        for (final intento in [
          () => compra([linea(ponchos, 10, 50000)], centavos: 100000),
          () => compra([linea(ponchos, 10, 50000), linea(ponchos, 1, 5000)]),
          () => compra([linea(otro, 1, 5000)]),
          () => compra([linea(ponchos, 0, 5000)]),
          () => compra([linea(ponchos, 1.5, 5000)]),
          () => compra([linea(ponchos, 1, 0)]),
          () => compra([
            linea(ponchos, 1, 5000),
          ], comprobante: const Comprobante(tipo: '01', serie: 'F1')),
          () => repo.registrar(
            tipo: Tipo.salio,
            centavos: 5900,
            categoriaId: 'luz',
            concepto: '',
            medio: MedioPago.transferencia,
            fecha: dia(2),
            lineas: [linea(ponchos, 1, 5000)],
          ),
          () => repo.registrar(
            tipo: Tipo.salio,
            centavos: 5900,
            categoriaId: 'mercaderia',
            concepto: '',
            medio: MedioPago.transferencia,
            fecha: dia(2),
            mercaderiaId: ponchos.id,
            lineas: [linea(ponchos, 1, 5000)],
          ),
        ]) {
          await expectLater(intento(), throwsArgumentError);
        }
        expect(await repo.listar(), isEmpty);
        expect(await repo.leerLineasAlmacen(), isEmpty);
      });

      test('compra sin IGV: las líneas suman el total', () async {
        final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
        final m = await compra([linea(ponchos, 1700, 8840000)], sinIgv: true);
        expect(m.centavos, 8840000);
        expect(m.igvCentavos, 0);
        expect(m.sinIgv, isTrue);
        final l = (await repo.lineasDeMovimiento(m.id)).single;
        expect(l.costoTotal, 8840000);
        expect(l.docTipo, TablasSunat.otros);
      });

      test(
        'una venta no saca más de lo que hay, ni con fecha pasada',
        () async {
          final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
          await inicial(ponchos, 100, 500000);

          await expectLater(
            venta([linea(ponchos, 150, 1050000)]),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'mensaje',
                contains('100 und'),
              ),
            ),
          );
          final v = await venta([linea(ponchos, 80, 560000)]);
          final l = (await repo.lineasDeMovimiento(v.id)).single;
          expect(l.operacion, OperacionAlmacen.venta);
          expect(l.entrada, isFalse);
          expect(l.costoTotal, isNull);
          expect(l.importe, 560000);
          expect(l.cuentaCosto, '69121');
          // La app le pone su factura electrónica: el cliente tiene RUC.
          expect(v.comprobante?.texto, 'F001-1');
          expect(l.docTipo, TablasSunat.factura);
          expect(l.comprobante?.texto, 'F001-1');
          expect(v.costoCentavos, isNull);
          expect(v.descripcionFormato, 'Venta de Ponchos');

          // El 3 había 100, pero el 5 salen 80: el 3 sólo pueden salir 20.
          await expectLater(
            venta([linea(ponchos, 30, 210000)], fecha: 3),
            throwsArgumentError,
          );
          await venta([linea(ponchos, 20, 140000)], fecha: 3);
          final lineas = await repo.leerLineasAlmacen();
          expect(StockAlmacen.saldo(lineas, ponchos.id), 0);
          expect(lineas.map((l) => l.efecto), [
            100000,
            -20000,
            -80000,
          ], reason: 'por día y, dentro del día, por número');
        },
      );

      test('exportación: sin IGV y costo a 69111; sólo en ventas', () async {
        final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
        await inicial(ponchos, 100, 500000);
        final v = await venta(
          [linea(ponchos, 10, 80000)],
          exportacion: true,
          comprobante: const Comprobante(
            tipo: '01',
            serie: 'FE01',
            numero: '113',
          ),
        );
        expect(v.exportacion, isTrue);
        expect(v.igvCentavos, 0);
        expect(v.centavos, 80000);
        expect(v.sinIgv, isFalse);
        final l = (await repo.lineasDeMovimiento(v.id)).single;
        expect(l.cuentaCosto, '69111');
        expect(l.comprobante?.texto, 'FE01-113');

        final w = await venta(
          [linea(ponchos, 1, 8000)],
          exportacion: true,
          vinculo: Vinculo.matriz,
        );
        expect(w.comprobante?.texto, 'F001-1');
        expect(
          (await repo.lineasDeMovimiento(w.id)).single.cuentaCosto,
          '69112',
        );
        final r = await venta([
          linea(ponchos, 1, 8000),
        ], vinculo: Vinculo.filial);
        expect(
          (await repo.lineasDeMovimiento(r.id)).single.cuentaCosto,
          '69122',
        );

        await expectLater(
          repo.registrar(
            tipo: Tipo.salio,
            centavos: 5000,
            categoriaId: 'mercaderia',
            concepto: '',
            medio: MedioPago.transferencia,
            fecha: dia(2),
            lineas: [linea(ponchos, 1, 5000)],
            exportacion: true,
          ),
          throwsArgumentError,
        );
      });

      test('merma, desmedro y ajuste', () async {
        final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
        await inicial(ponchos, 100, 500000);
        Future<LineaAlmacen> anotar(
          OperacionAlmacen o,
          num cantidad, {
          bool? entrada,
          int? costo,
          String motivo = 'Se mojaron',
        }) => repo.registrarEnAlmacen(
          operacion: o,
          mercaderiaId: ponchos.id,
          fecha: dia(4),
          cantidad: Cantidad.de(cantidad),
          entrada: entrada,
          costoTotal: costo,
          glosa: motivo,
        );

        await expectLater(
          anotar(OperacionAlmacen.merma, 5, motivo: '  '),
          throwsArgumentError,
        );
        await expectLater(
          anotar(OperacionAlmacen.merma, 101),
          throwsArgumentError,
        );
        await expectLater(
          anotar(OperacionAlmacen.merma, 5, costo: 100),
          throwsArgumentError,
        );
        await expectLater(
          anotar(OperacionAlmacen.merma, 5, entrada: true),
          throwsArgumentError,
        );
        final merma = await anotar(OperacionAlmacen.merma, 5);
        expect(merma.entrada, isFalse);
        expect(merma.glosa, 'Se mojaron');
        expect(merma.costoTotal, isNull);
        await anotar(OperacionAlmacen.desmedro, 2, motivo: 'Rotos');

        await expectLater(
          anotar(OperacionAlmacen.ajuste, 1, motivo: 'Conteo'),
          throwsArgumentError,
        );
        await expectLater(
          anotar(OperacionAlmacen.ajuste, 1, entrada: false, costo: 500),
          throwsArgumentError,
        );
        final sobra = await anotar(
          OperacionAlmacen.ajuste,
          3,
          entrada: true,
          motivo: 'Conteo',
        );
        expect(sobra.entrada, isTrue);
        expect(sobra.costoTotal, isNull);
        await anotar(
          OperacionAlmacen.ajuste,
          6,
          entrada: false,
          motivo: 'Conteo',
        );

        expect(
          StockAlmacen.saldo(await repo.leerLineasAlmacen(), ponchos.id),
          Cantidad.de(100 - 5 - 2 + 3 - 6),
        );
        await expectLater(
          repo.registrarEnAlmacen(
            operacion: OperacionAlmacen.venta,
            mercaderiaId: ponchos.id,
            fecha: dia(4),
            cantidad: 1000,
          ),
          throwsArgumentError,
        );
      });

      test(
        'devoluciones: sobre su operación y sin pasar lo que se movió',
        () async {
          final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
          final mantas = await repo.guardarProducto(nombre: 'Mantas');
          final c = await compra([linea(ponchos, 100, 500000)], fecha: 2);
          final lc = (await repo.lineasDeMovimiento(c.id)).single;
          final v = await venta([linea(ponchos, 80, 560000)], fecha: 5);
          final lv = (await repo.lineasDeMovimiento(v.id)).single;

          Future<LineaAlmacen> devolver(
            OperacionAlmacen o,
            String? origen,
            num cantidad, {
            int fecha = 6,
            String? producto,
          }) => repo.registrarEnAlmacen(
            operacion: o,
            mercaderiaId: producto ?? ponchos.id,
            fecha: dia(fecha),
            cantidad: Cantidad.de(cantidad),
            origenId: origen,
            comprobante: const Comprobante(
              tipo: '07',
              serie: 'FC01',
              numero: '1',
            ),
          );

          const recibida = OperacionAlmacen.devolucionRecibida;
          const entregada = OperacionAlmacen.devolucionEntregada;
          await expectLater(devolver(recibida, null, 1), throwsArgumentError);
          await expectLater(devolver(recibida, lc.id, 1), throwsArgumentError);
          await expectLater(
            devolver(recibida, lv.id, 1, fecha: 4),
            throwsArgumentError,
          );
          await expectLater(
            devolver(recibida, lv.id, 1, producto: mantas.id),
            throwsArgumentError,
          );
          final d = await devolver(recibida, lv.id, 30);
          expect(d.entrada, isTrue);
          expect(d.origenId, lv.id);
          expect(d.comprobante?.texto, 'FC01-1');
          await expectLater(
            devolver(recibida, lv.id, 60),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'mensaje',
                contains('quedan 50'),
              ),
            ),
          );

          // Hay 100 − 80 + 30 = 50: al proveedor se le pueden devolver 50.
          await expectLater(
            devolver(entregada, lc.id, 60),
            throwsArgumentError,
          );
          final e = await devolver(entregada, lc.id, 50);
          expect(e.entrada, isFalse);
          expect(
            StockAlmacen.saldo(await repo.leerLineasAlmacen(), ponchos.id),
            0,
          );
          await expectLater(
            repo.registrarEnAlmacen(
              operacion: OperacionAlmacen.merma,
              mercaderiaId: ponchos.id,
              fecha: dia(6),
              cantidad: 1000,
              origenId: lc.id,
              glosa: 'x',
            ),
            throwsArgumentError,
          );
        },
      );

      test('con productos no se borra ni se rehace; el voucher sí', () async {
        final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
        final c = await compra([linea(ponchos, 10, 50000)]);
        await expectLater(repo.eliminar(c), throwsArgumentError);
        await expectLater(
          repo.editar(c.copiarCon(centavos: 1000)),
          throwsArgumentError,
        );
        await expectLater(
          repo.editar(c.copiarCon(fecha: dia(9))),
          throwsArgumentError,
        );
        final completado = await repo.editar(
          c.copiarCon(rutaFoto: 'voucher.png', numeroTransaccion: '0099'),
        );
        expect(completado.rutaFoto, 'voucher.png');
        expect(await repo.lineasDeMovimiento(c.id), hasLength(1));

        // Lo que no tiene productos se sigue pudiendo borrar.
        final luz = await repo.registrar(
          tipo: Tipo.salio,
          centavos: 17700,
          categoriaId: 'luz',
          concepto: '',
          medio: MedioPago.transferencia,
          fecha: dia(2),
        );
        await repo.eliminar(luz);
        expect((await repo.listar()).map((m) => m.id), [c.id]);
      });

      test(
        'P4 exige al menos una línea en las compras de mercadería',
        () async {
          final tela = await repo.agregarMercaderia('Tela');
          await expectLater(
            repo.registrar(
              tipo: Tipo.salio,
              centavos: 118000,
              categoriaId: 'mercaderia',
              concepto: '',
              medio: MedioPago.transferencia,
              fecha: dia(2),
              mercaderiaId: tela.id,
            ),
            throwsArgumentError,
          );
          expect(await repo.listar(), isEmpty);
          expect(await repo.leerLineasAlmacen(), isEmpty);
          expect(ReglasMercaderia.exigirLineas, isTrue);
        },
      );

      test('el ejercicio del Excel del kardex queda en 900 unidades', () async {
        final ponchos = await repo.guardarProducto(
          nombre: 'Ponchos artesanales talla estándar',
          codigo: 'POSA 001',
          precioSugerido: 7000,
        );
        await inicial(ponchos, 1200, 6000000);
        for (final op in ejercicioDelExcel) {
          final doc = Comprobante(
            tipo: op.serie.startsWith('B') ? '03' : '01',
            serie: op.serie,
            numero: op.numero,
          );
          final l = LineaNueva(
            mercaderiaId: ponchos.id,
            cantidad: Cantidad.de(op.cantidad),
            importe: (op.cantidad * op.unitario * 100).round(),
          );
          if (op.compra) {
            await repo.registrar(
              tipo: Tipo.salio,
              centavos: ReglasMercaderia.montoParaLineas(
                l.importe,
                conIgv: !op.sinIgv,
              ),
              categoriaId: 'mercaderia',
              concepto: '',
              medio: MedioPago.cheque,
              fecha: dia(op.dia),
              contraparte: op.quien,
              lineas: [l],
              comprobante: doc,
              sinIgv: op.sinIgv,
            );
          } else {
            await repo.registrar(
              tipo: Tipo.entro,
              centavos: ReglasMercaderia.montoParaLineas(
                l.importe,
                conIgv: !op.exportacion,
              ),
              categoriaId: 'ventas',
              concepto: '',
              medio: MedioPago.cheque,
              fecha: dia(op.dia),
              contraparte: op.quien,
              documentoContraparte: doc.tipo == '03'
                  ? '12345678'
                  : '20304050811',
              lineas: [l],
              comprobante: doc,
              exportacion: op.exportacion,
            );
          }
        }
        final lineas = await repo.leerLineasAlmacen();
        expect(lineas, hasLength(16));
        expect(StockAlmacen.saldo(lineas, ponchos.id), Cantidad.de(900));
        final entradas = lineas.where((l) => l.entrada);
        final salidas = lineas.where((l) => !l.entrada);
        expect(
          entradas.fold(0, (t, l) => t + l.cantidad),
          Cantidad.de(1200 + 7350),
        );
        expect(
          entradas.fold(0, (t, l) => t + l.costoTotal!),
          6000000 + 37621000,
        );
        expect(salidas.fold(0, (t, l) => t + l.cantidad), Cantidad.de(7650));
        expect(
          salidas
              .where((l) => l.cuentaCosto == '69111')
              .map((l) => l.docNumero),
          ['113', '116'],
        );
        expect(
          salidas
              .where((l) => l.docTipo == '03')
              .map((l) => l.comprobante!.texto),
          ['BE01-15', 'BE01-16'],
        );
        final tarapoto = (await repo.listar()).firstWhere(
          (m) => m.docNumero == '535',
        );
        expect(tarapoto.sinIgv, isTrue);
        expect(tarapoto.centavos, 8840000);

        // Con el motor de P1, lo guardado da el resultado del plan.
        final kardex = Kardex.de(lineas);
        expect(kardex.saldo(ponchos.id).cantidad, Cantidad.de(900));
        expect(kardex.saldo(ponchos.id).costo, 4423455);
        expect(
          kardex.costoDeVentas(Periodo.mes, referencia: DateTime(2026, 10, 31)),
          {'69111': 8851800, '69121': 30345745},
        );
      });

      test('unidad de compra y descuento: 10 cajas entran como 120 '
          'unidades', () async {
        for (final intento in [
          () => repo.guardarProducto(nombre: 'Gaseosa', unidadCompra: '12'),
          () => repo.guardarProducto(
            nombre: 'Gaseosa',
            unidadCompra: '07',
            factorCompra: Cantidad.de(12),
          ),
          () => repo.guardarProducto(
            nombre: 'Gaseosa',
            unidadCompra: '12',
            factorCompra: Cantidad.de(12.5),
          ),
          () => repo.guardarProducto(nombre: 'Gaseosa', unidadFactura: 'XYZ'),
        ]) {
          await expectLater(intento(), throwsArgumentError);
        }
        final gaseosa = await repo.guardarProducto(
          nombre: 'Gaseosa',
          unidadCompra: '12',
          factorCompra: Cantidad.de(12),
        );
        expect(gaseosa.unidadFactura, 'NIU');
        expect(gaseosa.abreviaturaUnidadCompra, 'caja');
        expect(
          (await repo.guardarProducto(
            nombre: 'Azúcar',
            unidad: '01',
          )).unidadFactura,
          'KGM',
        );
        expect(
          (await repo.guardarProducto(
            nombre: 'Ladrillos',
            unidad: '13',
            unidadFactura: 'mil',
          )).unidadFactura,
          'MIL',
        );
        final azucar = (await repo.leerMercaderias()).firstWhere(
          (m) => m.nombre == 'Azúcar',
        );

        final c = await compra([
          LineaNueva(
            mercaderiaId: gaseosa.id,
            cantidad: Cantidad.de(10),
            importe: 54000,
            descuento: 6000,
            enUnidadDeCompra: true,
          ),
        ]);
        final l = (await repo.lineasDeMovimiento(c.id)).single;
        expect(l.cantidad, Cantidad.de(120));
        expect(l.costoTotal, 54000);
        expect(l.descuento, 6000);

        for (final intento in [
          // Sin unidad de compra.
          () => compra([
            LineaNueva(
              mercaderiaId: azucar.id,
              cantidad: Cantidad.de(1),
              importe: 100,
              enUnidadDeCompra: true,
            ),
          ]),
          // Media caja no se compra.
          () => compra([
            LineaNueva(
              mercaderiaId: gaseosa.id,
              cantidad: Cantidad.de(1.5),
              importe: 100,
              enUnidadDeCompra: true,
            ),
          ]),
          // Se vende por unidades.
          () => venta([
            LineaNueva(
              mercaderiaId: gaseosa.id,
              cantidad: Cantidad.de(1),
              importe: 100,
              enUnidadDeCompra: true,
            ),
          ]),
          () => compra([
            LineaNueva(
              mercaderiaId: azucar.id,
              cantidad: Cantidad.de(1),
              importe: 100,
              descuento: -1,
            ),
          ]),
        ]) {
          await expectLater(intento(), throwsArgumentError);
        }
        final v = await venta([
          LineaNueva(
            mercaderiaId: gaseosa.id,
            cantidad: Cantidad.de(24),
            importe: 12000,
            descuento: 1000,
          ),
        ]);
        expect((await repo.lineasDeMovimiento(v.id)).single.descuento, 1000);
        expect(
          StockAlmacen.saldo(await repo.leerLineasAlmacen(), gaseosa.id),
          Cantidad.de(96),
        );

        // Un sobrante sin stock ese día necesita su costo; con stock, no.
        Future<LineaAlmacen> sobra(Mercaderia p, {int? costo}) =>
            repo.registrarEnAlmacen(
              operacion: OperacionAlmacen.ajuste,
              mercaderiaId: p.id,
              fecha: dia(6),
              cantidad: Cantidad.de(2),
              entrada: true,
              costoTotal: costo,
              glosa: 'Conteo',
            );
        await expectLater(sobra(azucar), throwsArgumentError);
        expect((await sobra(azucar, costo: 800)).costoTotal, 800);
        await expectLater(sobra(gaseosa, costo: 800), throwsArgumentError);
      });

      test(
        'cada venta lleva su factura o boleta electrónica, en orden',
        () async {
          final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
          await inicial(ponchos, 100, 500000);
          Future<Movimiento> aDni({
            String? documento = '45678912',
            String categoria = 'ventas',
            List<LineaNueva>? lineas,
            Comprobante? comprobante,
          }) => repo.registrar(
            tipo: Tipo.entro,
            centavos: 8260,
            categoriaId: categoria,
            concepto: '',
            medio: MedioPago.yape,
            fecha: dia(5),
            contraparte: documento == null ? null : 'Ana',
            documentoContraparte: documento,
            lineas: lineas ?? [linea(ponchos, 1, 7000)],
            comprobante: comprobante,
          );

          final f1 = await venta([linea(ponchos, 1, 7000)]);
          expect(
            f1.comprobante,
            const Comprobante(tipo: '01', serie: 'F001', numero: '1'),
          );
          expect(
            (await repo.lineasDeMovimiento(f1.id)).single.comprobante?.texto,
            'F001-1',
          );
          final b1 = await aDni();
          expect(b1.docTipo, TablasSunat.boleta);
          expect(b1.comprobante?.texto, 'B001-1');
          expect((await aDni(documento: null)).comprobante?.texto, 'B001-2');
          expect(
            (await venta([
              linea(ponchos, 1, 7000),
            ], exportacion: true)).comprobante?.texto,
            'F001-2',
          );
          // Un adelanto de cliente también lleva la suya.
          expect(
            (await aDni(
              categoria: 'anticipos',
              lineas: const [],
            )).comprobante?.texto,
            'B001-3',
          );
          // La F001 de un proveedor es otra serie: no corre la numeración.
          await compra(
            [linea(ponchos, 1, 5000)],
            comprobante: const Comprobante(
              tipo: '01',
              serie: 'F001',
              numero: '900',
            ),
          );
          expect(
            (await venta([linea(ponchos, 1, 7000)])).comprobante?.texto,
            'F001-3',
          );

          // Escrito a mano: no se repite, va con F o con B, y la factura va a
          // un cliente con RUC.
          for (final intento in [
            () => venta(
              [linea(ponchos, 1, 7000)],
              comprobante: const Comprobante(
                tipo: '01',
                serie: 'F001',
                numero: '1',
              ),
            ),
            () => venta(
              [linea(ponchos, 1, 7000)],
              comprobante: const Comprobante(
                tipo: '01',
                serie: 'B001',
                numero: '50',
              ),
            ),
            () => venta(
              [linea(ponchos, 1, 7000)],
              comprobante: const Comprobante(
                tipo: '09',
                serie: 'T001',
                numero: '1',
              ),
            ),
            () => aDni(
              comprobante: const Comprobante(
                tipo: '01',
                serie: 'F001',
                numero: '77',
              ),
            ),
          ]) {
            await expectLater(intento(), throwsArgumentError);
          }
          await venta(
            [linea(ponchos, 1, 7000)],
            comprobante: const Comprobante(
              tipo: '01',
              serie: 'F001',
              numero: '40',
            ),
          );
          expect(
            (await venta([linea(ponchos, 1, 7000)])).comprobante?.texto,
            'F001-41',
          );
        },
      );

      test(
        'cerrar el mes: nada se registra ni se cambia con su fecha',
        () async {
          final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
          await inicial(ponchos, 100, 500000);
          final c = await compra([linea(ponchos, 10, 50000)]);
          final luz = await repo.registrar(
            tipo: Tipo.salio,
            centavos: 17700,
            categoriaId: 'luz',
            concepto: '',
            medio: MedioPago.transferencia,
            fecha: dia(3),
          );
          final hoy = DateTime.now();
          await expectLater(
            repo.cerrarMes(hoy.year, hoy.month),
            throwsArgumentError,
          );
          await expectLater(repo.cerrarMes(2026, 13), throwsArgumentError);

          final cierre = await repo.cerrarMes(2026, 10, cerradoPor: ' Wilmer ');
          expect(cierre.cerradoPor, 'Wilmer');
          expect(cierre.nombre, 'octubre de 2026');
          expect((await repo.leerCierres()).single.clave, cierre.clave);
          // No se cierra dos veces, ni uno de antes: ya quedó cerrado.
          await expectLater(repo.cerrarMes(2026, 10), throwsArgumentError);
          await expectLater(repo.cerrarMes(2026, 9), throwsArgumentError);

          for (final intento in [
            () => compra([linea(ponchos, 1, 5000)], fecha: 20),
            () => venta([linea(ponchos, 1, 7000)], fecha: 31),
            () => repo.registrar(
              tipo: Tipo.salio,
              centavos: 17700,
              categoriaId: 'luz',
              concepto: '',
              medio: MedioPago.transferencia,
              fecha: DateTime(2026, 9, 30),
            ),
            () => repo.registrarEnAlmacen(
              operacion: OperacionAlmacen.merma,
              mercaderiaId: ponchos.id,
              fecha: dia(15),
              cantidad: Cantidad.de(1),
              glosa: 'Rotos',
            ),
            () => repo.editar(luz.copiarCon(centavos: 100)),
            () => repo.editar(luz.copiarCon(fecha: DateTime(2026, 11, 2))),
            () => repo.eliminar(luz),
            () => repo.corregir(
              c,
              tipo: Tipo.salio,
              centavos: 5900,
              categoriaId: 'luz',
              concepto: '',
              medio: MedioPago.transferencia,
              fecha: DateTime(2026, 11, 2),
            ),
          ]) {
            await expectLater(
              intento(),
              throwsA(
                isA<ArgumentError>().having(
                  (e) => e.message,
                  'mensaje',
                  contains('está cerrado'),
                ),
              ),
            );
          }
          // El voucher sí se completa.
          final conVoucher = await repo.editar(
            luz.copiarCon(rutaFoto: 'v.png'),
          );
          expect(conVoucher.rutaFoto, 'v.png');
          // El mes siguiente sigue abierto.
          await repo.registrar(
            tipo: Tipo.salio,
            centavos: 5900,
            categoriaId: 'mercaderia',
            concepto: '',
            medio: MedioPago.transferencia,
            fecha: DateTime(2026, 11, 2),
            lineas: [linea(ponchos, 1, 5000)],
          );
          expect(await repo.listar(), hasLength(3));
        },
      );

      test('anular y volver a registrar: el original queda a la vista y no '
          'cuenta', () async {
        final ponchos = await repo.guardarProducto(nombre: 'Ponchos');
        await inicial(ponchos, 100, 500000);
        final v = await venta([linea(ponchos, 80, 560000)]);

        Future<Movimiento> corregirVenta(Movimiento original, num cantidad) =>
            repo.corregir(
              original,
              tipo: Tipo.entro,
              centavos: ReglasMercaderia.montoParaLineas(
                (cantidad * 7000).round(),
                conIgv: true,
              ),
              categoriaId: 'ventas',
              concepto: '',
              medio: MedioPago.transferencia,
              fecha: dia(5),
              contraparte: 'Cliente',
              documentoContraparte: '20304050811',
              lineas: [linea(ponchos, cantidad, (cantidad * 7000).round())],
              registradoPor: 'Ana',
            );

        final nuevo = await corregirVenta(v, 50);
        expect(nuevo.numero, v.numero + 1);
        expect(nuevo.comprobante?.texto, 'F001-2');
        expect(nuevo.registradoPor, 'Ana');
        expect(
          (await repo.lineasDeMovimiento(nuevo.id)).single.registradoPor,
          'Ana',
        );
        expect((await repo.listar()).map((m) => m.id), [nuevo.id]);
        final anulado = (await repo.listarAnulados()).single;
        expect(anulado.id, v.id);
        expect(anulado.anulado, isTrue);
        expect(anulado.reemplazadoPor, nuevo.id);
        expect((await repo.lineasDeMovimiento(v.id)).single.anulada, isTrue);
        final lineas = await repo.leerLineasAlmacen();
        expect(StockAlmacen.saldo(lineas, ponchos.id), Cantidad.de(50));
        expect(
          Kardex.de(lineas).saldo(ponchos.id),
          isA<SaldoAlmacen>()
              .having((s) => s.cantidad, 'cantidad', Cantidad.de(50))
              .having((s) => s.costo, 'costo', 250000),
        );

        // Lo anulado no se vuelve a anular, ni se edita, ni se borra.
        await expectLater(corregirVenta(v, 40), throwsArgumentError);
        await expectLater(
          repo.editar(anulado.copiarCon(rutaFoto: 'x.png')),
          throwsArgumentError,
        );
        await expectLater(repo.eliminar(anulado), throwsArgumentError);

        // Sin esta compra, la venta del 7 se queda sin stock: no se anula.
        final c = await compra([linea(ponchos, 100, 500000)], fecha: 6);
        await venta([linea(ponchos, 120, 840000)], fecha: 7);
        await expectLater(
          repo.corregir(
            c,
            tipo: Tipo.salio,
            centavos: 5900,
            categoriaId: 'luz',
            concepto: '',
            medio: MedioPago.transferencia,
            fecha: dia(6),
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'mensaje',
              contains('sin stock el 07/10/2026'),
            ),
          ),
        );

        // Con una devolución encima, tampoco.
        await repo.registrarEnAlmacen(
          operacion: OperacionAlmacen.devolucionRecibida,
          mercaderiaId: ponchos.id,
          fecha: dia(8),
          cantidad: Cantidad.de(1),
          origenId: (await repo.lineasDeMovimiento(nuevo.id)).single.id,
        );
        await expectLater(corregirVenta(nuevo, 40), throwsArgumentError);
        expect(await repo.listarAnulados(), hasLength(1));
        expect(await repo.listar(), hasLength(3));
      });
    });
  }

  test('EstadoCaja: productos, líneas y stock a la vista', () async {
    final estado = EstadoCaja(RepositorioDemo());
    await estado.cargar();
    estado.usuario = 'Wilmer';
    expect(estado.productos, isEmpty);
    expect(estado.lineasAlmacen, isEmpty);

    final mantas = await estado.guardarProducto(nombre: 'Mantas');
    final ponchos = await estado.agregarMercaderia('Ponchos');
    expect(estado.productos.map((m) => m.codigo), ['P001', 'P002']);
    expect(estado.mercaderias.map((m) => m.nombre), ['Mantas', 'Ponchos']);
    expect(estado.producto(ponchos.id)?.codigo, 'P002');

    await estado.registrarEnAlmacen(
      operacion: OperacionAlmacen.saldoInicial,
      mercaderiaId: ponchos.id,
      fecha: DateTime(2026, 10, 1),
      cantidad: Cantidad.de(100),
      costoTotal: 500000,
    );
    expect(estado.negocio.kardexDesde, DateTime(2026, 10, 1));

    final v = await estado.registrar(
      tipo: Tipo.entro,
      centavos: ReglasMercaderia.montoParaLineas(56000, conIgv: true),
      categoriaId: 'ventas',
      concepto: '',
      medio: MedioPago.yape,
      fecha: DateTime(2026, 10, 5),
      contraparte: 'Cliente',
      documentoContraparte: '20304050811',
      lineas: [
        LineaNueva(
          mercaderiaId: ponchos.id,
          cantidad: Cantidad.de(8),
          importe: 56000,
        ),
      ],
    );
    expect(estado.lineasAlmacen, hasLength(2));
    expect(estado.lineasDe(v.id).single.cantidad, Cantidad.de(8));
    expect(v.registradoPor, 'Wilmer');
    expect(estado.lineasDe(v.id).single.registradoPor, 'Wilmer');
    expect(estado.lineasAlmacen.first.registradoPor, 'Wilmer');
    // El kardex de P1 sale de lo que guarda P2.
    expect(estado.kardex.saldo(ponchos.id).costo, 460000);
    expect(estado.stockDe(ponchos.id), Cantidad.de(92));
    expect(
      estado.stockDe(ponchos.id, al: DateTime(2026, 10, 2)),
      Cantidad.de(100),
    );
    expect(
      estado.stockDisponible(ponchos.id, fecha: DateTime(2026, 10, 2)),
      Cantidad.de(92),
    );
    expect(estado.stockDe(mantas.id), 0);

    final nuevo = await estado.corregir(
      v,
      tipo: Tipo.entro,
      centavos: ReglasMercaderia.montoParaLineas(70000, conIgv: true),
      categoriaId: 'ventas',
      concepto: '',
      medio: MedioPago.yape,
      fecha: DateTime(2026, 10, 5),
      contraparte: 'Cliente',
      documentoContraparte: '20304050811',
      lineas: [
        LineaNueva(
          mercaderiaId: ponchos.id,
          cantidad: Cantidad.de(10),
          importe: 70000,
        ),
      ],
    );
    expect(estado.movimientos.map((m) => m.id), [nuevo.id]);
    expect(estado.anulados.single.reemplazadoPor, nuevo.id);
    expect(nuevo.registradoPor, 'Wilmer');
    expect(estado.stockDe(ponchos.id), Cantidad.de(90));
    expect(estado.ultimaFechaDe(ponchos.id), DateTime(2026, 10, 5));
    expect(estado.recienRegistrado, nuevo.id);

    expect(estado.mesCerrado(DateTime(2026, 10, 9)), isFalse);
    await estado.cerrarMes(2026, 10);
    expect(estado.mesCerrado(DateTime(2026, 10, 9)), isTrue);
    expect(estado.mesCerrado(DateTime(2026, 9, 9)), isTrue);
    expect(estado.cierres.single.cerradoPor, 'Wilmer');

    await estado.guardarProducto(
      id: mantas.id,
      nombre: 'Mantas',
      activo: false,
    );
    expect(estado.productosActivos.map((m) => m.id), [ponchos.id]);
  });
}

/// Las 15 operaciones del Excel del kardex (hojas 1 a 15), de octubre de
/// 2026: 5 compras y 10 ventas de ponchos. Son el caso de prueba del
/// inventario; P1 calcula con ellas el costo promedio.
const ejercicioDelExcel = <_Op>[
  _Op(1, 'FE01', '112', 800, 70, quien: 'FERNANDEZ E.I.R.L.'),
  _Op(2, 'FE01', '234', 1600, 52, compra: true, quien: 'GUADALUPE S.A.C.'),
  _Op(4, 'FE01', '113', 550, 80, exportacion: true, quien: 'MUJICA CIA.'),
  _Op(7, 'FE01', '114', 450, 70, quien: 'SABORES CHEPÉN E.I.R.L.'),
  _Op(8, 'FE01', '346', 1000, 54, compra: true, quien: 'CHICLAYO S.A.'),
  _Op(10, 'BE01', '15', 20, 75, quien: 'VALERA MALCA, DIANA'),
  _Op(13, 'FE01', '115', 880, 70, quien: 'PERCAL E.I.R.L.'),
  _Op(15, 'FE01', '453', 1400, 50.3, compra: true, quien: 'PACASMAYO S.A.'),
  _Op(16, 'BE01', '16', 30, 75, quien: 'ORTIZ GARCÍA, CARMEN'),
  _Op(17, 'FE01', '116', 1170, 80, exportacion: true, quien: 'CORREA CIA.'),
  _Op(
    18,
    'FE01',
    '535',
    1700,
    52,
    compra: true,
    sinIgv: true,
    quien: 'TARAPOTO S.A.',
  ),
  _Op(20, 'FE01', '117', 1250, 70, quien: 'YOLEIT S.R.L.'),
  _Op(21, 'FE01', '118', 1400, 70, quien: 'PRIMAVERA S.A.'),
  _Op(24, 'FE01', '692', 1650, 48.6, compra: true, quien: 'CHEPÉN S.A.A.'),
  _Op(28, 'FE01', '119', 1100, 70, quien: 'CHIMÚ S.A.'),
];

class _Op {
  const _Op(
    this.dia,
    this.serie,
    this.numero,
    this.cantidad,
    this.unitario, {
    required this.quien,
    this.compra = false,
    this.sinIgv = false,
    this.exportacion = false,
  });
  final int dia;
  final String serie;
  final String numero;
  final int cantidad;

  /// El valor unitario sin IGV de la factura.
  final num unitario;
  final String quien;
  final bool compra;
  final bool sinIgv;
  final bool exportacion;
}
