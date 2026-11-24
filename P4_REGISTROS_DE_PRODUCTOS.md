# P4 · Registro con productos

**24 puntos · Prioridad 4 de 7**

El paso **Productos** reemplaza a «¿Qué mercadería?» en compras y ventas. Cada operación trabaja con una o más líneas, y el kardex determina el costo y el stock.

## Funciones del registro

- **Líneas de productos:** se agregan y se quitan; cada línea conserva su producto, cantidad, importe y descuento.
- **Compras:** producto, cantidad e importe por línea. Con una sola línea, su importe determina el monto; se muestra el costo unitario resultante.
- **Ventas:** producto, cantidad y precio sugerido. Se muestra el stock disponible y «Costo S/ x, lo calcula el kardex». No se pide el costo manual ni se copia el costo calculado al movimiento: se vuelve a leer desde las líneas del kardex para no dejar un valor obsoleto.
- **Cuadre:** las líneas calculan el monto correspondiente. Si no coincide con el monto del formulario, aparece «Usar S/ x como monto».
- **Stock:** no se permite continuar si la cantidad supera el stock disponible; se informa cuánto hay.
- **Servicios:** se conserva «No es mercadería» para ventas que no descuentan inventario.
- **Comprobante del proveedor:** tipo, serie y número para compras.
- **Compra sin IGV:** opción «Esta compra no tiene IGV».
- **Unidad de compra:** la cantidad escrita en cajas u otra unidad de compra se convierte a la unidad de stock con el factor configurado en el producto.
- **Descuento por línea:** el importe guardado es neto, con el descuento ya restado.
- **Exportación:** «Venta de exportación» no calcula IGV y usa la cuenta 70111.
- **Comprobante de venta:** el tipo, la serie y el correlativo se asignan automáticamente: factura F001 para RUC y exportación; boleta B001 para DNI o cliente sin documento. Se valida que el documento del cliente corresponda al tipo elegido.
- **Límite de emisión electrónica:** el proyecto asigna y guarda los datos del comprobante, pero todavía no transmite XML ni obtiene CDR de SUNAT. Para que sea un comprobante electrónico oficial debe integrarse un PSE/OSE o el servicio autorizado que el negocio utilice; no se debe presentar la boleta de control interno como comprobante SUNAT.
- **Corrección:** «Anular y volver a registrar» abre el formulario con los datos del original y conserva el movimiento anulado. Solo se permite en meses abiertos.
- **Líneas preparadas:** `RegistroHoja.abrir` recibe `lineasIniciales` para registrar un pedido previamente armado.
- **Monto con IGV:** se calcula mediante `ReglasMercaderia.montoParaLineas`.
- **Stock disponible:** se consulta con `EstadoCaja.stockDisponible`.
- **Fecha anterior:** se avisa si la fecha elegida precede al último movimiento del producto.
- **Líneas obligatorias:** `ReglasMercaderia.exigirLineas` queda en `true` para compras y ventas de mercadería. Las ventas de servicios siguen exentas.
- **Compra con una línea:** el importe de la única línea se precarga con el valor sin IGV del monto del formulario; al quedar una sola línea después de quitar otra, se vuelve a sincronizar.

## Archivos

- `lib/ui/registro/paso_productos.dart`
- `lib/ui/registro/linea_producto.dart`
- `lib/ui/registro/registro_hoja.dart`
- `lib/ui/registro/paso_datos.dart`
- `lib/ui/historial/` (anular y volver a registrar)
- `lib/ui/registro/paso_mercaderia.dart` y `campo_costo.dart` (retirados)
- `test/registro_productos_test.dart`
- `test/registro_mercaderia_test.dart`

La ventana de alta rápida de productos se conecta con el catálogo común de P3, para que el producto creado desde el registro tenga la misma ficha y validaciones que el producto creado desde Inventario.

## Dependencias

- **P1:** `Kardex.costoDeSalida` y `costoDeSalida` para el costo de venta.
- **P2:** persistencia de productos, movimientos y líneas; stock disponible; `montoParaLineas`; correcciones y comprobantes.
- **P3:** catálogo y ficha del producto, unidades, factor de compra y ventana de inventario.

## Verificación

```powershell
flutter analyze
flutter test test/registro_productos_test.dart
flutter test test/registro_mercaderia_test.dart
flutter test
```

La entrega integrada debe comprobar una compra con dos productos, una compra de una sola línea, una venta con cantidad, el bloqueo de una venta mayor al stock, la conversión de cajas a unidades y la corrección de un error sin perder el original. La suite debe ejecutarse en un entorno con Flutter instalado. La emisión oficial ante SUNAT queda pendiente de conectar el proveedor autorizado y sus credenciales seguras.
