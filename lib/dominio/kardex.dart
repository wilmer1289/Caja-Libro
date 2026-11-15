import 'linea_kardex.dart';
import 'mercaderia.dart';
import 'periodo.dart';

export 'linea_kardex.dart';

DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

// Redondeo comercial sobre enteros, incluso si el producto excede los 53 bits
// exactos de la plataforma web.
int _parte(int total, int cantidad, int unidades) {
  final divisor = BigInt.from(unidades);
  return ((BigInt.from(total) * BigInt.from(cantidad) + (divisor >> 1)) ~/
          divisor)
      .toInt();
}

class SaldoAlmacen {
  const SaldoAlmacen(this.cantidad, this.costo);
  static const cero = SaldoAlmacen(0, 0);
  final int cantidad, costo;
  double get costoUnitario => cantidad == 0 ? 0 : costo / cantidad * 10;

  int costoSalida(int unidades, String producto) {
    if (unidades <= 0) throw ArgumentError.value(unidades, 'cantidad');
    if (unidades > cantidad) {
      throw StateError(
        'Stock insuficiente de $producto: hay ${cantidad / 1000} y se solicitan ${unidades / 1000}.',
      );
    }
    return unidades == cantidad ? costo : _parte(costo, unidades, cantidad);
  }
}

class FilaKardex {
  const FilaKardex(this.linea, this.costoTotal, this.saldo);
  final LineaAlmacen linea;
  final int costoTotal;
  final SaldoAlmacen saldo;
  int get saldoCantidad => saldo.cantidad;
  int get saldoCosto => saldo.costo;
  double get costoUnitario => costoTotal / linea.cantidad * 10;
  double get costoUnitarioSaldo => saldo.costoUnitario;
}

class AlertaStock {
  const AlertaStock(this.producto, this.cantidad);
  final Mercaderia producto;
  final int cantidad;
  String get mensaje => cantidad == 0 ? 'Sin stock' : 'Queda poco';
}

/// Reconstruye los saldos a partir de líneas vigentes. No persiste filas.
class Kardex {
  Kardex._();
  final _porId = <String, FilaKardex>{};
  final _porProducto = <String, List<FilaKardex>>{};
  Iterable<String> get productos => _porProducto.keys;

  static Kardex de(List<LineaAlmacen> lineas) {
    final motor = Kardex._();
    final vigentes = lineas.where((l) => !l.anulada).toList();
    // El índice conserva el orden de las líneas dentro de un mismo registro.
    final orden = vigentes.indexed.toList()
      ..sort((a, b) {
        final fecha = _dia(a.$2.fecha).compareTo(_dia(b.$2.fecha));
        if (fecha != 0) return fecha;
        final numero = a.$2.numero.compareTo(b.$2.numero);
        return numero != 0 ? numero : a.$1.compareTo(b.$1);
      });
    final devuelto = <String, int>{};
    for (final (_, linea) in orden) {
      if (motor._porId.containsKey(linea.id)) {
        throw StateError('Línea duplicada: ${linea.id}');
      }
      final historial = motor._porProducto.putIfAbsent(
        linea.mercaderiaId,
        () => [],
      );
      final previo = historial.lastOrNull?.saldo ?? SaldoAlmacen.cero;
      final costo = motor._valuar(linea, previo, devuelto);
      final signo = linea.entrada ? 1 : -1;
      final saldo = SaldoAlmacen(
        previo.cantidad + signo * linea.cantidad,
        previo.costo + signo * costo,
      );
      if (saldo.costo < 0 || (saldo.cantidad == 0 && saldo.costo != 0)) {
        throw StateError(
          'El costo de la devolución ${linea.id} es incompatible con el saldo disponible.',
        );
      }
      final fila = FilaKardex(linea, costo, saldo);
      historial.add(fila);
      motor._porId[linea.id] = fila;
    }
    return motor;
  }

