# Mejoras del Libro Bancos (Formato 1.2)

Parte del análisis del Excel `1. LIBRO BANCOS - ING SIST 6.xlsx`. En sus
hojas COBROS y PAGOS cada transferencia trae su voucher. De ese voucher salen
la descripción, el tercero, el N° de operación y la **cuenta contable** de la
hoja BANCOS.

- **Rama:** `libro-diario/p1-motor`, todavía sin commit.
- **Base de datos:** pasa a la v8, sin perder lo que ya estaba registrado.

## Lo que se decidió

| Tema | Decisión |
|---|---|
| Voucher | Opcional hasta S/ 699.99; **obligatorio desde S/ 700**, el mismo tope del DNI en la boleta. |
| N° de operación | Obligatorio en toda operación por banco: es una columna del Formato 1.2. |
| Vínculo | Sí entra: la app apunta a empresas medianas, que tienen matriz, filiales y sucursales. |
| ITF | **No va al libro.** Se calcula y se muestra en el Historial y en el voucher. |
| Leer el voucher | Sí: con la cámara en el celular y con el lector de Windows en la computadora. |
| Anexo PDF de vouchers | No se hace. |

## Cómo se usa

### Al registrar por banco (Yape/Plin, transferencia, depósito o tarjeta)

Después de los datos aparece un paso nuevo, **"Voucher"**. Tiene:

1. **El voucher.** Se elige una imagen o un PDF; en el celular también se puede
   tomar una foto. **Al adjuntarlo, la app lo lee** y llena el N° de
   operación, el cliente o proveedor y el banco.
   - Si el monto o la fecha del voucher no coinciden con lo anotado, lo avisa
     y ofrece "Usar este monto" o "Usar esta fecha".
   - Si no puede leerlo, el voucher queda adjunto igual y los datos se
     escriben a mano.
2. **El N° de operación.** Si ya existe otra operación con el mismo número,
   avisa: puede ser el mismo voucher anotado dos veces.
3. **El banco o la app del otro.** Con él, la app deduce el **tipo de
   operación**: transferencia, transferencia interbancaria, Yape, Plin,
   depósito o tarjeta.
4. **El cliente o proveedor, con su DNI o RUC.** Por banco se movieron del
   primer paso a este, junto al voucher.
5. **¿Quién es para el negocio?** Público en general, matriz, filial,
   sucursal, asociada, o trabajador o socio.
6. **¿Qué se cobró o se pagó?** Factura o letra, y en los cobros dónde estaba:
   en cartera, en cobranza o en descuento. Solo se pregunta en "Cobros de
   fiado" y "Pago a proveedor".
7. **La cuenta del formato y el ITF estimado.** Se ven en vivo mientras se
   elige.

### En el Historial

- **En la lista:**
  - Las filas con voucher llevan un clip.
  - Las operaciones de S/ 700 o más sin voucher dicen **"Falta el voucher"**.
  - Arriba de la lista, el **ITF estimado** de lo que se está viendo.
- **Filtro "Voucher":** con voucher o sin voucher.
- **Búsqueda:** ahora también por N° de operación, DNI o RUC y banco.
- **En el ⋮ de una operación por banco:**
  - Se ve todo el voucher: tipo de operación, N°, tercero, vínculo, cuenta e
    ITF.
  - **Ver** abre el voucher en grande, con zoom.
  - **Adjuntar o Cambiar** sube el voucher que faltó y lo lee para completar
    lo vacío.
  - **Completar datos** permite anotar después el N°, el banco, el nombre y el
    DNI o RUC.
  - El monto, la fecha, el vínculo y la cuenta **no se tocan**: un libro no se
    reescribe.

## La cuenta según el vínculo y el documento

Usa las cuentas del PCGE 2026 que trae la app. El Excel usa el PCGE anterior,
donde la letra en cartera era 1331; en el 2026 es 1332.

| Cobro de… | Tercero | Relacionada |
|---|---|---|
| Factura en cartera | 1212 | 1312 |
| Factura en cobranza | 1213 | 1313 |
| Factura en descuento | 1214 | 1314 |
| Letra en cartera | 1232 | 1332 |
| Letra en cobranza | 1233 | 1333 |
| Letra en descuento | 1234 | 1334 |

| Pago de… | Tercero | Relacionada |
|---|---|---|
| Factura o boleta | 4212 | 4312 |
| Letra | 423 | 4331 |

Otras reglas:

- **Adelanto de cliente:** 122, o 1321 si es una relacionada.
- **Venta a una relacionada:** 1312 y 70122, en lugar de 1212 y 70121.
- **Cuenta elegida a mano** ("Otros" o una categoría propia): manda siempre, la
  regla no la cambia.
