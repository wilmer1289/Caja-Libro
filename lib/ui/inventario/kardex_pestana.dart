import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/export/exportador_kardex.dart';
import '../../datos/export/exportador_kardex_pdf.dart';
import '../../datos/export/impresion.dart';
import '../../dominio/almacen.dart';
import '../../dominio/kardex.dart';
import '../../dominio/mercaderia.dart';
import '../../dominio/registro_inventario.dart';
import '../../estado/estado_caja.dart';
import 'entender_kardex.dart';

/// La sección Kardex del inventario: el Formato 13.1 de un producto en un
/// período, en pantalla y para descargar (13.1 y 12.1, en PDF y CSV).
class KardexPestana extends StatefulWidget {
  const KardexPestana({super.key});

  @override
  State<KardexPestana> createState() => _KardexPestanaState();
}

/// Qué descargar o imprimir.
enum _Salida {
  pdf131('Formato 13.1 en PDF', Icons.picture_as_pdf_outlined),
  csv131('Formato 13.1 en CSV (Excel)', Icons.table_view_outlined),
  pdf121('Formato 12.1 en PDF', Icons.picture_as_pdf_outlined),
  csv121('Formato 12.1 en CSV (Excel)', Icons.table_view_outlined),
  todos131('Todos los productos · 13.1 en PDF', Icons.library_books_outlined),
  todos121('Todos los productos · 12.1 en PDF', Icons.library_books_outlined);

  const _Salida(this.etiqueta, this.icono);
  final String etiqueta;
  final IconData icono;

  bool get csv => this == csv131 || this == csv121;
  bool get todos => this == todos131 || this == todos121;
  bool get valorizado => this == pdf131 || this == csv131 || this == todos131;
}

class _KardexPestanaState extends State<KardexPestana> {
  String? _productoId;

  /// El primer día del mes elegido; null es "todo el kardex".
  DateTime? _mes;
  bool _mesElegido = false;
  bool _entender = false;
  bool _ocupado = false;

  static DateTime _inicioMes(DateTime f) => DateTime(f.year, f.month);

  /// Los meses con algo en el kardex, del más nuevo al más viejo.
  List<DateTime> _meses(List<LineaAlmacen> lineas) {
    if (lineas.isEmpty) return [_inicioMes(DateTime.now())];
    var primero = lineas.first.fecha;
    for (final l in lineas) {
      if (l.fecha.isBefore(primero)) primero = l.fecha;
    }
    final meses = <DateTime>[];
    var m = _inicioMes(DateTime.now());
    final tope = _inicioMes(primero);
    while (!m.isBefore(tope)) {
      meses.add(m);
      m = DateTime(m.year, m.month - 1);
    }
    return meses;
  }

  (DateTime, DateTime) _rango(List<LineaAlmacen> lineas) {
    final mes = _mes;
    if (mes != null) {
      return (mes, DateTime(mes.year, mes.month + 1, 0));
    }
    var desde = DateTime.now();
    for (final l in lineas) {
      if (l.fecha.isBefore(desde)) desde = l.fecha;
    }
    return (desde, DateTime.now());
  }

