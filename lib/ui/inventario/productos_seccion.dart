import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/almacen.dart';
import '../../dominio/categoria.dart';
import '../../dominio/enums.dart';
import '../../dominio/mercaderia.dart';
import '../../estado/estado_caja.dart';
import '../registro/registro_hoja.dart';
import 'importar_productos.dart';
import 'inventario_inicial.dart';
import 'producto_dialogo.dart';

/// Catálogo con saldos calculados directamente desde el kardex.
class ProductosSeccion extends StatefulWidget {
  const ProductosSeccion({super.key});

  @override
  State<ProductosSeccion> createState() => _ProductosSeccionState();
}

class _ProductosSeccionState extends State<ProductosSeccion> {
  final _buscar = TextEditingController();
  String _filtroEstado = 'Todos';

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _nuevoProducto() async {
    await ProductoDialogo.abrir(context);
  }

  Future<void> _editar(Mercaderia producto) async {
    await ProductoDialogo.abrir(context, producto: producto);
  }

  Future<void> _inventarioInicial(Mercaderia producto) async {
    if (!producto.activo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Activa el producto para registrar o corregir su inventario.',
          ),
        ),
      );
      return;
    }
    await InventarioInicialDialogo.abrir(context, producto);
  }

  Future<void> _importar() async {
    await ImportarProductosDialogo.abrir(context);
  }

  Future<void> _registrarCompra() async {
    await RegistroHoja.abrir(
      context,
      Tipo.salio,
      categoriaInicialId: Categoria.mercaderia.id,
    );
  }

  Future<void> _cambiarEstado(Mercaderia producto) async {
    final activar = !producto.activo;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activar ? 'Activar producto' : 'Desactivar producto'),
        content: Text(
          activar
              ? '${producto.nombre} volverá a aparecer al registrar compras y ventas.'
              : '${producto.nombre} dejará de aparecer al registrar. Su historial y su kardex se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(activar ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await context.read<EstadoCaja>().guardarProducto(
        id: producto.id,
        nombre: producto.nombre,
        codigo: producto.codigo,
        tipoExistencia: producto.tipoExistencia,
        unidad: producto.unidad,
        stockMinimo: producto.stockMinimo,
        precioSugerido: producto.precioSugerido,
        activo: activar,
        unidadCompra: producto.unidadCompra,
        factorCompra: producto.factorCompra,
        unidadFactura: producto.codigoUnidadFactura,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el estado. $e')),
      );
    }
  }

  List<Mercaderia> _filtrados(List<Mercaderia> productos) {
    final texto = _buscar.text.trim().toLowerCase();
    return productos.where((p) {
      if (_filtroEstado == 'Activos' && !p.activo) return false;
      if (_filtroEstado == 'Inactivos' && p.activo) return false;
      if (texto.isEmpty) return true;
      return p.nombre.toLowerCase().contains(texto) ||
          p.codigo.toLowerCase().contains(texto);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final productos = _filtrados(estado.productos);
    final valorTotal = estado.kardex.valorTotal();
    final alertas = estado.alertasInventario;
    final ancho = MediaQuery.sizeOf(context).width;
    final escritorio = ancho >= 760;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, medidas) {
                  final compacto = medidas.maxWidth < 900;
                  final acciones = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: compacto
                        ? WrapAlignment.start
                        : WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _registrarCompra,
                        icon: const Icon(
                          Icons.add_shopping_cart_outlined,
                          size: 17,
                        ),
                        label: const Text('Registrar compra'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _importar,
                        icon: const Icon(Icons.upload_file_outlined, size: 17),
                        label: const Text('Importar Excel'),
                      ),
                      FilledButton.icon(
                        onPressed: _nuevoProducto,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Nuevo producto'),
                      ),
                    ],
                  );
                  if (compacto) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Productos',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Tokens.texto,
                          ),
                        ),
                        const SizedBox(height: 10),
                        acciones,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Productos',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Tokens.texto,
                          ),
                        ),
                      ),
                      acciones,
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              _ResumenInventario(
                valorCentavos: valorTotal,
                productos: estado.productos.length,
                porReponer: alertas.length,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _buscar,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar por código o descripción',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _buscar.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _buscar.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                children: [
                  for (final filtro in ['Todos', 'Activos', 'Inactivos'])
                    ChoiceChip(
                      label: Text(filtro),
                      selected: _filtroEstado == filtro,
                      onSelected: (_) => setState(() => _filtroEstado = filtro),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Tokens.borde),
        Expanded(
          child: productos.isEmpty
              ? _VacioProductos(hayProductos: estado.productos.isNotEmpty)
              : escritorio
              ? _TablaProductos(
                  productos: productos,
                  estado: estado,
                  onEditar: _editar,
                  onInventario: _inventarioInicial,
                  onCambiarEstado: _cambiarEstado,
                )
              : _ListaProductos(
                  productos: productos,
                  estado: estado,
                  onEditar: _editar,
                  onInventario: _inventarioInicial,
                  onCambiarEstado: _cambiarEstado,
                ),
        ),
      ],
    );
  }
}

