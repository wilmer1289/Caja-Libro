import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/datos/db/esquema.dart';
import 'package:mi_caja/datos/local/movimiento_dao.dart';
import 'package:mi_caja/datos/local/negocio_dao.dart';
import 'package:mi_caja/datos/export/exportador.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/importe.dart';
import 'package:mi_caja/dominio/libro_oficial.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/dominio/resumen.dart';
import 'package:mi_caja/dominio/series.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Movimiento movimiento(
  String id,
  DateTime fecha, {
  int numero = 1,
  int? recibo,
  String concepto = '',
  int centavos = 1000,
}) => Movimiento(
  id: id,
  numero: numero,
  tipo: Tipo.entro,
  centavos: centavos,
  categoriaId: 'ventas',
  concepto: concepto,
  medio: MedioPago.efectivo,
  fecha: fecha,
  creadoEn: fecha,
  actualizadoEn: fecha,
  numeroRecibo: recibo,
  sync: EstadoSync.local,
);

void main() {
  setUpAll(() async {
    // El CSV lleva el período escrito ("SEPTIEMBRE DE 2026"): sin los nombres
    // de los meses cargados, intl revienta antes de llegar a lo que se prueba.
    await initializeDateFormatting('es_PE');
    sqfliteFfiInit();
    final mapa = jsonDecode(
      File('assets/pcge.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    Pcge.cargarDePrueba(mapa.map((k, v) => MapEntry(k, v as String)));
  });

  test('moneda exacta, coma y dos decimales', () {
    expect(Importe.leer('25,50'), 2550);
    expect(Importe.leer('0.01'), 1);
    expect(Importe.leer('10'), 1000);
    expect(Importe.leer('-5.20', permitirNegativo: true), -520);
  });

  test('rechaza milésimas, texto, infinito y montos excesivos', () {
    for (final entrada in [
      '0.001',
      'NaN',
      'Infinity',
      '1e20',
      '1..2',
      '-1',
      '',
      '1000000000.00',
    ]) {
      expect(Importe.leer(entrada), isNull, reason: entrada);
    }
  });

  final apertura = DateTime(2026, 9, 1);
  final hoy = DateTime(2026, 9, 22);
  final negocio = Negocio(saldoInicialCaja: 10000, inicioPeriodo: apertura);
  final datos = [
    movimiento('viejo', DateTime(2026, 8, 31)),
    movimiento('actual', DateTime(2026, 9, 10)),
    movimiento('futuro', DateTime(2026, 9, 23)),
  ];

  test('el saldo excluye lo anterior a apertura y fechas futuras', () {
    final resumen = Resumen.de(
      datos,
      ahora: hoy,
      saldoInicialCaja: 10000,
      inicioPeriodo: apertura,
    );
    expect(resumen.saldoCaja, 11000);
    expect(resumen.entroMes, 1000);
  });

  test('gráfico termina en saldo con apertura y sin movimientos futuros', () {
    final puntos = Series.saldoDiario(
      datos,
      ahora: hoy,
      saldoInicial: 10000,
      inicioPeriodo: apertura,
    );
    expect(puntos.first.dia, apertura);
    expect(puntos.first.centavos, 10000);
    expect(puntos.last.centavos, 11000);
  });

  test('el formato no vuelve a sumar operaciones previas a apertura', () {
    final libro = LibroOficial.armar(
      cuenta: Cuenta.caja,
      negocio: negocio,
      movimientos: datos,
      desde: apertura,
      hasta: hoy,
    );
    expect(libro.saldoInicial, 10000);
    expect(libro.saldoDeCierre, 11000);
    expect(libro.filas.length, 2);
  });

  test('CSV protege las descripciones que parecen fórmulas', () {
    final libro = LibroOficial.armar(
      cuenta: Cuenta.caja,
      negocio: negocio,
      movimientos: [movimiento('formula', hoy, concepto: '=1+1')],
      desde: apertura,
      hasta: hoy,
    );
    expect(Exportador.csv(libro), contains("'=1+1"));
  });

  test('el formato bancario exige número de cuenta', () {
    final perfil = Negocio(
      razonSocial: 'Negocio',
      documento: '12345678',
      inicioPeriodo: apertura,
      entidadFinanciera: 'Banco',
    );
    expect(perfil.completoParaBanco, isFalse);
    expect(perfil.copiarCon(cuentaCorriente: '001').completoParaBanco, isTrue);
  });

  test('registros concurrentes reciben números y recibos distintos', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    try {
      await db.execute(Esquema.crearMovimientos);
      final dao = MovimientoDao(database: db);
      final resultados = await Future.wait(
        List.generate(
          20,
          (i) => dao.insertarNumerado(
            Tipo.entro,
            true,
            (n, r, _) => movimiento('id-$i', hoy, numero: n, recibo: r),
          ),
        ),
      );
      expect(resultados.map((m) => m.numero).toSet().length, 20);
      expect(resultados.map((m) => m.numeroRecibo).toSet().length, 20);
      expect((await dao.listar()).length, 20);

      // Una edición durante la subida debe continuar pendiente.
      final original = resultados.first;
      await dao.guardar(
        original.copiarCon(
          concepto: 'Editado',
          actualizadoEn: hoy.add(const Duration(seconds: 1)),
        ),
      );
      await dao.marcarRespaldados(resultados);
      expect((await dao.pendientesDeSubir()).single.id, original.id);
    } finally {
      await db.close();
    }
  });

  test(
    'el perfil se puede guardar varias veces sin conflicto de clave',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      try {
        await db.execute(Esquema.crearNegocio);
        final dao = NegocioDao(database: db);
        await dao.guardar(negocio);
        await dao.guardar(negocio.copiarCon(razonSocial: 'Actualizado'));
        expect((await dao.leer()).razonSocial, 'Actualizado');
        expect((await db.query(Esquema.tablaNegocio)).length, 1);
      } finally {
        await db.close();
      }
    },
  );
}
