import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../../dominio/libro_diario.dart';
import '../../dominio/pcge.dart';

/// Ayuda de lectura del PCGE. Las denominaciones proceden de las cadenas que
/// el motor ya armó con Pcge.cadena; esta vista no calcula contabilidad.
class EntenderCodigos extends StatelessWidget {
  const EntenderCodigos({super.key, required this.libro});

  final LibroDiario libro;

  @override
  Widget build(BuildContext context) {
    final cadenasUsadas = <String, List<CuentaDiario>>{};
    for (final asiento in libro.asientos) {
      for (final etapa in asiento.etapas) {
        for (final linea in etapa.lineas) {
          cadenasUsadas[linea.cuenta.codigo] = linea.cadena;
        }
      }
    }
    final ejemplos = <List<CuentaDiario>>[
      _ejemplo('40111', const ['40', '401', '4011', '40111']),
      _ejemplo('70121', const ['70', '701', '7012', '70121']),
    ];
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.account_tree_outlined, color: Tokens.marca),
        title: const Text(
          'Cómo leer un código',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'De lo general a lo específico; cada fila agrega un nivel.',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final ejemplo in ejemplos)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _Cadena(cuentas: ejemplo),
            ),
          if (cadenasUsadas.isNotEmpty) ...[
            const Divider(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cuentas usadas en este período',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final cadena
                in cadenasUsadas.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key)))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _Cadena(cuentas: cadena.value),
              ),
          ],
        ],
      ),
    );
  }

  static List<CuentaDiario> _ejemplo(String terminal, List<String> codigos) {
    final cadena = Pcge.instancia.cadena(terminal);
    final porCodigo = {
      for (final c in cadena) c.codigo: CuentaDiario(c.codigo, c.nombre),
    };
    return [
      for (final codigo in codigos)
        if (porCodigo[codigo] != null) porCodigo[codigo]!,
    ];
  }
}

class _Cadena extends StatelessWidget {
  const _Cadena({required this.cuentas});
  final List<CuentaDiario> cuentas;
  @override
  Widget build(BuildContext context) => Column(
    children: [for (final cuenta in cuentas) _FilaCuenta(cuenta: cuenta)],
  );
}

class _FilaCuenta extends StatelessWidget {
  const _FilaCuenta({required this.cuenta});
  final CuentaDiario cuenta;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: (cuenta.nivel - 2) * 12.0,
      top: 4,
      bottom: 4,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cuenta.codigo,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Tokens.texto,
          ),
        ),
        const SizedBox(width: 9),
        const Text('›', style: TextStyle(color: Tokens.texto2)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            cuenta.denominacion,
            softWrap: true,
            style: const TextStyle(color: Tokens.texto2),
          ),
        ),
      ],
    ),
  );
}
