# P6 · Asientos, Libro Diario y reportes

P6 conecta los asientos contables con el costo real del kardex (P1 y P2),
incorpora las operaciones de almacén y el asiento de apertura al Libro Diario,
y completa los reportes de inventario.

## Qué quedó hecho

- **Costo de venta:** el asiento 2 toma el costo de las líneas de venta del
  kardex. Si una venta antigua no tiene líneas, conserva el costo guardado en
  el movimiento. Los servicios no generan asiento de costo.
- **Cuentas de venta y costo:** se respeta el destino y el vínculo de la venta
  (decisión 12). Cada línea de almacén conserva su `cuentaCosto`; las líneas
  de una misma operación se agrupan por cuenta en un solo asiento 2.
- **Exportación:** la venta se registra en 70111 y el costo en 69111; para una
  relacionada, se usan 70112 y 69112. La exportación no genera IGV.
- **Compra sin IGV:** el asiento de reconocimiento omite la línea 40111 cuando
  el movimiento no tiene IGV.
- **Varias líneas de venta:** se genera un asiento de costo por operación, con
  el total del kardex y una glosa que identifica los productos.
- **Operaciones de almacén:** devoluciones, merma, desmedro y ajustes generan
  sus asientos según el costo y el sentido de las líneas del kardex. La
  devolución de cliente revierte el costo de venta original; el sobrante de
  conteo aumenta mercaderías contra 7599 y el faltante reconoce 659 contra
  20111.
- **Apertura:** caja, banco y mercaderías iniciales se cargan contra capital.
  Se usa 5011 para S.A. y 5012 para E.I.R.L. o S.R.L. El asiento se incorpora
  al Libro Diario cuando la fecha de apertura está dentro del rango.
- **Anulados:** los movimientos y líneas anulados no generan asientos.
- **Costo de ventas del período:** el panel resume el total por cuenta para
  el rango elegido y muestra el asiento referencial contra 20111, sin duplicar
  los asientos de costo de cada operación.
- **Panel de mercaderías:** cantidad, valor y costo unitario se leen del
  kardex.
- **Reportes de inventario:** se muestran el valor total, el margen bruto por
  producto y los productos sin movimiento en el período.
- **Formato 5.1:** se conserva la exportación CSV/PDF, con sus totales Debe y
  Haber. También se corrigió el acumulado de Haber del libro.

## Archivos principales

| Archivo | Responsabilidad |
|---|---|
| `lib/dominio/reglas_asiento.dart` | Cuenta de ventas según exportación y vínculo |
| `lib/dominio/libro_diario.dart` | Asientos de ventas, almacén y apertura; costos y totales del libro |
| `lib/dominio/kardex.dart` | Costos de venta agrupados por cuenta y rango |
| `lib/dominio/costo_ventas_resumen.dart` | Resumen del costo y asiento referencial |
| `lib/ui/libro_diario/panel_mercaderias.dart` | Cantidad y valor del inventario desde el kardex |
| `lib/ui/libro_diario/costo_ventas_resumen.dart` | Panel del costo de ventas por cuenta |
| `lib/ui/reportes/reportes_pagina.dart` | Valor, margen y productos sin movimiento |
| `test/libro_diario_kardex_test.dart` | Nuevo. Costos, cuentas, apertura y operaciones de almacén |
| `test/libro_diario_test.dart` | Reglas generales y cuadre del Libro Diario |
| `test/libro_diario_export_test.dart` | Exportación del Formato 5.1 |
| `test/libro_diario_pagina_test.dart` | Pantalla del diario y panel de mercaderías |
| `test/kardex_test.dart` | Costos y reportes derivados del kardex |

## Dependencias

- **P1:** `Kardex.costoDe`, `costoDeVentasEn`, saldos y márgenes.
- **P2:** `LineaAlmacen`, `cuentaCosto`, datos persistidos, operaciones de
  almacén y exclusión de líneas anuladas.
- **P3:** catálogo de productos y pantallas de inventario.
- **P4:** líneas de compra y venta, exportación y comprobantes.
- **P5:** devoluciones, merma, desmedro y ajustes de conteo.

## Verificación

```powershell
flutter analyze
flutter test test/libro_diario_test.dart test/libro_diario_kardex_test.dart test/kardex_test.dart test/libro_diario_export_test.dart test/libro_diario_pagina_test.dart
flutter test
```

Resultado de esta pasada:

- `flutter analyze`: sin problemas.
- Pruebas enfocadas de Libro Diario, Kardex, interfaz y Formato 5.1: **50
  pasaron**.
- El ejercicio de Kardex confirma 69111 = **S/ 88,518.00**, 69121 =
  **S/ 303,457.45** y 20111 = **S/ 391,975.45**.
- `flutter test` completo: **9 pruebas fallaron** en `datos_v7_test.dart`,
  `registro_productos_test.dart` e `inicio_test.dart`; revisar esas pruebas
  antes de dar por validada la suite completa. Las pruebas enfocadas de
  exportación del Formato 5.1 sí pasan.
