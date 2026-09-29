import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/mayor.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/resumen.dart';

/// El libro mayor de caja y bancos: que el total cuadre con el resumen, que
/// el desglose por medio sume exacto, y que el saldo de cada renglón sea el
/// que quedó después de ese movimiento.
void main() {
  final hoy = DateTime(2026, 9, 25);
  final apertura = DateTime(2026, 9, 1);
  final negocio = Negocio(
    razonSocial: 'LIBERTAD SA',
    documento: '20304050601',
    saldoInicialCaja: 4000000, // S/ 40,000
    saldoInicialBanco: 300000, // S/ 3,000
    inicioPeriodo: apertura,
  );

  var n = 0;
  Movimiento m(
    int dia,
    Tipo tipo,
    int centavos,
    MedioPago medio, {
    DateTime? eliminado,
  }) {
    n++;
    final fecha = DateTime(2026, 9, dia);
    return Movimiento(
      id: 'm$n',
      numero: n,
      tipo: tipo,
      centavos: centavos,
      categoriaId: tipo == Tipo.entro ? 'ventas' : 'mercaderia',
      concepto: '',
      medio: medio,
      fecha: fecha,
      creadoEn: fecha,
      actualizadoEn: fecha,
      eliminadoEn: eliminado,
      sync: EstadoSync.local,
    );
  }

  // Los datos del usuario, más o menos: ventas en efectivo y por Yape, una
  // venta grande por transferencia, pagos con tarjeta y por Yape.
  final datos = [
    m(9, Tipo.entro, 3000000, MedioPago.transferencia),
    m(10, Tipo.entro, 9000, MedioPago.yape),
    m(11, Tipo.entro, 9000, MedioPago.efectivo),
    m(11, Tipo.entro, 1000, MedioPago.efectivo),
    m(14, Tipo.entro, 100000, MedioPago.efectivo),
    m(14, Tipo.salio, 50000, MedioPago.transferencia),
    m(15, Tipo.salio, 500000, MedioPago.yape),
    m(15, Tipo.salio, 800000, MedioPago.tarjeta),
    // Lo que no cuenta: borrado, futuro y anterior a la apertura.
    m(12, Tipo.entro, 777700, MedioPago.yape, eliminado: hoy),
    m(28, Tipo.entro, 555500, MedioPago.efectivo),
    Movimiento(
      id: 'viejo',
      numero: 99,
      tipo: Tipo.entro,
      centavos: 123400,
      categoriaId: 'ventas',
      concepto: '',
      medio: MedioPago.deposito,
      fecha: DateTime(2026, 8, 20),
      creadoEn: DateTime(2026, 8, 20),
      actualizadoEn: DateTime(2026, 8, 20),
      sync: EstadoSync.local,
    ),
  ];

  final mayor = LibroMayor.armar(datos, negocio: negocio, ahora: hoy);

  test('caja, banco y total cuadran con el resumen del inicio', () {
    final resumen = Resumen.de(
      datos,
      ahora: hoy,
      saldoInicialCaja: negocio.saldoInicialCaja,
      saldoInicialBanco: negocio.saldoInicialBanco,
      inicioPeriodo: apertura,
    );

    // 40,000 + 90 + 10 + 1,000 = 41,100 en efectivo.
    expect(mayor.saldoCaja, 4110000);
    expect(mayor.saldoCaja, resumen.saldoCaja);
    // 3,000 + 30,000 + 90 − 500 − 5,000 − 8,000 = 19,590 en banco.
    expect(mayor.saldoBanco, 1959000);
    expect(mayor.saldoBanco, resumen.saldoBanco);
    expect(mayor.total, resumen.saldoTotal);
  });

  test('el desglose por medio suma exactamente el saldo del banco', () {
    final medios = {for (final t in mayor.mediosBanco) t.medio: t};

    // Todos los medios del banco que se ofrecen, aunque estén en cero:
    // depósito y tarjeta de crédito no "faltan", están sin movimientos.
    expect(medios.keys, [
      MedioPago.yape,
      MedioPago.transferencia,
      MedioPago.deposito,
      MedioPago.tarjeta,
      MedioPago.tarjetaCredito,
    ]);
    expect(medios[MedioPago.deposito]!.cantidad, 0);
    expect(medios[MedioPago.tarjetaCredito]!.neto, 0);
    expect(medios[MedioPago.yape]!.entro, 9000);
    expect(medios[MedioPago.yape]!.salio, 500000);
    expect(medios[MedioPago.yape]!.neto, -491000);
    expect(medios[MedioPago.transferencia]!.neto, 2950000);
    expect(medios[MedioPago.tarjeta]!.cantidad, 1);

    final suma = mayor.mediosBanco.fold(0, (s, t) => s + t.neto);
    expect(mayor.saldoInicialBanco + suma, mayor.saldoBanco);
  });

  test('cada renglón lleva el saldo que dejó, del más nuevo al más viejo', () {
    final lineas = mayor.lineas(Bolsillo.todo);

    expect(lineas.length, 8);
    // Arriba, lo último, y su saldo es el total de hoy.
    expect(lineas.first.saldo, mayor.total);
    // Abajo, lo primero: la transferencia de 30,000 sobre el saldo inicial.
    expect(lineas.last.movimiento.medio, MedioPago.transferencia);
    expect(lineas.last.saldo, 4300000 + 3000000);

    // Entre renglón y renglón, el saldo cambia exactamente lo que se movió.
    for (var i = 0; i < lineas.length - 1; i++) {
      final diferencia = lineas[i].saldo - lineas[i + 1].saldo;
      expect(diferencia, lineas[i].movimiento.efectoEnSaldo);
    }
  });

  test('un bolsillo arranca de su propio saldo inicial', () {
    expect(mayor.saldoDe(Bolsillo.caja), mayor.saldoCaja);
    expect(mayor.saldoDe(Bolsillo.banco), mayor.saldoBanco);
    expect(mayor.lineas(Bolsillo.caja).last.saldo, 4000000 + 9000);

    // Un medio digital suelto arranca de cero: el saldo de apertura del
    // banco no se puede repartir entre Yape y transferencia.
    final yape = Bolsillo.deMedio(MedioPago.yape);
    expect(mayor.saldoDe(yape), -491000);
    expect(mayor.lineas(yape).length, 2);
  });

  test('"sólo efectivo" es la caja, no un filtro repetido', () {
    expect(Bolsillo.deMedio(MedioPago.efectivo), Bolsillo.caja);
    expect(Bolsillo.deMedio(MedioPago.yape), isNot(Bolsillo.banco));
    expect(Bolsillo.deMedio(MedioPago.yape).etiqueta, 'Yape / Plin');
  });

  test('sin movimientos, el total es el saldo con que se abrió', () {
    final vacio = LibroMayor.armar(const [], negocio: negocio, ahora: hoy);
    expect(vacio.total, 4300000);
    expect(vacio.porMedio, isEmpty);
    expect(vacio.lineas(Bolsillo.todo), isEmpty);
  });
}
