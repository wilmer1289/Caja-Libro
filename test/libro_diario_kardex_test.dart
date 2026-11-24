import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/dominio/banco.dart' show Vinculo;
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/igv.dart';
import 'package:mi_caja/dominio/inventario.dart';
import 'package:mi_caja/dominio/kardex.dart';
import 'package:mi_caja/dominio/libro_diario.dart';
import 'package:mi_caja/dominio/mercaderia.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/dominio/periodo.dart';

final _fecha = DateTime(2026, 10, 15, 10);
final _inicio = DateTime(2026, 10, 1);
final _fin = DateTime(2026, 10, 31);

void main() {
  setUpAll(() {
    Pcge.cargarDeTexto(File('assets/pcge.json').readAsStringSync());
  });

  setUp(() => Categoria.registrarPropias(const []));

  Movimiento crearMovimiento({
    required String id,
    required Tipo tipo,
    required int centavos,
    required String categoria,
    int? igv,
    int? costo,
    bool exportacion = false,
    Vinculo vinculo = Vinculo.tercero,
    DateTime? fecha,
    DateTime? anuladoEn,
    String? cuentaAsociada,
  }) {
    final cat = Categoria.porId(categoria);
    final cuando = fecha ?? _fecha;
    return Movimiento(
      id: id,
      numero: 1,
      tipo: tipo,
      centavos: centavos,
      categoriaId: categoria,
      concepto: '',
      medio: MedioPago.efectivo,
      fecha: cuando,
      creadoEn: cuando,
      actualizadoEn: cuando,
      cuentaAsociada: cuentaAsociada ?? cat.cuentaAsociada,
      igvCentavos: igv ?? (cat.afectoIgv ? Igv.desagregar(centavos).igv : 0),
      costoCentavos: costo,
      exportacion: exportacion,
      vinculo: vinculo,
      anuladoEn: anuladoEn,
      sync: EstadoSync.local,
    );
  }

  LineaAlmacen crearLinea({
    required String id,
    required String producto,
    required int numero,
    required OperacionAlmacen operacion,
    required bool entrada,
    required int cantidad,
    required DateTime fecha,
    int? costo,
    int? importe,
    String? movimientoId,
    String? origenId,
    String? cuentaCosto,
    String glosa = '',
    bool anulada = false,
  }) => LineaAlmacen(
    id: id,
    mercaderiaId: producto,
    fecha: fecha,
    numero: numero,
    operacion: operacion,
    entrada: entrada,
    cantidad: cantidad,
    costoTotal: costo,
    importe: importe,
    movimientoId: movimientoId,
    origenId: origenId,
    cuentaCosto: cuentaCosto,
    glosa: glosa,
    anulada: anulada,
  );

  LibroDiario armarLibro(
    List<Movimiento> movimientos, {
    LibroDiarioDatos? datos,
    LeerMercaderia mercaderia = sinDatoDeMercaderia,
    Negocio? negocio,
    DateTime? desde,
    DateTime? hasta,
  }) => LibroDiario.armar(
    negocio:
        negocio ??
        Negocio(razonSocial: 'LIBERTAD S.A.', inicioPeriodo: _inicio),
    movimientos: movimientos,
    desde: desde ?? _inicio,
    hasta: hasta ?? _fin,
    datos: datos,
    mercaderia: mercaderia,
  );

  test('venta de exportación usa costo y cuenta de cada línea, sin IGV', () {
    final compra = crearLinea(
      id: 'compra',
      producto: 'tela',
      numero: 1,
      operacion: OperacionAlmacen.compra,
      entrada: true,
      cantidad: 2000,
      fecha: DateTime(2026, 10, 10),
      costo: 10000,
    );
    final venta = crearLinea(
      id: 'venta-linea',
      producto: 'tela',
      numero: 2,
      operacion: OperacionAlmacen.venta,
      entrada: false,
      cantidad: 1000,
      fecha: _fecha,
      importe: 23600,
      movimientoId: 'venta',
      cuentaCosto: '69111',
    );
    final movimiento = crearMovimiento(
      id: 'venta',
      tipo: Tipo.entro,
      centavos: 23600,
      categoria: 'ventas',
      igv: 3600,
      exportacion: true,
    );
    final libro = armarLibro(
      [movimiento],
      datos: LibroDiarioDatos(
        kardex: Kardex.de([compra, venta]),
        lineasAlmacen: [compra, venta],
        mercaderias: [Mercaderia(id: 'tela', nombre: 'Tela', creadoEn: _fecha)],
      ),
    );

    final asiento = libro.asientos.single;
    expect(asiento.etapas[0].lineas.map((l) => (l.codigo, l.debe, l.haber)), [
      ('1212', 23600, 0),
      ('70111', 0, 23600),
    ]);
    expect(asiento.etapas[1].lineas.map((l) => (l.codigo, l.debe, l.haber)), [
      ('69111', 5000, 0),
      ('20111', 0, 5000),
    ]);
    expect(asiento.cuadra, isTrue);
  });

  test('venta anterior conserva el costo guardado en el movimiento', () {
    final venta = crearMovimiento(
      id: 'venta-anterior',
      tipo: Tipo.entro,
      centavos: 11800,
      categoria: 'ventas',
      costo: 7000,
    );
    final libro = armarLibro(
      [venta],
      mercaderia: (_) => const DatoMercaderia(
        id: 'antigua',
        nombre: 'Mercadería antigua',
        costoCentavos: 9000,
      ),
    );

    expect(libro.asientos.single.etapas[1].lineas.first.debe, 7000);
    expect(libro.asientos.single.cuadra, isTrue);
  });

  test('venta local a una relacionada usa las cuentas de la decisión 12', () {
    final venta = crearMovimiento(
      id: 'venta-relacionada',
      tipo: Tipo.entro,
      centavos: 11800,
      categoria: 'ventas',
      costo: 5000,
      vinculo: Vinculo.filial,
      cuentaAsociada: '1312',
    );
    final asiento = armarLibro(
      [venta],
      mercaderia: (_) => const DatoMercaderia(
        id: 'producto',
        nombre: 'Producto',
        costoCentavos: 5000,
      ),
    ).asientos.single;

    expect(asiento.etapas[0].lineas.last.codigo, '70122');
    expect(asiento.etapas[1].lineas.first.codigo, '69122');
    expect(asiento.cuadra, isTrue);
  });

  test('compra sin IGV no genera la línea 40111', () {
    final compra = crearMovimiento(
      id: 'compra-sin-igv',
      tipo: Tipo.salio,
      centavos: 10000,
      categoria: 'mercaderia',
      igv: 0,
    );
    final asiento = armarLibro([compra]).asientos.single;

    expect(asiento.etapas.first.lineas.map((l) => l.codigo), ['6011', '4212']);
    expect(asiento.cuadra, isTrue);
  });

  test(
    'una venta de varios productos crea un solo asiento de costo con glosa',
    () {
      final lineas = [
        crearLinea(
          id: 'compra-poncho',
          producto: 'poncho',
          numero: 1,
          operacion: OperacionAlmacen.compra,
          entrada: true,
          cantidad: 1000,
          fecha: DateTime(2026, 10, 10),
          costo: 5000,
        ),
        crearLinea(
          id: 'compra-manta',
          producto: 'manta',
          numero: 2,
          operacion: OperacionAlmacen.compra,
          entrada: true,
          cantidad: 1000,
          fecha: DateTime(2026, 10, 10),
          costo: 8000,
        ),
        crearLinea(
          id: 'venta-poncho',
          producto: 'poncho',
          numero: 3,
          operacion: OperacionAlmacen.venta,
          entrada: false,
          cantidad: 500,
          fecha: _fecha,
          importe: 10000,
          movimientoId: 'venta',
          cuentaCosto: '69121',
        ),
        crearLinea(
          id: 'venta-manta',
          producto: 'manta',
          numero: 4,
          operacion: OperacionAlmacen.venta,
          entrada: false,
          cantidad: 500,
          fecha: _fecha,
          importe: 10000,
          movimientoId: 'venta',
          cuentaCosto: '69121',
        ),
      ];
      final venta = crearMovimiento(
        id: 'venta',
        tipo: Tipo.entro,
        centavos: 23600,
        categoria: 'ventas',
        igv: 3600,
      );
      final asiento = armarLibro(
        [venta],
        datos: LibroDiarioDatos(
          kardex: Kardex.de(lineas),
          lineasAlmacen: lineas,
          mercaderias: [
            Mercaderia(id: 'poncho', nombre: 'Poncho', creadoEn: _fecha),
            Mercaderia(id: 'manta', nombre: 'Manta', creadoEn: _fecha),
          ],
        ),
      ).asientos.single;
      final costos = asiento.etapas
          .where((e) => e.tipo == EtapaTipo.costoDeVenta)
          .toList();

      expect(costos, hasLength(1));
      expect(costos.single.glosa, 'Por el costo de venta (Poncho, Manta)');
      expect(costos.single.lineas.map((l) => (l.codigo, l.debe, l.haber)), [
        ('69121', 6500, 0),
        ('20111', 0, 6500),
      ]);
      expect(asiento.cuadra, isTrue);
    },
  );

  test('devolución al cliente revierte costo y mantiene balance', () {
    final compra = crearLinea(
      id: 'compra',
      producto: 'tela',
      numero: 1,
      operacion: OperacionAlmacen.compra,
      entrada: true,
      cantidad: 10000,
      fecha: DateTime(2026, 10, 1),
      costo: 100000,
    );
    final venta = crearLinea(
      id: 'venta-linea',
      producto: 'tela',
      numero: 2,
      operacion: OperacionAlmacen.venta,
      entrada: false,
      cantidad: 1000,
      fecha: DateTime(2026, 10, 2),
      importe: 50000,
      movimientoId: 'venta-caja',
      cuentaCosto: '69111',
    );
    final devolucion = crearLinea(
      id: 'devolucion',
      producto: 'tela',
      numero: 3,
      operacion: OperacionAlmacen.devolucionRecibida,
      entrada: true,
      cantidad: 500,
      fecha: DateTime(2026, 10, 3),
      importe: 20000,
      origenId: 'venta-linea',
    );
    final lineas = [compra, venta, devolucion];
    final libro = armarLibro(
      const [],
      datos: LibroDiarioDatos(
        kardex: Kardex.de(lineas),
        lineasAlmacen: lineas,
        mercaderias: [Mercaderia(id: 'tela', nombre: 'Tela', creadoEn: _fecha)],
      ),
    );
    final asiento = libro.asientos.singleWhere(
      (a) => a.glosa.startsWith('Por devolución de cliente'),
    );

    expect(
      asiento.etapas.single.lineas.map((l) => (l.codigo, l.debe, l.haber)),
      [('20111', 5000, 0), ('69111', 0, 5000)],
    );
    expect(asiento.cuadra, isTrue);
  });

  test('devoluciones, merma, desmedro y ajuste cuadran con el Kardex', () {
    final compra = crearLinea(
      id: 'compra',
      producto: 'tela',
      numero: 1,
      operacion: OperacionAlmacen.compra,
      entrada: true,
      cantidad: 10000,
      fecha: _inicio,
      costo: 100000,
    );
    final venta = crearLinea(
      id: 'venta-linea',
      producto: 'tela',
      numero: 2,
      operacion: OperacionAlmacen.venta,
      entrada: false,
      cantidad: 1000,
      fecha: DateTime(2026, 10, 2),
      importe: 50000,
      movimientoId: 'venta-caja',
      cuentaCosto: '69112',
    );
    final lineas = [
      compra,
      venta,
      crearLinea(
        id: 'dev-cliente',
        producto: 'tela',
        numero: 3,
        operacion: OperacionAlmacen.devolucionRecibida,
        entrada: true,
        cantidad: 500,
        fecha: DateTime(2026, 10, 3),
        origenId: 'venta-linea',
      ),
      crearLinea(
        id: 'dev-proveedor',
        producto: 'tela',
        numero: 4,
        operacion: OperacionAlmacen.devolucionEntregada,
        entrada: false,
        cantidad: 500,
        fecha: DateTime(2026, 10, 4),
        origenId: 'compra',
      ),
      crearLinea(
        id: 'merma',
        producto: 'tela',
        numero: 5,
        operacion: OperacionAlmacen.merma,
        entrada: false,
        cantidad: 500,
        fecha: DateTime(2026, 10, 5),
        glosa: 'Dañada',
      ),
      crearLinea(
        id: 'desmedro',
        producto: 'tela',
        numero: 6,
        operacion: OperacionAlmacen.desmedro,
        entrada: false,
        cantidad: 500,
        fecha: DateTime(2026, 10, 6),
        glosa: 'Vencida',
      ),
      crearLinea(
        id: 'sobrante',
        producto: 'tela',
        numero: 7,
        operacion: OperacionAlmacen.ajuste,
        entrada: true,
        cantidad: 1000,
        fecha: DateTime(2026, 10, 7),
        glosa: 'Conteo',
      ),
      crearLinea(
        id: 'faltante',
        producto: 'tela',
        numero: 8,
        operacion: OperacionAlmacen.ajuste,
        entrada: false,
        cantidad: 500,
        fecha: DateTime(2026, 10, 8),
        glosa: 'Conteo',
      ),
    ];
    final libro = armarLibro(
      const [],
      datos: LibroDiarioDatos(
        kardex: Kardex.de(lineas),
        lineasAlmacen: lineas,
        mercaderias: [Mercaderia(id: 'tela', nombre: 'Tela', creadoEn: _fecha)],
      ),
    );
    final asientos = libro.asientos
        .where((a) => a.origen.id != 'apertura')
        .toList();

    expect(asientos, hasLength(6));
    expect(asientos.every((a) => a.cuadra), isTrue);
    expect(
      asientos
          .singleWhere((a) => a.glosa.startsWith('Por devolución de cliente'))
          .etapas
          .single
          .lineas
          .map((l) => l.codigo),
      ['20111', '69112'],
    );
    expect(
      asientos
          .singleWhere((a) => a.glosa.startsWith('Por devolución a proveedor'))
          .etapas
          .single
          .lineas
          .map((l) => l.codigo),
      ['4212', '20111'],
    );
    expect(
      asientos
          .singleWhere(
            (a) =>
                a.glosa.startsWith('Por ajuste por conteo') &&
                a.etapas.single.lineas.first.codigo == '20111',
          )
          .etapas
          .single
          .lineas
          .map((l) => l.codigo),
      ['20111', '7599'],
    );
    expect(
      asientos
          .singleWhere(
            (a) =>
                a.glosa.startsWith('Por ajuste por conteo') &&
                a.etapas.single.lineas.first.codigo == '6593',
          )
          .etapas
          .single
          .lineas
          .map((l) => l.codigo),
      ['6593', '20111'],
    );
    // Merma y desmedro: gastos por deterioro de inventarios (6951).
    for (final glosa in ['Por merma', 'Por desmedro']) {
      expect(
        asientos
            .singleWhere((a) => a.glosa.startsWith(glosa))
            .etapas
            .single
            .lineas
            .map((l) => l.codigo),
        ['6951', '20111'],
        reason: glosa,
      );
    }
  });

  test('la apertura lleva el inventario inicial aunque ese día haya ventas', () {
    // Como el ejercicio del Excel: 1,200 ponchos a S/ 50 el 1 de octubre y,
    // el mismo día, una venta de 800.
    final lineas = [
      crearLinea(
        id: 'inicial',
        producto: 'posa',
        numero: 1,
        operacion: OperacionAlmacen.saldoInicial,
        entrada: true,
        cantidad: 1200000,
        fecha: _inicio,
        costo: 6000000,
      ),
      crearLinea(
        id: 'venta',
        producto: 'posa',
        numero: 2,
        operacion: OperacionAlmacen.venta,
        entrada: false,
        cantidad: 800000,
        fecha: _inicio,
        importe: 5600000,
        movimientoId: 'v1',
        cuentaCosto: '69121',
      ),
    ];
    final datos = LibroDiarioDatos(
      kardex: Kardex.de(lineas),
      lineasAlmacen: lineas,
    );
    LineaDiario mercaderias(LibroDiario libro) => libro
        .asientoApertura!
        .etapas
        .single
        .lineas
        .singleWhere((l) => l.codigo == '20111');

    final libro = armarLibro(const [], datos: datos);
    expect(mercaderias(libro).debe, 6000000);
    expect(libro.asientoApertura!.cuadra, isTrue);

    // Sin inicio del período, la apertura va el día del primer inventario.
    final sinPeriodo = armarLibro(
      const [],
      datos: datos,
      negocio: Negocio(razonSocial: 'LIBERTAD S.A.', kardexDesde: _inicio),
    );
    expect(sinPeriodo.asientoApertura!.fecha, _inicio);
    expect(mercaderias(sinPeriodo).debe, 6000000);
  });

  test('apertura se incluye y acredita capital según la forma jurídica', () {
    final stockInicial = crearLinea(
      id: 'stock-inicial',
      producto: 'tela',
      numero: 0,
      operacion: OperacionAlmacen.saldoInicial,
      entrada: true,
      cantidad: 1000,
      fecha: _inicio,
      costo: 50000,
    );
    for (final (razon, capital) in [
      ('LIBERTAD S.A.', '5011'),
      ('LIBERTAD E.I.R.L.', '5012'),
    ]) {
      final libro = armarLibro(
        const [],
        negocio: Negocio(
          razonSocial: razon,
          inicioPeriodo: _inicio,
          saldoInicialCaja: 12500,
          saldoInicialBanco: 27500,
        ),
        datos: LibroDiarioDatos(
          kardex: Kardex.de([stockInicial]),
          lineasAlmacen: [stockInicial],
        ),
      );
      final apertura = libro.asientoApertura!;

      expect(libro.asientos, hasLength(1));
      expect(libro.asientos.single.origen.id, 'apertura');
      expect(apertura.etapas.single.lineas.last.codigo, capital);
      expect(
        apertura.etapas.single.lineas.map((l) => (l.codigo, l.debe, l.haber)),
        [
          ('101', 12500, 0),
          ('1041', 27500, 0),
          ('20111', 50000, 0),
          (capital, 0, 90000),
        ],
      );
      expect(apertura.cuadra, isTrue);
    }
  });

  test('el resumen del ejercicio agrupa los costos por cuenta en el rango', () {
    final ejercicio = [
      (1, OperacionAlmacen.saldoInicial, 1200, 6000000),
      (1, OperacionAlmacen.venta, 800, 4000000),
      (2, OperacionAlmacen.compra, 1600, 8320000),
      (4, OperacionAlmacen.venta, 550, 2838000),
      (7, OperacionAlmacen.venta, 450, 2322000),
      (8, OperacionAlmacen.compra, 1000, 5400000),
      (10, OperacionAlmacen.venta, 20, 105600),
      (13, OperacionAlmacen.venta, 880, 4646400),
      (15, OperacionAlmacen.compra, 1400, 7042000),
      (16, OperacionAlmacen.venta, 30, 154200),
      (17, OperacionAlmacen.venta, 1170, 6013800),
      (18, OperacionAlmacen.compra, 1700, 8840000),
      (20, OperacionAlmacen.venta, 1250, 6467500),
      (21, OperacionAlmacen.venta, 1400, 7243600),
      (24, OperacionAlmacen.compra, 1650, 8019000),
      (28, OperacionAlmacen.venta, 1100, 5406445),
    ];
    final lineas = [
      for (var i = 0; i < ejercicio.length; i++)
        crearLinea(
          id: 'ejercicio-$i',
          producto: 'posa',
          numero: i,
          operacion: ejercicio[i].$2,
          entrada:
              ejercicio[i].$2 == OperacionAlmacen.compra ||
              ejercicio[i].$2 == OperacionAlmacen.saldoInicial,
          cantidad: ejercicio[i].$3 * 1000,
          fecha: DateTime(2026, 10, ejercicio[i].$1),
          costo: ejercicio[i].$2 == OperacionAlmacen.venta
              ? null
              : ejercicio[i].$4,
          cuentaCosto: [4, 17].contains(ejercicio[i].$1) ? '69111' : '69121',
        ),
    ];
    final kardex = Kardex.de(lineas);
    final resumen = CostoVentasResumen.enRango(
      kardex,
      desde: _inicio,
      hasta: _fin,
    );

    expect(resumen.porCuenta, {'69111': 8851800, '69121': 30345745});
    expect(resumen.total, 39197545);
    expect(
      kardex.costoDeVentas(Periodo.mes, referencia: _fin),
      resumen.porCuenta,
    );
  });

  test('los movimientos anulados no producen asientos', () {
    final venta = crearMovimiento(
      id: 'anulada',
      tipo: Tipo.entro,
      centavos: 11800,
      categoria: 'ventas',
      costo: 5000,
      anuladoEn: _fecha,
    );

    expect(armarLibro([venta]).asientos, isEmpty);
  });
}