  Future<void> _sacar(
    BuildContext context,
    _Salida salida, {
    required Kardex kardex,
    required RegistroInventario registro,
    required List<Mercaderia> productos,
    bool imprimir = false,
  }) async {
    final mensajero = ScaffoldMessenger.of(context);
    final estado = context.read<EstadoCaja>();
    final registros = salida.todos
        ? RegistroInventario.deTodos(
            kardex,
            negocio: estado.negocio,
            productos: productos,
            desde: registro.desde,
            hasta: registro.hasta,
          )
        : [registro];
    if (registros.isEmpty) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('No hay movimientos en ese período.')),
      );
      return;
    }
    final formato = salida.valorizado ? '13.1' : '12.1';
    setState(() => _ocupado = true);
    try {
      if (salida.csv) {
        if (kIsWeb) {
          mensajero.showSnackBar(
            const SnackBar(
              content: Text(
                'El CSV no está disponible en la web: descarga el PDF.',
              ),
            ),
          );
          return;
        }
        final contenido = salida.valorizado
            ? ExportadorKardex.csv131(registros)
            : ExportadorKardex.csv121(registros);
        final ruta = await ExportadorKardex.guardar(
          contenido,
          ExportadorKardex.nombre(formato, registros),
        );
        mensajero.showSnackBar(SnackBar(content: Text('Guardado en $ruta')));
        return;
      }
      final Uint8List pdf = salida.valorizado
          ? await ExportadorKardexPdf.formato131(registros)
          : await ExportadorKardexPdf.formato121(registros);
      final nombre = ExportadorKardex.nombre(
        formato,
        registros,
        extension: 'pdf',
      );
      if (imprimir) {
        await Impresion.imprimir(pdf, nombre);
        return;
      }
      final ruta = await Impresion.descargar(pdf, nombre);
      mensajero.showSnackBar(SnackBar(content: Text('Guardado en $ruta')));
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(content: Text('No se pudo preparar el formato. $e')),
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();
    final lineas = estado.lineasAlmacen;
    final kardex = estado.kardex;
    final conMovimiento = {for (final l in lineas) l.mercaderiaId};
    final productos = estado.productos
        .where((p) => p.activo || conMovimiento.contains(p.id))
        .toList();

    if (productos.isEmpty) {
      return const _Vacio(
        icono: Icons.inventory_2_outlined,
        titulo: 'Todavía no hay productos',
        detalle:
            'Crea tus productos y su inventario inicial en Productos. Aquí '
            'verás su kardex: lo que entra, lo que sale y lo que queda.',
      );
    }

    final producto = productos.firstWhere(
      (p) => p.id == _productoId,
      orElse: () => productos.firstWhere(
        (p) => conMovimiento.contains(p.id),
        orElse: () => productos.first,
      ),
    );
    final lineasProducto = lineas
        .where((l) => l.mercaderiaId == producto.id)
        .toList();
    final meses = _meses(lineasProducto);
    if (!_mesElegido && lineasProducto.isNotEmpty) {
      // Por defecto, el mes del último movimiento del producto.
      _mes = _inicioMes(lineasProducto.last.fecha);
    }
    if (_mes != null && !meses.contains(_mes)) _mes = meses.first;
    final (desde, hasta) = _rango(lineasProducto);
    final registro = RegistroInventario.de(
      kardex,
      negocio: estado.negocio,
      producto: producto,
      desde: desde,
      hasta: hasta,
    );

    final angosto = MediaQuery.sizeOf(context).width < 600;
    final menuFormatos = PopupMenuButton<_Salida>(
      tooltip: 'Descargar formatos',
      enabled: !_ocupado,
      onSelected: (s) => _sacar(
        context,
        s,
        kardex: kardex,
        registro: registro,
        productos: productos,
      ),
      itemBuilder: (_) => [
        for (final s in _Salida.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(s.icono, size: 19, color: Tokens.texto2),
                const SizedBox(width: 10),
                Flexible(child: Text(s.etiqueta)),
              ],
            ),
          ),
      ],
      child: IgnorePointer(
        child: angosto
            ? IconButton.outlined(
                onPressed: _ocupado ? null : () {},
                color: Tokens.marcaOscura,
                icon: const Icon(Icons.download_rounded, size: 20),
              )
            : OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Tokens.marcaOscura,
                  side: const BorderSide(color: Tokens.bordeFuerte),
                  minimumSize: const Size(0, 40),
                ),
                onPressed: _ocupado ? null : () {},
                icon: _ocupado
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: const Text('Formatos'),
              ),
      ),
    );

    final margen = angosto ? 14.0 : 20.0;
    final cabecera = Padding(
      padding: EdgeInsets.fromLTRB(margen, 14, margen, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Kardex',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Tokens.texto,
                ),
              ),
              const Spacer(),
              FilterChip(
                label: const Text('Entender'),
                avatar: const Icon(Icons.lightbulb_outline_rounded, size: 17),
                selected: _entender,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (v) => setState(() => _entender = v),
                tooltip: 'Toca una fila para ver de dónde sale cada número',
              ),
              const SizedBox(width: 8),
              menuFormatos,
              IconButton(
                tooltip: 'Imprimir el Formato 13.1',
                onPressed: _ocupado
                    ? null
                    : () => _sacar(
                        context,
                        _Salida.pdf131,
                        kardex: kardex,
                        registro: registro,
                        productos: productos,
                        imprimir: true,
                      ),
                icon: const Icon(Icons.print_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: producto.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Producto',
                    isDense: true,
                  ),
                  items: [
                    for (final p in productos)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.codigo} · ${p.nombre}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() {
                    _productoId = id;
                    _mesElegido = false;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<DateTime?>(
                  initialValue: _mes,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Período',
                    isDense: true,
                  ),
                  items: [
                    for (final m in meses)
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          Formato.capitalizar(Formato.mes(m)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todo el kardex'),
                    ),
                  ],
                  onChanged: (m) => setState(() {
                    _mes = m;
                    _mesElegido = true;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _datosDelFormato(registro),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Tokens.texto2),
          ),
          const SizedBox(height: 8),
          _Resumen(registro: registro),
          if (_entender) ...[
            const SizedBox(height: 8),
            const Text(
              'Toca una fila para ver cómo se calculó.',
              style: TextStyle(fontSize: 12.5, color: Tokens.marcaOscura),
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cabecera,
        Expanded(
          child: registro.vacio
              ? const _Vacio(
                  icono: Icons.receipt_long_outlined,
                  titulo: 'Sin movimientos en este período',
                  detalle:
                      'Elige otro mes o «Todo el kardex». Las compras y las '
                      'ventas con este producto aparecen aquí solas.',
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(margen, 2, margen, margen),
                  child: _TablaKardex(
                    registro: registro,
                    entender: _entender,
                    onEntender: (i) => EntenderKardex.abrir(
                      context,
                      registro.filas[i],
                      anterior: i == 0 ? null : registro.filas[i - 1],
                      producto: producto,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Los datos del encabezado del 13.1 en una línea: el producto y el período
/// ya están a la vista, y el encabezado completo va en el PDF.
String _datosDelFormato(RegistroInventario r) {
  final datos = {for (final (k, v) in r.encabezado()) k: v};
  return [
    'Tipo ${datos['TIPO (TABLA 5)']}',
    'Unidad ${datos['CÓDIGO DE LA UNIDAD DE MEDIDA (TABLA 6)']}',
    'Método: ${r.negocio.metodoValuacion.etiqueta.toLowerCase()}',
  ].join('  ·  ');
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.registro});

  final RegistroInventario registro;

  @override
  Widget build(BuildContext context) {
    final u = registro.producto.abreviaturaUnidad;

    /// Cada total con su color: entradas en verde, salidas en terracota y el
    /// saldo final en naranja, que es lo que queda.
    Widget dato(
      String titulo,
      int cantidad,
      int costo, {
      required Color fondo,
      required Color borde,
      required Color monto,
      Color rotulo = Tokens.texto2,
    }) => Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: borde),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: rotulo,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            Formato.soles(costo / 100),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: monto,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            '${Cantidad.texto(cantidad)} $u',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: rotulo),
          ),
        ],
      ),
    );
    final datos = [
      if (registro.inicialCantidad != 0 || registro.inicialCosto != 0)
        dato(
          'Saldo inicial',
          registro.inicialCantidad,
          registro.inicialCosto,
          fondo: Tokens.superficie,
          borde: Tokens.borde,
          monto: Tokens.texto,
        ),
      dato(
        '↑ Entradas',
        registro.entradasCantidad,
        registro.entradasCosto,
        fondo: Tokens.entroSuave,
        borde: Tokens.entro.withValues(alpha: .18),
        monto: Tokens.entro,
      ),
      dato(
        '↓ Salidas al costo',
        registro.salidasCantidad,
        registro.salidasCosto,
        fondo: Tokens.salioSuave,
        borde: Tokens.salio.withValues(alpha: .18),
        monto: Tokens.salio,
      ),
      dato(
        'Saldo final',
        registro.saldoFinalCantidad,
        registro.saldoFinalCosto,
        fondo: Tokens.marcaSuave,
        borde: Tokens.marca.withValues(alpha: .35),
        monto: Tokens.marcaOscura,
        rotulo: Tokens.marcaOscura,
      ),
    ];
    // En una fila si entran; en el celular, de dos en dos.
    return LayoutBuilder(
      builder: (context, caja) {
        final porFila = caja.maxWidth >= 560 ? datos.length : 2;
        final ancho = (caja.maxWidth - 8 * (porFila - 1)) / porFila;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final d in datos) SizedBox(width: ancho, child: d)],
        );
      },
    );
  }
}

