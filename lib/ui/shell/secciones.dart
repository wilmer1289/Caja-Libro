import 'package:flutter/material.dart';

/// Las secciones de la app (§3), con todo lo que hace falta para nombrarlas:
/// la barra lateral, el menú del celular y el encabezado de cada página leen
/// de acá, así un nombre no cambia en un sitio y en otro no.
class Seccion {
  const Seccion({
    required this.etiqueta,
    required this.icono,
    required this.iconoActivo,
    required this.bajada,
  });

  /// Nombre completo, para la barra lateral y el encabezado.
  final String etiqueta;

  final IconData icono;
  final IconData iconoActivo;

  /// Frase bajo el título de la página: qué hay acá, en una línea.
  final String bajada;

  static const resumen = Seccion(
    etiqueta: 'Resumen',
    icono: Icons.space_dashboard_outlined,
    iconoActivo: Icons.space_dashboard_rounded,
    bajada: 'Así va tu caja este mes',
  );

  /// La caja del día: se abre con un monto, el efectivo entra solo y se
  /// cierra contando. Va justo debajo del Resumen porque es lo primero y lo
  /// último que se hace cada día.
  static const arqueo = Seccion(
    etiqueta: 'Arqueo de caja',
    icono: Icons.fact_check_outlined,
    iconoActivo: Icons.fact_check_rounded,
    bajada: 'Abre la caja, mira lo que entra y ciérrala contando',
  );

  /// Caja y banco juntos, como un libro mayor: un solo lugar para saber
  /// cuánto hay en total, cuánto en efectivo y cuánto en cada medio digital.
  ///
  /// Antes eran dos secciones, "Caja (efectivo)" y "Banco / Digital". Pero el
  /// dueño no piensa su plata en dos cajones: quiere ver el total y, de ahí,
  /// dónde está. Separarlas obligaba a sumar de cabeza.
  static const cajaYBancos = Seccion(
    etiqueta: 'Caja y bancos',
    icono: Icons.account_balance_wallet_outlined,
    iconoActivo: Icons.account_balance_wallet_rounded,
    bajada: 'Todo tu dinero junto: efectivo, banco, Yape, Plin y más',
  );

  static const historial = Seccion(
    etiqueta: 'Historial',
    icono: Icons.receipt_long_outlined,
    iconoActivo: Icons.receipt_long_rounded,
    bajada: 'Todo lo que registraste, con búsqueda y filtros',
  );

  static const reportes = Seccion(
    etiqueta: 'Reportes',
    icono: Icons.insert_chart_outlined_rounded,
    iconoActivo: Icons.insert_chart_rounded,
    bajada: 'Cómo te fue mes a mes',
  );

  /// El libro de caja como lo pide SUNAT. Es una sección propia y no una
  /// pestaña dentro de Reportes porque no es un reporte: es *el* documento, y
  /// es la razón por la que un negocio formal usaría esta app.
  static const formatos = Seccion(
    etiqueta: 'Formatos oficiales',
    icono: Icons.description_outlined,
    iconoActivo: Icons.description_rounded,
    bajada: 'El Formato 1.1 y 1.2 listos para el contador',
  );

  static const todas = [
    resumen,
    arqueo,
    cajaYBancos,
    historial,
    reportes,
    formatos,
  ];

  /// Posición de cada una en `todas`, para saltar de una pantalla a otra sin
  /// números mágicos.
  static const iResumen = 0;
  static const iArqueo = 1;
  static const iCajaYBancos = 2;
  static const iHistorial = 3;
  static const iReportes = 4;
  static const iFormatos = 5;
}
