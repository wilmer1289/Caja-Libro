import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/tema.dart';
import '../../dominio/categoria.dart';
import '../../dominio/enums.dart';
import '../../estado/estado_caja.dart';
import 'campo_cuenta.dart';

/// La ventanita del "+" en "¿En qué?": agrega una categoría que no está en
/// la lista ("Movilidad", "Publicidad"…) con su cuenta del plan contable.
///
/// Pide lo mínimo: cómo se llama, a qué cuenta va y si trae IGV. Queda
/// guardada y aparece como ficha la próxima vez.
class NuevaCategoriaDialogo extends StatefulWidget {
  const NuevaCategoriaDialogo({super.key, required this.tipo});

  final Tipo tipo;

  /// Devuelve la categoría creada, o null si se canceló.
  static Future<Categoria?> abrir(BuildContext context, Tipo tipo) {
    return showDialog<Categoria>(
      context: context,
      barrierColor: Tokens.cromo.withValues(alpha: 0.35),
      builder: (_) => NuevaCategoriaDialogo(tipo: tipo),
    );
  }

  @override
  State<NuevaCategoriaDialogo> createState() => _NuevaCategoriaDialogoState();
}

class _NuevaCategoriaDialogoState extends State<NuevaCategoriaDialogo> {
  final _nombre = TextEditingController();
  String? _cuenta;
  bool _conIgv = false;
  bool _intento = false;
  bool _guardando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  String? get _errorNombre {
    if (!_intento) return null;
    if (_nombre.text.trim().isEmpty) return 'Ponle un nombre';
    return null;
  }

  String? get _errorCuenta {
    if (!_intento) return null;
    if (_cuenta == null) return 'Elige la cuenta de la lista';
    return null;
  }

  Future<void> _agregar() async {
    if (_guardando) return;
    setState(() {
      _intento = true;
      _errorGeneral = null;
    });
    if (_errorNombre != null || _errorCuenta != null) return;

    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    try {
      final nueva = await context.read<EstadoCaja>().agregarCategoria(
        etiqueta: _nombre.text,
        tipo: widget.tipo,
        cuenta: _cuenta!,
        afectoIgv: _conIgv,
      );
      if (!mounted) return;
      navegador.pop(nueva);
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _errorGeneral = '${e.message}');
    } catch (e) {
      if (mounted) {
        setState(() => _errorGeneral = 'No se pudo guardar. $e');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entro = widget.tipo == Tipo.entro;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Tokens.marca,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nueva categoría',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Tokens.texto,
                          ),
                        ),
                        Text(
                          entro
                              ? 'Para lo que te entra seguido y no está en la lista'
                              : 'Para lo que pagas seguido y no está en la lista',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Tokens.texto2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _Etiqueta('¿Cómo se llama?'),
              TextField(
                controller: _nombre,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: entro
                      ? 'Ej. Alquiler de local, Intereses'
                      : 'Ej. Movilidad, Publicidad, Gas',
                  errorText: _errorNombre,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const _Etiqueta('¿A qué cuenta del plan contable va?'),
              CampoCuentaPcge(
                tipo: widget.tipo,
                elegida: _cuenta,
                error: _errorCuenta,
                onElegir: (c) => setState(() => _cuenta = c),
                pista: entro
                    ? 'Escribe y elige, ej. alquileres, intereses…'
                    : 'Escribe y elige, ej. transporte, publicidad…',
              ),
              const SizedBox(height: 14),
              Material(
                color: Tokens.fondo,
                borderRadius: BorderRadius.circular(Tokens.radio),
                child: SwitchListTile(
                  value: _conIgv,
                  onChanged: (v) => setState(() => _conIgv = v),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Tokens.radio),
                  ),
                  title: const Text(
                    'El monto trae IGV',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Tokens.texto,
                    ),
                  ),
                  subtitle: const Text(
                    'Si normalmente te dan factura por esto',
                    style: TextStyle(fontSize: 12, color: Tokens.texto2),
                  ),
                ),
              ),
              if (_errorGeneral != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorGeneral!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Tokens.salio,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _guardando ? null : _agregar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Tokens.texto,
        ),
      ),
    );
  }
}
