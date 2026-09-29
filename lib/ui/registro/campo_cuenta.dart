import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../../dominio/enums.dart';
import '../../dominio/pcge.dart';

/// Busca y elige una cuenta del Plan Contable mientras se escribe.
///
/// Es el "¿En qué exactamente?" de la categoría "Otros" y de las categorías
/// nuevas: todo lo que se registra termina en el Formato 1.1 con su cuenta,
/// así que en vez de mandarlo a una cuenta genérica se busca la de verdad.
/// El usuario escribe como habla —"alquiler", "prestamo", "intereses"— y la
/// lista le muestra las cuentas que calzan, con el código y su ubicación.
///
/// En una entrada ordena primero los ingresos (7) y en una salida los gastos
/// (6); lo demás sigue apareciendo, más abajo.
class CampoCuentaPcge extends StatefulWidget {
  const CampoCuentaPcge({
    super.key,
    required this.tipo,
    required this.elegida,
    required this.onElegir,
    this.error,
    this.pista,
  });

  final Tipo tipo;

  /// El código elegido, o null si todavía no se eligió.
  final String? elegida;
  final ValueChanged<String?> onElegir;
  final String? error;

  /// Texto de ejemplo del campo.
  final String? pista;

  /// Qué elementos del plan van primero según el sentido de la plata.
  static List<String> prioridadDe(Tipo tipo) => tipo == Tipo.entro
      ? const ['7', '4', '5', '1']
      : const ['6', '4', '3', '2', '1'];

  @override
  State<CampoCuentaPcge> createState() => _CampoCuentaPcgeState();
}

class _CampoCuentaPcgeState extends State<CampoCuentaPcge> {
  final _texto = TextEditingController();
  final _foco = FocusNode();

  @override
  void dispose() {
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _elegir(String codigo) {
    _texto.clear();
    widget.onElegir(codigo);
  }

  void _cambiar() {
    widget.onElegir(null);
    // Vuelve a abrir la búsqueda para elegir otra sin un toque de más.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _foco.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final elegida = widget.elegida;
    if (elegida != null) {
      return _CuentaElegida(codigo: elegida, onCambiar: _cambiar);
    }

    final pcge = Pcge.instancia;

    return LayoutBuilder(
      builder: (context, medidas) => RawAutocomplete<String>(
        textEditingController: _texto,
        focusNode: _foco,
        optionsBuilder: (valor) => pcge.buscarContrapartida(
          valor.text,
          primero: CampoCuentaPcge.prioridadDe(widget.tipo),
        ),
        displayStringForOption: (codigo) =>
            '$codigo · ${pcge.denominacion(codigo)}',
        onSelected: _elegir,
        fieldViewBuilder: (context, controlador, foco, alEnviar) => TextField(
          controller: controlador,
          focusNode: foco,
          onSubmitted: (_) => alEnviar(),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText:
                widget.pista ?? 'Escribe y elige, ej. alquiler, intereses…',
            errorText: widget.error,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
          ),
        ),
        optionsViewBuilder: (context, alElegir, opciones) => Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: Tokens.superficie,
              elevation: 10,
              shadowColor: const Color(0x552A1A0C),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 300,
                  maxWidth: medidas.maxWidth,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Tokens.borde),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: opciones.length,
                    itemBuilder: (context, i) {
                      final codigo = opciones.elementAt(i);
                      final resaltada =
                          AutocompleteHighlightedOption.of(context) == i;
                      return _Opcion(
                        codigo: codigo,
                        resaltada: resaltada,
                        onTap: () => alElegir(codigo),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un renglón de la lista: el código en naranja, el nombre, y de dónde
/// cuelga. "Terceros" solo no dice nada; "Alquileres › Edificaciones" sí.
class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.codigo,
    required this.resaltada,
    required this.onTap,
  });

  final String codigo;
  final bool resaltada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pcge = Pcge.instancia;
    final padre = pcge.ruta(codigo).split(' › ');

    return InkWell(
      onTap: onTap,
      child: Container(
        color: resaltada ? Tokens.marcaSuave : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 58,
              child: Text(
                codigo,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Tokens.marcaOscura,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pcge.denominacion(codigo),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Tokens.texto,
                    ),
                  ),
                  if (padre.length > 1)
                    Text(
                      padre.sublist(0, padre.length - 1).join(' › '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Tokens.texto2,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La cuenta ya elegida, como una ficha con su código y un botón para
/// cambiarla. Dice en qué formato va a salir: es la razón de elegirla.
class _CuentaElegida extends StatelessWidget {
  const _CuentaElegida({required this.codigo, required this.onCambiar});

  final String codigo;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    final pcge = Pcge.instancia;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: Tokens.marcaSuave,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.marca.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Tokens.marca,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              codigo,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pcge.denominacion(codigo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Tokens.texto,
                  ),
                ),
                const Text(
                  'Así sale en el Formato 1.1 / 1.2',
                  style: TextStyle(fontSize: 11.5, color: Tokens.texto2),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cambiar la cuenta',
            onPressed: onCambiar,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
