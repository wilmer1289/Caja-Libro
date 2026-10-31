# P2: datos, mercaderías y base v7

## Qué incorpora

Se mantienen las 20 categorías existentes y sus 22 cuentas contables. Tela,
Pintura y otros nombres se registran como tipos de mercadería, no como categorías.
Todos los importes son soles y se almacenan en centavos enteros.

- En **Salió > Mercadería** se elige o crea un tipo.
- En **Entró > Ventas** se elige el tipo y se escribe el costo de lo vendido,
  sin IGV, separado del precio de venta. Una venta puede tener pérdida: el costo
  no se limita al precio.
- El interruptor permite indicar que se está cobrando un servicio.
- El saldo y la advertencia se consultan a la fecha elegida. Superar el saldo
  avisa y permite continuar: puede existir mercadería anterior al uso de la app.
- Los campos usan el tema, las ventanas y los pasos del formulario existente.

El costo de venta afecta el inventario y el Libro Diario; **no crea otro
movimiento de dinero**. El inventario controla valor, no cantidades o unidades.

## Persistencia y compatibilidad

La v7 crea `mercaderias` con id, nombre, clave única del nombre y fecha de creación.
Agrega a `movimientos`:

- `mercaderia_id`: referencia al tipo.
- `mercaderia_nombre`: copia histórica usada en comprobantes y descripciones.
- `costo_centavos`: costo vendido; nullable para conservar datos desconocidos.

La migración agrega tablas y columnas, sin recrear ni renumerar registros. Una
compra nueva exige tipo existente. Una venta con tipo exige costo positivo. Las
validaciones están compartidas por el repositorio local y la demo.

En registros anteriores, id y costo permanecen null. Una venta sin esos datos
queda con `faltaCosto` en P1. `costo_centavos = 0`, sin tipo, identifica un servicio
explícito. En compras, el costo que suma al inventario es `baseCentavos`: se resta
el IGV registrado, y si no había IGV se usa el importe completo.

La copia, edición, serialización y restauración conservan estos datos. También
se corrigió Deshacer: restaura la marca de borrado y conserva boleta, responsable
y detalle del efectivo. La demo inicia sin tipos ni operaciones y se reinicia al
recargar, igual que antes.

## Conexión con P1

`EstadoCaja` publica:

- `mercaderias`, `agregarMercaderia(nombre)` y `leerMercaderia(movimiento)`.
- `inventario`, `inventarioHasta(fecha:, excluirId:)`.
- `saldoDeMercaderia(id, fecha:, excluirId:)`.
- `advertenciaDeCosto(id, costoCentavos, fecha:, excluirId:)`.
- `libroDiario(desde:, hasta:)`, que pasa los datos reales y los ajustes a P1.
- `ajustes`: ids de faltantes/sobrantes de las cajas, como conjunto inmutable.

Las consultas de inventario respetan el inicio del negocio, excluyen eliminados
y fechas futuras y permiten excluir el movimiento que se está editando.
Los asientos se calculan, no se guardan como una segunda copia de las operaciones.
La pantalla del Libro Diario y su exportación corresponden a las siguientes partes.

## Catálogo del Excel

`tools/generar_pcge.py` lee la hoja **PCGE 2026** sin tener Excel instalado:

```powershell
python tools/generar_pcge.py "C:\ruta\FORMATO 5.2 LIBRO DIARIO.xlsx"
```

Produce `assets/pcge.json`: 1.615 registros con `codigo`, `nombre` y `nivel`.
`assets/pcge_origen.json` identifica el archivo, la hoja y su SHA-256. No es una
descarga de una norma: la fuente es el Excel proporcionado para el proyecto.

`Pcge.cadena(codigo)` devuelve las cuentas padre e hija con esos tres campos.
P1 utiliza este método. El lector también admite el JSON anterior para otros
consumidores. Al regenerar el catálogo se verifican duplicados y niveles.

## Verificación

```powershell
flutter analyze
flutter test
```

`test/datos_v7_test.dart` cubre el catálogo, migración real desde v6, validaciones
en SQLite y web, conservación de comprobantes e inventario conectado a P1.
`test/registro_mercaderia_test.dart` recorre la creación desde el formulario,
la compra y la venta/servicio en escritorio y celular.

Resultado verificado el 25 de octubre de 2026: **183 pruebas aprobadas**, incluidas
las 20 de P1 y las 15 nuevas de P2. Las dos suites de capturas antiguas se omiten
según `dart_test.yaml`. El análisis de Dart finaliza sin problemas. Se revisaron
vistas del formulario con la tipografía real en 933 × 600 y 390 × 844.
La compilación web de producción también terminó correctamente (build/web).

## Correcciones de la revisión (30/10/2026)

- Se quitó `lib/ui/registro/campo_mercaderia.dart`. Era interfaz del
  formulario (trabajo de P6) y quedó sin uso cuando P6 hizo el paso
  "¿Qué mercadería?".
- El largo máximo del nombre de una mercadería quedó en 40 caracteres, en una
  sola constante (`ReglasMercaderia.largoMaximo`) que usan el repositorio y el
  diálogo de P4. Antes el repositorio permitía 80 y el diálogo 40.
- Se quitó `EstadoCaja.deCuenta`: sólo lo usaba una pantalla vieja
  (`lib/ui/caja/cuenta_pagina.dart`) que nadie abría, y que también se quitó.
