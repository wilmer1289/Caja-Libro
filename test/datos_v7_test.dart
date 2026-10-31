import 'dart:convert';
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
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/efectivo.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/estado/estado_caja.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

RepositorioMovimientos repositorio(Database db) => RepositorioMovimientos(
  dao: MovimientoDao(database: db),
  negocioDao: NegocioDao(database: db),
  categoriaDao: CategoriaDao(database: db),
  jornadaDao: JornadaDao(database: db),
  fondoDao: FondoDao(database: db),
);

Movimiento antiguo({String id = 'viejo', String categoria = 'ventas'}) {
  final fecha = DateTime(2026, 10, 1);
  return Movimiento(
    id: id,
    numero: 1,
    tipo: categoria == 'ventas' ? Tipo.entro : Tipo.salio,
    centavos: 11800,
    categoriaId: categoria,
    concepto: 'Original',
    medio: MedioPago.yape,
    fecha: fecha,
    creadoEn: fecha,
    actualizadoEn: fecha,
    numeroBoleta: 7,
    numeroRecibo: 3,
    tesorero: 'Ana',
    detalleEfectivo: const DetalleEfectivo(
      entregado: Conteo({1000: 1}),
      vuelto: Conteo.vacio,
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    Pcge.cargarDeTexto(File('assets/pcge.json').readAsStringSync());
  });
  setUp(() => Categoria.registrarPropias(const []));

  test('PCGE 2026: registros completos y las 30 cuentas de las categorías', () {
    final datos =
        jsonDecode(File('assets/pcge.json').readAsStringSync()) as List;
    expect(datos.length, 1615);
    expect(datos.map((c) => c['codigo']).toSet().length, datos.length);
    final cuentas = <String>{
      for (final c in Categoria.base) c.cuentaAsociada,
      for (final c in Categoria.base)
        if (c.cuentaResultado != null) c.cuentaResultado!,
    };
    expect(cuentas.length, 30);
    // Las variantes por vínculo también tienen que existir en el catálogo.
    final variantes = <String>{
      for (final c in Categoria.base) ?c.cuentaRelacionada,
      for (final c in Categoria.base) ?c.cuentaPersonal,
    };
    for (final codigo in {...cuentas, ...variantes}) {
      expect(Pcge.instancia.existe(codigo), isTrue, reason: codigo);
    }
    expect(Pcge.instancia.denominacion('1212'), 'En cartera');
    expect(Pcge.instancia.denominacion('122'), 'Anticipos recibidos');
    expect(Pcge.instancia.cadena('6011').map((c) => c.codigo), [
      '60',
      '601',
      '6011',
    ]);
    expect(Pcge.instancia.cadena('6011').map((c) => c.nivel), [2, 3, 4]);
  });

  test('v6 abre en v7 sin alterar registros ni inventar costos', () async {
    final dir = await Directory.systemTemp.createTemp('mi_caja_v7_');
    final ruta = '${dir.path}/prueba.db';
    Database? db;
    try {
      db = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (db, _) async {
            for (final sql in [
              Esquema.crearMovimientosV6,
              Esquema.crearNegocio,
              Esquema.crearCategorias,
              Esquema.crearJornadas,
              Esquema.crearFondo,
              Esquema.crearArqueos,
            ]) {
              await db.execute(sql);
            }
            for (final indice in Esquema.indices.where(
              (s) => !s.contains('idx_mov_mercaderia'),
            )) {
              await db.execute(indice);
            }
          },
        ),
      );
      final viejo = antiguo().aMapa()
        ..remove('mercaderia_id')
        ..remove('mercaderia_nombre')
        ..remove('costo_centavos')
        ..remove('banco_tercero')
        ..remove('vinculo')
        ..remove('documento_pago')
        ..remove('situacion');
      await db.insert('movimientos', viejo);
      await db.insert('movimientos', {
        ...viejo,
        'id': 'borrado',
        'numero': 2,
        'eliminado_en': 42,
      });
      await db.insert('negocio', {
        'id': 1,
        'razon_social': 'Negocio',
        'saldo_inicial_caja': 12345,
      });
      await db.insert('categorias_propias', {
        'id': 'propia',
        'etiqueta': 'Fletes',
        'tipo': 'salio',
        'cuenta_asociada': '6311',
        'creado_en': 12,
      });
      await db.insert('fondo', {'id': 1, 'conteo': '{}', 'contado_en': 13});
      await db.insert('jornadas', {
        'id': 'caja',
        'numero': 1,
        'abierta_en': 1,
        'apertura': 2000,
        'inicio': 'libro',
        'responsable': 'Ana',
        'usuario': 'usuario',
        'ajuste_id': 'ajuste',
      });
      final tablas = [
        'negocio',
        'categorias_propias',
        'fondo',
        'jornadas',
        'arqueos',
      ];
      final antes = {for (final t in tablas) t: await db.query(t)};
      await db.close();
      db = await databaseFactoryFfi.openDatabase(
        ruta,
        options: BaseDatos.opciones,
      );
      // Pasa por la v7 y sigue hasta la versión actual.
      expect(await db.getVersion(), Esquema.version);
      final filas = await db.query('movimientos', orderBy: 'numero');
      expect(filas.length, 2);
      for (var i = 0; i < filas.length; i++) {
        final fila = Map<String, Object?>.from(filas[i]);
        for (final campo in [
          'mercaderia_id',
          'mercaderia_nombre',
          'costo_centavos',
          'banco_tercero',
          'vinculo',
          'documento_pago',
          'situacion',
        ]) {
          expect(fila.remove(campo), isNull);
        }
        expect(
          fila,
          i == 0
              ? viejo
              : {...viejo, 'id': 'borrado', 'numero': 2, 'eliminado_en': 42},
        );
      }
      for (final t in tablas) {
        expect(await db.query(t), antes[t], reason: t);
      }
      expect(await db.query('mercaderias'), isEmpty);
      final repo = repositorio(db);
      await repo.editar(
        Movimiento.desdeMapa(filas.first).copiarCon(concepto: 'Corregido'),
      );
      expect((await repo.listar()).single.costoCentavos, isNull);
    } finally {
      await db?.close();
      await dir.delete(recursive: true);
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

      Future<Movimiento> registrar({
        String categoria = 'ventas',
        String? mercaderia,
        int? costo,
        int total = 11800,
        bool? conIgv,
      }) => repo.registrar(
        tipo: categoria == 'ventas' ? Tipo.entro : Tipo.salio,
        centavos: total,
        categoriaId: categoria,
        concepto: '',
        medio: MedioPago.yape,
        fecha: DateTime.now(),
        mercaderiaId: mercaderia,
        costoCentavos: costo,
        conIgv: conIgv,
        conRecibo: true,
        tesorero: 'Ana',
      );

      test('catálogo vacío y nombres normalizados, sin duplicados', () async {
        expect(await repo.leerMercaderias(), isEmpty);
        final tela = await repo.agregarMercaderia('  Tela   azul  ');
        expect(tela.nombre, 'Tela azul');
        await expectLater(
          repo.agregarMercaderia('tela azul'),
          throwsArgumentError,
        );
        await expectLater(repo.agregarMercaderia('   '), throwsArgumentError);
        expect((await repo.leerMercaderias()).single.id, tela.id);
        expect(Categoria.base.length, 28);
      });

      test('repositorio rechaza compras sin tipo y costos inválidos', () async {
        final tela = await repo.agregarMercaderia('Tela');
        await expectLater(
          registrar(categoria: 'mercaderia'),
          throwsArgumentError,
        );
        await expectLater(
          registrar(categoria: 'mercaderia', mercaderia: 'inexistente'),
          throwsArgumentError,
        );
        for (final costo in [null, 0, -1, 100000000000]) {
          await expectLater(
            registrar(mercaderia: tela.id, costo: costo),
            throwsArgumentError,
          );
        }
        await expectLater(registrar(costo: 100), throwsArgumentError);
        await expectLater(
          registrar(categoria: 'luz', mercaderia: tela.id),
          throwsArgumentError,
        );
        expect(await repo.listar(), isEmpty);
      });

      test(
        'datos y comprobantes sobreviven edición, borrado y deshacer',
        () async {
          final tela = await repo.agregarMercaderia('Tela');
          final venta = await registrar(mercaderia: tela.id, costo: 5000);
          expect(venta.descripcionFormato, 'Venta de Tela');
          final editado = await repo.editar(
            venta.copiarCon(concepto: 'Venta especial'),
          );
          final borrado = await repo.eliminar(editado);
          expect(await repo.listar(), isEmpty);
          final restaurado = await repo.restaurar(borrado);
          final mapa = (await repo.listar()).single.aMapa();
          expect(restaurado.eliminado, isFalse);
          expect(mapa['mercaderia_id'], tela.id);
          expect(mapa['mercaderia_nombre'], 'Tela');
          expect(mapa['costo_centavos'], 5000);
          expect(mapa['numero_boleta'], venta.numeroBoleta);
          expect(mapa['numero_recibo'], venta.numeroRecibo);
          expect(mapa['tesorero'], 'Ana');
          await expectLater(
            repo.editar(restaurado.copiarCon(costoCentavos: 0)),
            throwsArgumentError,
          );
        },
      );

      test(
        'P1 recibe datos: compra sin IGV y costo vendido separado de caja',
        () async {
          final tela = await repo.agregarMercaderia('Tela');
          final pintura = await repo.agregarMercaderia('Pintura');
          final compra = await registrar(
            categoria: 'mercaderia',
            mercaderia: tela.id,
          );
          await registrar(
            categoria: 'mercaderia',
            mercaderia: pintura.id,
            conIgv: false,
            total: 5000,
          );
          final venta = await registrar(
            mercaderia: tela.id,
            costo: 4000,
            total: 5900,
          );
          final servicio = await registrar(costo: 0, total: 2360);
          final antiguo = await registrar(total: 1180);
          final estado = EstadoCaja(repo);
          await estado.cargar();
          expect(estado.error, isNull);
          expect(compra.descripcionFormato, 'Compra de Tela');
          expect(compra.baseCentavos, 10000);
          expect(estado.inventario.comprado(tela.id), 10000);
          expect(estado.saldoDeMercaderia(tela.id), 6000);
          expect(estado.saldoDeMercaderia(pintura.id), 5000);
          expect(estado.advertenciaDeCosto(tela.id, 6000), isNull);
          expect(estado.advertenciaDeCosto(tela.id, 6001), isNotNull);
          expect(estado.resumen.saldoBanco, -11800 - 5000 + 5900 + 2360 + 1180);
          final libro = estado.libroDiario(
            desde: DateTime.now(),
            hasta: DateTime.now(),
          );
          expect(libro.cuadra, isTrue);
          expect(
            libro.asientos
                .singleWhere((a) => a.origen.id == venta.id)
                .etapas
                .length,
            3,
          );
          expect(
            libro.asientos
                .singleWhere((a) => a.origen.id == servicio.id)
                .faltaCosto,
            isFalse,
          );
          expect(
            libro.asientos
                .singleWhere((a) => a.origen.id == antiguo.id)
                .faltaCosto,
            isTrue,
          );
          final borrar = await repo.eliminar(compra);
          await estado.cargar();
          expect(estado.saldoDeMercaderia(tela.id), -4000);
          await repo.restaurar(borrar);
          await estado.cargar();
          expect(estado.saldoDeMercaderia(tela.id), 6000);
          estado.dispose();
        },
      );
    });
  }

  test('inventario respeta fecha, apertura y exclusión al editar', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: BaseDatos.opciones,
    );
    try {
      final repo = repositorio(db);
      final tela = await repo.agregarMercaderia('Tela');
      await repo.guardarNegocio(Negocio(inicioPeriodo: DateTime(2026, 10, 2)));
      final base = antiguo(categoria: 'mercaderia')
          .copiarCon(mercaderiaId: tela.id, mercaderiaNombre: tela.nombre);
      for (final par in [
        ('anterior', DateTime(2026, 10, 1)),
        ('actual', DateTime(2026, 10, 3)),
        ('futuro', DateTime.now().add(const Duration(days: 1))),
      ]) {
        await db.insert('movimientos', {
          ...base.aMapa(),
          'id': par.$1,
          'fecha': par.$2.millisecondsSinceEpoch,
        });
      }
      final venta = antiguo(id: 'venta').copiarCon(
        fecha: DateTime(2026, 10, 4),
        mercaderiaId: tela.id,
        mercaderiaNombre: tela.nombre,
        costoCentavos: 5000,
      );
      await db.insert('movimientos', venta.aMapa());
      final estado = EstadoCaja(repo);
      await estado.cargar();
      expect(
        estado.saldoDeMercaderia(tela.id, fecha: DateTime(2026, 10, 3)),
        11800,
      );
      expect(estado.saldoDeMercaderia(tela.id), 6800);
      expect(estado.saldoDeMercaderia(tela.id, excluirId: 'venta'), 11800);
      expect(estado.ajustes, isEmpty);
      expect(() => estado.ajustes.add('otro'), throwsUnsupportedError);
      estado.dispose();
    } finally {
      await db.close();
    }
  });

  test('copiarCon conserva campos y permite quitar datos explícitamente', () {
    final original = antiguo().copiarCon(
      mercaderiaId: 'tela',
      mercaderiaNombre: 'Tela',
      costoCentavos: 5000,
    );
    final vuelta = Movimiento.desdeMapa(original.aMapa());
    expect(
      vuelta.detalleEfectivo!.aTexto(),
      original.detalleEfectivo!.aTexto(),
    );
    expect(vuelta.copiarCon(concepto: 'Otro').mercaderiaId, 'tela');
    final servicio = vuelta.copiarCon(
      mercaderiaId: null,
      mercaderiaNombre: null,
      costoCentavos: 0,
    );
    expect(servicio.mercaderiaId, isNull);
    expect(servicio.costoCentavos, 0);
  });
}
