# P6_MERCADERIA_Y_CAJA · Pasos de mercadería y caja

Parte **P6** del proyecto Mi Caja. Agrega el paso **“¿Qué mercadería?”** al
formulario de registro y ajusta dos comportamientos de la caja diaria: cómo se
abre “Con otro monto” y cómo se confirma el cierre.

## Archivos principales

- `lib/ui/registro/paso_mercaderia.dart`: paso “¿Qué mercadería?”. Permite
  elegir un tipo existente o crear uno nuevo con “+”.
- `lib/ui/registro/campo_costo.dart`: costo de lo vendido, saldo disponible y
  aviso cuando el costo supera el saldo.
- `lib/ui/registro/registro_hoja.dart`: inserta el paso entre Datos y Pago,
  valida mercadería/costo y guarda sus datos en el movimiento.
- `lib/ui/registro/paso_datos.dart`: ya no contiene los controles de
  mercadería; quedó sólo con los datos generales del movimiento.
- `lib/ui/arqueo/arqueo_pagina.dart`: apertura “Con otro monto” billete por
  billete y confirmación antes de cerrar la caja.
- `test/inicio_test.dart` y `test/registro_mercaderia_test.dart`: pruebas del
  nuevo flujo y de los dos ajustes de caja.
- `test/captura_app_test.dart`: capturas de caja actualizadas al conteo nuevo.

## Cambios incluidos

1. **Paso “¿Qué mercadería?”.** Se muestra entre Datos y Pago cuando
   corresponde:
   - En una **compra de mercadería** el tipo es obligatorio; no se puede
     continuar sin elegirlo o crearlo.
   - En una **venta** se elige un tipo o se marca **“No es mercadería”**.
     Marcarlo oculta el tipo y el costo, y no descuenta inventario.
2. **Costo obligatorio en ventas con tipo.** Con un tipo elegido aparece
   `CampoCosto`. El campo es obligatorio; además muestra el saldo disponible y
   advierte si el costo lo supera. El aviso **no bloquea**, porque la mercadería
   pudo existir antes de empezar a usar la app.
3. **RQF 1 — apertura “Con otro monto”.** Siempre se cuenta billete por
   billete con `ConteoEditor`. Se quitaron el interruptor, el campo de monto y
   el botón “Todo”. Sin conteo no se abre y se muestra
   `Cuenta los billetes y monedas con que empieza.` El monto de apertura es el
   total contado.
4. **RQF 5 — cierre de caja.** “Cerrar caja y ver el acta” queda deshabilitado
   hasta que haya algo contado. Al tocarlo se abre la confirmación
   `¿Cerrar la caja?` con el resultado exacto:
   - `La caja cuadra`
   - `Faltan S/ x`
   - `Sobran S/ x`
5. **Pruebas actualizadas.** Se cubren compras sin tipo, ventas con tipo y
   costo, “No es mercadería”, advertencia por saldo insuficiente, apertura
   billete por billete y confirmación de cierre.

## Comportamiento del flujo

- Compra de mercadería: **Datos → Mercadería → Pago (si es efectivo) →
  Comprobante (si corresponde)**.
- Venta: **Datos → Mercadería → Pago → Comprobante**. En Mercadería se elige
  tipo + costo, o “No es mercadería”.
- El paso de mercadería se valida por separado de Datos y Pago, de modo que un
  error de tipo o costo no permite avanzar ni guardar.
- El costo y el tipo elegidos se guardan en el movimiento; en ventas de
  servicio el costo es `0`.

## Verificación local

Desde la carpeta que contiene `pubspec.yaml`:

```powershell
flutter analyze lib test/inicio_test.dart test/registro_mercaderia_test.dart
flutter test
```

Resultado obtenido:

- `flutter analyze`: sin errores. Sólo quedan avisos informativos preexistentes
  en `lib`.
- `flutter test`: **192 pruebas pasaron**, 2 omitidas (las capturas).
- Las dos capturas de caja afectadas se ejecutaron a mano con
  `flutter test test/captura_app_test.dart --tags captura --run-skipped` y
  también pasan. Los PNG generados se borraron después.

## Notas

- `lib/ui/registro/campo_mercaderia.dart` quedó sin uso. Se conservó para no
  eliminar trabajo existente; el paso nuevo vive en `paso_mercaderia.dart`.
- El proyecto no es un repositorio Git en esta copia, por lo que los cambios
  están aplicados directamente en los archivos y no hay commit asociado.

## Correcciones de la revisión (30/10/2026)

- `campo_mercaderia.dart` se quitó: nadie lo usaba.
- Los avisos del análisis no eran preexistentes: venían de
  `registro_componentes.dart` (P5) y ya se corrigieron. El análisis queda sin
  avisos.
- La captura "caja del día: abierta, cerrando, cerrada y el acta" ahora pasa
  por la confirmación "¿Cerrar la caja?" antes del acta.
