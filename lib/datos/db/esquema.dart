/// DDL de la base local.
///
/// Cuatro tablas: el libro de caja es una lista de movimientos; el negocio
/// es una sola fila con los datos del encabezado de los formatos y los saldos
/// con que abre el período; las categorías que el usuario agrega con el "+"
/// del formulario; y las cajas, cada una con su apertura y su cierre.
class Esquema {
  /// v1: el libro básico.
  /// v2: la contabilidad del Excel — correlativo, cuenta asociada, IGV,
  ///     documento de la contraparte, N° de transacción bancaria, recibo, y
  ///     la tabla del negocio con los saldos iniciales.
  /// v3: las categorías propias del usuario.
  /// v4: boleta de venta interna, recibo con su tesorero, detalle de
  ///     billetes y vuelto, responsable de caja del negocio, y arqueos.
  /// v5: la caja del día —se abre con un monto y se cierra contando—, que
  ///     reemplaza al arqueo suelto contra el libro.
  static const version = 5;

  static const tablaMovimientos = 'movimientos';
  static const tablaNegocio = 'negocio';
  static const tablaCategorias = 'categorias_propias';
  static const tablaArqueos = 'arqueos';
  static const tablaJornadas = 'jornadas';

  static const crearMovimientos =
      '''
    CREATE TABLE $tablaMovimientos (
      id                    TEXT    PRIMARY KEY,
      numero                INTEGER NOT NULL DEFAULT 0,
      tipo                  TEXT    NOT NULL,
      centavos              INTEGER NOT NULL,
      categoria_id          TEXT    NOT NULL,
      concepto              TEXT    NOT NULL,
      medio                 TEXT    NOT NULL,
      cuenta                TEXT    NOT NULL,
      fecha                 INTEGER NOT NULL,
      creado_en             INTEGER NOT NULL,
      actualizado_en        INTEGER NOT NULL,
      cuenta_asociada       TEXT,
      igv_centavos          INTEGER NOT NULL DEFAULT 0,
      contraparte           TEXT,
      documento_contraparte TEXT,
      numero_transaccion    TEXT,
      numero_recibo         INTEGER,
      numero_boleta         INTEGER,
      tesorero              TEXT,
      detalle_efectivo      TEXT,
      ruta_foto             TEXT,
      eliminado_en          INTEGER,
      sync                  TEXT    NOT NULL
    )
  ''';

  /// Una sola fila, con id fijo 1: el negocio es uno.
  static const crearNegocio =
      '''
    CREATE TABLE $tablaNegocio (
      id                  INTEGER PRIMARY KEY,
      razon_social        TEXT    NOT NULL DEFAULT '',
      documento           TEXT    NOT NULL DEFAULT '',
      direccion           TEXT    NOT NULL DEFAULT '',
      entidad_financiera  TEXT    NOT NULL DEFAULT '',
      cuenta_corriente    TEXT    NOT NULL DEFAULT '',
      saldo_inicial_caja  INTEGER NOT NULL DEFAULT 0,
      saldo_inicial_banco INTEGER NOT NULL DEFAULT 0,
      inicio_periodo      INTEGER,
      tesorero            TEXT    NOT NULL DEFAULT ''
    )
  ''';

  /// La tabla del negocio tal como era en la v2. La migración desde la v1 la
  /// crea así, congelada: si usara la de arriba, que ya trae el tesorero, el
  /// paso a la v4 intentaría agregar una columna que ya existe.
  static const crearNegocioV2 =
      '''
    CREATE TABLE $tablaNegocio (
      id                  INTEGER PRIMARY KEY,
      razon_social        TEXT    NOT NULL DEFAULT '',
      documento           TEXT    NOT NULL DEFAULT '',
      direccion           TEXT    NOT NULL DEFAULT '',
      entidad_financiera  TEXT    NOT NULL DEFAULT '',
      cuenta_corriente    TEXT    NOT NULL DEFAULT '',
      saldo_inicial_caja  INTEGER NOT NULL DEFAULT 0,
      saldo_inicial_banco INTEGER NOT NULL DEFAULT 0,
      inicio_periodo      INTEGER
    )
  ''';