/// La tabla del 13.1: el documento, la operación y las tres partes con
/// cantidad, costo unitario y costo total. Cada parte lleva su color (verde
/// las entradas, terracota las salidas), las filas van alternadas para no
/// perderse al leer, y el total va en crema y en negrita. Se desliza a los
/// lados si no entra.
class _TablaKardex extends StatelessWidget {
  const _TablaKardex({
    required this.registro,
    required this.entender,
    required this.onEntender,
  });

  final RegistroInventario registro;
  final bool entender;
  final ValueChanged<int> onEntender;

  static const _fijas = [96.0, 44.0, 56.0, 72.0, 52.0];
  static const _numerica = 94.0;
  static double get _ancho => _fijas.fold(0.0, (t, a) => t + a) + _numerica * 9;

  /// Los anchos de las 14 columnas. Si sobra espacio (el inventario ocupa
  /// toda la pantalla de la computadora), todas crecen parejo hasta llenar la
  /// tarjeta; si falta, quedan en su mínimo y la tabla se desliza.
  static List<double> _anchosPara(double disponible) {
    final total = disponible.isFinite && disponible > _ancho
        ? disponible
        : _ancho;
    final factor = total / _ancho;
    final anchos = [
      for (final a in _fijas) a * factor,
      for (var i = 0; i < 8; i++) _numerica * factor,
    ];
    // La última se queda con el resto, para que no sobre ni falte un pelo.
    return [...anchos, total - anchos.fold(0.0, (t, a) => t + a)];
  }

