import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/categoria.dart';
import '../../dominio/enums.dart';
import '../../dominio/periodo.dart';
import '../../estado/estado_caja.dart';
import '../widgets/filtro_monto.dart';

/// Búsqueda y filtros del historial (§4.4).
///
/// Cada filtro es un botón que abre un menú anclado a él, chico, justo debajo.
/// Antes eran hojas que subían desde abajo y un calendario a pantalla
/// completa: en el celular pasaba, pero en la computadora ocupaban toda la
/// ventana para elegir entre cinco opciones.
///
/// Un filtro activo muestra su valor ("Este mes", "Ventas") y una "x" para
/// quitarlo: se ve qué está filtrando y cómo deshacerlo sin adivinar (§5).
class BarraFiltros extends StatefulWidget {
  const BarraFiltros({super.key});

  @override
  State<BarraFiltros> createState() => _BarraFiltrosState();
}

class _BarraFiltrosState extends State<BarraFiltros> {
  /// El controller vive en el State y no se recrea en cada build: si se
  /// reconstruyera, el campo perdería el cursor a cada letra tecleada.
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoCaja>();

    // "Quitar filtros" limpia el estado; el campo tiene que enterarse.
    if (_busqueda.text != estado.filtroTexto) {
      _busqueda.value = TextEditingValue(
        text: estado.filtroTexto,
        selection: TextSelection.collapsed(offset: estado.filtroTexto.length),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _busqueda,
          onChanged: (v) => estado.aplicarFiltro(texto: v),
          decoration: InputDecoration(
            hintText: 'Buscar por detalle o nombre…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: estado.filtroTexto.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => estado.aplicarFiltro(texto: ''),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FiltroTipo(estado: estado),
            _FiltroFecha(estado: estado),
            _FiltroCategoria(estado: estado),
            _FiltroMedio(estado: estado),
            FiltroMonto(
              actual: estado.filtroMonto,
              etiqueta: estado.filtroMontoEtiqueta,
              onElegir: (r, e) =>
                  estado.aplicarFiltro(monto: r, montoEtiqueta: e),
              onLimpiar: () => estado.aplicarFiltro(limpiarMonto: true),
            ),
          ],
        ),
      ],
    );
  }
}

class _FiltroTipo extends StatelessWidget {
  const _FiltroTipo({required this.estado});

  final EstadoCaja estado;

  @override
  Widget build(BuildContext context) {
    final actual = estado.filtroTipo;

    return BotonFiltro(
      etiqueta: 'Entró / Salió',
      icono: Icons.swap_vert_rounded,
      valor: actual?.etiqueta,
      onLimpiar: () => estado.aplicarFiltro(limpiarTipo: true),
      opciones: [
        for (final tipo in Tipo.values)
          OpcionFiltro(
            texto: '${tipo.flecha}  ${tipo.etiqueta}',
            elegida: actual == tipo,
            onPressed: () => estado.aplicarFiltro(tipo: tipo),
          ),
      ],
    );
  }
}

class _FiltroFecha extends StatelessWidget {
  const _FiltroFecha({required this.estado});

  final EstadoCaja estado;

  @override
  Widget build(BuildContext context) {
    final rango = estado.filtroRango;

    // Un período rápido se nombra ("Este mes"); un rango a medida muestra
    // sus fechas.
    final valor = rango == null
        ? null
        : estado.filtroRangoEtiqueta ??
              '${Formato.fechaCorta(rango.start)} – '
                  '${Formato.fechaCorta(rango.end)}';

    return BotonFiltro(
      etiqueta: 'Fechas',
      icono: Icons.calendar_today_rounded,
      valor: valor,
      onLimpiar: () => estado.aplicarFiltro(limpiarRango: true),
      opciones: [
        for (final periodo in Periodo.values)
          OpcionFiltro(
            texto: periodo.etiqueta,
            elegida: estado.filtroRangoEtiqueta == periodo.etiqueta,
            onPressed: () {
              final (desde, hasta) = periodo.rango();
              estado.aplicarFiltro(
                rango: DateTimeRange(start: desde, end: hasta),
                rangoEtiqueta: periodo.etiqueta,
              );
            },
          ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(Icons.date_range_rounded, size: 18),
          onPressed: () async {
            final elegido = await showDialog<DateTimeRange>(
              context: context,
              builder: (_) => _DialogoRango(inicial: rango),
            );
            if (elegido != null) estado.aplicarFiltro(rango: elegido);
          },
          child: const Text('Elegir fechas…'),
        ),
      ],
    );
  }
}

class _FiltroCategoria extends StatelessWidget {
  const _FiltroCategoria({required this.estado});

  final EstadoCaja estado;

  /// Hay dos "Otros", uno de cada lado. Solos serían ambiguos en el botón.
  static String _nombre(Categoria c) => c.etiqueta == 'Otros'
      ? 'Otros (${c.tipo == Tipo.entro ? 'ingresos' : 'egresos'})'
      : c.etiqueta;

  @override
  Widget build(BuildContext context) {
    final actual = estado.filtroCategoriaId;

    List<Widget> grupo(Tipo tipo) => [
      _TituloGrupo(tipo == Tipo.entro ? 'Entró' : 'Salió'),
      for (final c in Categoria.de(tipo))
        OpcionFiltro(
          texto: c.etiqueta,
          elegida: actual == c.id,
          onPressed: () => estado.aplicarFiltro(categoriaId: c.id),
        ),
    ];

    return BotonFiltro(
      etiqueta: 'Categoría',
      icono: Icons.sell_outlined,
      valor: actual == null ? null : _nombre(Categoria.porId(actual)),
      onLimpiar: () => estado.aplicarFiltro(limpiarCategoria: true),
      opciones: [
        ...grupo(Tipo.entro),
        const Divider(height: 8),
        ...grupo(Tipo.salio),
      ],
    );
  }
}

