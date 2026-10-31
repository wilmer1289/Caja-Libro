import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_caja/datos/ocr/lector_voucher.dart';
import 'package:mi_caja/dominio/lectura_voucher.dart';

/// Lo que la app entiende del texto de un voucher. Los textos son como los
/// devuelve el lector: una línea por renglón, con los saltos donde el banco
/// los pone.
void main() {
  group('montos', () {
    test('en soles, con miles y decimales de las dos formas', () {
      expect(LecturaVoucher.centavosDe('1,250.50'), 125050);
      expect(LecturaVoucher.centavosDe('1.250,50'), 125050);
      expect(LecturaVoucher.centavosDe('1,250'), 125000);
      expect(LecturaVoucher.centavosDe('50'), 5000);
      expect(LecturaVoucher.centavosDe('50.5'), 5050);
      expect(LecturaVoucher.centavosDe('52 864.00'), 5286400);
      expect(LecturaVoucher.centavosDe('abc'), isNull);
    });
  });

  test('un Yape: el monto grande, el nombre debajo, el N° aparte', () {
    final l = LecturaVoucher.de('''
¡Yapeaste!
S/ 1,250.50
Comercial Fernández E.I.R.L.
15 oct. 2026 - 10:38 a. m.
Nro. de operación
04512378
Comisión S/ 0.00''');
    expect(l.centavos, 125050);
    expect(l.fecha, DateTime(2026, 10, 15));
    expect(l.numeroOperacion, '04512378');
    expect(l.nombre, 'Comercial Fernández E.I.R.L.');
    expect(l.banco, 'Yape');
    expect(l.vacia, isFalse);
  });

  test('el voucher del BBVA de la hoja COBROS', () {
    final l = LecturaVoucher.de('''
Transferir
Operación exitosa
01 de diciembre de 2026, 10:38 h
Importe Transferido
S/ 52,864.00
Comisión S/0.00
ITF S/ 2.64
Cuenta independencia Libertad S.A.
*4455 BBVA
Número de cuenta de destino
004-808-112233445566-25
Tipo de operación
Transferencia
Número de operación
°0011
Cliente Fernández E.I.R.L.
DNI/RUC 20102030401
Concepto Mercaderías''');
    // Ni la comisión ni el ITF: el importe transferido.
    expect(l.centavos, 5286400);
    expect(l.fecha, DateTime(2026, 12, 1));
    expect(l.numeroOperacion, '0011');
    expect(l.nombre, 'Fernández E.I.R.L.');
    expect(l.banco, 'BBVA');
  });

  test('una constancia de transferencia con todo en la misma línea', () {
    final l = LecturaVoucher.de('''
Constancia de transferencia
Monto transferido: S/ 1,500.00
Fecha y hora: 15/10/2026 - 09:22
N° de operación: 00382716
Destinatario: Distribuidora Andina SAC
Cuenta destino: 191-12345678-0-12''');
    expect(l.centavos, 150000);
    expect(l.fecha, DateTime(2026, 10, 15));
    expect(l.numeroOperacion, '00382716');
    expect(l.nombre, 'Distribuidora Andina SAC');
  });

  test('un Plin, con el código de operación', () {
    final l = LecturaVoucher.de('''
¡Pago exitoso!
S/
35
Plineaste a
María Quispe
Código de operación: 7781203
14 oct 2026, 08:15 p. m.''');
    // "S/" y "35" vinieron en líneas distintas.
    expect(l.centavos, 3500);
    expect(l.numeroOperacion, '7781203');
    expect(l.nombre, 'María Quispe');
    expect(l.fecha, DateTime(2026, 10, 14));
    expect(l.banco, 'Plin');
  });

  test(
    'un voucher de dos columnas: primero los rótulos, después los datos',
    () {
      // Tal cual lo devolvió el lector de Windows con test/recursos/
      // voucher_prueba.png: se comió el "°" y dudó en la última letra.
      final l = LecturaVoucher.de('''
Constancia de transferencia
Banca por internet
OK
Operacion exitosa
Monto transferido
S/ 1,250.50
Fecha
N de operacion
Cliente
Banco de origen
Cuenta destino
Comision
15/10/2026 10:38
04512378
Fernandez E.I.R.I�
BCP
193-2468101-0-12
S/ 0.00''');
      expect(l.centavos, 125050);
      expect(l.fecha, DateTime(2026, 10, 15));
      expect(l.numeroOperacion, '04512378');
      expect(l.nombre, 'Fernandez E.I.R.I');
      expect(l.banco, 'BCP');
    },
  );

  test('lo que no se entiende queda vacío: nunca se inventa', () {
    final l = LecturaVoucher.de('Hola\nesto no es un voucher\n31/02/2026');
    expect(l.vacia, isTrue);
    expect(l.texto, contains('Hola'));
  });

  test('el lector de Windows lee un voucher de verdad, sin internet', () async {
    // Se dibuja un voucher con System.Drawing y se lo pasa al lector.
    final dir = await Directory.systemTemp.createTemp('mi_caja_ocr_prueba_');
    try {
      final png = '${dir.path}\\voucher.png';
      final dibujo = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'''
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 520, 520
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::White)
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$grande = New-Object System.Drawing.Font 'Segoe UI', 20, ([System.Drawing.FontStyle]::Bold)
$chica = New-Object System.Drawing.Font 'Segoe UI', 14
$y = 20
foreach ($l in @(@('Yapeaste', $grande), @('S/ 1,250.50', $grande), @('Comercial Andina SAC', $chica), @('15 oct. 2026 - 10:38 a. m.', $chica), @('Nro. de operacion', $chica), @('04512378', $chica))) {
  $g.DrawString($l[0], $l[1], [System.Drawing.Brushes]::Black, 30, $y); $y += 60
}
$bmp.Save($env:VOUCHER_PNG, [System.Drawing.Imaging.ImageFormat]::Png)
''',
        ],
        environment: {'VOUCHER_PNG': png},
      );
      expect(dibujo.exitCode, 0, reason: '${dibujo.stderr}');

      final texto = await LectorWindows().leer(
        await File(png).readAsBytes(),
        'png',
      );
      final l = LecturaVoucher.de(texto);
      expect(l.numeroOperacion, '04512378', reason: texto);
      expect(l.centavos, 125050, reason: texto);
      expect(l.fecha, DateTime(2026, 10, 15), reason: texto);
    } finally {
      await dir.delete(recursive: true);
    }
  }, skip: Platform.isWindows ? false : 'El lector de Windows sólo en Windows');
}
