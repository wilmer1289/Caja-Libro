/// Una línea del conteo físico de inventario.
class FilaConteoFisico {
  const FilaConteoFisico({
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.unidad,
    required this.cantidadSistema,
    required this.valorSistema,
    required this.cantidadContada,
    required this.diferenciaValor,
  });

  final String productoId;
  final String codigo;
  final String producto;
  final String unidad;
  final int cantidadSistema;
  final int valorSistema;
  final int cantidadContada;

  /// Positivo si sobra valor, negativo si falta.
  final int diferenciaValor;

  int get diferenciaCantidad => cantidadContada - cantidadSistema;
  int get valorContado => valorSistema + diferenciaValor;
  bool get tieneDiferencia => diferenciaCantidad != 0;
}

/// El resultado del conteo que se confirma y queda documentado en un acta.
class ConteoFisico {
  ConteoFisico({required this.fecha, required List<FilaConteoFisico> filas})
    : filas = List.unmodifiable(filas);

  final DateTime fecha;
  final List<FilaConteoFisico> filas;

  List<FilaConteoFisico> get conDiferencia =>
      filas.where((fila) => fila.tieneDiferencia).toList();

  int get valorSistema =>
      filas.fold(0, (total, fila) => total + fila.valorSistema);

  int get valorContado =>
      filas.fold(0, (total, fila) => total + fila.valorContado);

  int get diferenciaValor => valorContado - valorSistema;
}
