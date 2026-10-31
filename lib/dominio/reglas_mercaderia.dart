import 'categoria.dart';
import 'importe.dart';
import 'mercaderia.dart';

/// Validación compartida por SQLite y la demo web.
class ReglasMercaderia {
  /// El largo máximo del nombre de un tipo de mercadería. Lo usan el
  /// repositorio y el diálogo, para que los dos digan lo mismo.
  static const largoMaximo = 40;

  static String validarNombre(String nombre) {
    final limpio = Mercaderia.limpiarNombre(nombre);
    if (limpio.isEmpty || limpio.length > largoMaximo) {
      throw ArgumentError(
        'Escribe un nombre de mercadería de 1 a $largoMaximo caracteres.',
      );
    }
    return limpio;
  }

  static void validar({
    required String categoriaId,
    required String? mercaderiaId,
    required int? costoCentavos,
    bool permitirHeredado = false,
  }) {
    final compra = categoriaId == Categoria.mercaderia.id;
    final venta = categoriaId == Categoria.ventas.id;
    if (costoCentavos != null &&
        (costoCentavos < 0 || costoCentavos > Importe.maximoCentavos)) {
      throw ArgumentError('El costo en soles está fuera del límite permitido.');
    }
    if (compra) {
      if (mercaderiaId == null && !permitirHeredado) {
        throw ArgumentError('Elige el tipo de mercadería que compraste.');
      }
      if (costoCentavos != null) {
        throw ArgumentError('En una compra, el costo es su importe sin IGV.');
      }
    } else if (venta) {
      if (mercaderiaId != null && (costoCentavos ?? 0) <= 0) {
        throw ArgumentError(
          'Escribe el costo de la mercadería vendida, mayor que cero.',
        );
      }
      if (mercaderiaId == null && costoCentavos != null && costoCentavos != 0) {
        throw ArgumentError('Elige a qué mercadería corresponde el costo.');
      }
    } else if (mercaderiaId != null || costoCentavos != null) {
      throw ArgumentError(
        'Estos datos solo corresponden a compras o ventas de mercadería.',
      );
    }
  }
}
