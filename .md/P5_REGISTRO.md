# P5_REGISTRO · Formulario Entró y Salió

Parte **P5_REGISTRO** del proyecto Mi Caja. Esta parte mantiene el formulario de
registro de movimientos y separa la interfaz de cada paso para facilitar el
trabajo en paralelo con P6 y reducir conflictos al integrar cambios.

## Archivos principales

- `lib/ui/registro/registro_hoja.dart`: coordina el estado, las validaciones,
  el guardado del movimiento y la navegación entre pasos.
- `lib/ui/registro/paso_datos.dart`: datos del movimiento, categoría, importe,
  medio de pago y datos opcionales de la contraparte.
- `lib/ui/registro/paso_efectivo.dart`: captura manual de billetes y monedas
  entregados y del vuelto.
- `lib/ui/registro/paso_comprobante.dart`: vista previa del recibo/boleta y
  responsable de caja.
- `lib/ui/registro/pie_registro.dart`: pie compartido en celular y escritorio
  con Atrás, Continuar/Guardar y el ícono de imprimir cuando corresponde.
- `lib/ui/registro/registro_componentes.dart`: elementos reutilizables del
  formulario, incluida la línea informativa del IGV.
- `lib/ui/registro/nueva_categoria.dart`: creación de categorías propias sin un
  interruptor manual de IGV.

## Cambios incluidos

1. **Formulario dividido por pasos.** Datos, efectivo y comprobante están en
   archivos separados; el archivo principal conserva el estado y la lógica del
   flujo para evitar duplicar validaciones.
2. **IGV automático.** Se eliminó el estado `_conIgv` y el interruptor de la
   creación de categorías. La categoría determina si corresponde el IGV; cuando
   aplica, el formulario muestra `Incluye IGV S/ x` como información. Las
   categorías propias nuevas no activan IGV manualmente.
3. **Sin atajos de pago.** No hay opción «Exacto», texto «O marca billete por
   billete» ni lista `pagosRapidos` en el formulario.
4. **Pago y vuelto manuales.** El monto entregado debe ser mayor o igual al
   movimiento. Si hay diferencia, los billetes/monedas del vuelto se registran
   manualmente y deben sumar exactamente esa diferencia para continuar o guardar.
5. **Pie uniforme.** Se comparte el mismo componente para móvil y escritorio:
   Atrás, Continuar o Guardar y el ícono para guardar e imprimir cuando existe
   un comprobante imprimible.
6. **Pruebas ampliadas.** Se comprueba que no aparezca el control manual del IGV,
   que un pago insuficiente no continúe y que el vuelto incorrecto impida seguir.
   Las pruebas de captura también incluyen el formulario móvil y la creación de
   categoría.

## Verificación local

Desde la carpeta que contiene `pubspec.yaml`, con Flutter instalado:

```powershell
flutter pub get
flutter analyze
flutter test
flutter test test/captura_app_test.dart --tags captura --run-skipped
flutter build apk --release
flutter build web --release
```

Para guardar las capturas generadas por la prueba de aplicación en una carpeta
específica, define `CAPTURAS` antes de ejecutar la prueba. En PowerShell:

```powershell
$env:CAPTURAS = "capturas"
flutter test test/captura_app_test.dart --tags captura --run-skipped
```

## Estado de integración

Esta copia conserva el código y la documentación de las partes presentes en el
proyecto. No incluye la rama P6, por lo que la integración final entre P5 y P6
no se puede completar ni certificar con este ZIP por sí solo.

En el entorno donde se preparó esta entrega no está instalado Flutter/Dart. Por
ello, las pruebas Flutter, la regeneración efectiva de PNG, el APK nuevo y la
compilación web quedan pendientes de ejecutar en una máquina con el SDK. El APK
que ya existía en `entregables/` se conserva como artefacto anterior y no debe
considerarse una compilación de estos últimos cambios.

## Correcciones de la revisión (30/10/2026)

- Volvió el interruptor "El monto trae IGV" en Nueva categoría. El IGV
  automático quita el interruptor del formulario de registro, pero la
  categoría propia sigue diciendo si lleva IGV: de eso depende el IGV
  automático de cada movimiento con ella.
- Con boleta y recibo a la vez, el ícono de imprimir abre un menú: Boleta,
  Recibo, o Boleta y recibo. Con uno solo, imprime ese directamente.
- Los widgets públicos de `registro_componentes.dart` aceptan `key`: el
  análisis queda sin avisos.
- `LEEME_CORRECCIONES.md` volvió a su versión original; lo de P5 está en este
  archivo.
- Se quitó `.vscode/settings.json`: tenía una ruta de otra computadora
  (`C:/Users/klive/...`).
- La captura "registro: comprobantes, pago en efectivo y recibo" se actualizó
  al paso de mercadería.