  /// Los movimientos tal como eran en la v2 y la v3, para las pruebas de
  /// migración.
  static const crearMovimientosV2 =
      '''
    CREATE TABLE $tablaMovimientos (
      id                    TEXT    PRIMARY KEY,
      numero                INTEGER NOT NULL DEFAULT 0,
      tipo                  TEXT    NOT NULL,
      centavos              INTEGER NOT NULL,
      categoria_id          TEXT    NOT NULL,
      concepto              TEXT    NOT NULL,
      medio                 TEXT    NOT NULL,
      cuenta                TEXT    NOT NULL,
      fecha                 INTEGER NOT NULL,
      creado_en             INTEGER NOT NULL,
      actualizado_en        INTEGER NOT NULL,
      cuenta_asociada       TEXT,
      igv_centavos          INTEGER NOT NULL DEFAULT 0,
      contraparte           TEXT,
      documento_contraparte TEXT,
      numero_transaccion    TEXT,
      numero_recibo         INTEGER,
      ruta_foto             TEXT,
      eliminado_en          INTEGER,
      sync                  TEXT    NOT NULL
    )
  ''';

  /// Los arqueos de caja: lo que se contó, lo que decía el libro y la
  /// diferencia. La restricción de la diferencia está en la tabla misma: un
  /// arqueo guardado nunca puede tener una resta mal hecha.
  ///
  /// `IF NOT EXISTS` porque una versión anterior de la app ya creaba esta
  /// misma tabla, con estas mismas columnas, en algunas bases.
  static const crearArqueos =
      '''
    CREATE TABLE IF NOT EXISTS $tablaArqueos (
      id TEXT PRIMARY KEY,
      fecha_corte INTEGER NOT NULL,
      confirmado_en INTEGER NOT NULL,
      esperado INTEGER NOT NULL,
      contado INTEGER NOT NULL CHECK (contado >= 0),
      diferencia INTEGER NOT NULL CHECK (diferencia = contado - esperado),
      conteo_json TEXT NOT NULL,
      responsable TEXT NOT NULL,
      usuario TEXT NOT NULL,
      supervisor TEXT NOT NULL,
      observacion TEXT NOT NULL,
      negocio TEXT NOT NULL,
      documento TEXT NOT NULL
    )
  ''';

  /// Las cajas: con cuánto se abrió, qué entró y salió en efectivo mientras
  /// estuvo abierta, y lo que se contó al cerrarla.
  ///
  /// Que haya una sola abierta a la vez lo cuida quien la abre, dentro de una
  /// transacción: el índice que lo aseguraría en la tabla necesita un SQLite
  /// más nuevo que el de los Android viejos.
  static const crearJornadas =
      '''
    CREATE TABLE $tablaJornadas (
      id              TEXT    PRIMARY KEY,
      numero          INTEGER NOT NULL,
      abierta_en      INTEGER NOT NULL,
      apertura        INTEGER NOT NULL,
      conteo_apertura TEXT,
      inicio          TEXT    NOT NULL,
      anterior        INTEGER NOT NULL DEFAULT 0,
      responsable     TEXT    NOT NULL,
      usuario         TEXT    NOT NULL,
      negocio         TEXT    NOT NULL DEFAULT '',
      documento       TEXT    NOT NULL DEFAULT '',
      cerrada_en      INTEGER,
      entradas        INTEGER NOT NULL DEFAULT 0,
      salidas         INTEGER NOT NULL DEFAULT 0,
      operaciones     INTEGER NOT NULL DEFAULT 0,
      conteo_cierre   TEXT,
      supervisor      TEXT    NOT NULL DEFAULT '',
      observacion     TEXT    NOT NULL DEFAULT '',
      ajuste_id       TEXT
    )
  ''';

  /// Las categorías que agrega el usuario ("Movilidad", "Publicidad"…). Se
  /// guarda la cuenta del plan contable porque es la que sale en el formato:
  /// una categoría sin cuenta no se podría imprimir.
  static const crearCategorias =
      '''
    CREATE TABLE $tablaCategorias (
      id                TEXT    PRIMARY KEY,
      etiqueta          TEXT    NOT NULL,
      tipo              TEXT    NOT NULL,
      cuenta_asociada   TEXT    NOT NULL,
      cuenta_resultado  TEXT,
      afecto_igv        INTEGER NOT NULL DEFAULT 0,
      creado_en         INTEGER NOT NULL
    )
  ''';

