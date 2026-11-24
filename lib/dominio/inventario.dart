import 'kardex.dart';
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

  /// Una operación con más de un producto. No se agrupa bajo un ID ficticio;
  /// el kardex conserva el detalle por producto y el asiento recibe el costo total.
  const DatoMercaderia.multiple({required this.nombre, this.costoCentavos})
    : id = null,
      esMercaderia = true;

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
    this.saldoAlmacen,
  });

  final String id;
  final String nombre;

  /// La base de las compras, sin IGV: el costo con que entró al almacén.
  final int comprado;

  /// El costo de lo que se vendió.
  final int costoVendido;
  final SaldoAlmacen? saldoAlmacen;

  /// Lo que debería quedar en el almacén. Puede ser negativo si se vendió
  /// mercadería que se compró antes de usar la app.
  int get saldo => saldoAlmacen?.costo ?? comprado - costoVendido;
}

/// El inventario por tipo de mercadería, en soles.
///
/// No cuenta unidades, sólo plata: cuánto costó lo que entró y cuánto lo que
/// salió. Alcanza para el asiento 2 y para avisar cuando el costo de una venta
/// pasa de lo que hay; las cantidades vienen después.
class InventarioMercaderias {
  const InventarioMercaderias._(this._porTipo);

  final Map<String, SaldoMercaderia> _porTipo;

  /// Las compras y ventas conservan su significado en el panel. El saldo
  /// incluye también apertura, mermas, ajustes y devoluciones.
  factory InventarioMercaderias.desdeKardex(
    Kardex kardex, {
    Map<String, String> nombres = const {},
  }) {
    final tipos = <String, SaldoMercaderia>{};
    for (final id in kardex.productos) {
      var comprado = 0;
      var vendido = 0;
      for (final fila in kardex.filas(id)) {
        switch (fila.linea.operacion) {
          case OperacionAlmacen.compra:
            comprado += fila.costoTotal;
          case OperacionAlmacen.devolucionEntregada:
            comprado -= fila.costoTotal;
          case OperacionAlmacen.venta:
            vendido += fila.costoTotal;
          case OperacionAlmacen.devolucionRecibida:
            vendido -= fila.costoTotal;
          default:
            break;
        }
      }
      tipos[id] = SaldoMercaderia(
        id: id,
        nombre: nombres[id] ?? id,
        comprado: comprado,
        costoVendido: vendido,
        saldoAlmacen: kardex.saldo(id),
      );
    }
    return InventarioMercaderias._(tipos);
  }

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

  /// Combina el kardex de líneas con movimientos antiguos de la v7/v8 que
  /// todavía no tenían cantidades. El valor histórico se suma al costo del
  /// saldo actual sin inventar unidades.
  static InventarioMercaderias combinar(
    InventarioMercaderias conLineas,
    InventarioMercaderias heredado,
  ) {
    final resultado = Map<String, SaldoMercaderia>.of(conLineas._porTipo);
    for (final entrada in heredado._porTipo.entries) {
      final anterior = resultado[entrada.key];
      final viejo = entrada.value;
      if (anterior == null) {
        resultado[entrada.key] = viejo;
        continue;
      }
      final saldoLineas = anterior.saldoAlmacen ?? SaldoAlmacen.cero;
      resultado[entrada.key] = SaldoMercaderia(
        id: anterior.id,
        nombre: anterior.nombre,
        comprado: anterior.comprado + viejo.comprado,
        costoVendido: anterior.costoVendido + viejo.costoVendido,
        saldoAlmacen: SaldoAlmacen(
          saldoLineas.cantidad,
          saldoLineas.costo + viejo.saldo,
        ),
      );
    }
    return InventarioMercaderias._(resultado);
  }

  /// Los tipos que tuvieron algún movimiento, por nombre.
  List<SaldoMercaderia> get tipos =>
      _porTipo.values.toList()..sort((a, b) => a.nombre.compareTo(b.nombre));

  bool get vacio => _porTipo.isEmpty;

  int comprado(String id) => _porTipo[id]?.comprado ?? 0;
  int costoVendido(String id) => _porTipo[id]?.costoVendido ?? 0;
  int saldo(String id) => _porTipo[id]?.saldo ?? 0;
}
