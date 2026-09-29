import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/efectivo.dart';

/// Billetes y monedas con su cantidad: para decir con qué pagó un cliente,
/// qué vuelto se le dio, o contar la caja en un arqueo.
///
/// Cada ficha tiene − y + para lo de todos los días (dos de 50, uno de 10) y
/// un campo para escribir el número cuando son muchas (57 monedas de un sol
/// no se cuentan a toques).
class ConteoEditor extends StatefulWidget {
  const ConteoEditor({
    super.key,
    required this.conteo,
    required this.onCambiar,
    this.estimado,
  });

  final Conteo conteo;
  final ValueChanged<Conteo> onCambiar;

  /// Cuántos debería haber de cada uno, si se sabe. Sale como pista debajo de
  /// cada ficha, en el arqueo.
  final Conteo? estimado;

  @override
  State<ConteoEditor> createState() => _ConteoEditorState();
}

class _ConteoEditorState extends State<ConteoEditor> {
  final _textos = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final d in Denominacion.todas) {
      _textos[d] = TextEditingController(text: _texto(widget.conteo, d));
    }
  }

  @override
  void didUpdateWidget(ConteoEditor anterior) {
    super.didUpdateWidget(anterior);
    // Si el conteo cambió desde afuera ("monto exacto", "sugerir vuelto"),
    // los campos se ponen al día. Si el cambio vino de lo que se está
    // escribiendo, el texto ya dice lo mismo y no se toca: moverlo le
    // saltaría el cursor a quien escribe.
    for (final d in Denominacion.todas) {
      final c = _textos[d]!;
      if ((int.tryParse(c.text) ?? 0) != widget.conteo.cantidadDe(d)) {
        c.text = _texto(widget.conteo, d);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _textos.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _texto(Conteo conteo, int d) {
    final n = conteo.cantidadDe(d);
    return n == 0 ? '' : '$n';
  }

  void _poner(int d, int cantidad) =>
      widget.onCambiar(widget.conteo.con(d, cantidad < 0 ? 0 : cantidad));

  @override
  Widget build(BuildContext context) {
    Widget grupo(String titulo, List<int> denominaciones) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: Tokens.texto2,
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final d in denominaciones)
              _Ficha(
                denominacion: d,
                cantidad: widget.conteo.cantidadDe(d),
                estimado: widget.estimado?.cantidadDe(d),
                texto: _textos[d]!,
                onPoner: (n) => _poner(d, n),
              ),
          ],
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        grupo('Billetes', Denominacion.billetes),
        const SizedBox(height: 14),
        grupo('Monedas', Denominacion.monedas),
      ],
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({
    required this.denominacion,
    required this.cantidad,
    required this.texto,
    required this.onPoner,
    this.estimado,
  });

  final int denominacion;
  final int cantidad;
  final int? estimado;
  final TextEditingController texto;
  final ValueChanged<int> onPoner;

  @override
  Widget build(BuildContext context) {
    final activa = cantidad > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 150,
      padding: const EdgeInsets.fromLTRB(10, 9, 6, 6),
      decoration: BoxDecoration(
        color: activa ? Tokens.marcaSuave : Tokens.superficie,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(
          color: activa ? Tokens.marca.withValues(alpha: 0.5) : Tokens.borde,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Muestra(denominacion: denominacion),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  Denominacion.etiqueta(denominacion),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Tokens.texto,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _Boton(
                icono: Icons.remove_rounded,
                onTap: cantidad == 0 ? null : () => onPoner(cantidad - 1),
              ),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: texto,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    decoration: const InputDecoration(
                      hintText: '0',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 7),
                    ),
                    onChanged: (v) => onPoner(int.tryParse(v) ?? 0),
                  ),
                ),
              ),
              _Boton(
                icono: Icons.add_rounded,
                onTap: () => onPoner(cantidad + 1),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            // Los dos textos se achican si no entran: "Debería: 150" junto a
            // "S/ 30,000.00" no cabe en una ficha de 150 px.
            child: Row(
              children: [
                if (estimado != null)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      // Negativo quiere decir que se anotó un vuelto con
                      // monedas que el arqueo anterior no contó: el dato no
                      // alcanza para estimar, y un "-1" sólo confunde.
                      child: Text(
                        estimado! < 0 ? 'Debería: ?' : 'Debería: $estimado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: estimado == cantidad
                              ? Tokens.entro
                              : Tokens.texto2,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      activa
                          ? Formato.soles(cantidad * denominacion / 100)
                          : '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Tokens.texto2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
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

class _Boton extends StatelessWidget {
  const _Boton({required this.icono, required this.onTap});

  final IconData icono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: Icon(icono, size: 18),
        style: IconButton.styleFrom(
          foregroundColor: Tokens.texto,
          disabledForegroundColor: Tokens.bordeFuerte,
        ),
      ),
    );
  }
}

/// Un dibujito del billete o la moneda, en su color, para reconocerlo sin
/// leer: el de 10 es verde, el de 100 azul, la moneda de 1 plateada.
class _Muestra extends StatelessWidget {
  const _Muestra({required this.denominacion});

  final int denominacion;

  static Color _color(int d) => switch (d) {
    20000 => const Color(0xFFB65C8E),
    10000 => const Color(0xFF3F74B5),
    5000 => const Color(0xFFD0643B),
    2000 => const Color(0xFFC08A3E),
    1000 => const Color(0xFF4E9A6B),
    500 || 200 => const Color(0xFFCFA944),
    100 => const Color(0xFFB9B6B0),
    _ => const Color(0xFFD4A94C),
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(denominacion);
    if (Denominacion.esBillete(denominacion)) {
      return Container(
        width: 30,
        height: 19,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      // Las de 5 y 2 son bimetálicas: el centro de otro color.
      child: denominacion == 500 || denominacion == 200
          ? Center(
              child: Container(
                width: 11,
                height: 11,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFC9C6C0),
                ),
              ),
            )
          : null,
    );
  }
}
