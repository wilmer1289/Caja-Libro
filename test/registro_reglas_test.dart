import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/datos/db/base_datos.dart';
import 'package:mi_caja/datos/db/esquema.dart';
import 'package:mi_caja/datos/local/categoria_dao.dart';
import 'package:mi_caja/datos/local/movimiento_dao.dart';
import 'package:mi_caja/datos/local/negocio_dao.dart';
import 'package:mi_caja/datos/repositorio/repositorio_movimientos.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Las reglas nuevas del formulario: el tope de efectivo, las categorías que
/// agrega el usuario, la búsqueda en el plan contable y la migración de la
/// base que las guarda.
void main() {
  late Database db;
  late RepositorioMovimientos repo;

  setUpAll(() {
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
    );
    Categoria.registrarPropias(const []);
  });

  tearDown(() => db.close());

  // Un cobro de fiado y no una venta: acá se prueba el tope del efectivo,
  // no la boleta (que desde S/ 700 pide el nombre del cliente).
  Future<void> registrar(int centavos, MedioPago medio) => repo.registrar(
    tipo: Tipo.entro,
    centavos: centavos,
    categoriaId: 'cobros_fiado',
    concepto: '',
    medio: medio,
    fecha: DateTime.now(),
  );

  group('Ley de Bancarización', () {
    test('desde S/ 2,000 en efectivo no se guarda', () async {
      await expectLater(
        registrar(200000, MedioPago.efectivo),
        throwsA(isA<ArgumentError>()),
      );
      expect(await repo.listar(), isEmpty);
    });

    test('el mismo monto por Yape o transferencia sí', () async {
      await registrar(200000, MedioPago.yape);
      await registrar(500000, MedioPago.transferencia);
      expect((await repo.listar()).length, 2);
    });

    test('un sol menos del tope en efectivo se guarda', () async {
      await registrar(199999, MedioPago.efectivo);
      expect((await repo.listar()).single.centavos, 199999);
    });
  });

  group('Categorías propias', () {
    test('se guardan con su cuenta y la app las encuentra', () async {
      final nueva = await repo.agregarCategoria(
        etiqueta: 'Movilidad',
        tipo: Tipo.salio,
        cuenta: '6311',
      );
      Categoria.registrarPropias(await repo.leerCategoriasPropias());

      expect(nueva.propia, isTrue);
      expect(Categoria.porId(nueva.id).etiqueta, 'Movilidad');
      expect(Categoria.porId(nueva.id).cuentaAsociada, '6311');
      expect(Categoria.propiasDe(Tipo.salio).single.id, nueva.id);
      expect(Categoria.propiasDe(Tipo.entro), isEmpty);
    });

    test('un movimiento con categoría propia lleva su cuenta', () async {
      final nueva = await repo.agregarCategoria(
        etiqueta: 'Publicidad',
        tipo: Tipo.salio,
        cuenta: '6371',
      );
      Categoria.registrarPropias(await repo.leerCategoriasPropias());
      final m = await repo.registrar(
        tipo: Tipo.salio,
        centavos: 5000,
        categoriaId: nueva.id,
        concepto: '',
        medio: MedioPago.efectivo,
        fecha: DateTime.now(),
      );
      expect(m.cuentaDelFormato, '6371');
    });

    test('no se repite un nombre ni se crea sin cuenta', () async {
      await expectLater(
        repo.agregarCategoria(
          etiqueta: 'luz',
          tipo: Tipo.salio,
          cuenta: '6361',
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repo.agregarCategoria(etiqueta: 'Gas', tipo: Tipo.salio, cuenta: ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  test('"Otros" guarda la cuenta que eligió el usuario', () async {
    final m = await repo.registrar(
      tipo: Tipo.entro,
      centavos: 30000,
      categoriaId: Categoria.otrosIngresos.id,
      concepto: 'Alquileres',
      medio: MedioPago.transferencia,
      fecha: DateTime.now(),
      cuentaAsociada: '754',
    );
    expect(m.cuentaDelFormato, '754');
    expect(Categoria.otrosIngresos.pideCuenta, isTrue);
    expect(Categoria.ventas.pideCuenta, isFalse);
  });

  group('Búsqueda en el plan contable', () {
    List<String> buscar(String texto, Tipo tipo) =>
        Pcge.instancia.buscarContrapartida(
          texto,
          primero: tipo == Tipo.entro
              ? const ['7', '4', '5', '1']
              : const ['6', '4', '3', '2', '1'],
        );

    test('sin tildes y con la cuenta general primero', () {
      expect(buscar('regalias', Tipo.entro).first, '753');
      expect(buscar('alquiler', Tipo.entro).first, '754');
    });

    test('en una salida van primero los gastos', () {
      final alquiler = buscar('alquiler', Tipo.salio);
      expect(alquiler.first.startsWith('6'), isTrue);
    });

    test('nunca ofrece la caja, cuentas de orden ni títulos', () {
      for (final texto in ['caja', 'efectivo', 'bienes', 'ventas']) {
        for (final codigo in buscar(texto, Tipo.entro)) {
          expect(codigo.startsWith('10'), isFalse, reason: codigo);
          expect(codigo.startsWith('0'), isFalse, reason: codigo);
          expect(codigo.length, greaterThanOrEqualTo(3), reason: codigo);
        }
      }
    });

    test('por código también encuentra', () {
      expect(buscar('7541', Tipo.entro), contains('7541'));
    });
  });

  test('la base v2 migra a la última versión sin perder movimientos', () async {
    final carpeta = await Directory.systemTemp.createTemp('mi_caja_v2');
    final ruta = '${carpeta.path}/mi_caja.db';
    try {
      // Una base como la del usuario: versión 2, con un movimiento.
      final vieja = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (d, _) async {
            await d.execute(Esquema.crearMovimientosV2);
            await d.execute(Esquema.crearNegocioV2);
          },
        ),
      );
      await vieja.insert(Esquema.tablaMovimientos, {
        'id': 'viejo',
        'numero': 1,
        'tipo': 'entro',
        'centavos': 9000,
        'categoria_id': 'ventas',
        'concepto': 'sapatos',
        'medio': 'yape',
        'cuenta': 'banco',
        'fecha': DateTime(2026, 9, 16).millisecondsSinceEpoch,
        'creado_en': DateTime(2026, 9, 16).millisecondsSinceEpoch,
        'actualizado_en': DateTime(2026, 9, 16).millisecondsSinceEpoch,
        'sync': 'local',
      });
      await vieja.close();

      final nueva = await databaseFactoryFfi.openDatabase(
        ruta,
        options: BaseDatos.opciones,
      );
      expect(await nueva.getVersion(), Esquema.version);
      final movimientos = await MovimientoDao(database: nueva).listar();
      expect(movimientos.single.concepto, 'sapatos');
      await CategoriaDao(database: nueva).guardar(
        const Categoria(
          id: 'propia_x',
          etiqueta: 'Gas',
          tipo: Tipo.salio,
          grupo: GrupoCategoria.propias,
          cuentaAsociada: '6369',
        ),
      );
      expect(
        (await CategoriaDao(database: nueva).listar()).single.etiqueta,
        'Gas',
      );
      await nueva.close();
    } finally {
      await carpeta.delete(recursive: true);
    }
  });
}
