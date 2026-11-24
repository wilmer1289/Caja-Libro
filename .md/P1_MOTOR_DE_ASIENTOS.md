# P1 · Motor de asientos del Libro Diario

Parte de **P1** del plan del Libro Diario. Convierte los movimientos de la app
en los asientos del Formato 5.1 y calcula el inventario por tipo de
mercadería. No tiene pantallas: es la base que usan P3 (pantalla) y P4
(explicación y exportación).

- **Rama:** `libro-diario/p1-motor`, todavía sin commit.
- **Pruebas del motor:** 20. La integración con P2 y su verificación están documentadas en `P2_DATOS.md`.

## Lo que hice (4 archivos nuevos)

- **`lib/dominio/libro_diario.dart`**: los modelos y el armado del libro.
  - Cada movimiento se convierte en sus asientos bajo un correlativo (001, 002…).
  - Las cuentas salen completas, de 60 a 6011.
  - Se separa el IGV y se comprueba que Debe = Haber.
  - Cada línea trae su "por qué" para el modo Entender de P4.
- **`lib/dominio/reglas_asiento.dart`**: todas las cuentas por categoría en un solo lugar. Si el docente corrige alguna, se cambia solo ahí. Las de los ejemplos de la exposición están marcadas como "del Excel".
- **`lib/dominio/inventario.dart`**: el inventario por tipo de mercadería: lo comprado sin IGV, el costo vendido y el saldo.
- **`test/libro_diario_test.dart`**:
  - Los 4 ejemplos de la exposición (compra, venta, alquiler y luz) salen con las mismas cuentas e importes.
  - Todo asiento cuadra con cualquier categoría y cualquier medio de pago.
  - El motor no depende de ninguna pantalla.

## Conexión con P2

La base v7 guarda `mercaderiaId`, `mercaderiaNombre` y `costoCentavos` en los
movimientos. `EstadoCaja.leerMercaderia` los adapta al contrato `LeerMercaderia`
del motor. `EstadoCaja.libroDiario` y `EstadoCaja.inventario` ya usan esos datos.

Los registros antiguos conservan el dato desconocido. Sus ventas salen con
`faltaCosto`; los servicios explícitos no generan costo de venta.

## Cómo se usa

### El libro de un período

```dart
final libro = LibroDiario.armar(
  negocio: estado.negocio,
  movimientos: estado.movimientos,
  desde: DateTime(2026, 10, 1),
  hasta: DateTime(2026, 10, 31),
  mercaderia: estado.leerMercaderia,
  ajustes: estado.ajustes, // ids de faltantes y sobrantes de caja
);

for (final a in libro.asientos) {
  a.numero;      // "001"
  a.fecha;       // la del movimiento: todo es al contado
  a.glosa;       // "Por la compra de tela"
  a.documento;   // "B001-00000012", "Recibo 000007" o null
  a.codigoLibro; // "08" en las compras de mercadería
  a.faltaCosto;  // venta sin costo: no tiene asiento 2
  for (final e in a.etapas) {
    e.tipo.etiqueta; // "Reconocimiento", "Costo de venta"…
    e.glosa;
    for (final l in e.lineas) {
      l.cadena;  // [40, 401, 4011, 40111], cada una con código y nombre
      l.debe;    // en centavos
      l.haber;
      l.porQue;  // "El IGV que pagaste: lo descuentas del que le debes al Estado."
    }
  }
}

libro.totalDebe; // igual a totalHaber
libro.cuadra;
```

El libro filtra solo: deja afuera lo borrado, lo anterior a la apertura del
negocio y lo que cae fuera del rango. Ordena por fecha y, el mismo día, por el
orden en que se anotó.

### El inventario por tipo

```dart
final inventario = InventarioMercaderias.de(estado.movimientos, leer: estado.leerMercaderia);

inventario.tipos;               // cada tipo con comprado, costoVendido y saldo
inventario.saldo('tela');       // en centavos
inventario.costoVendido('tela');
```

Las compras suman su base, sin IGV, y las ventas restan su costo. Lo que no
dice qué tipo es no entra.

## Las reglas

| Categoría | Asientos | Asiento 2 | Origen |
|---|---|---|---|
| Ventas con mercadería | 3 | Costo de venta: 69121 contra 20111 | Excel |
| Ventas de servicio ("No es mercadería") | 2 | No tiene | Propuesta |
| Compra de mercadería | 3 | Variación de inventarios: 20111 contra 6111 | Excel |
| Alquiler y luz | 3 | Destino del gasto: 91 contra 791 (deuda en 4699) | Excel |
| Agua, internet, teléfono, contable, otros servicios | 3 | Igual que alquiler y luz | Propuesta |
| Suministros, sueldos, EsSalud | 3 | Destino 91 contra 791 (deuda en su cuenta: 4212, 4111, 4031) | Propuesta |
| Pago a proveedor, ONP, AFP, otras obligaciones | 1 | No tiene | Propuesta |
| Cobro de fiado, adelanto de cliente | 1 | No tiene | Propuesta |
| Otros ingresos y categorías propias de entrada | 2 si la cuenta es un ingreso (7); si no, 1 | No tiene (un ingreso no se destina) | Propuesta |
| Otros egresos y categorías propias | 3 si la cuenta es un gasto (62 a 68); si no, 1 | Destino 91 contra 791 | Propuesta |
| Faltante o sobrante de un cierre de caja | 1 | No tiene (659 o 7599 contra la caja) | Propuesta |

- **Efectivo:** va en 101 Caja.
- **Banco:** Yape, transferencia, depósito y tarjetas van en 104 › 1041.
- **"Propuesta":** es una regla nuestra, porque el Excel no trae un ejemplo. Hay que mostrársela al docente.

## Integración

P2 incorpora el catálogo de la hoja PCGE 2026. La cadena de cuentas se obtiene
de `Pcge.cadena`. `EstadoCaja.ajustes` expone los ids de faltantes y sobrantes
para evitar tratarlos como operaciones ordinarias. La pantalla del Diario y
su exportación corresponden a P3 y P4. Las reglas marcadas como propuesta
siguen pendientes de confirmación con el docente.

## Cómo correr las pruebas

```bash
flutter test test/libro_diario_test.dart
```

## Después de la integración (30/10/2026)

- P2 adaptó el motor a su catálogo nuevo: `_cadena` usa `Pcge.cadena` y las
  pruebas cargan el catálogo con `Pcge.cargarDeTexto`. Los resultados no
  cambiaron.
- Los dos avisos de arriba ya están resueltos: `EstadoCaja.libroDiario` pasa
  la mercadería real y los ajustes de caja, y la pantalla marca las ventas sin
  costo.
- El "por qué" de cada línea ya se muestra al desplegar una operación.
