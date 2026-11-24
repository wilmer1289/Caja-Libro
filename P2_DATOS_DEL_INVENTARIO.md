# P2 · Datos del inventario

Rama `inventario/p2-datos`, basada en P1 (`c99c4a9`). Sin commit.

## Qué quedó hecho

- **Base v9** sin perder datos: columnas nuevas (solo si faltan), tabla
  `kardex`, tabla `cierres` e índices. Una base v8 abre en v9 con todo lo que
  tenía y sus tipos de mercadería pasan a ser productos P001, P002… por
  antigüedad.
- **Productos** (`Mercaderia`): código, tipo (Tabla 5), unidad (Tabla 6),
  stock mínimo, precio sugerido, activo, unidad de compra con su factor y
  código de unidad de la factura electrónica (catálogo 03).
- **Tablas de SUNAT** 5, 6, 10 y 12 del Excel, y el catálogo 03 con la
  equivalencia de fábrica (07 → NIU, 01 → KGM, 13 → MIL…).
- **Compras y ventas con productos**: el movimiento y sus líneas se guardan
  en la misma transacción. Descuento por línea. Compra por cajas que entra en
  unidades.
- **Comprobante de venta**: la app asigna automáticamente el tipo, la serie y
  el correlativo (F001 si el cliente tiene RUC o es exportación; B001 si tiene
  DNI o no se registra documento). La exportación va sin IGV. Esta versión
  todavía no transmite XML ni solicita CDR a SUNAT; para emisión electrónica
  oficial falta conectar un PSE/OSE o el servicio autorizado elegido por el
  negocio.
- **`registrarEnAlmacen`**: saldo inicial, merma, desmedro, devoluciones (solo
  el lado del almacén) y ajuste.
- **«Registrado por»** en cada movimiento y cada línea.
- **Cerrar el mes** y **«Anular y volver a registrar»** (`corregir`).
- **Demo web** con las mismas reglas: ahora solo cambia dónde se guarda, ya no
  repite el código. Arranca vacía.
- **Pruebas**: `test/datos_v9_test.dart`, en SQLite y en la demo web.

## Archivos

| Archivo | Qué tiene |
|---|---|
| `lib/dominio/almacen.dart` | Nuevo. Reexporta `LineaAlmacen` y `OperacionAlmacen` de P1 y agrega `Cantidad`, `Comprobante`, `LineaNueva`, `StockAlmacen`, y cómo se guarda una línea |
| `lib/dominio/tablas_sunat.dart` | Nuevo. Tablas 5, 6, 10, 12 y catálogo 03 |
| `lib/dominio/cierre_mes.dart` | Nuevo. Los meses cerrados y sus reglas |
| `lib/dominio/mercaderia.dart` | Campos del producto |
| `lib/dominio/movimiento.dart` | Comprobante, exportación, `registradoPor`, `anuladoEn`, `reemplazadoPor` |
| `lib/dominio/negocio.dart` | `metodoValuacion` y `kardexDesde` |
| `lib/dominio/reglas_mercaderia.dart` | Reglas de productos, líneas, comprobante de venta y cuentas |
| `lib/datos/db/esquema.dart`, `base_datos.dart` | v9 y su migración |
| `lib/datos/local/kardex_dao.dart`, `cierre_dao.dart` | Nuevos |
| `lib/datos/local/mercaderia_dao.dart`, `movimiento_dao.dart` | `actualizar`; número del comprobante y anulación dentro de la transacción |
| `lib/datos/repositorio/` | Las reglas, en SQLite y en la demo |
| `lib/estado/estado_caja.dart` | Lo que usan las pantallas |
| `test/datos_v9_test.dart` | Nuevo |
| `test/datos_v7_test.dart`, `datos_v8_test.dart`, `inicio_test.dart` | Solo se ajustaron a las columnas y parámetros nuevos |

## Cómo se usa

**Unidades.** Cantidades en milésimas enteras (1,600 unidades = `1600000`):
`Cantidad.leer('2.5')`, `Cantidad.texto(…)`, `Cantidad.de(48.6)`. Plata en
centavos. Unidades, latas y cajas van sin decimales.

**P1.** La clase de las líneas sigue siendo la tuya (`linea_kardex.dart`); P2
no la cambió. `estado.kardex` ya sale de lo guardado. Las líneas de un
movimiento anulado o borrado no llegan al kardex. Antes de guardar, P2 pasa la
operación por `Kardex.de` y rechaza lo que el motor no acepta.