- **Descripción del formato:** se arma como en el Excel. Ejemplo: "Cobro de
  fiado, sucursal, letra en cobranza".

## Categorías nuevas

Están en "Otra" → "Activos y financiamiento", y Honorarios en Servicios.

| Categoría | Tercero | Relacionada | Trabajador o socio |
|---|---|---|---|
| Venta de activo fijo (cobro) | 1653 | 1753 | — |
| Cobro de préstamo | 1612 | 1712 | 1411 |
| Dividendos (cobro) | 1633 | 1733 | — |
| Regalías (cobro) | 1632 | 1732 | — |
| Compra de activo fijo (pago) | 4654 | 4774 | — |
| Pago de préstamo | 4511 | 471 | 4411 |
| Pago de dividendos | 4412 | 475 | — |
| Honorarios (recibo por honorarios) | 424 | 424 | 424 |

Son cobros y pagos de algo que ya se debía. Por eso, en el Libro Diario van
en **un solo asiento**: banco contra la cuenta.

## El ITF

- **Cálculo:** 0.005% del monto, truncado a múltiplos de S/ 0.05. Por eso una
  operación de menos de S/ 1,000 no paga nada; es lo que el Excel hace con su
  `SI(monto > 1000)`.
- **No se registra:** lo descuenta el banco. Se muestra en el paso Voucher, en
  el ⋮ de cada operación y como total arriba del Historial.

## Leer el voucher sin internet

- **En el celular:** ML Kit de Google, que viaja dentro de la app.
- **En Windows:** el lector que trae el propio Windows (`Windows.Media.Ocr`),
  en el idioma del usuario. Se probó de verdad: lee el N° de operación, el
  monto y la fecha.
- **Vouchers de dos columnas:** Windows los devuelve con todos los rótulos
  primero y todos los valores después; el intérprete los empareja.
- **PDF:** primero se convierte la primera página en imagen.
- **En la demo web no hay lector.** El voucher se adjunta y se guarda en
  memoria, como el resto de la demo.

## Archivos

### Nuevos

- `lib/dominio/banco.dart`: vínculo, documento, situación, ITF, bancos, tipo
  de operación y la regla de la cuenta.
- `lib/dominio/lectura_voucher.dart`: interpreta el texto del voucher.
- `lib/datos/local/evidencias.dart`: dónde se guardan los vouchers, en la
  carpeta `Documentos/mi_caja_vouchers`.
- `lib/datos/local/selector_voucher.dart`: la cámara o el archivo.
- `lib/datos/ocr/lector_voucher.dart`: el lector del celular y el de Windows.
- `lib/ui/registro/paso_voucher.dart`: el paso "Voucher".
- `lib/ui/widgets/voucher_adjunto.dart`: la tarjeta del voucher, la miniatura
  y el visor.
- `lib/ui/historial/datos_voucher_dialogo.dart`: "Completar datos".

### Cambiados

- `movimiento.dart`, `categoria.dart`, el esquema v8, los repositorios y
  `estado_caja.dart`.
- El registro, el Historial y las reglas del Libro Diario: la contrapartida
  sale de la cuenta del formato, y sin boleta ni recibo el documento es
  "Oper. N°".

### Paquetes nuevos

`image_picker`, `file_selector` y `google_mlkit_text_recognition`. Ninguno
necesita el NDK de Android.

## Pruebas

- `test/banco_test.dart`: las cuentas de la hoja BANCOS, todas las
  combinaciones contra el PCGE, el ITF, el tipo de operación, la descripción y
  el Libro Diario.
- `test/lectura_voucher_test.dart`: Yape, Plin, una constancia, el BBVA del
  Excel y un voucher de dos columnas. Incluye una prueba con el **lector real
  de Windows**.
- `test/datos_v8_test.dart`: la migración v7 → v8, el guardado en SQLite y en
  la demo, "Completar voucher", el filtro y la búsqueda.
- `test/registro_voucher_test.dart`: el paso Voucher en escritorio y en el
  celular, el aviso de N° repetido y el Historial (falta, adjuntar, ver,
  completar).
- Capturas nuevas: `app-voucher-*`, `app-voucher-celular-*`,
  `app-historial-voucher*` y `app-visor-voucher`.

## Lo que queda para después

- **Varias cuentas bancarias.** El Formato 1.2 es uno por cuenta corriente, y
  la app hoy tiene una sola, en "Datos del negocio".
- **El voucher no viaja por la nube.** Viaja su nombre, pero el archivo queda
  en el equipo donde se adjuntó. En otro equipo, "Ver" avisa que no está.
- **La lectura en el celular** está programada, pero falta probarla en un
  celular de verdad.
