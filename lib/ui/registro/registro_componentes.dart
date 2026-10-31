import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/categoria.dart';
import '../../dominio/enums.dart';
import '../../dominio/igv.dart';
import '../../estado/estado_caja.dart';

/// Los pasos arriba del formulario: dónde se está y cuántos faltan.
class IndicadorPasos extends StatelessWidget {
  const IndicadorPasos({
    super.key,
    required this.pasos,
    required this.actual,
    required this.color,
    this.compacto = false,
  });

  final List<String> pasos;
  final int actual;
  final Color color;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compacto
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(28, 12, 28, 12),
      decoration: compacto
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Tokens.borde)),
            ),
      child: Row(
        children: [
          for (var i = 0; i < pasos.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: i <= actual ? color : Tokens.borde,
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= actual ? color : Tokens.superficie,
                border: Border.all(color: i <= actual ? color : Tokens.borde),
              ),
              child: i < actual
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    )
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i <= actual ? Colors.white : Tokens.texto2,
                      ),
                    ),
            ),
            if (!compacto || i == actual) ...[
              const SizedBox(width: 8),
              Text(
                pasos[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: i == actual ? FontWeight.w700 : FontWeight.w500,
                  color: i == actual ? Tokens.texto : Tokens.texto2,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Los comprobantes del movimiento, al pie de la columna derecha: el recibo
/// para firmar, el aviso del paso del efectivo y la boleta, que se genera
/// sola.
class ComprobantesRegistro extends StatelessWidget {
  const ComprobantesRegistro({
    super.key,
    required this.tipo,
    required this.conRecibo,
    required this.onRecibo,
    required this.enEfectivo,
    required this.emiteBoleta,
    required this.exigeCliente,
  });

  final Tipo tipo;
  final bool conRecibo;
  final ValueChanged<bool> onRecibo;
  final bool enEfectivo;
  final bool emiteBoleta;
  final bool exigeCliente;

  @override
  Widget build(BuildContext context) {
    final entro = tipo == Tipo.entro;

    Widget interruptor({
      required IconData icono,
      required String titulo,
      required String bajada,
      required bool valor,
      required ValueChanged<bool> onCambiar,
    }) => Material(
      color: valor ? Tokens.marcaSuave : Tokens.superficie,
      borderRadius: BorderRadius.circular(Tokens.radio),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radio),
        onTap: () => onCambiar(!valor),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radio),
            border: Border.all(
              color: valor
                  ? Tokens.marca.withValues(alpha: 0.45)
                  : Tokens.borde,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icono,
                size: 19,
                color: valor ? Tokens.marca : Tokens.texto2,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Tokens.texto,
                      ),
                    ),
                    Text(
                      bajada,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Tokens.texto2,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: valor,
                onChanged: onCambiar,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );

    Widget nota(IconData icono, String texto) => Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Tokens.fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.borde),
      ),
      child: Row(
        children: [
          Icon(icono, size: 19, color: Tokens.texto2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 12, color: Tokens.texto2),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const EtiquetaRegistro('Comprobantes'),
        interruptor(
          icono: Icons.receipt_long_rounded,
          titulo: 'Recibo interno',
          bajada: 'Se imprime para que lo firmen',
          valor: conRecibo,
          onCambiar: onRecibo,
        ),
        if (enEfectivo) ...[
          const SizedBox(height: 8),
          nota(
            Icons.payments_outlined,
            entro
                ? 'Efectivo: en el paso siguiente anotas con cuánto pagó y '
                      'el vuelto.'
                : 'Efectivo: en el paso siguiente anotas con qué billetes '
                      'pagaste y si te dieron vuelto.',
          ),
        ],
        if (emiteBoleta) ...[
          const SizedBox(height: 8),
          nota(
            Icons.shopping_bag_outlined,
            exigeCliente
                ? 'Boleta de venta: se genera sola. Desde S/ 700 lleva nombre '
                      'y DNI o RUC del cliente.'
                : 'Boleta de venta: se genera sola al guardar.',
          ),
        ],
      ],
    );
  }
}

