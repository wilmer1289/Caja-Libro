import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/core/tema.dart';
import 'package:mi_caja/datos/repositorio/repositorio_demo.dart';
import 'package:mi_caja/dominio/almacen.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/mercaderia.dart';
import 'package:mi_caja/dominio/reglas_mercaderia.dart';
import 'package:mi_caja/estado/estado_caja.dart';
import 'package:mi_caja/ui/inventario/inventario_ventana.dart';
import 'package:provider/provider.dart';

Future<(EstadoCaja, Mercaderia)> _estadoConStock({
  int cantidad = 10,
  DateTime? fecha,
}) async {
  final estado = EstadoCaja(RepositorioDemo())..usuario = 'Responsable P5';
  final producto = await estado.guardarProducto(
    nombre: 'Arroz',
    codigo: 'P001',
  );
  await estado.registrarEnAlmacen(
    operacion: OperacionAlmacen.saldoInicial,
    mercaderiaId: producto.id,
    fecha: fecha ?? DateTime.now(),
    cantidad: Cantidad.de(cantidad),
    costoTotal: cantidad * 1000,
  );
  return (estado, producto);
}

Widget _aplicacion(EstadoCaja estado) => ChangeNotifierProvider.value(
  value: estado,
  child: MaterialApp(
    theme: construirTema(),
    home: Scaffold(body: InventarioVentana()),
  ),
);

Future<void> _abrirSeccion(WidgetTester tester, String etiqueta) async {
  await tester.tap(find.text(etiqueta).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('es_PE'));

  group('P5 · operaciones y conteo', () {
    testWidgets('devuelve una venta al costo original y muestra el ingreso', (
      tester,
    ) async {
      final (estado, producto) = await _estadoConStock();
      await estado.registrar(
        tipo: Tipo.entro,
        centavos: ReglasMercaderia.montoParaLineas(2000, conIgv: true),
        categoriaId: 'ventas',
        concepto: 'Venta de prueba',
        medio: MedioPago.yape,
        fecha: DateTime.now(),
        contraparte: 'Cliente de prueba',
        documentoContraparte: '12345678',
        lineas: [
          LineaNueva(
            mercaderiaId: producto.id,
            cantidad: Cantidad.de(1),
            importe: 2000,
          ),
        ],
      );
      expect(estado.stockDe(producto.id), Cantidad.de(9));
      await tester.pumpWidget(_aplicacion(estado));
      await _abrirSeccion(tester, 'Operaciones');
      await tester.tap(find.text('Nueva operación'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Devolución').last);
      await tester.pumpAndSettle();

      expect(find.text('Registrar devolución'), findsOneWidget);
      expect(find.text('Venta original'), findsOneWidget);
      await tester.tap(find.text('Venta original'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Arroz').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Cantidad (und)'),
        '1',
      );
      await tester.tap(find.text('Registrar').last);
      await tester.pumpAndSettle();

      expect(estado.stockDe(producto.id), Cantidad.de(10));
      expect(estado.kardex.saldo(producto.id).costo, 10000);
      expect(find.text('Devolución de un cliente'), findsOneWidget);
      expect(find.text('+1 und'), findsOneWidget);
      final exception = tester.takeException();
      expect(exception, isNull);
    });

    testWidgets('registra una merma al promedio y la muestra en operaciones', (
      tester,
    ) async {
      final (estado, producto) = await _estadoConStock();
      await tester.pumpWidget(_aplicacion(estado));
      await _abrirSeccion(tester, 'Operaciones');
      await tester.tap(find.text('Nueva operación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Merma o desmedro'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('P001 · Arroz').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Cantidad (und)'),
        '2',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Motivo'),
        'Daño en bodega',
      );
      await tester.tap(find.text('Registrar').last);
      await tester.pumpAndSettle();

      expect(estado.stockDe(producto.id), Cantidad.de(8));
      expect(estado.kardex.valorTotal(), 8000);
      expect(find.text('Merma'), findsOneWidget);
      expect(find.text('Daño en bodega'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ajusta el stock contado y abre el acta', (tester) async {
      final (estado, producto) = await _estadoConStock();
      await tester.pumpWidget(_aplicacion(estado));
      await _abrirSeccion(tester, 'Conteo');
      await tester.enterText(
        find.widgetWithText(TextField, 'Contado (und)'),
        '7',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Falta: 3 und'), findsOneWidget);

      await tester.tap(find.text('Confirmar conteo y generar acta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar y ajustar'));
      await tester.pumpAndSettle();

      expect(estado.stockDe(producto.id), Cantidad.de(7));
      expect(estado.kardex.valorTotal(), 7000);
      expect(find.text('ACTA DE CONTEO FÍSICO'), findsOneWidget);
      expect(find.text('Responsable P5'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cuenta el saldo al 31 de diciembre y genera un acta anual', (
      tester,
    ) async {
      final anio = DateTime.now().year - 1;
      final (estado, producto) = await _estadoConStock(
        fecha: DateTime(anio, 3, 1),
      );
      await estado.guardarProducto(
        id: producto.id,
        nombre: producto.nombre,
        codigo: producto.codigo,
        activo: false,
      );
      await tester.pumpWidget(_aplicacion(estado));
      await _abrirSeccion(tester, 'Conteo');
      await tester.tap(find.text('Conteo anual al 31 de diciembre'));
      await tester.pumpAndSettle();

      expect(find.text('Conteo anual de inventario'), findsOneWidget);
      expect(
        find.textContaining('Saldos del kardex al 31/12/$anio'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Contado (und)').last,
        '7',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar conteo anual y generar acta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar y generar acta'));
      await tester.pumpAndSettle();

      expect(
        estado.kardex.saldo(producto.id, al: DateTime(anio, 12, 31)).cantidad,
        Cantidad.de(7),
      );
      expect(estado.stockDe(producto.id), Cantidad.de(7));
      expect(find.text('ACTA DE CONTEO ANUAL DE INVENTARIO'), findsOneWidget);
      expect(find.textContaining('31/12/$anio'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el cierre muestra el mes y bloquea sus fechas', (
      tester,
    ) async {
      final (estado, _) = await _estadoConStock();
      await tester.pumpWidget(_aplicacion(estado));
      await tester.tap(find.text('Cerrar mes'));
      await tester.pumpAndSettle();

      final anterior = DateTime(DateTime.now().year, DateTime.now().month - 1);
      expect(find.textContaining('${anterior.year}'), findsWidgets);
      expect(find.text('Movimientos de inventario'), findsOneWidget);
      expect(
        find.textContaining('Valor del inventario al cierre'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cerrar período').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar período').last);
      await tester.pumpAndSettle();

      expect(estado.mesCerrado(anterior), isTrue);
      expect(find.textContaining('Se cerró'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
