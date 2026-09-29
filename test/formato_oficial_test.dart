import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/libro_oficial.dart';
import 'package:mi_caja/dominio/monto_en_letras.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/dominio/recibo.dart';

/// Pruebas del Formato 1.1 / 1.2 y de los recibos.
///
/// Lo que más importa acá es el **cuadre**: un libro de caja cuyas dos columnas
/// no dan lo mismo no sirve para nada, y es un error que a simple vista no se
/// ve. Por eso cada caso lo verifica.
Movimiento mov({
  required Tipo tipo,
  required int centavos,
  MedioPago medio = MedioPago.efectivo,
  String categoriaId = 'ventas',
  required DateTime fecha,
  int numero = 1,
  String? contraparte,
  DateTime? eliminadoEn,
}) {
  return Movimiento(
    id: 'id-$centavos-${tipo.name}-${fecha.millisecondsSinceEpoch}',
    numero: numero,
    tipo: tipo,
    centavos: centavos,
    categoriaId: categoriaId,
    concepto: '',
    medio: medio,
    fecha: fecha,
    creadoEn: fecha,
    actualizadoEn: fecha,
    contraparte: contraparte,
    eliminadoEn: eliminadoEn,
  );
}

final negocio = Negocio(
  razonSocial: 'LIBERTAD SA',
  documento: '20304050601',
  saldoInicialCaja: 43600,
  inicioPeriodo: DateTime(2026, 9, 1),
);

LibroOficial armar(
  List<Movimiento> movimientos, {
  Cuenta cuenta = Cuenta.caja,
  Negocio? deQuien,
}) => LibroOficial.armar(
  cuenta: cuenta,
  negocio: deQuien ?? negocio,
  movimientos: movimientos,
  desde: DateTime(2026, 9, 1),
  hasta: DateTime(2026, 9, 30),
);

