# P3: pantalla del Libro Diario

La sección **Libro diario** aparece en el menú lateral y en el del celular, con
su ícono y su bajada. Muestra cada operación convertida en sus asientos, con las
cuentas del PCGE. Reemplaza al bloque "Para el Libro Diario" que vivía al pie de
Formatos oficiales: el diario tiene ahora su propio período, su resumen y su
panel de mercaderías.

- **Período:** los atajos que ya existían (Hoy, Esta semana, Este mes, Mes
  pasado, Este año) y **Elegir fechas** para un rango a medida. Arranca en Este
  mes. Debajo se lee el rango exacto ("Del 01/10/2026 al 31/10/2026").
- **Resumen:** operaciones, asientos, total Debe, total Haber y el sello
  **Cuadra** (verde) o **No cuadra** (rojo). Sin operaciones no se afirma nada.
  Si hay ventas sin costo, agrega cuántas son.
- **Una tarjeta por operación:** correlativo, fecha, documento, glosa, tipo de
  mercadería e importe (con signo y color de Entró o Salió). Al tocarla se
  despliega en sus **3 asientos**, cada cuenta con su cadena completa
  (`40 › 401 › 4011 › 40111`), el Debe y el Haber, y el total de cada asiento.
- **Venta antigua sin costo:** la tarjeta lleva la etiqueta **Sin asiento 2** y,
  al desplegarla, una explicación. Es el caso `faltaCosto` de P1: la venta se
  anotó antes de los tipos de mercadería y no tiene costo de venta.
- **Panel Mercaderías:** por cada tipo, lo **comprado** (sin IGV), el **costo
  vendido** y el **saldo**. Un saldo negativo se marca en rojo con su aviso. La
  cuenta es **acumulada hasta el último día del período**, no sólo del período:
  un saldo no tiene sentido recortado.
- **Tipo de mercadería en el Historial:** cada fila muestra una etiqueta con el
  tipo; en una venta suma el costo ("tela · costo S/ 1,000.00"). El diálogo de
  un movimiento también lo incluye. Los servicios y los registros anteriores no
  llevan etiqueta.


## Diseño

| Ancho útil | Disposición |
| --- | --- |
| Menos de 860 px (celular) | Una columna: período, resumen, panel de mercaderías y operaciones. Margen de 16 px y 120 px de aire al final para los botones flotantes. |
| 860 px o más (escritorio) | Operaciones a la izquierda y el panel de mercaderías fijo de 340 px a la derecha. |

- Los atajos de período se deslizan de costado en el celular.
- El resumen pasa de 2 × 2 datos a 4 en fila desde 600 px.
- Dentro de un asiento, por debajo de 520 px el Debe y el Haber comparten una
  columna, cada importe con su rótulo; desde 520 px van en dos columnas, como en
  el Formato 5.1. La cuenta abonada va sangrada.

## Conexión con P1 y P2

La pantalla no calcula nada contable. Pide los datos ya armados a `EstadoCaja`:

- `libroDiario(desde:, hasta:)` devuelve el `LibroDiario` de P1, con sus
  `AsientoDiario` y `EtapaAsiento`.
- `inventarioHasta(fecha:)` devuelve el inventario de P2.

`LibroDiarioPagina` sólo guarda el período elegido. El dibujo está en
`LibroDiarioVista`, que recibe el libro y el inventario ya calculados y no sabe
de estado: por eso se prueba con los 4 ejemplos sin una base de datos.

## Archivos

Nuevos:

- `lib/ui/libro_diario/libro_diario_pagina.dart`: la página, la vista, el
  selector de período y el diseño de celular y escritorio.
- `lib/ui/libro_diario/resumen_libro.dart`: el resumen y el sello.
- `lib/ui/libro_diario/tarjeta_operacion.dart`: la tarjeta y el aviso de
  "Sin asiento 2".
- `lib/ui/libro_diario/panel_mercaderias.dart`: el panel de mercaderías.
- `test/libro_diario_pagina_test.dart`: las pruebas de la pantalla.

Modificados:

- `lib/ui/shell/secciones.dart`: la sección nueva. Libro diario queda en el
  índice 5 y Formatos oficiales pasa al 6; los índices 0 a 4 no cambian.
- `lib/ui/inicio.dart`: conecta la sección con la pantalla.
- `lib/ui/formatos/formatos_pagina.dart`: sin el bloque ni su título.
- `lib/ui/formatos/bloque_asiento.dart`: ahora dibuja **un asiento del diario**
  (`EtapaAsiento`). Ya no usa `AsientoResumen`.
- `lib/ui/widgets/fila_movimiento.dart`: la etiqueta de mercadería.
- `lib/ui/historial/acciones_movimiento.dart`: el tipo en el diálogo.
- `lib/ui/historial/barra_filtros.dart`: `DialogoRango` pasa a ser público para
  que lo comparta el Libro Diario.
- `test/captura_test.dart`: usaba el `BloqueAsiento` anterior y se ajustó para
  que siga compilando.

## Lo que no cambia

- `AsientoResumen` y el exportador a PDF siguen como estaban. Corresponden a la
  exportación del Libro Diario, que es de otra parte.
- El Historial muestra el tipo de mercadería pero no filtra ni busca por él: eso
  toca `EstadoCaja`.

## Verificación

```powershell
flutter analyze
flutter test test/libro_diario_pagina_test.dart
flutter test
```

`test/libro_diario_pagina_test.dart` cubre, con los 4 ejemplos (compra de tela,
venta, alquiler y luz) y la tipografía real:

- La sección Libro diario está en el menú y antes de Formatos oficiales.
- En celular de 390 px: las 4 operaciones, 12 asientos, Debe y Haber iguales
  (S/ 12,272.00) y el sello "Cuadra", sin desbordes.
- Una tarjeta se despliega en sus 3 asientos y muestra la cadena de cuentas.
- Una venta sin costo muestra "Sin asiento 2" y el aviso del resumen.
- El panel de mercaderías muestra comprado, costo vendido y saldo.
- En escritorio de 1280 × 800: el panel queda al costado y no hay desbordes. Sin
  operaciones se ve el mensaje vacío.
- Formatos oficiales ya no contiene el bloque.

