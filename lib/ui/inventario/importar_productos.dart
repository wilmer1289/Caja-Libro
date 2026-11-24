import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xml/xml.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/almacen.dart';
import '../../dominio/importe.dart';
import '../../dominio/mercaderia.dart';
import '../../dominio/reglas_mercaderia.dart';
import '../../dominio/tablas_sunat.dart';
import '../../estado/estado_caja.dart';

/// Una fila leída del Excel y validada antes de tocar la base.
class FilaProductoImportada {
  FilaProductoImportada({
    required this.numeroFila,
    required this.codigo,
    required this.descripcion,
    required this.unidadCodigo,
    required this.cantidad,
    required this.costoUnitario,
    required this.costoTotal,
    required this.errores,
  });

  final int numeroFila;
  final String codigo;
  final String descripcion;
  final String? unidadCodigo;
  final int? cantidad;
  final int? costoUnitario;
  final int? costoTotal;
  final List<String> errores;

  bool get valida =>
      errores.isEmpty &&
      unidadCodigo != null &&
      cantidad != null &&
      costoUnitario != null &&
      costoTotal != null;
}

/// Lectura del primer libro/hoja XLSX. Las columnas son fijas:
/// A código, B descripción, C unidad (Tabla 6), D cantidad, E costo unitario.
class ImportadorProductosExcel {
  ImportadorProductosExcel._();

  static List<FilaProductoImportada> leer(
    Uint8List bytes,
    List<Mercaderia> existentes,
  ) {
    final archivo = ZipDecoder().decodeBytes(bytes);
    final hoja = _contenido(archivo, 'xl/worksheets/sheet1.xml');
    if (hoja == null) {
      throw const FormatException(
        'El Excel no contiene la primera hoja esperada (sheet1).',
      );
    }

    final compartidos = _leerCompartidos(archivo);
    final documento = XmlDocument.parse(utf8.decode(hoja));
    final filasXml = documento.findAllElements('row').toList();
    final codigos = <String>{};
    final nombres = <String>{};
    final resultado = <FilaProductoImportada>[];

    for (var i = 0; i < filasXml.length; i++) {
      final filaXml = filasXml[i];
      final numero = int.tryParse(filaXml.getAttribute('r') ?? '') ?? i + 1;
      final celdas = <int, String>{};
      for (final celda in filaXml.findAllElements('c')) {
        final referencia = celda.getAttribute('r') ?? '';
        final columna = _columna(referencia);
        if (columna < 1 || columna > 5) continue;
        celdas[columna] = _valorCelda(celda, compartidos).trim();
      }

      if (celdas.values.every((v) => v.isEmpty)) continue;
      if (numero == 1 && _esEncabezado(celdas)) continue;

      final codigoEscrito = celdas[1] ?? '';
      final descripcion = celdas[2] ?? '';
      final unidadEscrita = celdas[3] ?? '';
      final cantidadEscrita = celdas[4] ?? '';
      final costoEscrito = celdas[5] ?? '';
      final errores = <String>[];

      String codigo = codigoEscrito;
      try {
        codigo = ReglasMercaderia.validarCodigo(codigoEscrito);
      } on ArgumentError catch (e) {
        errores.add('${e.message}');
      }
      if (codigo.isNotEmpty) {
        if (existentes.any((p) => p.codigo == codigo)) {
          errores.add('El código ya existe en el catálogo.');
        }
        if (!codigos.add(codigo)) {
          errores.add('El código está repetido en el archivo.');
        }
      }

      String nombre = descripcion;
      try {
        nombre = ReglasMercaderia.validarNombre(descripcion);
      } on ArgumentError catch (e) {
        errores.add('${e.message}');
      }
      if (nombre.isNotEmpty) {
        final clave = Mercaderia.claveDe(nombre);
        if (existentes.any((p) => Mercaderia.claveDe(p.nombre) == clave)) {
          errores.add('La descripción ya existe en el catálogo.');
        }
        if (!nombres.add(clave)) {
          errores.add('La descripción está repetida en el archivo.');
        }
      }

      final unidad = _buscarUnidad(unidadEscrita);
      if (unidad == null) {
        errores.add(
          'La unidad debe corresponder a un código o nombre de la Tabla 6.',
        );
      }

      final cantidad = Cantidad.leer(cantidadEscrita);
      if (cantidad == null || cantidad <= 0) {
        errores.add(
          'La cantidad debe ser mayor que cero y tener hasta 3 decimales.',
        );
      } else if (unidad != null &&
          unidad.entera &&
          !Cantidad.esEntera(cantidad)) {
        errores.add('La unidad ${unidad.abreviatura} no admite decimales.');
      }

      final costoLimpio = costoEscrito.replaceAll(RegExp(r'[^0-9,.-]'), '');
      final costoUnitario = Importe.leer(costoLimpio);
      if (costoUnitario == null || costoUnitario <= 0) {
        errores.add('El costo unitario debe ser mayor que cero.');
      }

      int? costoTotal;
      if (cantidad != null &&
          cantidad > 0 &&
          costoUnitario != null &&
          costoUnitario > 0) {
        final total =
            (BigInt.from(cantidad) * BigInt.from(costoUnitario) +
                BigInt.from(Cantidad.escala ~/ 2)) ~/
            BigInt.from(Cantidad.escala);
        if (total <= BigInt.zero ||
            total > BigInt.from(Importe.maximoCentavos)) {
          errores.add('El costo total de la fila supera el límite permitido.');
        } else {
          costoTotal = total.toInt();
        }
      }

      resultado.add(
        FilaProductoImportada(
          numeroFila: numero,
          codigo: codigo,
          descripcion: nombre,
          unidadCodigo: unidad?.codigo,
          cantidad: cantidad,
          costoUnitario: costoUnitario,
          costoTotal: costoTotal,
          errores: errores,
        ),
      );
    }

    if (resultado.isEmpty) {
      throw const FormatException(
        'No se encontraron productos. Revisa las cinco columnas del Excel.',
      );
    }
    return resultado;
  }

