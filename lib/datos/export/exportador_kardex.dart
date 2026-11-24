import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../dominio/almacen.dart';
import '../../dominio/registro_inventario.dart';

/// Los formatos 13.1 y 12.1 en CSV, para que el contador siga trabajando el
/// dato en Excel.
///
/// Igual que el Formato 1.1: punto y coma como separador y BOM al inicio,
/// para que Excel en español los abra en columnas y con las tildes bien.
/// Los números van planos (sin separador de miles) para que se puedan sumar.
class ExportadorKardex {
  static const _sep = ';';

  /// El 13.1 de uno o varios productos, uno debajo del otro.
  static String csv131(List<RegistroInventario> registros) {
    final lineas = <String>[];
    void fila(List<String> celdas) => lineas.add(celdas.map(_celda).join(_sep));

    for (final r in registros) {
      if (lineas.isNotEmpty) fila(const []);
      fila([RegistroInventario.titulo131]);
      for (final (rotulo, valor) in r.encabezado()) {
        fila(['$rotulo:', valor]);
      }
      fila(const []);
      fila(const [
        'DOCUMENTO DE TRASLADO, COMPROBANTE DE PAGO, DOCUMENTO INTERNO O SIMILAR',
        '',
        '',
        '',
        'TIPO DE OPERACIÓN (TABLA 12)',
        'ENTRADAS',
        '',
        '',
        'SALIDAS',
        '',
        '',
        'SALDO FINAL',
        '',
        '',
      ]);
      fila(const [
        'FECHA',
        'TIPO (TABLA 10)',
        'SERIE',
        'NÚMERO',
        '',
        'CANTIDAD',
        'COSTO UNITARIO',
        'COSTO TOTAL',
        'CANTIDAD',
        'COSTO UNITARIO',
        'COSTO TOTAL',
        'CANTIDAD',
        'COSTO UNITARIO',
        'COSTO TOTAL',
      ]);
      for (final f in r.filas) {
        fila([
          _fecha(f.fecha),
          f.tipoDocumento,
          f.serie,
          f.numero,
          f.operacion,
          _cantidad(f.entradaCantidad),
          RegistroInventario.unitario(f.entradaUnitario),
          _monto(f.entradaCosto),
          _cantidad(f.salidaCantidad),
          RegistroInventario.unitario(f.salidaUnitario),
          _monto(f.salidaCosto),
          _cantidad(f.saldoCantidad),
          RegistroInventario.unitario(f.saldoUnitario),
          _monto(f.saldoCosto),
        ]);
      }
      fila([
        '',
        '',
        '',
        '',
        'TOTALES',
        _cantidad(r.entradasCantidad),
        '',
        _monto(r.entradasCosto),
        _cantidad(r.salidasCantidad),
        '',
        _monto(r.salidasCosto),
        _cantidad(r.saldoFinalCantidad),
        '',
        _monto(r.saldoFinalCosto),
      ]);
    }
    return lineas.join('\r\n');
  }

  /// El 12.1: las mismas filas, sólo en unidades.
  static String csv121(List<RegistroInventario> registros) {
    final lineas = <String>[];
    void fila(List<String> celdas) => lineas.add(celdas.map(_celda).join(_sep));

    for (final r in registros) {
      if (lineas.isNotEmpty) fila(const []);
      fila([RegistroInventario.titulo121]);
      for (final (rotulo, valor) in r.encabezado(valorizado: false)) {
        fila(['$rotulo:', valor]);
      }
      fila(const []);
      fila(const [
        'FECHA',
        'TIPO (TABLA 10)',
        'SERIE',
        'NÚMERO',
        'TIPO DE OPERACIÓN (TABLA 12)',
        'ENTRADAS',
        'SALIDAS',
        'SALDO FINAL',
      ]);
      for (final f in r.filas) {
        fila([
          _fecha(f.fecha),
          f.tipoDocumento,
          f.serie,
          f.numero,
          f.operacion,
          _cantidad(f.entradaCantidad),
          _cantidad(f.salidaCantidad),
          _cantidad(f.saldoCantidad),
        ]);
      }
      fila([
        '',
        '',
        '',
        '',
        'TOTALES',
        _cantidad(r.entradasCantidad),
        _cantidad(r.salidasCantidad),
        _cantidad(r.saldoFinalCantidad),
      ]);
    }
    return lineas.join('\r\n');
  }

  /// "Formato 13.1 - POSA 001 - 2026-10.csv", o "Todos" si son varios.
  static String nombre(
    String formato,
    List<RegistroInventario> registros, {
    String extension = 'csv',
  }) {
    final r = registros.first;
    final quien = registros.length == 1
        ? r.producto.codigo.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        : 'Todos los productos';
    final periodo =
        '${r.desde.year}-${r.desde.month.toString().padLeft(2, '0')}';
    return 'Formato $formato - $quien - $periodo.$extension';
  }

  /// Escribe el archivo en Documentos\Mi Caja y devuelve la ruta.
  static Future<String> guardar(String contenido, String nombre) async {
    final documentos = await getApplicationDocumentsDirectory();
    final carpeta = Directory(p.join(documentos.path, 'Mi Caja'));
    if (!await carpeta.exists()) await carpeta.create(recursive: true);
    final archivo = File(p.join(carpeta.path, nombre));
    await archivo.writeAsBytes(utf8.encode('﻿$contenido'));
    return archivo.path;
  }

  static String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Las cantidades, planas y con punto decimal: 1600, 2.5.
  static String _cantidad(int? milesimas) {
    if (milesimas == null) return '';
    return Cantidad.texto(milesimas).replaceAll(',', '');
  }

  static String _monto(int? centavos) =>
      centavos == null ? '' : (centavos / 100).toStringAsFixed(2);

  static String _celda(String valor) {
    // Un texto escrito por el usuario nunca debe ejecutarse como fórmula.
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
