import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../../dominio/boleta.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/negocio.dart';
import '../../dominio/recibo.dart';
import '../formatos/recibo_hoja.dart';

/// El último paso cuando se pidió recibo: se ve el recibo tal como va a
/// salir, se revisa quién firma por la caja, y recién ahí se guarda.
///
/// El número se asigna al guardar y no antes: si se imprimiera con número y
/// después se cancelara, el talonario quedaría con un hueco.
class PasoComprobante extends StatefulWidget {
  const PasoComprobante({
    super.key,
    required this.movimiento,
    required this.negocio,
    required this.conBoleta,
    required this.tesorero,
    required this.tesoreroFijo,
    required this.onTesoreroFijo,
  });

  /// El movimiento tal como quedaría, todavía sin número.
  final Movimiento movimiento;
  final Negocio negocio;
  final bool conBoleta;
  final TextEditingController tesorero;
  final bool tesoreroFijo;
  final ValueChanged<bool> onTesoreroFijo;

  @override
  State<PasoComprobante> createState() => _PasoComprobanteState();
}

class _PasoComprobanteState extends State<PasoComprobante> {
  bool _verBoleta = false;

  @override
  Widget build(BuildContext context) {
    final vista = _verBoleta && widget.conBoleta
        ? BoletaVista(
            boleta: Boleta(
              negocio: widget.negocio,
              movimiento: widget.movimiento,
            ),
          )
        : ReciboVista(
            recibo: Recibo(
              negocio: widget.negocio,
              movimiento: widget.movimiento,
            ),
          );

    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Responsable de caja',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Tokens.texto,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: widget.tesorero,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Quién firma por la caja',
            prefixIcon: Icon(Icons.badge_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        CheckboxListTile(
          value: widget.tesoreroFijo,
          onChanged: (v) => widget.onTesoreroFijo(v ?? false),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Tokens.marca,
          title: const Text(
            'Usar este nombre de aquí en adelante',
            style: TextStyle(fontSize: 12.5, color: Tokens.texto),
          ),
        ),
        const SizedBox(height: 10),
        const _Nota(
          icono: Icons.pin_outlined,
          texto:
              'El número del recibo se asigna al guardar: así el '
              'talonario nunca tiene huecos.',
        ),
        const SizedBox(height: 8),
        const _Nota(
          icono: Icons.print_outlined,
          texto:
              'Se imprime original y copia en una hoja A4, para que '
              'firmen los dos.',
        ),
        if (widget.conBoleta) ...[
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Recibo')),
              ButtonSegment(value: true, label: Text('Boleta')),
            ],
            selected: {_verBoleta},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _verBoleta = s.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: Tokens.marcaSuave,
              selectedForegroundColor: Tokens.marcaOscura,
            ),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, medidas) {
        if (medidas.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [panel, const SizedBox(height: 18), vista],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: vista),
            const SizedBox(width: 24),
            SizedBox(width: 240, child: panel),
          ],
        );
      },
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 16, color: Tokens.texto2),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Tokens.texto2,
            ),
          ),
        ),
      ],
    );
  }
}
