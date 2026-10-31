# P4 · Lectura y exportación del Libro Diario

Implementación de P4 sobre los modelos publicados por P1 (`LibroDiario`,
`AsientoDiario`, `EtapaAsiento` y `LineaDiario`) y el catálogo PCGE de P2.
P4 no arma asientos ni vuelve a calcular importes: consume esas estructuras y
mantiene los importes como centavos enteros hasta mostrarlos o exportarlos.

## Incluido

- `lib/ui/libro_diario/entender_codigos.dart`: ayuda desplegable “Cómo leer un
  código”, con los ejemplos 40 → 401 → 4011 → 40111 y 70 → 701 → 7012 → 70121.
  Las denominaciones salen de `Pcge.cadena`. Cuando el período contiene
  operaciones, agrega las cuentas distintas usadas en sus asientos.
- `lib/datos/export/exportador.dart`: `csvDiario` y `guardarDiario` generan el
  CSV del Formato 5.1 en UTF-8 con BOM, coma, comillas CSV y nombre
  `LibroDiario_5-1_YYYY-MM.csv`. Cada importe aparece en la fila de dos
  dígitos de su cadena; las hijas sólo muestran código y denominación. El
  correlativo, fecha, glosa y referencia se repiten en todas las filas.
- `lib/datos/export/exportador_pdf.dart`: `diario` genera el PDF A4 horizontal,
  con fuente incrustada, encabezado y columnas, totales por operación y período
  y pie con número de página. Nombre: `LibroDiario_5-1_YYYY-MM.pdf`.
- `lib/ui/libro_diario/libro_diario_pagina.dart`: agrega los botones PDF/CSV,
  la ayuda de lectura y las advertencias de datos del negocio y asientos que no
  cuadran. Ante un descuadre muestra los correlativos y pide confirmación antes
  de exportar.
- `lib/ui/registro/nueva_mercaderia.dart`: diálogo con el estilo de “Nueva
  categoría”, validación de nombre vacío, duplicado (sin distinguir mayúsculas
  ni espacios) y máximo de 40 caracteres. Al guardar usa
  `EstadoCaja.agregarMercaderia` y devuelve la entidad creada.
- `lib/ui/registro/campo_mercaderia.dart`: el botón de creación existente usa
  el diálogo compartido y deja seleccionada la mercadería devuelta.
- Los exportadores 1.1/1.2 ya no agregan el bloque de asientos resumen del
  Libro Diario.

## Límites conocidos

- El selector de período está en la pantalla P3. El posible texto duplicado
  “Octubre de 2026 2026” queda señalado para P3 y no se cambió aquí.
- El código de libro continúa siendo el que entrega P1 (`codigoLibro`); sólo
  las compras de mercadería tienen confirmado el código `08` en el motor
  actual. P4 no asigna códigos a ventas o gastos.
- La exportación CSV sigue el mismo destino de archivos locales que los demás
  formatos; en web la app informa que CSV todavía no está disponible. El PDF
  se comparte/descarga en web con el mecanismo existente.

## Verificación

No se ejecutaron pruebas ni análisis automáticos en esta pasada. El proyecto
contiene pruebas de P1/P2/P3, pero aún no se añadió el archivo dedicado
`test/libro_diario_export_test.dart` descrito en el plan.

## Correcciones de la revisión (30/10/2026)

Esto reemplaza lo que dice arriba sobre la exportación y la ayuda:

- El CSV y el PDF del Formato 5.1 llevan las 11 columnas de la plantilla. La
  referencia va en sus tres columnas: código del libro (Tabla 8), número
  correlativo y documento sustentatorio. El número correlativo de la
  referencia queda en blanco, como en el ejemplo del Excel; antes se ponía ahí
  el correlativo del propio asiento.
- El CSV lleva el encabezado de la plantilla (formato, período, RUC y razón
  social) y usa punto y coma, como los demás CSV de la app: con coma, Excel en
  español mete todo en una sola columna. También protege los textos que
  empiezan con "=" para que Excel no los ejecute como fórmula.
- Modo Entender: hay una ayuda nueva, "Cómo se arma un asiento"
  (`entender_pasos.dart`), con los 4 pasos y las 3 etapas. Además, cada línea
  de un asiento muestra su "por qué".
- `test/libro_diario_export_test.dart`: 7 pruebas del CSV y el PDF con los 4
  ejemplos.
- El texto "Octubre de 2026 2026" no aparece en la pantalla de P3: la página
  muestra "Del 01/10/2026 al 31/10/2026".
- `campo_mercaderia.dart` se quitó porque nadie lo usaba.