**P3.**
- `estado.usuario = '…'` al entrar a la app.
- `estado.productos` (por código), `productosActivos`, `producto(id)`.
- `estado.guardarProducto(id:, nombre:, codigo:, tipoExistencia:, unidad:,
  stockMinimo:, precioSugerido:, activo:, unidadCompra:, factorCompra:,
  unidadFactura:)`. Al editar, manda todos los campos.
  `ReglasMercaderia.codigoSugerido(estado.productos)` para mostrarlo antes.
- Caja de 12: `unidadCompra: '12'`, `factorCompra: Cantidad.de(12)`.
- Saldo inicial: `registrarEnAlmacen(operacion: saldoInicial, mercaderiaId:,
  fecha:, cantidad:, costoTotal:)`. Solo si el producto no tiene nada antes.
- Avisos: `estado.stockDe(id)` frente a `producto.stockMinimo`, o
  `estado.kardex.alertas(...)` de P1.
- `TablasSunat.unidades`, `tiposDeExistencia`, `unidadesFactura` para las
  listas; `negocio.metodoValuacion.etiqueta` da «Promedio ponderado».

**P4.**
- `estado.registrar(..., lineas: [LineaNueva(mercaderiaId:, cantidad:,
  importe:, descuento:, enUnidadDeCompra:)], comprobante:, sinIgv:,
  exportacion:)`. `importe` va **neto** (ya sin el descuento) y sin IGV.
- Las líneas suman el valor sin IGV. Para «Usar S/ x como monto»:
  `ReglasMercaderia.montoParaLineas(suma, conIgv: !sinIgv && !exportacion)`.
- En ventas no mandes comprobante: la app pone F001 o B001 con su número.
  Solo para cargar facturas viejas se puede escribir uno (F… o B…, sin
  repetir).
- Stock al vender: `estado.stockDisponible(id, fecha:)`. Aviso de fecha
  anterior: `estado.ultimaFechaDe(id)`. Mes cerrado: `estado.mesCerrado(fecha)`.
- «Anular y volver a registrar»: `estado.corregir(original, …)`, con los
  mismos parámetros de `registrar`. El anulado sale en `estado.anulados`.
- P4 deja `ReglasMercaderia.exigirLineas = true`: compras de mercadería y
  ventas de productos requieren líneas. La venta de servicios conserva la
  opción «No es mercadería».

**P5.**
- Merma y desmedro: `registrarEnAlmacen` con `glosa` (el motivo).
- Ajuste: `entrada: true` (sobra) o `false` (falta). Un sobrante entra al
  promedio; si ese día no había stock, pide `costoTotal`.
- Devoluciones: `devolucionRecibida` o `devolucionEntregada`, con `origenId`
  = la línea de la venta o de la compra.
- Cerrar el mes: `estado.cerrarMes(año, mes)`. Solo un mes que ya terminó;
  cierra también los anteriores y no se reabre.

**P6.** `movimiento.exportacion`, `sinIgv`, `comprobante`. Cada línea de
venta trae su `cuentaCosto` (69121, 69122, 69111 o 69112). Una venta con
productos tiene `costoCentavos == null`: el costo sale del kardex. Lo anulado
ya no está en `estado.movimientos`.

**P7.** Por línea: `comprobante.texto` («F001-12»), `descuento`, `importe`;
`operacion.codigo` da el de la Tabla 12. Para la factura:
`producto.codigoUnidadFactura`. Las líneas de una venta:
`estado.lineasDe(movimiento.id)`; de una anulada, `estado.leerLineasDe(id)`.

## Reglas

1. Un movimiento con productos no se borra ni cambia su monto o su fecha: se
   anula y se vuelve a registrar, o se corrige con una devolución.
2. «Anular y volver a registrar» solo en un mes abierto, y no si su efectivo
   ya se contó al cerrar una caja, ni si tiene devoluciones.
3. Sin stock no sale nada, ni con fecha pasada. Al anular, tampoco puede
   quedar sin stock lo de después.
4. Un mes cerrado no acepta nada con su fecha, ni en caja ni en el almacén.
   Solo se completa el voucher.
5. Los números de factura y boleta no se repiten ni se reutilizan.
6. Código único y en mayúsculas; un producto desactivado no se usa.

## Pendiente

- La plata de las devoluciones (después, según el plan).
- Un mes cerrado no se reabre: si hiciera falta, hay que decidir quién puede.
