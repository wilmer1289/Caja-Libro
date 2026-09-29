import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/formato.dart';
import '../../dominio/enums.dart';
import '../../dominio/libro_oficial.dart';

/// Saca el formato oficial a un archivo que se abre en Excel.
///
/// Es CSV y no un .xlsx armado a mano: el contador va a querer retocarlo de
/// todos modos —anchos, bordes, su membrete— y un CSV entra en su plantilla sin
/// pelear. Lo que la app garantiza son los datos y el cuadre; la presentación
/// ya está en pantalla.
///
/// Dos detalles que deciden si Excel lo abre bien en una máquina peruana:
/// el separador es **punto y coma** (con coma, Excel en español mete todo en
/// una sola columna) y el archivo lleva **BOM** (sin él, "PERÍODO" se ve como
/// "PERÃ?ODO").
class Exportador {
  static const _sep = ';';

  /// Escribe el formato y devuelve la ruta del archivo.
  static Future<String> guardarFormato(LibroOficial libro) async {
    final carpeta = await _carpeta();
    final nombre =
        'Formato ${libro.cuenta == Cuenta.caja ? '1.1' : '1.2'} '
        '- ${_periodoArchivo(libro.desde)}.csv';
    final archivo = File(p.join(carpeta.path, nombre));

    await archivo.writeAsString(
      // El BOM va como texto, no como bytes sueltos: así `writeAsString` lo
      // deja tal cual al frente del contenido.
      '﻿${csv(libro)}',
      encoding: utf8,
    );
    return archivo.path;
  }

  /// La carpeta donde queda el archivo: la misma donde vive la base, así todo
  /// lo de la app está en un solo sitio y el usuario sabe dónde buscar.
  static Future<Directory> _carpeta() async {
    final documentos = await getApplicationDocumentsDirectory();
    final carpeta = Directory(p.join(documentos.path, 'Mi Caja'));
    if (!await carpeta.exists()) await carpeta.create(recursive: true);
    return carpeta;
  }

  static String _periodoArchivo(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// El contenido del archivo. Separado de la escritura para poder probarlo
  /// sin tocar el disco.
  static String csv(LibroOficial libro) {
    final esCaja = libro.cuenta == Cuenta.caja;
    final lineas = <String>[];

    void fila(List<String> celdas) => lineas.add(celdas.map(_celda).join(_sep));

    // --- Encabezado del formato ---
    fila([libro.titulo]);
    fila(['PERÍODO:', _periodo(libro)]);
    fila(['RUC:', libro.negocio.documento]);
    fila([
      'APELLIDOS Y NOMBRES, DENOMINACIÓN O RAZÓN SOCIAL:',
      libro.negocio.razonSocial,
    ]);
    if (!esCaja) {
      fila(['ENTIDAD FINANCIERA:', libro.negocio.entidadFinanciera]);
      fila(['CÓDIGO DE LA CUENTA CORRIENTE:', libro.negocio.cuentaCorriente]);
    }
    fila([libro.cuenta.codigoPcge, libro.rotuloCuenta]);
    fila(const []);

    // --- Cabecera de la tabla ---
    fila(
      esCaja
          ? const [
              'N° DE OPER.',
              'FECHA DE LA OPER.',
              'DESCRIPCIÓN DE LA OPERACIÓN',
              'CÓDIGO',
              'DENOMINACIÓN',
              'DEUDOR (+)',
              'ACREEDOR (-)',
            ]
          : const [
              'N° CORREL. DE OPER.',
              'FECHA DE LA OPERAC.',
              'MEDIO DE PAGO (TABLA 1)',
              'DESCRIPCIÓN DE LA OPERACIÓN',
              'APELLIDOS Y NOMBRES, DENOMINACIÓN O RAZÓN SOCIAL',
              'N° DE TRANSACC. BANCARIA',
              'CÓD.',
              'DENOMINACIÓN',
              'DEUDOR (+)',
              'ACREEDOR (-)',
            ],
    );

    for (final f in libro.filas) {
      final comunes = [
        f.numero?.toString() ?? '',
        f.fecha == null ? '' : Formato.fecha(f.fecha!),
      ];
      final cuenta = [f.codigoCuenta ?? '', f.denominacion ?? ''];
      final montos = [_monto(f.deudor), _monto(f.acreedor)];

      fila(
        esCaja
            ? [...comunes, f.descripcion, ...cuenta, ...montos]
            : [
                ...comunes,
                f.medioTabla1 ?? '',
                f.descripcion,
                f.contraparte ?? '',
                f.numeroTransaccion ?? '',
                ...cuenta,
                ...montos,
              ],
      );
    }

    // --- El cuadre ---
    final huecos = List.filled(esCaja ? 4 : 7, '');
    fila([
      ...huecos,
      'SUBTOTAL',
      _monto(libro.subtotalDeudor),
      _monto(libro.subtotalAcreedor),
    ]);
    fila([
      ...huecos,
      'SALDO FINAL',
      _monto(libro.saldoFinalDeudor),
      _monto(libro.saldoFinalAcreedor),
    ]);
    fila([
      ...huecos,
      'TOTALES',
      _monto(libro.totalDeudor),
      _monto(libro.totalAcreedor),
    ]);

    // --- Los asientos resumen, como los pone el Excel debajo del formato ---
    for (final asiento in libro.asientos) {
      fila(const []);
      fila([asiento.titulo]);
      fila([...huecos.take(3), 'CÓD.', 'DENOMINACIÓN', 'DEBE', 'HABER']);
      for (final l in asiento.lineas) {
        fila([
          ...huecos.take(3),
          l.codigo,
          l.denominacion,
          _monto(l.debe),
          _monto(l.haber),
        ]);
      }
      fila([
        ...huecos.take(4),
        'TOTAL',
        _monto(asiento.totalDebe),
        _monto(asiento.totalHaber),
      ]);
    }

    return lineas.join('\r\n');
  }

  static String _periodo(LibroOficial libro) =>
      Formato.capitalizar(Formato.mes(libro.desde)).toUpperCase();

  /// Los montos van como número plano —sin "S/" ni separador de miles— para
  /// que Excel los reciba como números y se puedan sumar. Un cero se deja en
  /// blanco, igual que en la hoja del curso.
  static String _monto(int centavos) =>
      centavos == 0 ? '' : (centavos / 100).toStringAsFixed(2);

  /// Entrecomilla lo que haga falta. Una razón social con punto y coma
  /// adentro rompería las columnas si no.
  static String _celda(String valor) {
    // Una descripción escrita por el usuario nunca debe ejecutarse como fórmula.
    if (RegExp(r'^\s*[=+@-]').hasMatch(valor) &&
        !RegExp(r'^-?\d+(\.\d+)?$').hasMatch(valor)) {
      valor = "'$valor";
    }
    if (!valor.contains(_sep) &&
        !valor.contains('"') &&
        !valor.contains('\n') &&
        !valor.contains('\r')) {
      return valor;
    }
    return '"${valor.replaceAll('"', '""')}"';
  }
}
