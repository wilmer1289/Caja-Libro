import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tema.dart';
import '../../dominio/banco.dart';
import '../../dominio/enums.dart';
import '../../dominio/movimiento.dart';

/// Lo que se puede completar del voucher de un movimiento ya guardado.
typedef DatosVoucher = ({
  String numero,
  String? banco,
  String nombre,
  String documento,
});

/// Completa los datos del voucher que faltaron al registrar: el N° de
/// operación, el banco del otro, su nombre y su documento.
///
/// El monto, la fecha, el vínculo y la cuenta no se tocan: cambian lo que ya
/// salió en el libro, y un libro no se reescribe.
class DatosVoucherDialogo extends StatefulWidget {
  const DatosVoucherDialogo({super.key, required this.movimiento});

  final Movimiento movimiento;

  static Future<DatosVoucher?> abrir(
    BuildContext context,
    Movimiento movimiento,
  ) {
    return showDialog<DatosVoucher>(
      context: context,
      barrierColor: Tokens.cromo.withValues(alpha: 0.40),
      builder: (_) => DatosVoucherDialogo(movimiento: movimiento),
    );
  }

  @override
  State<DatosVoucherDialogo> createState() => _DatosVoucherDialogoState();
}

class _DatosVoucherDialogoState extends State<DatosVoucherDialogo> {
  late final _numero = TextEditingController(
    text: widget.movimiento.numeroTransaccion ?? '',
  );
  late final _nombre = TextEditingController(
    text: widget.movimiento.contraparte ?? '',
  );
  late final _documento = TextEditingController(
    text: widget.movimiento.documentoContraparte ?? '',
  );
  late String? _banco = widget.movimiento.bancoTercero;
  bool _intento = false;

  @override
  void dispose() {
    _numero.dispose();
    _nombre.dispose();
    _documento.dispose();
    super.dispose();
  }

  String? get _errorNumero => _intento && _numero.text.trim().isEmpty
      ? 'Escribe el N° de operación del voucher'
      : null;

  String? get _errorDocumento {
    final doc = _documento.text.trim();
    if (!_intento || doc.isEmpty) return null;
    return doc.length == 8 || doc.length == 11
        ? null
        : 'El DNI tiene 8 dígitos y el RUC 11';
  }

  void _guardar() {
    setState(() => _intento = true);
    if (_errorNumero != null || _errorDocumento != null) return;
    Navigator.of(context).pop((
      numero: _numero.text.trim(),
      banco: _banco,
      nombre: _nombre.text.trim(),
      documento: _documento.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movimiento;
    final opciones = EntidadesBancarias.para(m.medio);

    return AlertDialog(
      title: const Text('Datos del voucher'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _numero,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'N° de operación',
                  errorText: _errorNumero,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: opciones.contains(_banco) ? _banco : null,
                decoration: InputDecoration(
                  labelText: m.medio == MedioPago.yape
                      ? 'App del otro'
                      : 'Banco del otro',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No sé')),
                  for (final b in opciones)
                    DropdownMenuItem(value: b, child: Text(b)),
                ],
                onChanged: (b) => setState(() => _banco = b),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: m.tipo == Tipo.entro ? 'Cliente' : 'Proveedor',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _documento,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: InputDecoration(
                  labelText: 'DNI o RUC',
                  errorText: _errorDocumento,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
