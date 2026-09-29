import '../../dominio/movimiento.dart';

/// Contrato del respaldo en la nube.
///
/// Está separado a propósito: hoy detrás hay un no-op, mañana habrá Firestore,
/// y el repositorio y la UI no cambian ni una línea. También permite que el
/// resto del equipo avance sin tener las credenciales de Firebase.
abstract interface class FuenteRemota {
  /// ¿Hay con qué sincronizar ahora mismo?
  Future<bool> disponible();

  /// Sube los movimientos que el equipo todavía no respaldó.
  Future<void> subir(List<Movimiento> movimientos);

  /// Trae lo que cambió en la nube desde la última sincronización.
  /// Si `desde` es null, trae todo (primer arranque de un equipo nuevo).
  Future<List<Movimiento>> bajar({DateTime? desde});
}
