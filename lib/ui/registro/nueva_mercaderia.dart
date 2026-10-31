import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/tema.dart';
import '../../dominio/mercaderia.dart';
import '../../dominio/reglas_mercaderia.dart';
import '../../estado/estado_caja.dart';

/// Diálogo de creación usado también por el botón + del selector de P6.
class NuevaMercaderiaDialogo extends StatefulWidget {
  const NuevaMercaderiaDialogo({super.key});

  static Future<Mercaderia?> abrir(BuildContext context) =>
      showDialog<Mercaderia>(
        context: context,
        barrierColor: Tokens.cromo.withValues(alpha: .35),
        builder: (_) => const NuevaMercaderiaDialogo(),
      );

  @override
  State<NuevaMercaderiaDialogo> createState() => _NuevaMercaderiaDialogoState();
}

class _NuevaMercaderiaDialogoState extends State<NuevaMercaderiaDialogo> {
  final _nombre = TextEditingController();
  bool _intento = false;
  bool _guardando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  String? get _error {
    if (!_intento) return null;
    final nombre = Mercaderia.limpiarNombre(_nombre.text);
    if (nombre.isEmpty) return 'Escribe un nombre';
    if (nombre.length > ReglasMercaderia.largoMaximo) {
      return 'Usa ${ReglasMercaderia.largoMaximo} caracteres o menos';
    }
    final clave = Mercaderia.claveDe(nombre);
    if (context.read<EstadoCaja>().mercaderias.any(
      (m) => Mercaderia.claveDe(m.nombre) == clave,
    )) {
      return 'Ya existe una mercadería con ese nombre';
    }
    return null;
  }

  Future<void> _agregar() async {
    if (_guardando) return;
    setState(() {
      _intento = true;
      _errorGeneral = null;
    });
    if (_error != null) return;
    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    try {
      final creada = await context.read<EstadoCaja>().agregarMercaderia(
        _nombre.text,
      );
      if (mounted) navegador.pop(creada);
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _errorGeneral = '${e.message}');
    } catch (e) {
      if (mounted) setState(() => _errorGeneral = 'No se pudo guardar. $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
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
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Nueva mercadería',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Tokens.texto,
                    ),
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
            const Padding(
              padding: EdgeInsets.only(bottom: 7),
              child: Text(
                '¿Cómo se llama?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Tokens.texto,
                ),
              ),
            ),
            TextField(
              controller: _nombre,
              autofocus: true,
              maxLength: ReglasMercaderia.largoMaximo,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'tela, pintura',
                errorText: _error,
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
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