class _FiltroMedio extends StatelessWidget {
  const _FiltroMedio({required this.estado});

  final EstadoCaja estado;

  @override
  Widget build(BuildContext context) {
    final actual = estado.filtroMedio;

    return BotonFiltro(
      etiqueta: 'Medio de pago',
      icono: Icons.credit_card_rounded,
      valor: actual?.etiqueta,
      onLimpiar: () => estado.aplicarFiltro(limpiarMedio: true),
      opciones: [
        for (final medio in MedioPago.disponibles)
          OpcionFiltro(
            texto: medio.etiqueta,
            elegida: actual == medio,
            onPressed: () => estado.aplicarFiltro(medio: medio),
          ),
      ],
    );
  }
}

/// Un botón de filtro con su menú desplegable.
///
/// Es público porque el mismo patrón sirve para otros filtros de la app (los
/// reportes, por ejemplo) y conviene que se vean todos iguales (§5).
class BotonFiltro extends StatelessWidget {
  const BotonFiltro({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.opciones,
    required this.onLimpiar,
    this.valor,
  });

  /// Qué filtra, cuando no está activo: "Categoría".
  final String etiqueta;
  final IconData icono;
  final List<Widget> opciones;
  final VoidCallback onLimpiar;

  /// El valor elegido; null si el filtro no está activo.
  final String? valor;

  @override
  Widget build(BuildContext context) {
    final activo = valor != null;

    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Tokens.superficie),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(
          Tokens.cromo.withValues(alpha: 0.25),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radio),
            side: const BorderSide(color: Tokens.borde),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
      ),
      menuChildren: opciones,
      builder: (context, menu, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        decoration: BoxDecoration(
          color: activo ? Tokens.marcaSuave : Tokens.superficie,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: activo ? Tokens.marca.withValues(alpha: 0.55) : Tokens.borde,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => menu.isOpen ? menu.close() : menu.open(),
            child: Padding(
              padding: EdgeInsets.only(left: 14, right: activo ? 6 : 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icono,
                    size: 16,
                    color: activo ? Tokens.marca : Tokens.texto2,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    valor ?? etiqueta,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
                      color: activo ? Tokens.marcaOscura : Tokens.texto,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (activo)
                    _Quitar(onPressed: onLimpiar, que: etiqueta)
                  else
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: Tokens.texto2,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La "x" de un filtro activo.
class _Quitar extends StatelessWidget {
  const _Quitar({required this.onPressed, required this.que});

  final VoidCallback onPressed;
  final String que;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Quitar filtro de ${que.toLowerCase()}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.close_rounded, size: 16, color: Tokens.marca),
        ),
      ),
    );
  }
}

class OpcionFiltro extends StatelessWidget {
  const OpcionFiltro({
    super.key,
    required this.texto,
    required this.elegida,
    required this.onPressed,
  });

  final String texto;
  final bool elegida;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onPressed,
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(200, 42)),
      ),
      trailingIcon: elegida
          ? const Icon(Icons.check_rounded, size: 18, color: Tokens.marca)
          : null,
      child: Text(
        texto,
        style: TextStyle(
          fontWeight: elegida ? FontWeight.w600 : FontWeight.w400,
          color: Tokens.texto,
        ),
      ),
    );
  }
}

class _TituloGrupo extends StatelessWidget {
  const _TituloGrupo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: Tokens.texto2,
        ),
      ),
    );
  }
}

/// Rango a medida: una ventanita con "Desde" y "Hasta".
///
/// Cada fecha abre el selector de un solo día, que en escritorio es un diálogo
/// de tamaño normal. El de rango de Flutter, en cambio, es siempre a pantalla
/// completa y no se puede achicar: por eso no se usa.
class _DialogoRango extends StatefulWidget {
  const _DialogoRango({this.inicial});

  final DateTimeRange? inicial;

  @override
  State<_DialogoRango> createState() => _DialogoRangoState();
}

class _DialogoRangoState extends State<_DialogoRango> {
  late DateTime _desde;
  late DateTime _hasta;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _desde = widget.inicial?.start ?? DateTime(hoy.year, hoy.month);
    _hasta = widget.inicial?.end ?? DateTime(hoy.year, hoy.month, hoy.day);
  }

  Future<void> _elegir({required bool desde}) async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: desde ? _desde : _hasta,
      // "Hasta" no puede ser antes de "Desde": el selector ni lo ofrece.
      firstDate: desde ? DateTime(2020) : _desde,
      lastDate: DateTime(hoy.year, hoy.month, hoy.day),
    );
    if (elegida == null) return;

    setState(() {
      if (desde) {
        _desde = elegida;
        // Si el nuevo "Desde" quedó después de "Hasta", se lo lleva consigo.
        if (_hasta.isBefore(_desde)) _hasta = _desde;
      } else {
        _hasta = elegida;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elegir fechas'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CampoFecha(
              etiqueta: 'Desde',
              fecha: _desde,
              onTap: () => _elegir(desde: true),
            ),
            const SizedBox(height: 12),
            _CampoFecha(
              etiqueta: 'Hasta',
              fecha: _hasta,
              onTap: () => _elegir(desde: false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop(DateTimeRange(start: _desde, end: _hasta)),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    required this.etiqueta,
    required this.fecha,
    required this.onTap,
  });

  final String etiqueta;
  final DateTime fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Tokens.radio),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: const Icon(Icons.event_rounded, size: 20),
        ),
        child: Text(Formato.fecha(fecha)),
      ),
    );
  }
}
