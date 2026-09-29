import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/igv.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/pcge.dart';
import 'package:mi_caja/dominio/periodo.dart';
import 'package:mi_caja/dominio/resumen.dart';
import 'package:mi_caja/dominio/series.dart';

/// Pruebas de la lógica del libro de caja. No tocan SQLite ni Firebase: el
/// dominio es puro a propósito, para poder verificar los saldos sin montar
/// una base de datos.
Movimiento mov({
  required Tipo tipo,
  required int centavos,
  MedioPago medio = MedioPago.efectivo,
  String categoriaId = 'ventas',
  DateTime? fecha,
  DateTime? eliminadoEn,
}) {
  final cuando = fecha ?? DateTime(2026, 9, 16);
  return Movimiento(
    id: 'id-$centavos-${tipo.name}-${cuando.millisecondsSinceEpoch}',
    numero: 1,
    tipo: tipo,
    centavos: centavos,
    categoriaId: categoriaId,
    concepto: 'prueba',
    medio: medio,
    fecha: cuando,
    creadoEn: cuando,
    actualizadoEn: cuando,
    eliminadoEn: eliminadoEn,
  );
}

void main() {
  // El catálogo de cuentas, leído del mismo archivo que se empaqueta. Lo
  // necesitan tanto las pruebas de cuentas como las del formato oficial.
  setUpAll(() {
    final crudo = File('assets/pcge.json').readAsStringSync();
    Pcge.cargarDePrueba(
      (jsonDecode(crudo) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
    );
  });

  group('Movimiento', () {
    test('el efecto en el saldo lleva el signo del tipo', () {
      expect(mov(tipo: Tipo.entro, centavos: 5000).efectoEnSaldo, 5000);
      expect(mov(tipo: Tipo.salio, centavos: 5000).efectoEnSaldo, -5000);
    });

    test('el medio de pago decide la cuenta', () {
      expect(
        mov(tipo: Tipo.entro, centavos: 100, medio: MedioPago.efectivo).cuenta,
        Cuenta.caja,
      );
      expect(
        mov(tipo: Tipo.entro, centavos: 100, medio: MedioPago.yape).cuenta,
        Cuenta.banco,
      );
    });

    test('el aviso de bancarización sólo aplica a efectivo desde S/ 2,000', () {
      expect(
        mov(tipo: Tipo.salio, centavos: 199999).superaUmbralBancarizacion,
        isFalse,
      );
      expect(
        mov(tipo: Tipo.salio, centavos: 200000).superaUmbralBancarizacion,
        isTrue,
      );
      // Pagar S/ 5,000 por transferencia es justamente lo que pide la ley:
      // no hay nada que avisar.
      expect(
        mov(
          tipo: Tipo.salio,
          centavos: 500000,
          medio: MedioPago.transferencia,
        ).superaUmbralBancarizacion,
        isFalse,
      );
    });

    test('sobrevive una vuelta por el mapa de la base', () {
      final original = mov(tipo: Tipo.salio, centavos: 12345);
      final copia = Movimiento.desdeMapa(original.aMapa());

      expect(copia.id, original.id);
      expect(copia.centavos, original.centavos);
      expect(copia.tipo, original.tipo);
      expect(copia.medio, original.medio);
      expect(copia.fecha, original.fecha);
    });
  });

  group('Resumen', () {
    test('separa el saldo de caja del de banco', () {
      final resumen = Resumen.de([
        mov(tipo: Tipo.entro, centavos: 10000),
        mov(tipo: Tipo.salio, centavos: 3000),
        mov(tipo: Tipo.entro, centavos: 5000, medio: MedioPago.yape),
      ]);

      expect(resumen.saldoCaja, 7000);
      expect(resumen.saldoBanco, 5000);
      expect(resumen.saldoTotal, 12000);
    });

    test('no cuenta los movimientos eliminados', () {
      final resumen = Resumen.de([
        mov(tipo: Tipo.entro, centavos: 10000),
        mov(
          tipo: Tipo.entro,
          centavos: 99999,
          eliminadoEn: DateTime(2026, 9, 16),
        ),
      ]);

      expect(resumen.saldoCaja, 10000);
    });

    test('entró/salió del mes ignora los meses anteriores', () {
      final ahora = DateTime(2026, 9, 16);
      final resumen = Resumen.de([
        mov(tipo: Tipo.entro, centavos: 10000, fecha: DateTime(2026, 9, 2)),
        mov(tipo: Tipo.salio, centavos: 4000, fecha: DateTime(2026, 9, 10)),
        mov(tipo: Tipo.entro, centavos: 77700, fecha: DateTime(2026, 8, 30)),
      ], ahora: ahora);

      expect(resumen.entroMes, 10000);
      expect(resumen.salioMes, 4000);
      // El de agosto igual suma al saldo, sólo no al total del mes.
      expect(resumen.saldoCaja, 83700);
    });

    test('sumar céntimos muchas veces no acumula error', () {
      // El caso que justifica guardar centavos enteros: 0.10 en double no es
      // exacto y 1000 sumas se van del entero redondo.
      final movimientos = List.generate(
        1000,
        (i) =>
            mov(tipo: Tipo.entro, centavos: 10, fecha: DateTime(2026, 9, 16)),
      );

      expect(Resumen.de(movimientos).saldoCaja, 10000); // S/ 100.00 exactos
    });
  });

  group('Series', () {
    test('la línea de saldo termina en el saldo actual', () {
      final ahora = DateTime(2026, 9, 16);
      final movimientos = [
        mov(tipo: Tipo.entro, centavos: 50000, fecha: DateTime(2026, 9, 1)),
        mov(tipo: Tipo.salio, centavos: 20000, fecha: DateTime(2026, 9, 10)),
      ];

      final puntos = Series.saldoDiario(movimientos, dias: 30, ahora: ahora);

      expect(puntos.length, 30);
      expect(puntos.last.centavos, 30000);
      expect(puntos.last.dia, DateTime(2026, 9, 16));
    });

    test('los egresos por categoría vienen de mayor a menor', () {
      final mes = DateTime(2026, 9, 16);
      final porciones = Series.egresosPorCategoria([
        mov(
          tipo: Tipo.salio,
          centavos: 5000,
          categoriaId: Categoria.servicios.id,
          fecha: mes,
        ),
        mov(
          tipo: Tipo.salio,
          centavos: 30000,
          categoriaId: Categoria.mercaderia.id,
          fecha: mes,
        ),
        mov(tipo: Tipo.entro, centavos: 99999, fecha: mes),
      ], mes: mes);

      expect(porciones.length, 2);
      expect(porciones.first.categoria.id, Categoria.mercaderia.id);
      expect(porciones.first.centavos, 30000);
    });
  });

  group('Categoria', () {
    test('un id desconocido cae en Otros en vez de reventar', () {
      expect(Categoria.porId('categoria_que_no_existe').id, 'otros_egresos');
    });

    test('cada tipo ofrece sólo sus categorías', () {
      expect(
        Categoria.de(Tipo.entro).every((c) => c.tipo == Tipo.entro),
        isTrue,
      );
      expect(
        Categoria.de(Tipo.salio).every((c) => c.tipo == Tipo.salio),
        isTrue,
      );
    });
  });

  group('Periodo', () {
    test('mes pasado en enero cae en diciembre del año anterior', () {
      final (desde, hasta) = Periodo.mesPasado.rango(DateTime(2027, 1, 10));
      expect(desde, DateTime(2026, 12, 1));
      expect(hasta, DateTime(2026, 12, 31));
    });

    test('la semana arranca el lunes', () {
      // 17/09/2026 es jueves.
      final (desde, hasta) = Periodo.semana.rango(DateTime(2026, 9, 17, 15));
      expect(desde, DateTime(2026, 9, 14));
      expect(hasta, DateTime(2026, 9, 17));
    });

    test('un lunes, la semana es sólo ese día', () {
      final (desde, hasta) = Periodo.semana.rango(DateTime(2026, 9, 14));
      expect(desde, hasta);
    });

    test('mes pasado sabe cuántos días tiene febrero', () {
      final (_, hasta) = Periodo.mesPasado.rango(DateTime(2028, 3, 5));
      expect(hasta, DateTime(2028, 2, 29)); // 2028 es bisiesto
    });
  });

  group('IGV', () {
    test('el total siempre es la base más el impuesto, al céntimo', () {
      // Lo que cuadra un libro: si base e IGV se redondearan por separado, la
      // suma se iría de un céntimo y el asiento no cerraría.
      for (final total in [11800, 100, 1, 333, 99999, 52864]) {
        final r = Igv.desagregar(total);
        expect(r.base + r.igv, total, reason: 'total $total');
      }
    });

    test('desagrega el 18% de un monto con impuesto adentro', () {
      final r = Igv.desagregar(11800); // S/ 118.00
      expect(r.base, 10000); // S/ 100.00
      expect(r.igv, 1800); //  S/  18.00
    });

    test('agregar y desagregar son ida y vuelta', () {
      expect(Igv.desagregar(Igv.agregar(10000)).base, 10000);
    });
  });

  group('Saldo inicial', () {
    test('el libro abre con el saldo del período, no en cero', () {
      final resumen = Resumen.de(
        [mov(tipo: Tipo.entro, centavos: 10000)],
        saldoInicialCaja: 43600,
        saldoInicialBanco: 218390,
      );

      expect(resumen.saldoCaja, 53600);
      expect(resumen.saldoBanco, 218390);
      expect(resumen.saldoTotal, 271990);
    });

    test('el saldo inicial no cuenta como movimiento del mes', () {
      final resumen = Resumen.de(const [], saldoInicialCaja: 43600);
      expect(resumen.entroMes, 0);
      expect(resumen.cantidadEntroMes, 0);
    });
  });

  group('Cuentas contables', () {
    test('toda cuenta que usa la app existe en el plan contable', () {
      // Si alguien escribe mal un código, el Formato 1.1 saldría con una
      // denominación vacía. Mejor que falle acá.
      for (final c in Categoria.todas) {
        expect(
          Pcge.instancia.existe(c.cuentaAsociada),
          isTrue,
          reason: '${c.etiqueta}: cuenta asociada ${c.cuentaAsociada}',
        );
        final resultado = c.cuentaResultado;
        if (resultado != null) {
          expect(
            Pcge.instancia.existe(resultado),
            isTrue,
            reason: '${c.etiqueta}: cuenta de resultado $resultado',
          );
        }
      }

      for (final cuenta in Cuenta.values) {
        expect(Pcge.instancia.existe(cuenta.codigoPcge), isTrue);
      }
    });

    test('las cuentas del efectivo son las del Excel', () {
      expect(Cuenta.caja.codigoPcge, '101');
      expect(Cuenta.banco.codigoPcge, '1041');
      expect(Pcge.instancia.denominacion('101'), 'Caja');
      expect(
        Pcge.instancia.denominacion('1041'),
        'Cuentas corrientes operativas',
      );
    });

    test('la ruta arma la jerarquía desde los propios códigos', () {
      expect(Pcge.instancia.ruta('70121'), contains('VENTAS'));
      expect(Pcge.instancia.ruta('70121'), endsWith('Terceros'));
    });

    test('vender lleva IGV; cobrar un fiado no', () {
      expect(Categoria.ventas.afectoIgv, isTrue);
      expect(Categoria.cobrosFiado.afectoIgv, isFalse);
      // Cobrar un fiado no genera venta nueva: sólo cancela lo ya anotado.
      expect(Categoria.cobrosFiado.cuentaResultado, isNull);
    });
  });

  group('Medios de pago', () {
    test('cada uno lleva su código de la Tabla 1 de SUNAT', () {
      expect(MedioPago.efectivo.codigoTabla1, '008');
      expect(MedioPago.deposito.codigoTabla1, '001');
      expect(MedioPago.transferencia.codigoTabla1, '003');
      expect(MedioPago.cheque.codigoTabla1, '007');
    });

    test('sólo el efectivo va a caja', () {
      for (final m in MedioPago.values) {
        expect(
          m.cuenta,
          m == MedioPago.efectivo ? Cuenta.caja : Cuenta.banco,
          reason: m.etiqueta,
        );
      }
    });

    test('un medio desconocido no tumba el historial', () {
      expect(MedioPago.desdeBd('lo_que_sea'), MedioPago.efectivo);
    });
  });
}
