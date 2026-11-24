# Mi Caja: correcciones

## Abrir en Windows

1. Cierra Mi Caja y conserva una copia de tu proyecto anterior.
2. Si ya registraste datos, copia también `mi_caja.db` desde la carpeta Documentos
   que usa la aplicación. El ZIP contiene código, no tu base de datos personal.
3. Extrae este ZIP y abre la carpeta `Libro-caja` en VS Code.
4. Ejecuta, desde la carpeta que contiene `pubspec.yaml`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Para generar el ejecutable:

```powershell
flutter build windows --release
```

Conserva toda la carpeta de salida Release junto al ejecutable: necesita sus
DLL y la carpeta `data`. Las versiones de Flutter/Dart y las dependencias del
proyecto original no se han cambiado.

## Cambios realizados

- Guardar movimientos o el perfil informa los errores y permite reintentar.
- Corregido el conflicto de clave que impedía actualizar el perfil tras el
  primer guardado: ahora reemplaza la única fila del negocio correctamente.
- Importes convertidos a centavos enteros, con máximo dos decimales; se rechazan
  importes inválidos, excesivos y movimientos que terminarían en cero centavos.
- Saldos iniciales inválidos ya no se convierten silenciosamente en cero.
- No se aceptan nuevos movimientos futuros ni anteriores a la apertura configurada.
- Resumen y gráficos excluyen movimientos anteriores a la apertura y futuros.
  El historial conserva los registros antiguos para que puedan revisarse.
- El formato arrastra operaciones desde la apertura, sin duplicar lo anterior.
- El gráfico de saldo incluye los saldos iniciales y el dashboard los muestra
  aunque todavía no haya movimientos.
- Numeración de nuevas operaciones y recibos asignada en la misma transacción
  SQLite que guarda el movimiento. Es numeración local, no multidispositivo.
- Migración desde v1 con orden determinista cuando coinciden fechas de creación.
  No se borran registros ni se renumeran automáticamente datos ya migrados a v2.
- Eliminación confirmada después de guardar; errores de eliminar/restaurar visibles.
- Deshacer no agrega dos copias del mismo movimiento a la lista en memoria.
- Filtro de fechas incluye el último día completo, también sus milisegundos.
- Apertura de SQLite compartida entre solicitudes simultáneas.
- Fallos de carga muestran un error y el botón Reintentar.
- Copiar un movimiento no altera su fecha de actualización salvo que se solicite.
- Marcar respaldos sólo afecta a la versión enviada; no marca una edición posterior.
- Exportación exige el perfil y, para bancos, la entidad y el número de cuenta.
- CSV protege textos que podrían interpretarse como fórmulas y escapa retornos.
- Mensajes de sincronización distinguen éxito, falta de configuración y error.
- Apertura de archivos en Linux/macOS comprueba el resultado del proceso.

## Verificación y límites

Se verificó la sintaxis de los 71 archivos Dart con un analizador sintáctico y
los imports relativos. Se ejecutaron comprobaciones SQLite del guardado repetido
del perfil, la numeración de la migración con fechas empatadas (sin perder
importes) y el marcado condicionado de respaldos: todas pasaron.

Se agregaron nueve pruebas Flutter en `test/correcciones_test.dart` para importes,
saldos, gráficos, formatos, CSV, perfil bancario, registros concurrentes y edición
durante respaldo. También se ajustó el caso existente de arrastre entre meses
para distinguir la fecha de apertura de la fecha del informe.

Flutter/Dart no están instalados en el entorno de edición. No se ejecutaron
`flutter analyze`, `flutter test` ni la compilación de Windows. La validación de
sintaxis no sustituye esas comprobaciones ni garantiza ausencia total de errores.

El acceso sigue siendo de demostración (`usuario` / `usuario123`) y SQLite sigue
sin cifrado. No se ha añadido autenticación de producción ni conexión con Firebase.
La nube sigue sin configurar; los datos permanecen en el equipo. Esas funciones
requieren un trabajo de seguridad e integración adicional. No se añadió arqueo.

No se incluyeron los binarios temporales `windows/flutter/ephemeral` ni el archivo
`android/local.properties` con rutas de otro equipo: Flutter los regenera.
No se alteraron tasas ni reglas tributarias; esto no es una validación normativa.
