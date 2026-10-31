import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/dominio/banco.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/igv.dart';
import 'package:mi_caja/dominio/inventario.dart';
import 'package:mi_caja/dominio/libro_diario.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';

/// Los datos del voucher del Formato 1.2: el vínculo y el documento deciden la
/// cuenta, como en la hoja BANCOS del Excel "1. LIBRO BANCOS - ING SIST 6".
///
/// El Excel usa el PCGE anterior; la app, el 2026. Donde cambió el número de
/// la subcuenta (la letra en cartera era 1331 y ahora es 1332), se espera el
/// del 2026.
void main() {
  setUpAll(() {
    Pcge.cargarDeTexto(File('assets/pcge.json').readAsStringSync());
  });

  setUp(() => Categoria.registrarPropias(const []));

  String cuenta(
    Categoria c, {
    Vinculo vinculo = Vinculo.tercero,
    DocumentoPago documento = DocumentoPago.factura,
    Situacion situacion = Situacion.cartera,
  }) => ReglasCuenta.para(
    c,
    vinculo: vinculo,
    documento: documento,
    situacion: situacion,
  );

  group('la cuenta según el vínculo y el documento', () {
    test('los cobros de la hoja BANCOS', () {
      // "Mercaderías, terceros, factura".
      expect(cuenta(Categoria.cobrosFiado), '1212');
      // "Mercaderías, terc., fact. Cobranza".
      expect(
        cuenta(Categoria.cobrosFiado, situacion: Situacion.cobranza),
        '1213',
      );
      // "Mercaderías, terceros, F. en dscto".
      expect(
        cuenta(Categoria.cobrosFiado, situacion: Situacion.descuento),
        '1214',
      );
      // "Mercaderías, sucursal, letra".
      expect(
        cuenta(
          Categoria.cobrosFiado,
          vinculo: Vinculo.sucursal,
          documento: DocumentoPago.letra,
        ),
        '1332',
      );
      // "Mercaderías, sucursal, L. en Dscto".
      expect(
        cuenta(
          Categoria.cobrosFiado,
          vinculo: Vinculo.sucursal,
          documento: DocumentoPago.letra,
          situacion: Situacion.descuento,
        ),
        '1334',
      );
      // "Camioneta, tercero" y "PC, filial".
      expect(cuenta(Categoria.ventaActivo), '1653');
      expect(cuenta(Categoria.ventaActivo, vinculo: Vinculo.filial), '1753');
      // "Dividendos, asociada".
      expect(
        cuenta(Categoria.dividendosRecibidos, vinculo: Vinculo.asociada),
        '1733',
      );
      // "Préstamo, ingeniera": a un trabajador.
      expect(
        cuenta(Categoria.cobroPrestamo, vinculo: Vinculo.personal),
        '1411',
      );
      // "Regalías, terceros".
      expect(cuenta(Categoria.regalias), '1632');
    });

    test('los pagos de la hoja BANCOS', () {
      // "Mercaderías, terceros, F. en Cartera" y "Recibo de luz".
      expect(cuenta(Categoria.proveedores), '4212');
      expect(cuenta(Categoria.luz), '4212');
      // "Mercaderías, matriz, L. en cobranza".
      expect(
        cuenta(
          Categoria.proveedores,
          vinculo: Vinculo.matriz,
          documento: DocumentoPago.letra,
        ),
        '4331',
      );
      // "Camión, tercero".
      expect(cuenta(Categoria.compraActivo), '4654');
      // "Dividendos, asociada".
      expect(
        cuenta(Categoria.dividendosPagados, vinculo: Vinculo.asociada),
        '475',
      );
      // "Asesoría contable", con recibo por honorarios.
      expect(cuenta(Categoria.honorarios), '424');
    });

    test('las demás combinaciones', () {
      expect(
        cuenta(Categoria.ventas, vinculo: Vinculo.matriz),
        '1312',
        reason: 'venta a una relacionada',
      );
      expect(cuenta(Categoria.anticipos, vinculo: Vinculo.filial), '1321');
      expect(cuenta(Categoria.mercaderia, vinculo: Vinculo.matriz), '4312');
      expect(
        cuenta(Categoria.proveedores, documento: DocumentoPago.letra),
        '423',
      );
      expect(cuenta(Categoria.compraActivo, vinculo: Vinculo.sucursal), '4774');
      expect(cuenta(Categoria.pagoPrestamo), '4511');
      expect(cuenta(Categoria.pagoPrestamo, vinculo: Vinculo.asociada), '471');
      expect(cuenta(Categoria.pagoPrestamo, vinculo: Vinculo.personal), '4411');
      expect(cuenta(Categoria.cobroPrestamo), '1612');
      expect(cuenta(Categoria.dividendosPagados), '4412');
      // Lo que no tiene variante no cambia: la planilla es la planilla.
      expect(cuenta(Categoria.sueldos, vinculo: Vinculo.matriz), '4111');
      expect(cuenta(Categoria.honorarios, vinculo: Vinculo.asociada), '424');
      // "Otros" pide la cuenta exacta: la regla no la toca.
      expect(cuenta(Categoria.otrosEgresos, vinculo: Vinculo.matriz), '4212');
    });

    test('todas las cuentas que puede elegir la regla existen en el PCGE', () {
      for (final c in Categoria.base) {
        for (final v in Vinculo.values) {
          for (final d in DocumentoPago.values) {
            for (final s in Situacion.values) {
              final codigo = cuenta(c, vinculo: v, documento: d, situacion: s);
              expect(
                Pcge.instancia.existe(codigo),
                isTrue,
                reason: '${c.id} · ${v.name} · ${d.name} · ${s.name}: $codigo',
              );
            }
          }
        }
      }
    });

    test('la venta a una relacionada va a la 70122', () {
      expect(ReglasCuenta.ventaSegun(Vinculo.tercero, '70121'), '70121');
      expect(ReglasCuenta.ventaSegun(Vinculo.asociada, '70121'), '70122');
      expect(ReglasCuenta.ventaSegun(Vinculo.personal, '70121'), '70121');
    });
  });

  group('ITF', () {
    test('0.005% truncado a cinco céntimos: menos de S/ 1,000 no paga', () {
      expect(Itf.de(0), 0);
      expect(Itf.de(99999), 0);
      expect(Itf.de(100000), 5);
      expect(Itf.de(199999), 5);
      // Los vouchers del Excel: 52,864 da 2.6432 y 38,540 da 1.927.
      expect(Itf.de(5286400), 260);
      expect(Itf.de(3854000), 190);
    });
  });

  group('tipo de operación', () {
    test('una transferencia a otro banco es interbancaria', () {
      String tipo(String? tercero, String negocio) =>
          EntidadesBancarias.tipoOperacion(
            MedioPago.transferencia,
            bancoTercero: tercero,
            bancoNegocio: negocio,
          );
      expect(tipo('BBVA', 'BBVA Banco Continental'), 'Transferencia');
      expect(
        tipo('BCP', 'BBVA Banco Continental'),
        'Transferencia interbancaria',
      );
      expect(tipo('BCP', 'Banco de Crédito del Perú'), 'Transferencia');
      expect(tipo(null, 'BBVA'), 'Transferencia');
      expect(tipo('BCP', ''), 'Transferencia');
    });

    test('Yape y Plin se nombran por su app', () {
      expect(
        EntidadesBancarias.tipoOperacion(MedioPago.yape, bancoTercero: 'Plin'),
        'Plin',
      );
      expect(EntidadesBancarias.tipoOperacion(MedioPago.yape), 'Yape / Plin');
      expect(EntidadesBancarias.para(MedioPago.yape), ['Yape', 'Plin']);
      expect(EntidadesBancarias.para(MedioPago.deposito), contains('BCP'));
    });
  });

  Movimiento mov(
    String categoria, {
    int centavos = 100000,
    MedioPago medio = MedioPago.transferencia,
    Vinculo vinculo = Vinculo.tercero,
    DocumentoPago documento = DocumentoPago.factura,
    Situacion situacion = Situacion.cartera,
    String? numeroTransaccion,
    String? rutaFoto,
  }) {
    final c = Categoria.porId(categoria);
    final dia = DateTime(2026, 10, 15, 10);
    return Movimiento(
      id: '$categoria-${vinculo.name}',
      numero: 1,
      tipo: c.tipo,
      centavos: centavos,
      categoriaId: categoria,
      concepto: '',
      medio: medio,
      fecha: dia,
      creadoEn: dia,
      actualizadoEn: dia,
      cuentaAsociada: ReglasCuenta.para(
        c,
        vinculo: vinculo,
        documento: documento,
        situacion: situacion,
      ),
      igvCentavos: c.afectoIgv ? Igv.desagregar(centavos).igv : 0,
      numeroTransaccion: numeroTransaccion,
      vinculo: vinculo,
      documentoPago: documento,
      situacion: situacion,
      rutaFoto: rutaFoto,
      sync: EstadoSync.local,
    );
  }

  group('el movimiento con su voucher', () {
    test('la descripción suma el vínculo y el documento, como el Excel', () {
      expect(mov('cobros_fiado').descripcionFormato, 'Cobro de fiado');
      expect(
        mov(
          'cobros_fiado',
          vinculo: Vinculo.sucursal,
          documento: DocumentoPago.letra,
          situacion: Situacion.cobranza,
        ).descripcionFormato,
        'Cobro de fiado, sucursal, letra en cobranza',
      );
      expect(
        mov(
          'proveedores',
          vinculo: Vinculo.matriz,
          documento: DocumentoPago.letra,
        ).descripcionFormato,
        'Pago a proveedor, matriz, letra',
      );
      expect(
        mov('venta_activo', vinculo: Vinculo.filial).descripcionFormato,
        'Cobro por venta de activo fijo, filial',
      );
    });

    test('el voucher es obligatorio desde S/ 700 y sólo por banco', () {
      expect(mov('ventas', centavos: 69999).exigeVoucher, isFalse);
      expect(mov('ventas', centavos: 70000).exigeVoucher, isTrue);
      expect(
        mov('ventas', centavos: 70000, medio: MedioPago.efectivo).exigeVoucher,
        isFalse,
      );
      expect(mov('ventas', rutaFoto: 'v.jpg').tieneVoucher, isTrue);
      expect(mov('ventas', rutaFoto: '  ').tieneVoucher, isFalse);
    });

    test('el ITF sólo lo tienen las operaciones por banco', () {
      expect(mov('ventas', centavos: 5286400).itfCentavos, 260);
      expect(
        mov('ventas', centavos: 150000, medio: MedioPago.efectivo).itfCentavos,
        0,
      );
    });

    test('sobrevive al mapa de la base', () {
      final m = mov(
        'cobros_fiado',
        vinculo: Vinculo.asociada,
        documento: DocumentoPago.letra,
        situacion: Situacion.descuento,
        numeroTransaccion: '04512378',
        rutaFoto: 'abc.png',
      ).copiarCon(bancoTercero: 'BCP');
      final vuelta = Movimiento.desdeMapa(m.aMapa());
      expect(vuelta.vinculo, Vinculo.asociada);
      expect(vuelta.documentoPago, DocumentoPago.letra);
      expect(vuelta.situacion, Situacion.descuento);
      expect(vuelta.bancoTercero, 'BCP');
      expect(vuelta.rutaFoto, 'abc.png');
      expect(vuelta.cuentaDelFormato, '1334');

      // Una fila de antes de la v8 no tiene esas columnas: es un tercero con
      // una factura en cartera.
      final viejo = Movimiento.desdeMapa(
        mov('ventas').aMapa()
          ..remove('vinculo')
          ..remove('documento_pago')
          ..remove('situacion')
          ..remove('banco_tercero'),
      );
      expect(viejo.vinculo, Vinculo.tercero);
      expect(viejo.documentoPago, DocumentoPago.factura);
      expect(viejo.situacion, Situacion.cartera);
    });
  });

  group('el Libro Diario usa la misma cuenta', () {
    LibroDiario libro(List<Movimiento> movimientos) => LibroDiario.armar(
      negocio: const Negocio(razonSocial: 'LIBERTAD SA'),
      movimientos: movimientos,
      desde: DateTime(2026, 10, 1),
      hasta: DateTime(2026, 10, 31),
      mercaderia: sinDatoDeMercaderia,
    );

    Set<String> codigos(AsientoDiario a) => {
      for (final e in a.etapas)
        for (final l in e.lineas) l.codigo,
    };

    test('una venta a una relacionada va a la 1312 y a la 70122', () {
      final a = libro([
        mov('ventas', centavos: 118000, vinculo: Vinculo.matriz),
      ]).asientos.single;
      expect(codigos(a), containsAll(['1312', '70122']));
      expect(codigos(a), isNot(contains('1212')));
      expect(codigos(a), isNot(contains('70121')));
    });

    test('el cobro de una letra en cobranza cancela la 1233', () {
      final a = libro([
        mov(
          'cobros_fiado',
          documento: DocumentoPago.letra,
          situacion: Situacion.cobranza,
        ),
      ]).asientos.single;
      expect(a.etapas, hasLength(1));
      expect(codigos(a), {'1041', '1233'});
    });

    test('las categorías nuevas se cobran o pagan en un solo asiento', () {
      final l = libro([
        mov('venta_activo', vinculo: Vinculo.filial),
        mov('honorarios'),
      ]);
      final cobro = l.asientos.firstWhere((a) => codigos(a).contains('1753'));
      final pago = l.asientos.firstWhere((a) => codigos(a).contains('424'));
      expect(cobro.etapas.single.glosa, 'Por el cobro del activo fijo vendido');
      expect(pago.etapas.single.glosa, 'Por el pago de los honorarios');
      expect(l.cuadra, isTrue);
    });

    test('sin boleta ni recibo, el documento es el N° de operación', () {
      final a = libro([mov('proveedores', numeroTransaccion: '04512378')])
          .asientos
          .single;
      expect(a.documento, 'Oper. 04512378');
    });
  });
}
