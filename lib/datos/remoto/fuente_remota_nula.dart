import '../../dominio/movimiento.dart';
import 'fuente_remota.dart';

/// Implementación vacía: la app corre 100% local mientras Firebase no esté
/// conectado. Sirve además para las pruebas, que no deberían tocar la red.
class FuenteRemotaNula implements FuenteRemota {
  const FuenteRemotaNula();

  @override
  Future<bool> disponible() async => false;

  @override
  Future<void> subir(List<Movimiento> movimientos) async {}

  @override
  Future<List<Movimiento>> bajar({DateTime? desde}) async => const [];
}