void main() {
  setUpAll(() {
    // El catálogo real, el mismo que se empaqueta con la app.
    final crudo = File('assets/pcge.json').readAsStringSync();
    Pcge.cargarDePrueba(
      (jsonDecode(crudo) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
    );
  });

  group('Monto en letras', () {
    test('escribe el importe como lo pide el recibo', () {
      expect(
        MontoEnLetras.soles(177000),
        'MIL SETECIENTOS SETENTA Y 00/100 SOLES',
      );
      expect(MontoEnLetras.soles(2124), 'VEINTIÚN Y 24/100 SOLES');
      expect(MontoEnLetras.soles(0), 'CERO Y 00/100 SOLES');
      expect(MontoEnLetras.soles(100), 'UN Y 00/100 SOLES');
    });

    test('el cien exacto no es ciento', () {
      expect(MontoEnLetras.soles(10000), startsWith('CIEN Y'));
      expect(MontoEnLetras.soles(10100), startsWith('CIENTO UN Y'));
    });

    test('mil va solo; un millón lleva su artículo', () {
      expect(MontoEnLetras.soles(100000), startsWith('MIL Y'));
      expect(MontoEnLetras.soles(100000000), startsWith('UN MILLÓN Y'));
      expect(MontoEnLetras.soles(200000000), startsWith('DOS MILLONES Y'));
    });

    test('los céntimos van siempre con dos dígitos', () {
      expect(MontoEnLetras.soles(505), endsWith('Y 05/100 SOLES'));
      expect(MontoEnLetras.soles(550), endsWith('Y 50/100 SOLES'));
    });
  });

  group('Formato 1.1', () {
    test('la primera fila es el saldo inicial, del lado deudor', () {
      final libro = armar(const []);
      expect(libro.filas.first.descripcion, 'Saldo Inicial');
      expect(libro.filas.first.deudor, 43600);
      expect(libro.filas.first.numero, 1);
      expect(libro.sinOperaciones, isTrue);
    });

    test('el cuadre del Excel: el saldo final va en la columna contraria', () {
      final libro = armar([
        mov(tipo: Tipo.entro, centavos: 10000, fecha: DateTime(2026, 9, 5)),
        mov(tipo: Tipo.salio, centavos: 50000, fecha: DateTime(2026, 9, 6)),
      ]);

      expect(libro.subtotalDeudor, 53600); // 43600 de apertura + 10000
      expect(libro.subtotalAcreedor, 50000);
      // Pesa el deudor, así que la diferencia se abona para cerrar.
      expect(libro.saldoFinalAcreedor, 3600);
      expect(libro.saldoFinalDeudor, 0);
      expect(libro.totalDeudor, libro.totalAcreedor);
      expect(libro.cuadra, isTrue);
      expect(libro.saldoDeCierre, 3600);
    });

    test('cuadra también cuando el período cierra en rojo', () {
      final libro = armar([
        mov(tipo: Tipo.salio, centavos: 90000, fecha: DateTime(2026, 9, 5)),
      ]);
      expect(libro.saldoFinalDeudor, 46400);
      expect(libro.saldoFinalAcreedor, 0);
      expect(libro.cuadra, isTrue);
    });

    test('lo anterior al período se arrastra al saldo de apertura', () {
      final libro = armar([
        mov(tipo: Tipo.entro, centavos: 20000, fecha: DateTime(2026, 8, 20)),
        mov(tipo: Tipo.entro, centavos: 10000, fecha: DateTime(2026, 9, 5)),
      ], deQuien: negocio.copiarCon(inicioPeriodo: DateTime(2026, 8, 1)));
      expect(libro.saldoInicial, 63600); // 43600 + lo de agosto
      // Lo de agosto no aparece como fila: ya está dentro del saldo inicial.
      expect(libro.filas.length, 2);
    });

    test('cada formato ve sólo su propia cuenta', () {
      final movimientos = [
        mov(tipo: Tipo.entro, centavos: 10000, fecha: DateTime(2026, 9, 5)),
        mov(
          tipo: Tipo.entro,
          centavos: 70000,
          medio: MedioPago.yape,
          fecha: DateTime(2026, 9, 6),
        ),
      ];
      // Cada uno: su saldo inicial más una sola operación.
      expect(armar(movimientos).filas.length, 2);
      expect(armar(movimientos, cuenta: Cuenta.banco).filas.length, 2);
      expect(armar(movimientos, cuenta: Cuenta.banco).subtotalDeudor, 70000);
    });

    test('lo eliminado no entra al formato', () {
      final libro = armar([
        mov(
          tipo: Tipo.entro,
          centavos: 10000,
          fecha: DateTime(2026, 9, 5),
          eliminadoEn: DateTime(2026, 9, 7),
        ),
      ]);
      expect(libro.sinOperaciones, isTrue);
      expect(libro.subtotalDeudor, 43600);
    });

    test('cada operación sale con su código y su denominación', () {
      final libro = armar([
        mov(tipo: Tipo.entro, centavos: 10000, fecha: DateTime(2026, 9, 5)),
      ]);
      final fila = libro.filas.last;
      expect(fila.codigoCuenta, '1212');
      // Si la denominación fuera el código, el VLOOKUP habría fallado.
      expect(fila.denominacion, isNot('1212'));
      expect(fila.denominacion, isNotEmpty);
      expect(fila.medioTabla1, '008');
    });

    test('las operaciones se numeran después del saldo inicial', () {
      final libro = armar([
        mov(tipo: Tipo.entro, centavos: 100, fecha: DateTime(2026, 9, 5)),
        mov(tipo: Tipo.entro, centavos: 200, fecha: DateTime(2026, 9, 6)),
      ]);
      expect(libro.filas.map((f) => f.numero), [1, 2, 3]);
    });

    test('el rótulo de la cuenta sale del plan contable', () {
      expect(armar(const []).rotuloCuenta, contains('101'));
      expect(armar(const []).rotuloCuenta, contains('Caja'));
    });
  });

  group('Asiento resumen del Libro Diario', () {
    final sinApertura = Negocio(
      razonSocial: 'LIBERTAD SA',
      documento: '20304050601',
      inicioPeriodo: DateTime(2026, 9, 1),
    );

    test('los cobros del mes entran como un solo asiento que cuadra', () {
      final libro = armar([
        mov(tipo: Tipo.entro, centavos: 10000, fecha: DateTime(2026, 9, 5)),
        mov(tipo: Tipo.entro, centavos: 25000, fecha: DateTime(2026, 9, 8)),
      ], deQuien: sinApertura);

      final asiento = libro.resumenCobros;
      expect(asiento.cuadra, isTrue);
      expect(asiento.totalDebe, 35000);
      // Caja se carga por el total y la contrapartida se agrupa: dos ventas,
      // una sola línea de 1212. Eso es lo que lo hace un resumen.
      expect(asiento.lineas.length, 2);
      expect(asiento.lineas.first.codigo, '101');
      expect(asiento.lineas.first.debe, 35000);
      expect(asiento.lineas.last.codigo, '1212');
      expect(asiento.lineas.last.haber, 35000);
    });

    test('los pagos abonan caja y cargan cada cuenta asociada', () {
      final libro = armar([
        mov(
          tipo: Tipo.salio,
          centavos: 30000,
          categoriaId: 'mercaderia',
          fecha: DateTime(2026, 9, 5),
        ),
        mov(
          tipo: Tipo.salio,
          centavos: 8000,
          categoriaId: 'sueldos',
          fecha: DateTime(2026, 9, 6),
        ),
      ], deQuien: sinApertura);

      final asiento = libro.resumenPagos;
      expect(asiento.cuadra, isTrue);
      expect(asiento.totalHaber, 38000);
      // 4111 (sueldos) y 4212 (proveedores), más el abono a caja.
      expect(asiento.lineas.length, 3);
      expect(asiento.lineas.last.codigo, '101');
      expect(asiento.lineas.last.haber, 38000);
    });

    test('un mes sin movimientos no genera asientos', () {
      expect(armar(const [], deQuien: sinApertura).asientos, isEmpty);
    });
  });

  group('Recibo de caja', () {
    Movimiento conRecibo({int? numeroRecibo, String? contraparte}) =>
        Movimiento(
          id: 'x',
          numero: 3,
          tipo: Tipo.entro,
          centavos: 177000,
          categoriaId: 'ventas',
          concepto: 'Venta de 50 ponchos',
          medio: MedioPago.efectivo,
          fecha: DateTime(2026, 9, 10),
          creadoEn: DateTime(2026, 9, 10),
          actualizadoEn: DateTime(2026, 9, 10),
          contraparte: contraparte,
          numeroRecibo: numeroRecibo,
        );

    test('el correlativo va con ceros a la izquierda', () {
      final recibo = Recibo(
        negocio: negocio,
        movimiento: conRecibo(numeroRecibo: 672),
      );
      expect(recibo.numero, '000672');
      expect(recibo.titulo, 'RECIBO DE INGRESO DE CAJA');
      expect(recibo.montoEnLetras, 'MIL SETECIENTOS SETENTA Y 00/100 SOLES');
    });

    test('sin talonario o sin perfil no se puede emitir', () {
      expect(
        Recibo(negocio: negocio, movimiento: conRecibo()).emitible,
        isFalse,
      );
      expect(
        Recibo(
          negocio: Negocio.vacio,
          movimiento: conRecibo(numeroRecibo: 1),
        ).emitible,
        isFalse,
      );
    });

    test('avisa cuando no se sabe a quién se le cobró', () {
      expect(
        Recibo(
          negocio: negocio,
          movimiento: conRecibo(numeroRecibo: 1),
        ).identificaContraparte,
        isFalse,
      );
      expect(
        Recibo(
          negocio: negocio,
          movimiento: conRecibo(numeroRecibo: 1, contraparte: 'Diana Valera'),
        ).identificaContraparte,
        isTrue,
      );
    });
  });
}
