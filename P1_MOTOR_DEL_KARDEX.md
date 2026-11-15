# P1 · Motor del kardex

Rama `inventario/p1-motor`, basada en `e4adbb1`. El motor está en
`lib/dominio/kardex.dart`. Recibe líneas de almacén y reconstruye el historial
de cada producto en orden de día y número de registro. A igual día y número
conserva el orden de las líneas del comprobante.

## Uso e integración

- P2 puede reexportar `LineaAlmacen` y `OperacionAlmacen` desde
  `lib/dominio/linea_kardex.dart`. La base v8 del proyecto todavía no trae
  estas clases. Cantidades y mínimos se expresan en milésimas, dinero en
  centavos y costos unitarios en soles por unidad.
- Pasar las líneas a `Kardex.de(lineas)`. Marcar como anuladas todas las líneas
  de un movimiento anulado, o excluirlas al leer. Para conectar con el estado,
  proporcionar `leerLineasAlmacen` al construir `EstadoCaja`. Con la fuente
  v9, el panel lee el kardex. Con el repositorio v8 mantiene la lectura histórica.
- El registro puede consultar `costoDeSalida(id, cantidad, fecha)`. El Libro
  Diario puede consultar `costoDe(lineaId)` y `costoDeVentas(periodo)`.
  Las ventas antiguas conservan su tratamiento en el Libro Diario.
- Para ver un mes histórico usar, por ejemplo, `Periodo.mes` con
  `referencia: DateTime(2026, 10, 31)`. Las filas del período ya incorporan
  el saldo arrastrado. Las alertas reciben el catálogo activo y sus mínimos
  por ID. El margen bruto usa el importe de venta después del descuento.
- Para la etapa 2, P2 entrega el gasto de compra ya repartido en
  `gastoCompraAsignado`, separado del costo base. El corte
  `saldosFinDeAnio(anio)` incluye movimientos hasta el 31 de diciembre.

## Decisiones de cálculo

Las salidas al promedio se calculan con el saldo monetario completo y se
redondean al centavo. Una salida al promedio que agota la existencia toma
todo su valor. Las devoluciones parciales toman el costo proporcional de
la línea original. Se redondea el acumulado para que varias devoluciones
sumen exactamente el costo original. Se rechaza una devolución al proveedor
si valorar al costo original dejaría valor negativo o dinero sin unidades.
Un ajuste positivo sobre existencia cero necesita un costo explícito.

## Verificación y entrega

`flutter test test/kardex_test.dart` contrasta apertura y 15 comprobantes
con el plan. El resultado esperado es 900 unidades, S/ 44,234.55 en almacén
y S/ 391,975.45 en salidas. El costo de ventas se reparte entre 69111
(S/ 88,518.00) y 69121 (S/ 303,457.45).

La integración de las ramas P2–P7 y las capturas de las pantallas finales
quedan para cuando el equipo entregue esas ramas. Entonces se debe conectar
la fuente persistida de P2 y ejecutar nuevamente la suite sobre el conjunto.
