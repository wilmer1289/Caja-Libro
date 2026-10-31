import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_caja/datos/export/exportador.dart';
import 'package:mi_caja/datos/export/exportador_pdf.dart';
import 'package:mi_caja/dominio/categoria.dart';
import 'package:mi_caja/dominio/enums.dart';
import 'package:mi_caja/dominio/igv.dart';
import 'package:mi_caja/dominio/inventario.dart';
import 'package:mi_caja/dominio/libro_diario.dart';
import 'package:mi_caja/dominio/movimiento.dart';
import 'package:mi_caja/dominio/negocio.dart';
import 'package:mi_caja/dominio/pcge.dart';

/// La exportación del Libro Diario (Formato 5.1): el CSV y el PDF llevan el
/// encabezado y las 11 columnas de la plantilla del curso, con los 4 ejemplos
/// de la exposición.
void main() {
  setUpAll(() async {
    // Los PDF cargan la tipografía de los assets: hace falta el enlace.
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_PE');
    Pcge.cargarDeTexto(File('assets/pcge.json').readAsStringSync());
  });

  setUp(() => Categoria.registrarPropias(const []));

  final negocio = Negocio(
    razonSocial: 'LIBERTAD SA',
    documento: '11902816511',
    inicioPeriodo: DateTime(2026, 10, 1),
  );

  Movimiento mov(
    String id,
    int numero,
    Tipo tipo,
    int centavos,
    String categoria, {
    int? numeroBoleta,
  }) {
    final cat = Categoria.porId(categoria);
    final cuando = DateTime(2026, 10, 15, 10);
    return Movimiento(
      id: id,
      numero: numero,
      tipo: tipo,
      centavos: centavos,
      categoriaId: categoria,
      concepto: '',
      medio: MedioPago.efectivo,
      fecha: cuando,
      creadoEn: cuando,
      actualizadoEn: cuando,
      cuentaAsociada: cat.cuentaAsociada,
      igvCentavos: cat.afectoIgv ? Igv.desagregar(centavos).igv : 0,
      numeroBoleta: numeroBoleta,
      sync: EstadoSync.local,
    );
  }

  /// Los 4 ejemplos de la exposición: compra, venta, alquiler y luz.
  LibroDiario ejemplos({Negocio? de}) => LibroDiario.armar(
    negocio: de ?? negocio,
    movimientos: [
      mov('c', 1, Tipo.salio, 118000, 'mercaderia'),
      mov('v', 2, Tipo.entro, 236000, 'ventas', numeroBoleta: 12),
      mov('a', 3, Tipo.salio, 94400, 'alquiler'),
      mov('l', 4, Tipo.salio, 17700, 'luz'),
    ],
    desde: DateTime(2026, 10, 1),
    hasta: DateTime(2026, 10, 31),
    mercaderia: (m) =>
        const DatoMercaderia(id: 'tela', nombre: 'tela', costoCentavos: 100000),
  );

  List<List<String>> filas(String csv) => [
    for (final linea in csv.split('\r\n')) linea.split(';'),
  ];

  group('el CSV del Formato 5.1', () {
    test('lleva el encabezado de la plantilla', () {
      final f = filas(Exportador.csvDiario(ejemplos()));

      expect(f[0].single, contains('FORMATO 5.1'));
      expect(f[1], ['PERÍODO:', '01/10/2026 al 31/10/2026']);
      expect(f[2], ['RUC:', '11902816511']);
      expect(f[3], [
        'APELLIDOS Y NOMBRES, DENOMINACIÓN O RAZÓN SOCIAL:',
        'LIBERTAD SA',
      ]);
    });

    test('usa punto y coma y las 11 columnas, con la referencia en tres', () {
      final f = filas(Exportador.csvDiario(ejemplos()));
      final cabecera = f[5];

      expect(cabecera, Exportador.columnasDiario);
      expect(cabecera.length, 11);
      expect(cabecera.sublist(4, 7), [
        'CÓDIGO DEL LIBRO O REGISTRO (TABLA 8)',
        'NÚMERO CORRELATIVO',
        'NÚMERO DEL DOCUMENTO SUSTENTATORIO',
      ]);
      // Todas las filas de datos tienen las 11 columnas.
      for (final fila in f.skip(6)) {
        expect(fila.length, 11, reason: fila.join(';'));
      }
    });

    test('la compra lleva el código de libro 08 y el importe arriba', () {
      final f = filas(Exportador.csvDiario(ejemplos()));
      final compra = f.where((x) => x.first == '001').toList();

      // 60 › 601 › 6011: el importe va en la fila de 2 dígitos.
      final cadena = compra.take(3).toList();
      expect(cadena.map((x) => x[7]), ['60', '601', '6011']);
      expect(cadena.map((x) => x[9]), ['1000.00', '', '']);
      expect(compra.first[4], '08');
      // El correlativo de la referencia queda en blanco, como en el Excel:
      // no es el número del asiento.
      expect(compra.first[5], '');
      expect(compra.first[3], 'Por la compra de tela');
    });

    test('la venta lleva su boleta como documento sustentatorio', () {
      final f = filas(Exportador.csvDiario(ejemplos()));
      final venta = f.firstWhere((x) => x.first == '002');
      expect(venta[6], 'B001-00000012');
      expect(venta[4], '');
    });

    test('cierra con el total del período, Debe igual a Haber', () {
      final f = filas(Exportador.csvDiario(ejemplos()));
      final total = f.last;
      expect(total[8], 'TOTAL PERÍODO');
      // 3,360 + 5,720 + 2,688 + 504.
      expect(total[9], '12272.00');
      expect(total[10], '12272.00');
      expect(
        f.where((x) => x.length > 8 && x[8].startsWith('TOTAL OPERACIÓN')),
        hasLength(4),
      );
    });

    test('un texto que empieza con "=" no se vuelve fórmula en Excel', () {
      final csv = Exportador.csvDiario(
        ejemplos(
          de: Negocio(
            razonSocial: '=HYPERLINK("x")',
            documento: '11902816511',
            inicioPeriodo: DateTime(2026, 10, 1),
          ),
        ),
      );
      final razon = csv.split('\r\n')[3];
      expect(razon, isNot(contains(';=')));
      expect(razon, contains("'="));
    });
  });

  test('el PDF del Formato 5.1 se arma con los 4 ejemplos', () async {
    final bytes = await ExportadorPdf.diario(ejemplos());
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(
      ExportadorPdf.nombreDiario(ejemplos()),
      'LibroDiario_5-1_2026-10.pdf',
    );
  });
}
