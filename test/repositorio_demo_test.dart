import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/datos/repositorio/repositorio_demo.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/efectivo.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/jornada.dart';
import 'package:mi_caja/estado/estado_caja.dart';

/// La versión web (`RepositorioDemo`) arranca como un negocio que recién
/// empieza: sin datos, sin cajas, con el efectivo sin contar. Estas pruebas
/// cuidan que siga así, y que desde cero se pueda hacer todo el recorrido
/// con las mismas reglas que la app de verdad.
void main() {
  setUp(() => Categoria.registrarPropias(const []));

  test('arranca vacía, como el primer día', () async {
    final repo = RepositorioDemo();
    expect(await repo.listar(), isEmpty);
    expect(await repo.leerJornadas(), isEmpty);
    expect(await repo.leerFondo(), isNull);
    expect(await repo.leerCategoriasPropias(), isEmpty);
    final negocio = await repo.leerNegocio();
    expect(negocio.razonSocial, isEmpty);
    expect(negocio.completo, isFalse);
  });

  test('cada visita empieza de cero: nada queda de la anterior', () async {
    final primera = RepositorioDemo();
    await primera.contarFondo(
      conteo: const Conteo({10000: 1}),
      usuario: 'usuario',
    );
    expect(await RepositorioDemo().leerFondo(), isNull);
  });

  test('la app carga la demo vacía sin errores y pide los datos', () async {
    final estado = EstadoCaja(RepositorioDemo());
    await estado.cargar();

    expect(estado.error, isNull);
    expect(estado.vacio, isTrue);
    expect(estado.faltaPerfil, isTrue);
    expect(estado.cajaAbierta, isNull);
    expect(estado.fondo, isNull);
    expect(estado.efectivoNegocio, isNull);
  });

  test(
    'desde cero: contar, abrir la caja, cobrar en efectivo y cerrar',
    () async {
      final estado = EstadoCaja(RepositorioDemo());
      await estado.cargar();

      Future<void> cobrar(int centavos, MedioPago medio) => estado.registrar(
        tipo: Tipo.entro,
        centavos: centavos,
        categoriaId: 'ventas',
        concepto: 'Venta',
        medio: medio,
        fecha: DateTime.now(),
        detalleEfectivo: medio == MedioPago.efectivo
            ? DetalleEfectivo(
                entregado: Conteo.sugerir(centavos),
                vuelto: Conteo.vacio,
              )
            : null,
      );

      // Sin caja no hay efectivo; sin contar el efectivo no hay caja.
      await expectLater(
        cobrar(2000, MedioPago.efectivo),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        estado.abrirCaja(
          apertura: 10000,
          inicio: InicioCaja.primera,
          responsable: 'Ana',
          usuario: 'usuario',
        ),
        throwsA(isA<ArgumentError>()),
      );

      await estado.contarFondo(
        const Conteo({10000: 5, 5000: 10}),
        usuario: 'usuario',
      );
      await estado.abrirCaja(
        apertura: 30000,
        inicio: InicioCaja.primera,
        responsable: 'Ana',
        usuario: 'usuario',
      );
      await cobrar(2000, MedioPago.efectivo);
      await cobrar(5000, MedioPago.yape);

      final efectivo = estado.efectivoNegocio!;
      expect(efectivo.guardado, 70000);
      expect(efectivo.enCaja, 32000);
      expect(estado.cajaAbierta!.operaciones, 1);

      // Una segunda caja a la vez, no.
      await expectLater(
        estado.abrirCaja(
          apertura: 0,
          inicio: InicioCaja.otroMonto,
          responsable: 'Ana',
          usuario: 'usuario',
        ),
        throwsA(isA<ArgumentError>()),
      );

      final cerrada = await estado.cerrarCaja(
        conteo: const Conteo({10000: 3, 2000: 1}),
      );
      expect(cerrada.cuadra, isTrue);
      expect(estado.cajaAbierta, isNull);
      expect(estado.efectivoNegocio!.total, 102000);
    },
  );

  test('la demo cuida las mismas reglas que la app real', () async {
    final repo = RepositorioDemo();
    // Bancarización: desde S/ 2,000 no va en efectivo.
    await expectLater(
      repo.registrar(
        tipo: Tipo.entro,
        centavos: 200000,
        categoriaId: 'ventas',
        concepto: '',
        medio: MedioPago.efectivo,
        fecha: DateTime.now(),
      ),
      throwsA(isA<ArgumentError>()),
    );
    // Desde S/ 700 la boleta lleva cliente.
    await expectLater(
      repo.registrar(
        tipo: Tipo.entro,
        centavos: 70000,
        categoriaId: 'ventas',
        concepto: '',
        medio: MedioPago.yape,
        fecha: DateTime.now(),
      ),
      throwsA(isA<ArgumentError>()),
    );
    // Las boletas salen numeradas desde la 1.
    final primera = await repo.registrar(
      tipo: Tipo.entro,
      centavos: 1000,
      categoriaId: 'ventas',
      concepto: '',
      medio: MedioPago.yape,
      fecha: DateTime.now(),
    );
    expect(primera.numero, 1);
    expect(primera.numeroBoleta, 1);
  });
}
