# P7 · Kardex, formatos y factura electrónica

Rama `inventario/p2-datos` (con P1 a P6 integrados). Sin commit.

## Qué quedó hecho

- **Sección Kardex** del inventario: se elige el producto y el período (un
  mes o todo el kardex). Arriba van los datos del 13.1 y los totales (saldo
  inicial, entradas, salidas al costo y saldo final); abajo, la tabla con
  documento, operación (Tabla 12), entradas, salidas y saldo, con su fila de
  totales. Se desliza a los lados en pantallas chicas.
- **Modo «Entender»**: al tocar una fila explica de dónde salió el número, con
  la cuenta del promedio (cuánto había, cuánto entra o sale, el promedio
  nuevo, el redondeo y el caso «sale todo el stock»).
- **Formato 13.1** (valorizado) y **Formato 12.1** (unidades físicas) en
  **PDF** (A4 horizontal, encabezado agrupado como la hoja REG INV) y en
  **CSV** (punto y coma y BOM, como el Formato 1.1).
- **Todos los productos** en un solo PDF, una hoja por producto.
- Si el período empieza después del inventario inicial, la primera fila es el
  saldo que viene del período anterior (operación 16). El saldo inicial va
  sólo en las columnas del saldo: no suma como entrada.
- **Factura electrónica** (F001, cliente con RUC o exportación) y **boleta de
  venta electrónica** (B001) en lugar de la boleta de control interno: con
  cantidad, unidad (catálogo 03), código y descripción del producto, valor
  unitario, descuento, valor de venta, IGV, total y monto en letras. Igual en
  pantalla y en PDF. Las ventas de antes del inventario siguen saliendo como
  la boleta interna que se emitió entonces.
- **Formatos de Mi Caja** tiene una tarjeta que abre el inventario en el
  kardex.
- El **acta de conteo** de P5 ya se ve en el visor de documentos.

## Archivos

| Archivo | Qué tiene |
|---|---|
| `lib/dominio/registro_inventario.dart` | Nuevo. El 13.1/12.1 de un producto: encabezado, filas y totales. Lo usan la pantalla, el PDF y el CSV |
| `lib/ui/inventario/kardex_pestana.dart` | Nuevo. La sección Kardex |
| `lib/ui/inventario/entender_kardex.dart` | Nuevo. Los pasos del modo «Entender» |
| `lib/datos/export/exportador_kardex.dart` | Nuevo. CSV del 13.1 y del 12.1 |
| `lib/datos/export/exportador_kardex_pdf.dart` | Nuevo. PDF del 13.1 y del 12.1 |
| `lib/dominio/boleta.dart` | La factura o boleta electrónica y sus líneas (`ItemComprobante`) |
| `lib/dominio/documento.dart` | Cómo se dibuja el comprobante |
| `lib/ui/formatos/` | La tarjeta del inventario y la ventana del comprobante con sus productos |
| `test/kardex_export_test.dart` | Nuevo. El ejercicio del Excel en el 13.1, el CSV, el PDF, «Entender» y la sección |
| `test/comprobantes_test.dart` | Pruebas de la factura y la boleta electrónica |

Cambios chicos en archivos de otros, para conectar: `inventario_ventana.dart`
(abre la sección Kardex y se puede abrir en una sección), el historial y el
registro (le pasan los productos al comprobante; el botón «Boleta interna»
ahora dice «Comprobante») e `inicio.dart` (el aviso dice «Factura
electrónica F001-…»).

## Cómo se comprueba

```powershell
flutter analyze
flutter test test/kardex_export_test.dart test/comprobantes_test.dart
flutter test
```

El ejercicio de octubre da 7,350 unidades de entrada por S/ 376,210.00,
7,650 de salida por S/ 391,975.45 y un saldo final de 900 unidades por
S/ 44,234.55 (costo unitario 49.1495), igual que el plan.

## Correcciones hechas al integrar

- **P4:** 9 pruebas fallaban. Las 4 de `datos_v7_test` probaban ventas sin
  productos, que ya no se pueden registrar desde que `exigirLineas` es
  `true`: ahora guardan esos datos viejos directo y hay una prueba de que ya
  no se registran. `inicio_test` esperaba el mensaje anterior. En
  `registro_productos_test`, 3 pruebas tocaban botones fuera de la pantalla y
  una escribía el detalle después de pasar de paso; la de compra y venta
  abría siempre «Salió».
- **P6:** merma y desmedro van a **6951** (no 659), el faltante por conteo a
  **6593** (no 659), y el asiento de apertura toma el **inventario inicial**
  (operación 16) y no el saldo del kardex al cierre del primer día. Sin fecha
  de inicio del período, la apertura va el día del primer inventario.
- **P3:** se quitó `.vscode/settings.json`, que apuntaba a una carpeta de otra
  computadora.

## Pendiente

- El envío a SUNAT (XML y CDR) llega con su API, al terminar el proyecto.
- El 13.1 sale por producto y por mes; el Formato 3.7 (fin de año) es de la
  etapa 2.