  static Uint8List? _contenido(Archive archivo, String nombre) {
    ArchiveFile? entrada;
    for (final archivoZip in archivo.files) {
      if (archivoZip.name == nombre) {
        entrada = archivoZip;
        break;
      }
    }
    if (entrada == null) return null;
    return entrada.content;
  }

  static List<String> _leerCompartidos(Archive archivo) {
    final bytes = _contenido(archivo, 'xl/sharedStrings.xml');
    if (bytes == null) return const [];
    final doc = XmlDocument.parse(utf8.decode(bytes));
    return [
      for (final item in doc.findAllElements('si'))
        item.findAllElements('t').map((t) => t.innerText).join(),
    ];
  }

  static String _valorCelda(XmlElement celda, List<String> compartidos) {
    final tipo = celda.getAttribute('t');
    if (tipo == 'inlineStr') {
      return celda.findAllElements('t').map((t) => t.innerText).join();
    }
    final valor = celda.getElement('v')?.innerText ?? '';
    if (tipo == 's') {
      final indice = int.tryParse(valor);
      if (indice == null || indice < 0 || indice >= compartidos.length) {
        return '';
      }
      return compartidos[indice];
    }
    return valor;
  }

  static int _columna(String referencia) {
    final letras = RegExp(
      r'^[A-Z]+',
      caseSensitive: false,
    ).firstMatch(referencia)?.group(0)?.toUpperCase();
    if (letras == null) return 0;
    var numero = 0;
    for (final letra in letras.codeUnits) {
      numero = numero * 26 + letra - 64;
    }
    return numero;
  }

  static bool _esEncabezado(Map<int, String> celdas) {
    final primero = (celdas[1] ?? '').toLowerCase();
    final segundo = (celdas[2] ?? '').toLowerCase();
    return (primero.contains('código') ||
            primero.contains('codigo') ||
            primero == 'code') &&
        (segundo.contains('descrip') || segundo.contains('nombre'));
  }

  static UnidadMedida? _buscarUnidad(String escrita) {
    final texto = escrita.trim().toLowerCase();
    if (texto.isEmpty) return null;
    final soloNumero = RegExp(r'^\d{1,2}$').hasMatch(texto);
    final codigo = soloNumero
        ? texto.padLeft(2, '0')
        : RegExp(r'^(\d{2})').firstMatch(texto)?.group(1);
    for (final unidad in TablasSunat.unidades) {
      if (unidad.codigo == texto ||
          unidad.codigo == codigo ||
          unidad.abreviatura.toLowerCase() == texto ||
          unidad.descripcion.toLowerCase() == texto) {
        return unidad;
      }
    }
    return null;
  }
}

/// Ventana de selección, vista previa de errores y guardado de productos más
/// su inventario inicial. No se guarda ninguna fila antes de mostrar la vista
/// previa al usuario.
class ImportarProductosDialogo extends StatefulWidget {
  const ImportarProductosDialogo({super.key});

  static Future<void> abrir(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Tokens.cromo.withValues(alpha: .38),
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: const ImportarProductosDialogo(),
      ),
    ),
  );

  @override
  State<ImportarProductosDialogo> createState() =>
      _ImportarProductosDialogoState();
}

class _ImportarProductosDialogoState extends State<ImportarProductosDialogo> {
  List<FilaProductoImportada> _filas = const [];
  String? _nombreArchivo;
  String? _error;
  String? _resultado;
  bool _leyendo = false;
  bool _guardando = false;

  List<FilaProductoImportada> get _validas =>
      _filas.where((f) => f.valida).toList();

  List<FilaProductoImportada> get _conErrores =>
      _filas.where((f) => !f.valida).toList();

