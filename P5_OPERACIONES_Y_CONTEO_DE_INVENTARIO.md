# P5 · Operaciones y conteo de inventario

**Etapa 1 · Operaciones de almacén, devoluciones, conteo físico y cierre mensual**

P5 completa las secciones **Operaciones** y **Conteo** preparadas en P3. Usa el
kardex de P1 y las reglas y persistencia de inventario de P2. P4 aporta las
compras y ventas originales que se pueden devolver.

## Qué hace

- **Operaciones:** el botón «Nueva operación» permite elegir merma/desmedro o
  devolución. La lista muestra los movimientos que no pasan por Caja, en orden
  de fecha, con producto, cantidad y sentido de entrada/salida.
- **Merma y desmedro:** pide producto, cantidad, fecha y motivo; el kardex valora
  la salida al costo promedio. La pantalla recuerda conservar el sustento
  documentario que corresponda.
- **Devolución de cliente:** se vincula a una línea de venta, limita la cantidad
  a lo que queda por devolver y repone el stock al costo de salida original. El
  reembolso de dinero queda fuera de esta etapa.
- **Devolución a proveedor:** se vincula a una línea de compra, limita la
  cantidad pendiente y descuenta stock al costo original de compra. El pago al
  proveedor queda fuera de esta etapa.
- **Conteo físico:** presenta los productos y su saldo del sistema; el usuario
  ingresa el conteo real y ve la diferencia en unidades y soles. Al confirmar,
  registra un ajuste por producto con diferencia y genera el acta de conteo.
- **Acta:** incluye negocio, fecha, responsable, existencias del sistema y
  contadas, diferencias y valores; se puede ver e imprimir/guardar como PDF.
- **Conteo anual:** desde Conteo se elige un año terminado. La pantalla toma
  los saldos históricos del kardex al 31 de diciembre, incluye productos
  desactivados que aún tenían saldo, permite ingresar el conteo real, registra
  las diferencias con esa fecha y genera un acta anual.
  Si diciembre está cerrado, no permite escribir ajustes en ese período.
- **Cierre mensual:** resume movimientos de Caja e inventario y el valor del
  inventario al cierre. Cierra el mes elegido y los anteriores mediante la
  barrera compartida con Caja; no acepta fechas de períodos ya cerrados.

## Archivos principales

| Archivo | Responsabilidad |
|---|---|
| `lib/ui/inventario/operaciones_pestana.dart` | Historial y selector «Nueva operación» |
| `lib/ui/inventario/operacion_dialogo.dart` | Alta de merma o desmedro |
| `lib/ui/inventario/devolucion_dialogo.dart` | Devoluciones vinculadas a su origen |
| `lib/ui/inventario/conteo_pestana.dart` | Conteo, diferencias y ajustes |
| `lib/ui/inventario/conteo_anual_dialogo.dart` | Conteo anual al 31 de diciembre |
| `lib/ui/inventario/fila_conteo.dart` | Fila compartida entre conteos |
| `lib/dominio/conteo_fisico.dart` | Resultado y diferencias del conteo |
| `lib/dominio/acta_conteo.dart` | Datos del acta |
| `lib/ui/inventario/acta_conteo_vista.dart` | Vista e impresión del acta |
| `lib/dominio/documento.dart` | Diseño imprimible del acta |
| `lib/ui/inventario/cerrar_mes.dart` | Resumen y confirmación del cierre |
| `lib/dominio/cierre_mes.dart`, `lib/estado/estado_caja.dart` | Reglas y bloqueo común del período |
| `test/inventario_operaciones_test.dart` | Pruebas de interfaz de P5 |
| `test/datos_v9_test.dart` | Persistencia, costo de devoluciones y cierre |

## Verificación

```powershell
flutter analyze
flutter test test/inventario_operaciones_test.dart
flutter test test/inventario_productos_test.dart
flutter test test/datos_v9_test.dart
```

## Alcance pendiente

- **P6:** la integración de los asientos contables de las operaciones de
  inventario debe verificarse al integrar P6; no se considera certificada por
  las pruebas de esta etapa.
- Las pruebas automatizadas cubren la devolución completa de una venta al costo
  original, merma al promedio, conteo físico y anual con acta, bloqueo de cierre
  y reglas de persistencia.
  La impresión/PDF y el uso manual en distintos tamaños de ventana requieren
  además una comprobación visual en la aplicación.
