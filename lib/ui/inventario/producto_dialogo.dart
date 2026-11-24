import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/tema.dart';
import '../../dominio/almacen.dart';
import '../../dominio/importe.dart';
import '../../dominio/mercaderia.dart';
import '../../dominio/reglas_mercaderia.dart';
import '../../dominio/tablas_sunat.dart';
import '../../estado/estado_caja.dart';

/// Alta y edición del catálogo de productos. Usa las tablas SUNAT que ya
/// forman parte de P2; el stock y el costo no se escriben aquí porque salen
/// del kardex.
class ProductoDialogo extends StatefulWidget {
  const ProductoDialogo({super.key, this.producto});

  final Mercaderia? producto;

  static Future<Mercaderia?> abrir(
    BuildContext context, {
    Mercaderia? producto,
  }) {
    final movil = MediaQuery.sizeOf(context).width < 600;
    return showDialog<Mercaderia>(
      context: context,
      barrierColor: Tokens.cromo.withValues(alpha: .38),
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.all(movil ? 10 : 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
          child: ProductoDialogo(producto: producto),
        ),
      ),
    );
  }

  @override
  State<ProductoDialogo> createState() => _ProductoDialogoState();
}

class _ProductoDialogoState extends State<ProductoDialogo> {
  final _nombre = TextEditingController();
  final _codigo = TextEditingController();
  final _stockMinimo = TextEditingController();
  final _precio = TextEditingController();
  final _factorCompra = TextEditingController();

  late String _tipoExistencia;
  late String _unidad;
  late String _unidadFactura;
  String? _unidadCompra;
  bool _activo = true;
  bool _intentoGuardar = false;
  bool _guardando = false;
  String? _errorGeneral;

  bool get _tieneMovimientos {
    final producto = widget.producto;
    if (producto == null) return false;
    return context.read<EstadoCaja>().tieneMovimientosAlmacen(producto.id);
  }

  @override
  void initState() {
    super.initState();
    final estado = context.read<EstadoCaja>();
    final p = widget.producto;
    _nombre.text = p?.nombre ?? '';
    _codigo.text = p?.codigo.isNotEmpty == true
        ? p!.codigo
        : ReglasMercaderia.codigoSugerido(estado.productos);
    _stockMinimo.text = Cantidad.texto(p?.stockMinimo ?? 0);
    _precio.text = p?.precioSugerido == null
        ? ''
        : (p!.precioSugerido! / 100).toStringAsFixed(2);
    _tipoExistencia = p?.tipoExistencia ?? TablasSunat.mercaderia;
    _unidad = p?.unidad ?? TablasSunat.unidadesSueltas;
    _unidadCompra = p?.unidadCompra;
    _factorCompra.text = p?.factorCompra == null
        ? ''
        : Cantidad.texto(p!.factorCompra!);
    _unidadFactura =
        p?.codigoUnidadFactura ?? TablasSunat.unidadFacturaDe(_unidad);
    _activo = p?.activo ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _codigo.dispose();
    _stockMinimo.dispose();
    _precio.dispose();
    _factorCompra.dispose();
    super.dispose();
  }

  String? get _errorNombre {
    if (!_intentoGuardar) return null;
    final nombre = Mercaderia.limpiarNombre(_nombre.text);
    if (nombre.isEmpty) return 'Escribe la descripción del producto.';
    if (nombre.length > ReglasMercaderia.largoMaximo) {
      return 'Usa ${ReglasMercaderia.largoMaximo} caracteres o menos.';
    }
    final clave = Mercaderia.claveDe(nombre);
    final repetido = context.read<EstadoCaja>().productos.any(
      (m) =>
          m.id != widget.producto?.id && Mercaderia.claveDe(m.nombre) == clave,
    );
    return repetido ? 'Ya existe un producto con esa descripción.' : null;
  }