  Future<void> _elegirArchivo() async {
    final productosExistentes = context.read<EstadoCaja>().productos;
    setState(() {
      _leyendo = true;
      _error = null;
      _resultado = null;
      _filas = const [];
      _nombreArchivo = null;
    });
    try {
      final archivo = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Libro de Excel',
            extensions: ['xlsx'],
            mimeTypes: [
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            webWildCards: ['.xlsx'],
          ),
        ],
        confirmButtonText: 'Abrir Excel',
      );
      if (archivo == null) {
        if (mounted) setState(() => _leyendo = false);
        return;
      }
      final bytes = await archivo.readAsBytes();
      final filas = ImportadorProductosExcel.leer(bytes, productosExistentes);
      if (mounted) {
        setState(() {
          _nombreArchivo = archivo.name;
          _filas = filas;
        });
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo leer el Excel. $e');
    } finally {
      if (mounted) setState(() => _leyendo = false);
    }
  }

  Future<void> _importarValidas() async {
    if (_guardando || _validas.isEmpty) return;
    final estado = context.read<EstadoCaja>();
    if (estado.mesCerrado(DateTime.now())) {
      setState(() {
        _error = 'El mes actual está cerrado. No se puede registrar el inventario inicial.';
      });
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
      _resultado = null;
    });

    var guardadas = 0;
    final fallidas = <String>[];
    for (final fila in _validas) {
      try {
        final producto = await estado.guardarProducto(
          nombre: fila.descripcion,
          codigo: fila.codigo,
          unidad: fila.unidadCodigo!,
        );
        await estado.registrarEnAlmacen(
          operacion: OperacionAlmacen.saldoInicial,
          mercaderiaId: producto.id,
          fecha: DateTime.now(),
          cantidad: fila.cantidad!,
          costoTotal: fila.costoTotal!,
        );
        guardadas++;
      } catch (e) {
        fallidas.add('Fila ${fila.numeroFila}: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _guardando = false;
      _resultado =
          '$guardadas producto(s) importado(s) con inventario inicial.'
          '${fallidas.isEmpty ? '' : '\n${fallidas.join('\n')}'}';
      if (fallidas.isNotEmpty) {
        _error = 'Algunas filas no se pudieron guardar. Revisa el detalle.';
      }
    });
    if (guardadas > 0 && fallidas.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.superficie,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.upload_file_outlined,
                  color: Tokens.marcaOscura,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Importar productos desde Excel',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Tokens.texto,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _guardando
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Tokens.borde),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Columnas fijas: A código · B descripción · C unidad (Tabla 6) · D cantidad · E costo unitario. La primera fila puede contener encabezados.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Tokens.texto2,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _leyendo || _guardando ? null : _elegirArchivo,
                    icon: _leyendo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open_outlined, size: 18),
                    label: Text(_nombreArchivo ?? 'Elegir archivo .xlsx'),
                  ),
                ),
                if (_filas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _ContadorPreview(
                        texto: '${_filas.length} filas',
                        color: Tokens.texto2,
                      ),
                      _ContadorPreview(
                        texto: '${_validas.length} válidas',
                        color: Tokens.entro,
                      ),
                      _ContadorPreview(
                        texto: '${_conErrores.length} con errores',
                        color: _conErrores.isEmpty
                            ? Tokens.texto2
                            : Tokens.salio,
                      ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Tokens.salio,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_resultado != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _resultado!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Tokens.texto2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Tokens.borde),
          Expanded(
            child: _filas.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Selecciona un Excel para revisar sus productos antes de guardarlos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Tokens.texto2),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: _filas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
                    itemBuilder: (context, i) {
                      final fila = _filas[i];
                      final valida = fila.valida;
                      return Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: valida ? Tokens.fondo : Tokens.salioSuave,
                          borderRadius: BorderRadius.circular(Tokens.radio),
                          border: Border.all(
                            color: valida
                                ? Tokens.borde
                                : Tokens.salio.withValues(alpha: .25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  valida
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  size: 17,
                                  color: valida ? Tokens.entro : Tokens.salio,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    'Fila ${fila.numeroFila} · ${fila.codigo} · ${fila.descripcion}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Tokens.texto,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${fila.unidadCodigo ?? 'Unidad inválida'} · '
                              '${fila.cantidad == null ? 'Cantidad inválida' : Cantidad.texto(fila.cantidad!)} · '
                              '${fila.costoUnitario == null ? 'Costo inválido' : Formato.soles(fila.costoUnitario! / 100)} por unidad',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Tokens.texto2,
                              ),
                            ),
                            if (fila.errores.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              for (final error in fila.errores)
                                Text(
                                  '• $error',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Tokens.salio,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1, color: Tokens.borde),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 11, 18, 14),
            child: Row(
              children: [
                const Spacer(),
                OutlinedButton(
                  onPressed: _guardando
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _guardando || _validas.isEmpty
                      ? null
                      : _importarValidas,
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_alt_rounded, size: 18),
                  label: Text('Importar ${_validas.length} válidas'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContadorPreview extends StatelessWidget {
  const _ContadorPreview({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
