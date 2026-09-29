/// Períodos de un toque para filtrar por fecha (§4.4: "día/semana/mes/rango").
///
/// Cubren casi todo lo que se busca en una bodega sin abrir un calendario.
/// El calendario queda sólo para el caso raro de un rango a medida.
enum Periodo {
  hoy('Hoy'),
  semana('Esta semana'),
  mes('Este mes'),
  mesPasado('Mes pasado'),
  anio('Este año');

  const Periodo(this.etiqueta);
  final String etiqueta;

  /// Primer y último día del período, ambos incluidos, sin hora.
  (DateTime desde, DateTime hasta) rango([DateTime? ahora]) {
    final hoy = _soloFecha(ahora ?? DateTime.now());

    return switch (this) {
      Periodo.hoy => (hoy, hoy),
      // La semana empieza el lunes, como en el calendario de acá.
      Periodo.semana => (
        hoy.subtract(Duration(days: hoy.weekday - DateTime.monday)),
        hoy,
      ),
      Periodo.mes => (DateTime(hoy.year, hoy.month), hoy),
      // Día 0 del mes actual = último día del mes anterior. Así no hay que
      // saber cuántos días tiene cada mes ni si el año es bisiesto.
      Periodo.mesPasado => (
        DateTime(hoy.year, hoy.month - 1),
        DateTime(hoy.year, hoy.month, 0),
      ),
      Periodo.anio => (DateTime(hoy.year), hoy),
    };
  }

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
}