/// La cabeza del formulario: de qué se trata, en el color de lo que se anota.
///
/// En el diálogo es una franja teñida que ocupa todo el ancho, con una frase
/// que dice qué cabe acá; en el celular, una fila simple bajo la manija.
class CabeceraRegistro extends StatelessWidget {
  const CabeceraRegistro({
    super.key,
    required this.entro,
    required this.color,
    required this.enDialogo,
    required this.onCerrar,
  });

  final bool entro;
  final Color color;
  final bool enDialogo;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final icono = Container(
      width: enDialogo ? 46 : 38,
      height: enDialogo ? 46 : 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enDialogo ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(enDialogo ? 14 : 11),
      ),
      child: Icon(
        entro ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        color: enDialogo ? Colors.white : color,
        size: enDialogo ? 24 : 20,
      ),
    );

    final titulo = Text(
      entro ? 'Entró plata' : 'Salió plata',
      style: TextStyle(
        fontSize: enDialogo ? 21 : 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: Tokens.texto,
      ),
    );

    if (!enDialogo) {
      return Row(
        children: [
          icono,
          const SizedBox(width: 12),
          Expanded(child: titulo),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 22, 18, 20),
      decoration: BoxDecoration(
        color: entro ? Tokens.entroSuave : Tokens.salioSuave,
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: [
          icono,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titulo,
                const SizedBox(height: 2),
                Text(
                  entro
                      ? 'Una venta, un cobro o cualquier plata que llegó'
                      : 'Una compra, un pago o cualquier plata que se fue',
                  style: const TextStyle(fontSize: 13, color: Tokens.texto2),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close_rounded, size: 22),
            onPressed: onCerrar,
          ),
        ],
      ),
    );
  }
}

/// Las categorías como fichas.
///
/// En una entrada son cuatro y nada más: Ventas, Cobros de fiado, Adelanto de
/// cliente y Otros —que abre el plan contable—. En una salida van las de todos
/// los días, las que agregó el usuario, el menú "Otra" con el resto agrupado,
/// y el "+" para agregar una nueva.
class CategoriasRegistro extends StatelessWidget {
  const CategoriasRegistro({
    super.key,
    required this.tipo,
    required this.elegida,
    required this.onElegir,
    this.onAgregar,
  });

  final Tipo tipo;
  final String? elegida;
  final ValueChanged<Categoria> onElegir;

  /// El "+". Null donde no se ofrece.
  final VoidCallback? onAgregar;

  @override
  Widget build(BuildContext context) {
    // Se lee del estado para redibujar cuando se agrega una categoría.
    context.watch<EstadoCaja>();

    final visibles = [
      ...Categoria.comunesDe(tipo),
      ...Categoria.propiasDe(tipo),
    ];
    final resto = Categoria.restoDe(tipo);

    // Si la elegida no está a la vista, se agrega a las fichas para que se
    // vea seleccionada en vez de quedar escondida dentro del menú.
    final extra = elegida != null && !visibles.any((c) => c.id == elegida)
        ? Categoria.porId(elegida!)
        : null;

    final grupos = <GrupoCategoria, List<Categoria>>{};
    for (final c in resto) {
      grupos.putIfAbsent(c.grupo, () => []).add(c);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in [...visibles, ?extra])
          ChoiceChip(
            label: Text(c.etiqueta),
            selected: elegida == c.id,
            onSelected: (_) => onElegir(c),
          ),
        if (grupos.isNotEmpty)
          MenuAnchor(
            alignmentOffset: const Offset(0, 6),
            menuChildren: [
              for (final grupo in grupos.keys)
                SubmenuButton(
                  menuChildren: [
                    for (final c in grupos[grupo]!)
                      MenuItemButton(
                        onPressed: () => onElegir(c),
                        child: Text(c.etiqueta),
                      ),
                  ],
                  child: Text(grupo.etiqueta),
                ),
            ],
            builder: (context, menu, _) => ActionChip(
              avatar: const Icon(Icons.more_horiz_rounded, size: 18),
              label: const Text('Otra'),
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            ),
          ),
        if (onAgregar != null)
          Tooltip(
            message: 'Agregar una categoría nueva',
            child: ActionChip(
              label: const Icon(
                Icons.add_rounded,
                size: 18,
                color: Tokens.marca,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              side: BorderSide(
                color: Tokens.marca.withValues(alpha: 0.55),
                style: BorderStyle.solid,
              ),
              backgroundColor: Tokens.marcaSuave,
              onPressed: onAgregar,
            ),
          ),
      ],
    );
  }
}