  /// El historial casi siempre se lee por fecha descendente y filtrando lo
  /// borrado; estos índices son los que hacen que esa consulta no recorra todo.
  static const indices = <String>[
    'CREATE INDEX idx_mov_fecha ON $tablaMovimientos (fecha DESC)',
    'CREATE INDEX idx_mov_cuenta ON $tablaMovimientos (cuenta, fecha DESC)',
    'CREATE INDEX idx_mov_sync ON $tablaMovimientos (sync)',
    'CREATE INDEX idx_mov_numero ON $tablaMovimientos (numero)',
    'CREATE INDEX idx_jornada_abierta ON $tablaJornadas (abierta_en DESC)',
  ];

  /// De la v1 a la v2, sin perder lo que ya había registrado.
  ///
  /// SQLite sólo deja agregar una columna por sentencia, así que van de a una.
  /// El correlativo se rellena por orden de creación: los movimientos viejos
  /// no tenían número y el formato lo necesita.
  static const migracionV2 = <String>[
    'ALTER TABLE $tablaMovimientos ADD COLUMN numero INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE $tablaMovimientos ADD COLUMN cuenta_asociada TEXT',
    'ALTER TABLE $tablaMovimientos ADD COLUMN igv_centavos INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE $tablaMovimientos ADD COLUMN documento_contraparte TEXT',
    'ALTER TABLE $tablaMovimientos ADD COLUMN numero_transaccion TEXT',
    'ALTER TABLE $tablaMovimientos ADD COLUMN numero_recibo INTEGER',
    '''
    UPDATE $tablaMovimientos SET numero = (
      SELECT COUNT(*) FROM $tablaMovimientos AS previos
      WHERE previos.creado_en < $tablaMovimientos.creado_en
        OR (previos.creado_en = $tablaMovimientos.creado_en
            AND previos.id <= $tablaMovimientos.id)
    )
    ''',
    'CREATE INDEX idx_mov_numero ON $tablaMovimientos (numero)',
    crearNegocioV2,
  ];

  /// De la v3 a la v4: sólo agrega. Lo ya registrado queda igual; los
  /// movimientos viejos no tienen boleta ni detalle de billetes, y está bien.
  static const migracionV4 = <String>[
    'ALTER TABLE $tablaMovimientos ADD COLUMN numero_boleta INTEGER',
    'ALTER TABLE $tablaMovimientos ADD COLUMN tesorero TEXT',
    'ALTER TABLE $tablaMovimientos ADD COLUMN detalle_efectivo TEXT',
    "ALTER TABLE $tablaNegocio ADD COLUMN tesorero TEXT NOT NULL DEFAULT ''",
    crearArqueos,
  ];

  /// De la v4 a la v5: la tabla de las cajas. Los arqueos que ya se habían
  /// hecho pasan a ser cajas cerradas —empezaron con lo que decía el libro y
  /// terminaron con lo contado—, para que no desaparezcan del historial. La
  /// tabla vieja queda como estaba.
  static const migracionV5 = <String>[
    crearJornadas,
    'CREATE INDEX idx_jornada_abierta ON $tablaJornadas (abierta_en DESC)',
    '''
    INSERT INTO $tablaJornadas (
      id, numero, abierta_en, apertura, conteo_apertura, inicio, anterior,
      responsable, usuario, negocio, documento, cerrada_en, entradas,
      salidas, operaciones, conteo_cierre, supervisor, observacion
    )
    SELECT
      id,
      (SELECT COUNT(*) FROM $tablaArqueos AS previos
        WHERE previos.confirmado_en <= $tablaArqueos.confirmado_en),
      fecha_corte, esperado, NULL, 'libro', 0,
      responsable, usuario, negocio, documento, confirmado_en, 0,
      0, 0, conteo_json, supervisor, observacion
    FROM $tablaArqueos
    ''',
  ];
}