  int _valuar(LineaAlmacen l, SaldoAlmacen previo, Map<String, int> devuelto) {
    if (l.cantidad <= 0) throw ArgumentError.value(l.cantidad, 'cantidad');
    final op = l.operacion;
    final entrada = switch (op) {
      OperacionAlmacen.compra ||
      OperacionAlmacen.saldoInicial ||
      OperacionAlmacen.devolucionRecibida => true,
      OperacionAlmacen.ajuste => l.entrada,
      _ => false,
    };
    if (l.entrada != entrada) {
      throw StateError('Dirección incorrecta en ${l.id}.');
    }
    if (l.gastoCompraAsignado < 0 ||
        (op != OperacionAlmacen.compra && l.gastoCompraAsignado != 0)) {
      throw StateError('Gasto de compra inválido en ${l.id}.');
    }
    final alPromedio = entrada
        ? null
        : previo.costoSalida(l.cantidad, l.mercaderiaId);
    if (op == OperacionAlmacen.devolucionRecibida ||
        op == OperacionAlmacen.devolucionEntregada) {
      final origen = _porId[l.origenId];
      final esperada = entrada
          ? OperacionAlmacen.venta
          : OperacionAlmacen.compra;
      if (origen == null ||
          origen.linea.operacion != esperada ||
          origen.linea.mercaderiaId != l.mercaderiaId) {
        throw StateError('Origen inválido de la devolución ${l.id}.');
      }
      final id = origen.linea.id;
      final anterior = devuelto[id] ?? 0;
      final acumulado = anterior + l.cantidad;
      final unidades = origen.linea.cantidad;
      if (acumulado > unidades) {
        throw StateError('La devolución supera la cantidad de $id.');
      }
      devuelto[id] = acumulado;
      return _parte(origen.costoTotal, acumulado, unidades) -
          _parte(origen.costoTotal, anterior, unidades);
    }
    if (!entrada) return alPromedio!;
    if (op == OperacionAlmacen.ajuste && previo.cantidad > 0) {
      return _parte(previo.costo, l.cantidad, previo.cantidad);
    }
    final costo = l.costoTotal;
    if (costo == null || costo < 0) {
      throw StateError('Falta un costo válido en ${l.id}.');
    }
    return costo + l.gastoCompraAsignado;
  }

  List<FilaKardex> filas(
    String mercaderiaId, {
    Periodo? periodo,
    DateTime? referencia,
  }) {
    final rango = periodo?.rango(referencia);
    return List.unmodifiable(
      (_porProducto[mercaderiaId] ?? <FilaKardex>[]).where(
        (f) => rango == null || _enRango(f, rango),
      ),
    );
  }

  bool _enRango(FilaKardex f, (DateTime, DateTime) rango) {
    final dia = _dia(f.linea.fecha);
    return !dia.isBefore(rango.$1) && !dia.isAfter(rango.$2);
  }

  SaldoAlmacen saldo(String mercaderiaId, {DateTime? al}) {
    final historial = _porProducto[mercaderiaId];
    if (historial == null) return SaldoAlmacen.cero;
    if (al == null) return historial.last.saldo;
    final corte = _dia(al);
    for (final fila in historial.reversed) {
      if (!_dia(fila.linea.fecha).isAfter(corte)) return fila.saldo;
    }
    return SaldoAlmacen.cero;
  }

  int costoDeSalida(String mercaderiaId, int cantidad, DateTime fecha) =>
      saldo(mercaderiaId, al: fecha).costoSalida(cantidad, mercaderiaId);
  int costoDe(String lineaId) =>
      (_porId[lineaId] ??
              (throw StateError('Línea de almacén desconocida: $lineaId')))
          .costoTotal;

  Map<String, int> costoDeVentas(Periodo periodo, {DateTime? referencia}) {
    final cuentas = <String, int>{};
    final rango = periodo.rango(referencia);
    for (final fila in _porId.values.where((f) => _enRango(f, rango))) {
      final l = fila.linea;
      final devolucion = l.operacion == OperacionAlmacen.devolucionRecibida;
      if (!devolucion && l.operacion != OperacionAlmacen.venta) continue;
      final venta = devolucion ? _porId[l.origenId]!.linea : l;
      final cuenta = venta.cuentaCosto ?? '69121';
      cuentas[cuenta] =
          (cuentas[cuenta] ?? 0) +
          (devolucion ? -fila.costoTotal : fila.costoTotal);
    }
    return cuentas;
  }

  int valorTotal({DateTime? al}) =>
      productos.fold(0, (s, id) => s + saldo(id, al: al).costo);
  Map<String, SaldoAlmacen> saldosFinDeAnio(int anio) => {
    for (final id in productos.where(
      (id) => _porProducto[id]!.first.linea.fecha.year <= anio,
    ))
      id: saldo(id, al: DateTime(anio, 12, 31)),
  };

  List<AlertaStock> alertas(
    List<Mercaderia> catalogo, {
    Map<String, int> minimos = const {},
  }) => [
    for (final p in catalogo)
      if (saldo(p.id).cantidad <= (minimos[p.id] ?? 0))
        AlertaStock(p, saldo(p.id).cantidad),
  ];

  List<Mercaderia> sinMovimiento(
    List<Mercaderia> catalogo,
    Periodo periodo, {
    DateTime? referencia,
  }) => catalogo
      .where(
        (p) => filas(p.id, periodo: periodo, referencia: referencia).isEmpty,
      )
      .toList();

  /// Margen bruto de las ventas en centavos, usando el importe neto de cada línea.
  int margenPorProducto(String id, Periodo periodo, {DateTime? referencia}) {
    var margen = 0;
    for (final f in filas(id, periodo: periodo, referencia: referencia)) {
      if (f.linea.operacion == OperacionAlmacen.venta) {
        final ingreso =
            f.linea.importe ??
            (throw StateError('Falta el importe de venta en ${f.linea.id}.'));
        margen += ingreso - f.costoTotal;
      }
    }
    return margen;
  }
}