class _ResumenInventario extends StatelessWidget {
  const _ResumenInventario({
    required this.valorCentavos,
    required this.productos,
    required this.porReponer,
  });

  final int valorCentavos;
  final int productos;
  final int porReponer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        final compacto = medidas.maxWidth < 470;
        final elementos = [
          _DatoResumen(
            titulo: 'Valor total del inventario',
            valor: Formato.soles(valorCentavos / 100),
            icono: Icons.account_balance_wallet_outlined,
          ),
          _DatoResumen(
            titulo: 'Productos',
            valor: '$productos',
            icono: Icons.inventory_2_outlined,
          ),
          _DatoResumen(
            titulo: 'Por reponer',
            valor: '$porReponer',
            icono: Icons.warning_amber_rounded,
            advertencia: porReponer > 0,
          ),
        ];
        return compacto
            ? Column(
                children: [
                  for (var i = 0; i < elementos.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    elementos[i],
                  ],
                ],
              )
            : Row(
                children: [
                  for (var i = 0; i < elementos.length; i++) ...[
                    if (i > 0) const SizedBox(width: 9),
                    Expanded(child: elementos[i]),
                  ],
                ],
              );
      },
    );
  }
}

class _DatoResumen extends StatelessWidget {
  const _DatoResumen({
    required this.titulo,
    required this.valor,
    required this.icono,
    this.advertencia = false,
  });

  final String titulo;
  final String valor;
  final IconData icono;
  final bool advertencia;

  @override
  Widget build(BuildContext context) {
    final color = advertencia ? Tokens.salio : Tokens.marcaOscura;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Tokens.superficie,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
      ),
      child: Row(
        children: [
          Icon(icono, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Tokens.texto2),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Tokens.texto,
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

class _TablaProductos extends StatelessWidget {
  const _TablaProductos({
    required this.productos,
    required this.estado,
    required this.onEditar,
    required this.onInventario,
    required this.onCambiarEstado,
  });

  final List<Mercaderia> productos;
  final EstadoCaja estado;
  final ValueChanged<Mercaderia> onEditar;
  final ValueChanged<Mercaderia> onInventario;
  final ValueChanged<Mercaderia> onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 22,
            headingRowHeight: 44,
            dataRowMinHeight: 58,
            dataRowMaxHeight: 68,
            columns: const [
              DataColumn(label: Text('Código')),
              DataColumn(label: Text('Producto')),
              DataColumn(label: Text('Unidad')),
              DataColumn(label: Text('Stock'), numeric: true),
              DataColumn(label: Text('Costo promedio'), numeric: true),
              DataColumn(label: Text('Valor'), numeric: true),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: [for (final producto in productos) _fila(context, producto)],
          ),
        ),
      ),
    );
  }

  DataRow _fila(BuildContext context, Mercaderia producto) {
    final saldo = estado.kardex.saldo(producto.id);
    final bajo = saldo.cantidad <= producto.stockMinimo;
    final costo = saldo.costoUnitario;
    final valor = saldo.costo;
    final tieneMovimientos = estado.tieneMovimientosAlmacen(producto.id);
    return DataRow(
      cells: [
        DataCell(Text(producto.codigo)),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(producto.nombre, overflow: TextOverflow.ellipsis),
          ),
        ),
        DataCell(Text(producto.abreviaturaUnidad)),
        DataCell(
          Text(
            '${Cantidad.texto(saldo.cantidad)}${bajo ? '  !' : ''}',
            style: TextStyle(
              color: bajo ? Tokens.salio : Tokens.texto,
              fontWeight: bajo ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        DataCell(Text(Formato.soles(costo))),
        DataCell(Text(Formato.soles(valor / 100))),
        DataCell(_EstadoProducto(activo: producto.activo)),
        DataCell(
          _AccionesProducto(
            producto: producto,
            tieneMovimientos: tieneMovimientos,
            onEditar: () => onEditar(producto),
            onInventario: () => onInventario(producto),
            onCambiarEstado: () => onCambiarEstado(producto),
          ),
        ),
      ],
    );
  }
}

