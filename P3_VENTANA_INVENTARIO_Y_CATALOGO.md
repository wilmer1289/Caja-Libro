# P3 · Ventana del inventario y catálogo

**24 puntos · Prioridad 3 de 7**

P3 incorpora una ventana propia de Inventario conectada a los datos y al kardex de P1 y P2.

## Ventana y navegación

- El ícono **Inventario** aparece en el encabezado de escritorio, junto al acceso a Datos del negocio.
- En celular, **Inventario** aparece como primera opción del menú lateral que se abre por la derecha.
- La ventana contiene las secciones **Productos**, **Kardex**, **Operaciones** y **Conteo**.
- El botón **‹ Mi Caja** cierra la ventana y deja seleccionada la sección de Mi Caja que estaba abierta.
- Las opciones salen de `OpcionInventario.todas`; cada opción puede declarar los roles que la ven.
- Kardex, Operaciones y Conteo quedan como espacios de navegación preparados para las etapas que los completan.

## Productos

- Catálogo con código, descripción, unidad, stock, costo promedio, valor y estado.
- Búsqueda por código o descripción; filtros de activos e inactivos.
- Valor total del inventario calculado por el kardex.
- Alta y edición con código sugerido, descripción, unidad de la Tabla 6, tipo de la Tabla 5, stock mínimo, precio sugerido, unidad de compra y factor, y unidad del catálogo 03 de factura electrónica.
- La unidad de un producto que ya tiene movimientos queda bloqueada para no mezclar unidades dentro del kardex.
- Desactivar no elimina: conserva el historial y evita que el producto aparezca en nuevos registros.
- El alta rápida del paso Productos de P4 reutiliza la misma ficha de producto.

## Inventario inicial y correcciones

- El saldo inicial se registra una sola vez por producto, con cantidad y costo unitario.
- Una vez registrado, el saldo inicial queda bloqueado.
- **Corregir inventario** registra un ajuste por la diferencia entre el stock actual y el conteo físico. Los sobrantes se valoran al promedio del kardex cuando ya existe stock; si no hay stock, se solicita costo unitario.

## Importación desde Excel

- Lee archivos `.xlsx` con cinco columnas fijas: código, descripción, unidad, cantidad y costo unitario.
- Presenta una vista previa de todas las filas, separando las válidas de las que tienen errores.
- Solo después de mostrar la vista previa permite importar las filas válidas.
- Cada fila importada crea el producto y registra su inventario inicial.

## Avisos e integración

- El contador del ícono Inventario y la tarjeta **Productos por reponer** del Resumen usan la misma lista de alertas del kardex.
- **Registrar compra** abre el mismo formulario **Salió → Mercadería** encima de la ventana de Inventario y sugiere la categoría Mercadería.
- Datos del negocio muestra el método de valuación: **Promedio ponderado**.
- Al ingresar a la aplicación, el usuario se copia a `estado.usuario` para completar el campo «registrado por».
- Diseño adaptable: menú horizontal y tarjetas en celular; navegación lateral y tabla en escritorio.

## Archivos

- `lib/ui/shell/encabezado.dart`
- `lib/ui/shell/barra_lateral.dart`
- `lib/ui/inicio.dart`
- `lib/ui/inventario/inventario_ventana.dart`
- `lib/ui/inventario/productos_seccion.dart`
- `lib/ui/inventario/producto_dialogo.dart`
- `lib/ui/inventario/inventario_inicial.dart`
- `lib/ui/inventario/importar_productos.dart`
- `lib/ui/dashboard/dashboard_pagina.dart` (tarjeta de avisos)
- `lib/ui/negocio/negocio_pagina.dart` (método de valuación)
- `lib/ui/registro/linea_producto.dart` (alta rápida conectada al catálogo común)
- `lib/ui/registro/registro_hoja.dart` (categoría inicial para Registrar compra)
- `lib/estado/estado_caja.dart` (alertas del inventario)
- `test/inventario_productos_test.dart`

## Dependencias

P1 aporta el kardex, costo promedio, valor total y alertas. P2 aporta productos, tablas SUNAT, stock, unidades de compra, persistencia y `registrarEnAlmacen`. P4 usa este catálogo para las líneas de compra y venta.

## Verificación

```powershell
flutter pub get
flutter analyze
flutter test test/inventario_productos_test.dart
flutter test
```

También debe probarse manualmente en una ventana de 390 px y en escritorio de 933 × 600: abrir Inventario, volver a Mi Caja, crear un producto, registrar su saldo inicial, corregirlo con un ajuste, importar un Excel y comprobar que el contador y la tarjeta de reposición se actualicen.