/// Los medios de pago, todos a la vista: son seis y cubren todo lo que usa
/// un negocio. Antes había un menú "Otro" con tarjeta de crédito, cheque y
/// "otro medio"; escondía justo uno que sí se usa.
class MediosRegistro extends StatelessWidget {
  const MediosRegistro({
    super.key,
    required this.elegido,
    required this.onElegir,
  });

  final MedioPago elegido;
  final ValueChanged<MedioPago> onElegir;

  @override
  Widget build(BuildContext context) {
    // Un medio que ya no se ofrece (cheque, "otro") sólo aparece si es el que
    // viene recordado, para que no quede elegido algo invisible.
    final extra = MedioPago.disponibles.contains(elegido) ? null : elegido;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in [...MedioPago.disponibles, ?extra])
          ChoiceChip(
            label: Text(m.etiqueta),
            selected: elegido == m,
            onSelected: (_) => onElegir(m),
          ),
      ],
    );
  }
}

/// Línea informativa del IGV que corresponde automáticamente a la categoría.
class LineaIgv extends StatelessWidget {
  const LineaIgv({required this.centavos, super.key});

  final int centavos;

  @override
  Widget build(BuildContext context) {
    final desglose = Igv.desagregar(centavos);
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 16,
            color: Tokens.texto2,
          ),
          const SizedBox(width: 6),
          Text(
            'Incluye IGV ${Formato.soles(desglose.igv / 100)}',
            style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
          ),
        ],
      ),
    );
  }
}

/// La sección plegada con los datos que piden los formatos oficiales.
class MasDatosRegistro extends StatelessWidget {
  const MasDatosRegistro({
    super.key,
    required this.abierto,
    required this.onCambiar,
    required this.children,
  });

  final bool abierto;
  final ValueChanged<bool> onCambiar;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => onCambiar(!abierto),
          style: TextButton.styleFrom(
            foregroundColor: Tokens.texto2,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 40),
            textStyle: const TextStyle(
              fontFamily: Tokens.tipografia,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: AnimatedRotation(
            turns: abierto ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.expand_more_rounded, size: 18),
          ),
          label: const Text('Datos para el comprobante'),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: abierto
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class EtiquetaRegistro extends StatelessWidget {
  const EtiquetaRegistro(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 13, color: Tokens.texto2),
      ),
    );
  }
}

class AvisoRegistro extends StatelessWidget {
  const AvisoRegistro(this.texto, {super.key, this.bloquea = false});

  final String texto;

  /// En rojo: no es un consejo, es lo que impide guardar.
  final bool bloquea;

  @override
  Widget build(BuildContext context) {
    final fondo = bloquea ? Tokens.salioSuave : const Color(0xFFFFF6E5);
    final borde = bloquea
        ? Tokens.salio.withValues(alpha: 0.35)
        : const Color(0xFFF0DCB4);
    final color = bloquea ? Tokens.salio : const Color(0xFF6B520F);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            bloquea ? Icons.block_rounded : Icons.info_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: bloquea ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