class _ListaProductos extends StatelessWidget {
  const _ListaProductos({
    required this.productos,
    required this.estado,
    required this.onEditar,
    required this.onInventario,
    required this.onCambiarEstado,
  });

  final List<Mercaderia> productos;
  final EstadoCaja estado;
  final ValueChanged<Mercaderia> onEditar;
  final ValueChanged<Mercaderia> onInventario;
  final ValueChanged<Mercaderia> onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      itemCount: productos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, i) {
        final producto = productos[i];
        final saldo = estado.kardex.saldo(producto.id);
        final bajo = saldo.cantidad <= producto.stockMinimo;
        final tieneMovimientos = estado.lineasAlmacen.any(
          (l) => l.mercaderiaId == producto.id,
        );
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Tokens.superficie,
            borderRadius: BorderRadius.circular(Tokens.radioGrande),
            border: Border.all(color: Tokens.borde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producto.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Tokens.texto,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${producto.codigo} · ${producto.abreviaturaUnidad}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Tokens.texto2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _EstadoProducto(activo: producto.activo),
                  _AccionesProducto(
                    producto: producto,
                    tieneMovimientos: tieneMovimientos,
                    onEditar: () => onEditar(producto),
                    onInventario: () => onInventario(producto),
                    onCambiarEstado: () => onCambiarEstado(producto),
                  ),
                ],
              ),
              const Divider(height: 20, color: Tokens.borde),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  _DatoProducto(
                    titulo: 'Stock',
                    valor:
                        '${Cantidad.texto(saldo.cantidad)} ${producto.abreviaturaUnidad}',
                    advertencia: bajo,
                  ),
                  _DatoProducto(
                    titulo: 'Costo promedio',
                    valor: Formato.soles(saldo.costoUnitario),
                  ),
                  _DatoProducto(
                    titulo: 'Valor',
                    valor: Formato.soles(saldo.costo / 100),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onInventario(producto),
                  icon: Icon(
                    tieneMovimientos
                        ? Icons.edit_note_rounded
                        : Icons.playlist_add_rounded,
                    size: 18,
                  ),
                  label: Text(
                    tieneMovimientos
                        ? 'Corregir inventario'
                        : 'Inventario inicial',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DatoProducto extends StatelessWidget {
  const _DatoProducto({
    required this.titulo,
    required this.valor,
    this.advertencia = false,
  });

  final String titulo;
  final String valor;
  final bool advertencia;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 11, color: Tokens.texto2),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: advertencia ? Tokens.salio : Tokens.texto,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoProducto extends StatelessWidget {
  const _EstadoProducto({required this.activo});

  final bool activo;

  @override
  Widget build(BuildContext context) {
    final color = activo ? Tokens.entro : Tokens.texto2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AccionesProducto extends StatelessWidget {
  const _AccionesProducto({
    required this.producto,
    required this.tieneMovimientos,
    required this.onEditar,
    required this.onInventario,
    required this.onCambiarEstado,
  });

  final Mercaderia producto;
  final bool tieneMovimientos;
  final VoidCallback onEditar;
  final VoidCallback onInventario;
  final VoidCallback onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Acciones del producto',
      onSelected: (accion) {
        switch (accion) {
          case 'editar':
            onEditar();
            break;
          case 'inventario':
            onInventario();
            break;
          case 'estado':
            onCambiarEstado();
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'editar', child: Text('Editar producto')),
        PopupMenuItem(
          value: 'inventario',
          child: Text(
            tieneMovimientos ? 'Corregir inventario' : 'Inventario inicial',
          ),
        ),
        PopupMenuItem(
          value: 'estado',
          child: Text(producto.activo ? 'Desactivar' : 'Activar'),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.more_vert_rounded, color: Tokens.texto2),
      ),
    );
  }
}

class _VacioProductos extends StatelessWidget {
  const _VacioProductos({required this.hayProductos});

  final bool hayProductos;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 42,
              color: Tokens.texto2,
            ),
            const SizedBox(height: 12),
            Text(
              hayProductos
                  ? 'No hay productos con ese filtro'
                  : 'Tu catálogo está vacío',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Tokens.texto,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hayProductos ? 'Prueba otra búsqueda o cambia el estado.' : 'Crea el primer producto o importa tu catálogo desde Excel.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
            ),
          ],
        ),
      ),
    );
  }
}