  /// La cabecera de cada grupo y el tono de sus columnas.
  static const _cabeceraDocumento = Color(0xFFF1EEE9);
  static const _cebra = Color(0xFFFAF8F5);

  static String _cant(int? m) => m == null ? '' : Cantidad.texto(m);
  static String _monto(int? c) => c == null ? '' : Formato.monto(c / 100);

  /// De qué grupo es la columna: 0 documento, 1 entradas, 2 salidas, 3 saldo.
  static int _grupo(int columna) => columna < 5 ? 0 : 1 + (columna - 5) ~/ 3;

  List<String> _celdas(FilaRegistro f) => [
    Formato.fecha(f.fecha),
    f.tipoDocumento,
    f.serie,
    f.numero,
    f.operacion,
    _cant(f.entradaCantidad),
    RegistroInventario.unitario(f.entradaUnitario),
    _monto(f.entradaCosto),
    _cant(f.salidaCantidad),
    RegistroInventario.unitario(f.salidaUnitario),
    _monto(f.salidaCosto),
    _cant(f.saldoCantidad),
    RegistroInventario.unitario(f.saldoUnitario),
    _monto(f.saldoCosto),
  ];

  /// Una fila: `color` decide el texto de cada columna.
  Widget _fila(
    List<String> celdas, {
    required List<double> anchos,
    required Color Function(int columna) color,
    FontWeight Function(int columna)? peso,
    Color? fondo,
    double alto = 38,
  }) {
    return Container(
      color: fondo,
      height: alto,
      child: Row(
        children: [
          for (var i = 0; i < celdas.length; i++)
            Container(
              width: anchos[i],
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: i >= 5 ? Alignment.centerRight : Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  left: i == 5 || i == 8 || i == 11
                      ? BorderSide(color: Colors.black.withValues(alpha: .06))
                      : BorderSide.none,
                ),
              ),
              child: Text(
                celdas[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: peso?.call(i) ?? FontWeight.w400,
                  color: color(i),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Las celdas de cada grupo en la cabecera: el título y su tono.
  Widget _cabecera(List<double> anchos) {
    Color fondo(int grupo) => switch (grupo) {
      1 => Tokens.entroSuave,
      2 => Tokens.salioSuave,
      3 => Tokens.escenario,
      _ => _cabeceraDocumento,
    };
    Color tinta(int grupo) => switch (grupo) {
      1 => Tokens.entro,
      2 => Tokens.salio,
      _ => Tokens.texto,
    };

    Widget grupo(String texto, double ancho, int g) => Container(
      width: ancho,
      height: 28,
      alignment: Alignment.center,
      color: fondo(g),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
          color: tinta(g),
        ),
      ),
    );

    const titulos = [
      'Fecha',
      'Tipo',
      'Serie',
      'Número',
      'Op.',
      'Cant.',
      'C. unit.',
      'Total',
      'Cant.',
      'C. unit.',
      'Total',
      'Cant.',
      'C. unit.',
      'Total',
    ];
    double suma(int desde, int hasta) =>
        anchos.sublist(desde, hasta).fold(0.0, (t, a) => t + a);
    return Column(
      children: [
        Row(
          children: [
            grupo('DOCUMENTO', suma(0, 5), 0),
            grupo('↑ ENTRADAS', suma(5, 8), 1),
            grupo('↓ SALIDAS', suma(8, 11), 2),
            grupo('SALDO FINAL', suma(11, 14), 3),
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < titulos.length; i++)
              Container(
                width: anchos[i],
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: i >= 5 ? Alignment.centerRight : Alignment.center,
                color: fondo(_grupo(i)),
                child: Text(
                  titulos[i],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: tinta(_grupo(i)).withValues(alpha: .8),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.superficie,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
        boxShadow: Tokens.sombraTarjeta,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radio),
        child: LayoutBuilder(
          builder: (context, medidas) => _tabla(_anchosPara(medidas.maxWidth)),
        ),
      ),
    );
  }

  Widget _tabla(List<double> anchos) {
    Color tintaFila(int columna) => switch (_grupo(columna)) {
      1 => Tokens.entro,
      2 => Tokens.salio,
      _ => Tokens.texto,
    };

    final total = _fila(
      [
        '',
        '',
        '',
        '',
        'Total',
        _cant(registro.entradasCantidad),
        '',
        _monto(registro.entradasCosto),
        _cant(registro.salidasCantidad),
        '',
        _monto(registro.salidasCosto),
        _cant(registro.saldoFinalCantidad),
        '',
        _monto(registro.saldoFinalCosto),
      ],
      anchos: anchos,
      fondo: Tokens.escenario,
      alto: 42,
      peso: (_) => FontWeight.w800,
      color: (i) => switch (_grupo(i)) {
        1 => Tokens.entro,
        2 => Tokens.salio,
        3 => Tokens.marcaOscura,
        _ => Tokens.texto,
      },
    );

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: anchos.fold<double>(0, (t, a) => t + a),
          child: Column(
            children: [
              _cabecera(anchos),
              Expanded(
                child: ListView.builder(
                  itemCount: registro.filas.length,
                  itemBuilder: (context, i) {
                    final f = registro.filas[i];
                    // El saldo con que empieza el período se marca,
                    // para que no se confunda con una compra.
                    final fondo = f.esSaldoInicial
                        ? Tokens.marcaSuave
                        : i.isOdd
                        ? _cebra
                        : Tokens.superficie;
                    final fila = _fila(
                      _celdas(f),
                      anchos: anchos,
                      fondo: fondo,
                      color: tintaFila,
                      peso: (c) => _grupo(c) == 3 && c == 13
                          ? FontWeight.w600
                          : FontWeight.w400,
                    );
                    final conAyuda = Tooltip(
                      message: f.arrastrado
                          ? 'Saldo del período anterior'
                          : f.nombreOperacion,
                      child: fila,
                    );
                    return entender
                        ? Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onEntender(i),
                              hoverColor: Tokens.marca.withValues(alpha: .06),
                              child: conAyuda,
                            ),
                          )
                        : conAyuda;
                  },
                ),
              ),
              const Divider(height: 1, color: Tokens.bordeFuerte),
              total,
            ],
          ),
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 40, color: Tokens.texto2),
              const SizedBox(height: 12),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Tokens.texto,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                detalle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Tokens.texto2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
