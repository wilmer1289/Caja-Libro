import 'package:flutter/material.dart';

/// Construye una vez con `listo` en false y otra vez, al frame siguiente, con
/// `listo` en true.
///
/// Sirve para que los gráficos se dibujen solos al aparecer: se arman en cero
/// y al instante reciben los datos de verdad, y la animación implícita de la
/// biblioteca hace el resto. Sin esto, el gráfico ya está dibujado cuando la
/// pantalla aparece y el momento se pierde.
class AlEntrar extends StatefulWidget {
  const AlEntrar({super.key, required this.constructor});

  final Widget Function(BuildContext context, bool listo) constructor;

  @override
  State<AlEntrar> createState() => _AlEntrarState();
}

class _AlEntrarState extends State<AlEntrar> {
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _listo = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Con "reducir movimiento" no hay nada que dibujar: el dato va completo
    // desde el primer frame.
    final listo = _listo || MediaQuery.disableAnimationsOf(context);
    return widget.constructor(context, listo);
  }
}