  String? get _errorCodigo {
    if (!_intentoGuardar) return null;
    try {
      final codigo = ReglasMercaderia.validarCodigo(_codigo.text);
      final repetido = context.read<EstadoCaja>().productos.any(
        (m) => m.id != widget.producto?.id && m.codigo == codigo,
      );
      return repetido ? 'Ya existe un producto con ese código.' : null;
    } on ArgumentError catch (e) {
      return '${e.message}';
    }
  }

  String? get _errorStockMinimo {
    if (!_intentoGuardar) return null;
    final cantidad = Cantidad.leer(_stockMinimo.text);
    if (cantidad == null) return 'Escribe un stock mínimo válido.';
    if (cantidad < 0) return 'El stock mínimo no puede ser negativo.';
    if (TablasSunat.unidadEntera(_unidad) && !Cantidad.esEntera(cantidad)) {
      return 'Esta unidad se controla con cantidades enteras.';
    }
    return null;
  }

  String? get _errorPrecio {
    if (!_intentoGuardar || _precio.text.trim().isEmpty) return null;
    final precio = Importe.leer(_precio.text);
    return precio == null || precio <= 0
        ? 'Escribe un precio mayor que cero.'
        : null;
  }

  String? get _errorFactor {
    if (!_intentoGuardar || _unidadCompra == null) return null;
    final factor = Cantidad.leer(_factorCompra.text);
    if (factor == null || factor <= 0) {
      return 'Escribe cuánto trae cada ${TablasSunat.unidad(_unidadCompra!)!.abreviatura}.';
    }
    if (TablasSunat.unidadEntera(_unidad) && !Cantidad.esEntera(factor)) {
      return 'El factor debe ser entero para esta unidad de stock.';
    }
    return null;
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _intentoGuardar = true;
      _errorGeneral = null;
    });
    if (_errorNombre != null ||
        _errorCodigo != null ||
        _errorStockMinimo != null ||
        _errorPrecio != null ||
        _errorFactor != null) {
      return;
    }

    setState(() => _guardando = true);
    try {
      final guardado = await context.read<EstadoCaja>().guardarProducto(
        id: widget.producto?.id,
        nombre: _nombre.text,
        codigo: _codigo.text,
        tipoExistencia: _tipoExistencia,
        unidad: _unidad,
        stockMinimo: Cantidad.leer(_stockMinimo.text)!,
        precioSugerido: _precio.text.trim().isEmpty
            ? null
            : Importe.leer(_precio.text),
        activo: _activo,
        unidadCompra: _unidadCompra,
        factorCompra: _unidadCompra == null
            ? null
            : Cantidad.leer(_factorCompra.text),
        unidadFactura: _unidadFactura,
      );
      if (mounted) Navigator.of(context).pop(guardado);
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _errorGeneral = '${e.message}');
    } catch (e) {
      if (mounted) setState(() => _errorGeneral = 'No se pudo guardar. $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _campo({
    required String etiqueta,
    required TextEditingController controller,
    String? ayuda,
    String? error,
    String? prefijo,
    TextInputType? teclado,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      inputFormatters: formatters,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        errorText: error,
        prefixText: prefijo,
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final tieneMovimientos = _tieneMovimientos;

    final camposCantidadPrecio = ancho < 480
        ? Column(
            children: [
              _campo(
                etiqueta: 'Stock mínimo',
                controller: _stockMinimo,
                error: _errorStockMinimo,
                teclado: const TextInputType.numberWithOptions(decimal: true),
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
              ),
              const SizedBox(height: 12),
              _campo(
                etiqueta: 'Precio sugerido de venta',
                controller: _precio,
                prefijo: 'S/ ',
                error: _errorPrecio,
                teclado: const TextInputType.numberWithOptions(decimal: true),
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: _campo(
                  etiqueta: 'Stock mínimo',
                  controller: _stockMinimo,
                  error: _errorStockMinimo,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  formatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _campo(
                  etiqueta: 'Precio sugerido de venta',
                  controller: _precio,
                  prefijo: 'S/ ',
                  error: _errorPrecio,
                  teclado: const TextInputType.numberWithOptions(decimal: true),
                  formatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                ),
              ),
            ],
          );

    return Material(
      color: Tokens.superficie,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Tokens.marcaSuave,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Tokens.marcaOscura,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.producto == null
                        ? 'Nuevo producto'
                        : 'Editar producto',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Tokens.texto,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: _guardando
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Tokens.borde),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _campo(
                    etiqueta: 'Nombre del producto',
                    controller: _nombre,
                    ayuda: 'Nombre con el que aparecerá al registrar.',
                    error: _errorNombre,
                  ),
                  const SizedBox(height: 12),
                  _campo(
                    etiqueta: 'Código',
                    controller: _codigo,
                    ayuda: 'Sugerido automáticamente; puedes modificarlo.',
                    error: _errorCodigo,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _tipoExistencia,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de existencia · Tabla 5',
                      isDense: true,
                    ),
                    items: [
                      for (final tipo in TablasSunat.tiposDeExistencia)
                        DropdownMenuItem(
                          value: tipo.codigo,
                          child: Text('${tipo.codigo} · ${tipo.descripcion}'),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      if (v != null) _tipoExistencia = v;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _unidad,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Unidad de stock · Tabla 6',
                      isDense: true,
                    ),
                    items: [
                      for (final unidad in TablasSunat.unidades)
                        DropdownMenuItem(
                          value: unidad.codigo,
                          child: Text(
                            '${unidad.codigo} · ${unidad.abreviatura} · ${unidad.descripcion}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: tieneMovimientos
                        ? null
                        : (v) => setState(() {
                            if (v != null) {
                              _unidad = v;
                              if (_unidadCompra == v) _unidadCompra = null;
                              _unidadFactura = TablasSunat.unidadFacturaDe(v);
                            }
                          }),
                  ),
                  if (tieneMovimientos)
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(
                        'La unidad no se puede cambiar porque el producto ya tiene movimientos.',
                        style: TextStyle(fontSize: 11.5, color: Tokens.texto2),
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _unidadCompra,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Unidad en que se compra (opcional)',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('La misma unidad del stock'),
                      ),
                      for (final unidad in TablasSunat.unidades)
                        if (unidad.codigo != _unidad)
                          DropdownMenuItem<String?>(
                            value: unidad.codigo,
                            child: Text(
                              '${unidad.abreviatura} · ${unidad.descripcion}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                    onChanged: (v) => setState(() {
                      _unidadCompra = v;
                      _factorCompra.clear();
                    }),
                  ),
                  if (_unidadCompra != null) ...[
                    const SizedBox(height: 12),
                    _campo(
                      etiqueta:
                          'Cuánto trae cada ${TablasSunat.unidad(_unidadCompra!)!.abreviatura}',
                      controller: _factorCompra,
                      ayuda: 'Ejemplo: 12 cajas equivalen a 144 unidades si cada caja trae 12.',
                      error: _errorFactor,
                      teclado: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      formatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _unidadFactura,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Unidad de factura electrónica · Catálogo 03',
                      isDense: true,
                    ),
                    items: [
                      for (final unidad in TablasSunat.unidadesFactura)
                        DropdownMenuItem(
                          value: unidad.codigo,
                          child: Text(
                            '${unidad.codigo} · ${unidad.descripcion}',
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      if (v != null) _unidadFactura = v;
                    }),
                  ),
                  const SizedBox(height: 14),
                  camposCantidadPrecio,
                  if (widget.producto != null) ...[
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Producto activo'),
                      subtitle: const Text(
                        'Si lo desactivas, deja de aparecer al registrar; su historial se conserva.',
                      ),
                      value: _activo,
                      onChanged: (v) => setState(() => _activo = v),
                    ),
                  ],
                  if (_errorGeneral != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Tokens.salioSuave,
                        borderRadius: BorderRadius.circular(Tokens.radio),
                      ),
                      child: Text(
                        _errorGeneral!,
                        style: const TextStyle(
                          color: Tokens.salio,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Tokens.borde),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    widget.producto == null
                        ? 'Agregar producto'
                        : 'Guardar cambios',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
