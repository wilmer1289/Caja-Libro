/// Un tipo de mercadería. No es una categoría contable ni cuenta unidades.
class Mercaderia {
  const Mercaderia({
    required this.id,
    required this.nombre,
    required this.creadoEn,
  });

  final String id;
  final String nombre;
  final DateTime creadoEn;

  static String limpiarNombre(String nombre) =>
      nombre.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String claveDe(String nombre) => limpiarNombre(nombre).toLowerCase();

  Map<String, Object?> aMapa() => {
    'id': id,
    'nombre': nombre,
    'nombre_clave': claveDe(nombre),
    'creado_en': creadoEn.millisecondsSinceEpoch,
  };

  factory Mercaderia.desdeMapa(Map<String, Object?> mapa) => Mercaderia(
    id: mapa['id']! as String,
    nombre: mapa['nombre']! as String,
    creadoEn: DateTime.fromMillisecondsSinceEpoch(mapa['creado_en']! as int),
  );
}
