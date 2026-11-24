import 'conteo_fisico.dart';
import 'negocio.dart';

/// Datos inmutables para mostrar, imprimir y archivar un conteo de inventario.
class ActaConteo {
  const ActaConteo({
    required this.negocio,
    required this.conteo,
    required this.responsable,
    required this.registradaEn,
    this.anual = false,
  });

  final Negocio negocio;
  final ConteoFisico conteo;
  final String responsable;
  final DateTime registradaEn;
  final bool anual;
}
