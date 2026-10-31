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
import 'package:mi_caja/dominio/banco.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/estado/estado_caja.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// La v8: los datos del voucher del Formato 1.2 en la base.
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

  test('v7 abre en v8 sin tocar lo registrado', () async {
    final dir = await Directory.systemTemp.createTemp('mi_caja_v8_');
    final ruta = '${dir.path}/prueba.db';
    Database? db;
    try {
      db = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (db, _) async {
            for (final sql in [
              Esquema.crearMercaderias,
              Esquema.crearMovimientosV7,
              Esquema.crearNegocio,
              Esquema.crearCategorias,
              Esquema.crearJornadas,
              Esquema.crearFondo,
            ]) {
              await db.execute(sql);
            }
          },
        ),
      );
      final fecha = DateTime(2026, 10, 1);
      final viejo =
          Movimiento(
              id: 'viejo',
              numero: 1,
              tipo: Tipo.entro,
              centavos: 250000,
              categoriaId: 'cobros_fiado',
              concepto: '',
              medio: MedioPago.transferencia,
              fecha: fecha,
              creadoEn: fecha,
              actualizadoEn: fecha,
              cuentaAsociada: '1212',
              numeroTransaccion: '0011',
              sync: EstadoSync.local,
            ).aMapa()
            ..remove('banco_tercero')
            ..remove('vinculo')
            ..remove('documento_pago')
            ..remove('situacion');
      await db.insert('movimientos', viejo);
      await db.close();

      db = await databaseFactoryFfi.openDatabase(
        ruta,
        options: BaseDatos.opciones,
      );
      expect(await db.getVersion(), 8);
      final fila = (await db.query('movimientos')).single;
      for (final campo in [
        'banco_tercero',
        'vinculo',
        'documento_pago',
        'situacion',
      ]) {
        expect(fila[campo], isNull, reason: campo);
      }
      // Lo de antes se lee como siempre: un tercero con factura en cartera,
      // en la misma cuenta y sin voucher.
      final m = Movimiento.desdeMapa(fila);
      expect(m.vinculo, Vinculo.tercero);
      expect(m.documentoPago, DocumentoPago.factura);
      expect(m.cuentaDelFormato, '1212');
      expect(m.numeroTransaccion, '0011');
      expect(m.tieneVoucher, isFalse);
      expect(m.exigeVoucher, isTrue);
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

      test('guarda el voucher y arma la cuenta con el vínculo', () async {
        final m = await repo.registrar(
          tipo: Tipo.entro,
          centavos: 4672800,
          categoriaId: 'cobros_fiado',
          concepto: '',
          medio: MedioPago.transferencia,
          fecha: DateTime(2026, 10, 4),
          contraparte: 'Mujica CIA',
          numeroTransaccion: '1122',
          bancoTercero: 'BCP',
          vinculo: Vinculo.sucursal,
          documentoPago: DocumentoPago.letra,
          rutaFoto: 'voucher-1.png',
        );
        final leido = (await repo.listar()).single;
        expect(leido.cuentaDelFormato, '1332');
        expect(leido.descripcionFormato, 'Cobro de fiado, sucursal, letra');
        expect(leido.bancoTercero, 'BCP');
        expect(leido.vinculo, Vinculo.sucursal);
        expect(leido.documentoPago, DocumentoPago.letra);
        expect(leido.rutaFoto, 'voucher-1.png');
        expect(leido.id, m.id);
      });

      test('la cuenta elegida a mano manda sobre la regla', () async {
        final m = await repo.registrar(
          tipo: Tipo.salio,
          centavos: 50000,
          categoriaId: 'otros_egresos',
          concepto: 'Donación',
          cuentaAsociada: '659',
          medio: MedioPago.transferencia,
          fecha: DateTime(2026, 10, 4),
          vinculo: Vinculo.matriz,
        );
        expect(m.cuentaDelFormato, '659');
      });

      test('el voucher se completa después, sin tocar el libro', () async {
        final estado = EstadoCaja(repo);
        await estado.cargar();
        final m = await repo.registrar(
          tipo: Tipo.salio,
          centavos: 120000,
          categoriaId: 'honorarios',
          concepto: '',
          medio: MedioPago.transferencia,
          fecha: DateTime(2026, 10, 21),
        );
        await estado.cargar();
        expect(estado.conNumeroDeOperacion('6677'), isNull);

        final completo = await estado.completarVoucher(
          m,
          rutaFoto: 'voucher-9.jpg',
          numeroTransaccion: ' 6677 ',
          bancoTercero: 'BCP',
          contraparte: 'Puescas Guzmán, Cristhian',
          documentoContraparte: '10456789012',
        );
        expect(completo.numeroTransaccion, '6677');
        expect(completo.tieneVoucher, isTrue);
        expect(completo.centavos, m.centavos);
        expect(completo.cuentaDelFormato, '424');

        final leido = (await repo.listar()).single;
        expect(leido.rutaFoto, 'voucher-9.jpg');
        expect(leido.contraparte, 'Puescas Guzmán, Cristhian');
        expect(estado.conNumeroDeOperacion('6677')?.id, m.id);
        // El mismo movimiento no se avisa a sí mismo.
        expect(estado.conNumeroDeOperacion('6677', salvoId: m.id), isNull);

        // El filtro "Sin voucher" ya no lo muestra; "Con voucher", sí.
        estado.aplicarFiltro(voucher: false);
        expect(estado.historial, isEmpty);
        estado.aplicarFiltro(voucher: true);
        expect(estado.historial.single.id, m.id);
        // Y se encuentra por su N° de operación.
        estado.limpiarFiltros();
        estado.aplicarFiltro(texto: '6677');
        expect(estado.historial.single.id, m.id);
        estado.dispose();
      });
    });
  }
}
