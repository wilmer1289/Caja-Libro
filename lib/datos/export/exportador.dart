import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/formato.dart';
import '../../dominio/enums.dart';
import '../../dominio/libro_oficial.dart';
import '../../dominio/libro_diario.dart';

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

  static Future<String> guardarDiario(LibroDiario libro) async {
    final carpeta = await _carpeta();
    final archivo = File(p.join(carpeta.path, nombreDiario(libro)));
    await archivo.writeAsBytes(utf8.encode('\uFEFF${csvDiario(libro)}'));
    return archivo.path;
  }

  static String nombreDiario(LibroDiario libro) =>
      'LibroDiario_5-1_${_periodoArchivo(libro.desde)}.csv';

  /// Las columnas del Formato 5.1, como en la plantilla del curso. Las usan
  /// el CSV y el PDF.
  static const columnasDiario = [
    'NÚMERO CORRELATIVO DEL ASIENTO O CÓDIGO ÚNICO DE LA OPERACIÓN',
    'CÓDIGO PROPUESTO EN EL RVIE O RCE / CÓDIGO DE ANOTACIÓN DE REGISTRO (CAR)',
    'FECHA O PERÍODO DE LA OPERACIÓN',
    'GLOSA O DESCRIPCIÓN DE LA OPERACIÓN',
    'CÓDIGO DEL LIBRO O REGISTRO (TABLA 8)',
    'NÚMERO CORRELATIVO',
    'NÚMERO DEL DOCUMENTO SUSTENTATORIO',
    'CÓDIGO DE LA CUENTA CONTABLE',
    'DENOMINACIÓN DE LA CUENTA CONTABLE',
    'DEBE',
    'HABER',
  ];

  /// El CSV del Formato 5.1, con el mismo encabezado y las mismas columnas
  /// que la plantilla.
  ///
  /// La referencia va en sus tres columnas: código del libro (Tabla 8),
  /// número correlativo y documento sustentatorio. El correlativo queda en
  /// blanco: la app no lleva un Registro de Compras ni de Ventas de donde
  /// sacarlo, y en el ejemplo del Excel también va vacío. El importe va en la
  /// primera fila de cada cadena de cuentas; las hijas sólo llevan código y
  /// denominación.
  static String csvDiario(LibroDiario libro) {
    final lineas = <String>[];
    void fila(List<String> celdas) => lineas.add(celdas.map(_celda).join(_sep));

    // --- Encabezado del formato ---
    fila(const ['FORMATO 5.1: "LIBRO DIARIO"']);
    fila([
      'PERÍODO:',
      '${Formato.fecha(libro.desde)} al ${Formato.fecha(libro.hasta)}',
    ]);
    fila(['RUC:', libro.negocio.documento]);
    fila([
      'APELLIDOS Y NOMBRES, DENOMINACIÓN O RAZÓN SOCIAL:',
      libro.negocio.razonSocial,
    ]);
    fila(const []);
    fila(columnasDiario);

    for (final a in libro.asientos) {
      for (final etapa in a.etapas) {
        for (final linea in etapa.lineas) {
          for (var i = 0; i < linea.cadena.length; i++) {
            final cuenta = linea.cadena[i];
            final conImporte = i == 0;
            fila([
              a.numero,
              '',
              Formato.fecha(a.fecha),
              etapa.glosa,
              a.codigoLibro ?? '',
              '',
              a.documento ?? '',
              cuenta.codigo,
              cuenta.denominacion,
              conImporte ? _monto(linea.debe) : '',
              conImporte ? _monto(linea.haber) : '',
            ]);
          }
        }
      }
      fila([
        ...List.filled(8, ''),
        'TOTAL OPERACIÓN ${a.numero}',
        _monto(a.totalDebe),
        _monto(a.totalHaber),
      ]);
    }
    fila([
      ...List.filled(8, ''),
      'TOTAL PERÍODO',
      _monto(libro.totalDebe),
      _monto(libro.totalHaber),
    ]);
    return lineas.join('\r\n');
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
