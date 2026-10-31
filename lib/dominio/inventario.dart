import 'movimiento.dart';
import 'reglas_asiento.dart';

/// Qué mercadería movió una operación, según lo que se anotó al registrarla.
///
/// Es lo que necesitan el asiento 2 y el inventario: en una compra, qué tipo
/// entró al almacén; en una venta, qué tipo salió y cuánto había costado.
class DatoMercaderia {
  /// Una compra o una venta de un tipo de mercadería. En una venta,
  /// `costoCentavos` es lo que costó lo vendido, no su precio.
  const DatoMercaderia({
    required this.id,
    required this.nombre,
    this.costoCentavos,
  }) : assert(id != null && nombre != null),
       esMercaderia = true;

  /// Una venta que no es de mercadería, como un servicio: no tiene costo de
  /// venta ni sale nada del almacén.
  const DatoMercaderia.servicio()
    : id = null,
      nombre = null,
      costoCentavos = null,
      esMercaderia = false;

  /// El tipo de mercadería: "tela", "pintura".
  final String? id;
  final String? nombre;
  final int? costoCentavos;
  final bool esMercaderia;
}

/// Cómo se lee la mercadería de un movimiento. Devuelve null cuando no se
/// sabe, como en lo registrado antes de que existieran los tipos.
///
/// P2 persiste los campos en la base v7. `EstadoCaja.leerMercaderia` los
/// adapta a este contrato, usando el nombre histórico del movimiento:
///
/// ```dart
/// (m) => m.mercaderiaId != null
///     ? DatoMercaderia(
///         id: m.mercaderiaId,
///         nombre: m.mercaderiaNombre ?? m.mercaderiaId!,
///         costoCentavos: m.costoCentavos,
///       )
///     : m.costoCentavos == 0
///     ? const DatoMercaderia.servicio()
///     : null
/// ```
typedef LeerMercaderia = DatoMercaderia? Function(Movimiento m);

/// La lectura de cuando todavía no hay datos de mercadería.
DatoMercaderia? sinDatoDeMercaderia(Movimiento m) => null;

/// Lo que se compró y se vendió de un tipo de mercadería, en soles.
class SaldoMercaderia {
  const SaldoMercaderia({
    required this.id,
    required this.nombre,
    required this.comprado,
    required this.costoVendido,
  });

  final String id;
  final String nombre;

  /// La base de las compras, sin IGV: el costo con que entró al almacén.
  final int comprado;

  /// El costo de lo que se vendió.
  final int costoVendido;

  /// Lo que debería quedar en el almacén. Puede ser negativo si se vendió
  /// mercadería que se compró antes de usar la app.
  int get saldo => comprado - costoVendido;
}

/// El inventario por tipo de mercadería, en soles.
///
/// No cuenta unidades, sólo plata: cuánto costó lo que entró y cuánto lo que
/// salió. Alcanza para el asiento 2 y para avisar cuando el costo de una venta
/// pasa de lo que hay; las cantidades vienen después.
class InventarioMercaderias {
  const InventarioMercaderias._(this._porTipo);

  final Map<String, SaldoMercaderia> _porTipo;

  /// Las compras de mercadería suman su base y las ventas restan su costo.
  /// Lo que no dice qué tipo es no entra: no hay a qué tipo sumarlo.
  static InventarioMercaderias de(
    List<Movimiento> movimientos, {
    LeerMercaderia leer = sinDatoDeMercaderia,
  }) {
    final comprado = <String, int>{};
    final vendido = <String, int>{};
    final nombres = <String, String>{};

    for (final m in movimientos) {
      if (m.eliminado) continue;
      final dato = leer(m);
      final id = dato?.id;
      if (dato == null || id == null) continue;

      switch (ReglasAsiento.para(m).esquema) {
        case Esquema.compraMercaderia:
          comprado.update(
            id,
            (v) => v + m.baseCentavos,
            ifAbsent: () => m.baseCentavos,
          );
          nombres[id] = dato.nombre!;
        case Esquema.venta:
          final costo = dato.costoCentavos ?? 0;
          vendido.update(id, (v) => v + costo, ifAbsent: () => costo);
          nombres[id] = dato.nombre!;
        default:
          break;
      }
    }

    return InventarioMercaderias._({
      for (final id in nombres.keys)
        id: SaldoMercaderia(
          id: id,
          nombre: nombres[id]!,
          comprado: comprado[id] ?? 0,
          costoVendido: vendido[id] ?? 0,
        ),
    });
  }

  /// Los tipos que tuvieron algún movimiento, por nombre.
  List<SaldoMercaderia> get tipos =>
      _porTipo.values.toList()..sort((a, b) => a.nombre.compareTo(b.nombre));

  bool get vacio => _porTipo.isEmpty;

  int comprado(String id) => _porTipo[id]?.comprado ?? 0;
  int costoVendido(String id) => _porTipo[id]?.costoVendido ?? 0;
  int saldo(String id) => _porTipo[id]?.saldo ?? 0;
}
