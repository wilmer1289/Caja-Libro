import 'package:uuid/uuid.dart';

import '../../dominio/boleta.dart';
import '../../dominio/categoria.dart';
import '../../dominio/efectivo.dart';
import '../../dominio/enums.dart';
import '../../dominio/fondo.dart';
import '../../dominio/igv.dart';
import '../../dominio/importe.dart';
import '../../dominio/jornada.dart';
import '../../dominio/movimiento.dart';
import '../../dominio/negocio.dart';
import '../local/categoria_dao.dart';
import '../local/fondo_dao.dart';
import '../local/jornada_dao.dart';
import '../local/movimiento_dao.dart';
import '../local/negocio_dao.dart';
import '../remoto/fuente_remota.dart';
import '../remoto/fuente_remota_nula.dart';

/// La pieza clave de la arquitectura (§2.4): las pantallas nunca hablan con
/// SQLite ni con Firebase, siempre pasan por aquí.
///
/// Regla de oro del offline-first: **lo local manda**. Toda escritura se
/// confirma contra SQLite y recién después se intenta la nube. Si no hay
/// internet, no pasa nada: el movimiento ya está guardado y queda pendiente.
class RepositorioMovimientos {
  RepositorioMovimientos({
    MovimientoDao? dao,
    NegocioDao? negocioDao,
    CategoriaDao? categoriaDao,
    JornadaDao? jornadaDao,
    FondoDao? fondoDao,
    FuenteRemota? remoto,
  }) : _dao = dao ?? MovimientoDao(),
       _negocioDao = negocioDao ?? NegocioDao(),
       _categoriaDao = categoriaDao ?? CategoriaDao(),
       _jornadaDao = jornadaDao ?? JornadaDao(),
       _fondoDao = fondoDao ?? FondoDao(),
       _remoto = remoto ?? const FuenteRemotaNula();

  final MovimientoDao _dao;
  final NegocioDao _negocioDao;
  final CategoriaDao _categoriaDao;
  final JornadaDao _jornadaDao;
  final FondoDao _fondoDao;
  final FuenteRemota _remoto;

  /// El efectivo del negocio, o null si todavía no se contó.
  Future<FondoNegocio?> leerFondo() => _fondoDao.leer();

  /// Guarda el primer conteo del efectivo del negocio. Se hace una vez, con
  /// la caja cerrada; después sólo se corrige.
  Future<FondoNegocio> contarFondo({
    required Conteo conteo,
    required String usuario,
  }) async {
    if (await leerFondo() != null) {
      throw ArgumentError(
        'El efectivo del negocio ya se contó. Si contaste mal, corrígelo.',
      );
    }
    final problema = FondoNegocio.problemaCon(conteo, await leerJornadas());
    if (problema != null) throw ArgumentError(problema);
    final fondo = FondoNegocio(
      conteo: conteo,
      contadoEn: _alMilisegundo(DateTime.now()),
      usuario: usuario,
    );
    await _fondoDao.guardar(fondo);
    return fondo;
  }

  /// Corrige lo que se contó, por si se contó mal. Lo que vino después —lo
  /// guardado en cada apertura— se recalcula solo a partir de este conteo.
  Future<FondoNegocio> corregirFondo({
    required Conteo conteo,
    required String usuario,
  }) async {
    final actual = await leerFondo();
    if (actual == null) {
      throw ArgumentError('Todavía no se contó el efectivo del negocio.');
    }
    final problema = FondoNegocio.problemaCon(
      conteo,
      await leerJornadas(),
      contadoEn: actual.contadoEn,
    );
    if (problema != null) throw ArgumentError(problema);
    final corregido = actual.corregir(
      conteo,
      usuario: usuario,
      en: _alMilisegundo(DateTime.now()),
    );
    await _fondoDao.guardar(corregido);
    return corregido;
  }

  /// Las cajas, de la más nueva a la más vieja.
  Future<List<Jornada>> leerJornadas() => _jornadaDao.listar();

  /// La base guarda las horas al milisegundo: redondeada así, la que queda
  /// en memoria es la misma que se leería después.
  static DateTime _alMilisegundo(DateTime d) =>
      DateTime.fromMillisecondsSinceEpoch(d.millisecondsSinceEpoch);

  /// Abre una caja con el monto con que empieza.
  ///
  /// Antes hay que haber contado el efectivo del negocio: lo de la caja sale
  /// de ahí. Si se contaron los billetes, tienen que sumar el monto: es de
  /// donde la app parte para decir, al cerrar, cuántos de cada uno debería
  /// haber.
  Future<Jornada> abrirCaja({
    required int apertura,
    required InicioCaja inicio,
    required String responsable,
    required String usuario,
    Conteo? conteo,
    int anterior = 0,
  }) async {
    if (apertura < 0 || apertura > Importe.maximoCentavos) {
      throw ArgumentError('El monto con que empieza la caja no es válido.');
    }
    if (conteo != null && conteo.total != apertura) {
      throw ArgumentError(
        'Los billetes contados no suman lo que dice el monto de apertura.',
      );
    }
    if (responsable.trim().isEmpty) {
      throw ArgumentError('Escribe quién queda a cargo de la caja.');
    }
    if (await leerFondo() == null) {
      throw ArgumentError(
        'Primero cuenta el efectivo del negocio: de ahí sale lo de la caja.',
      );
    }
    final negocio = await leerNegocio();
    final ahora = DateTime.now();
    return _jornadaDao.abrir(
      (numero) => Jornada(
        id: _uuid.v4(),
        numero: numero,
        abiertaEn: ahora,
        apertura: apertura,
        conteoApertura: conteo,
        inicio: inicio,
        anterior: anterior,
        responsable: responsable.trim(),
        usuario: usuario,
        negocio: negocio.razonSocial,
        documento: negocio.documento,
      ),
    );
  }

  /// Guarda el cierre de una caja: lo contado y los totales, que desde acá
  /// quedan fijos.
  Future<void> guardarCierre(Jornada caja) {
    if (caja.abierta || caja.conteoCierre == null) {
      throw ArgumentError('Para cerrar la caja hay que contar la plata.');
    }
    return _jornadaDao.actualizar(caja);
  }

  /// Anota en la caja el movimiento con que se llevó al libro su faltante o
  /// su sobrante.
  Future<void> guardarAjuste(Jornada caja) => _jornadaDao.actualizar(caja);

  /// Le da recibo a un movimiento guardado sin él, con el responsable de caja
  /// de ese momento.
  Future<Movimiento> emitirRecibo(
    Movimiento movimiento, {
    required String tesorero,
  }) {
    if (movimiento.numeroRecibo != null) return Future.value(movimiento);
    return _dao.asignarRecibo(
      movimiento,
      tesorero: tesorero.trim(),
      ahora: DateTime.now(),
    );
  }

  /// Las categorías que el usuario agregó. Por ahora viven sólo en el
  /// equipo: cuando se conecte la nube, habrá que subirlas junto con los
  /// movimientos que las usan.
  Future<List<Categoria>> leerCategoriasPropias() => _categoriaDao.listar();

  /// Crea una categoría propia con su cuenta del plan contable.
  ///
  /// La cuenta elegida va directo como "cuenta contable asociada" del
  /// formato: es la que el usuario buscó y eligió, y es la que espera ver
  /// impresa. No se inventa una provisión intermedia.
  Future<Categoria> agregarCategoria({
    required String etiqueta,
    required Tipo tipo,
    required String cuenta,
    bool afectoIgv = false,
  }) async {
    final nombre = etiqueta.trim();
    if (nombre.isEmpty) {
      throw ArgumentError('La categoría necesita un nombre.');
    }
    if (cuenta.trim().isEmpty) {
      throw ArgumentError('La categoría necesita su cuenta del plan contable.');
    }
    final repetida = Categoria.de(tipo)
        .any((c) => c.etiqueta.toLowerCase() == nombre.toLowerCase());
    if (repetida) {
      throw ArgumentError('Ya hay una categoría que se llama "$nombre".');
    }

    final categoria = Categoria(
      id: 'propia_${_uuid.v4()}',
      etiqueta: nombre,
      tipo: tipo,
      grupo: GrupoCategoria.propias,
      cuentaAsociada: cuenta.trim(),
      afectoIgv: afectoIgv,
      comun: true,
      propia: true,
    );
    await _categoriaDao.guardar(categoria);
    return categoria;
  }

  Future<Negocio> leerNegocio() => _negocioDao.leer();
  Future<void> guardarNegocio(Negocio negocio) => _negocioDao.guardar(negocio);
  static const _uuid = Uuid();

  Future<List<Movimiento>> listar({Cuenta? cuenta}) =>
      _dao.listar(cuenta: cuenta);

  /// Registra un movimiento nuevo y devuelve lo que quedó guardado.
  Future<Movimiento> registrar({
    required Tipo tipo,
    required int centavos,
    required String categoriaId,
    required String concepto,
    required MedioPago medio,
    required DateTime fecha,
    String? contraparte,
    String? documentoContraparte,
    String? numeroTransaccion,
    String? cuentaAsociada,
    bool? conIgv,
    String? rutaFoto,
    bool conRecibo = false,
    String? tesorero,
    DetalleEfectivo? detalleEfectivo,
  }) async {
    final ahora = DateTime.now();
    final categoria = Categoria.porId(categoriaId);
    if (centavos <= 0 || centavos > Importe.maximoCentavos) {
      throw ArgumentError(
        'El monto debe ser mayor que cero y estar dentro del límite.',
      );
    }
    if (categoria.id != categoriaId || categoria.tipo != tipo) {
      throw ArgumentError('La categoría no corresponde al movimiento.');
    }
    // Ley de Bancarización: desde S/ 2,000 no se paga ni se cobra en
    // efectivo. El formulario ya no deja guardarlo; esto es la segunda
    // barrera, por si algún día llega un movimiento por otro camino.
    if (medio == MedioPago.efectivo &&
        centavos >= Movimiento.umbralBancarizacionCentavos) {
      throw ArgumentError(
        'Desde S/ 2,000 no se puede registrar en efectivo: usa banco, Yape, '
        'transferencia, depósito o tarjeta.',
      );
    }
    // La boleta de control interno: desde S/ 700 lleva quién compró.
    final conBoleta = Boleta.corresponde(categoria);
    if (conBoleta &&
        Boleta.exigeCliente(centavos) &&
        ((contraparte ?? '').trim().isEmpty ||
            (documentoContraparte ?? '').trim().isEmpty)) {
      throw ArgumentError(
        'Desde S/ 700 la boleta lleva el nombre y el DNI o RUC del cliente.',
      );
    }
    if (detalleEfectivo != null &&
        (medio != MedioPago.efectivo || !detalleEfectivo.cuadraCon(centavos))) {
      throw ArgumentError(
        'Los billetes y el vuelto no cuadran con el monto del movimiento.',
      );
    }
    if (!fecha.isBefore(DateTime(ahora.year, ahora.month, ahora.day + 1))) {
      throw ArgumentError('No se pueden registrar movimientos futuros.');
    }
    final negocio = await leerNegocio();
    if (negocio.inicioPeriodo != null &&
        fecha.isBefore(negocio.inicioPeriodo!)) {
      throw ArgumentError('La fecha es anterior a la apertura del negocio.');
    }

    // El IGV va incluido en el monto: se desagrega hacia adentro para que el
    // saldo del libro siga siendo la plata que de verdad se movió.
    final afecto = conIgv ?? categoria.afectoIgv;
    final igv = afecto ? Igv.desagregar(centavos).igv : 0;

    // Numeración local: lectura e inserción atómicas, incluso con dos formularios.
    return _dao.insertarNumerado(
      tipo,
      conRecibo,
      conBoleta: conBoleta,
      (numero, recibo, boleta) => Movimiento(
        id: _uuid.v4(),
        numero: numero,
        tipo: tipo,
        centavos: centavos,
        categoriaId: categoriaId,
        concepto: concepto,
        medio: medio,
        fecha: fecha,
        creadoEn: ahora,
        actualizadoEn: ahora,
        cuentaAsociada: cuentaAsociada ?? categoria.cuentaAsociada,
        igvCentavos: igv,
        contraparte: contraparte,
        documentoContraparte: documentoContraparte,
        numeroTransaccion: numeroTransaccion,
        numeroRecibo: recibo,
        numeroBoleta: boleta,
        tesorero: conRecibo ? tesorero?.trim() : null,
        detalleEfectivo: detalleEfectivo,
        rutaFoto: rutaFoto,
        sync: EstadoSync.local,
      ),
    );
  }

  /// Cualquier edición vuelve el registro a "pendiente de subir" y le pone
  /// hora nueva, que es lo que después define quién gana el conflicto.
  Future<Movimiento> editar(Movimiento movimiento) async {
    final actualizado = movimiento.copiarCon(
      actualizadoEn: DateTime.now(),
      sync: EstadoSync.local,
    );
    await _dao.guardar(actualizado);
    return actualizado;
  }

  /// Borrado lógico. El registro sigue en la tabla con `eliminado_en`, así el
  /// "Deshacer" es inmediato y la nube se entera del borrado igual que de
  /// cualquier otro cambio.
  Future<Movimiento> eliminar(Movimiento movimiento) async {
    final borrado = movimiento.copiarCon(
      eliminadoEn: DateTime.now(),
      actualizadoEn: DateTime.now(),
      sync: EstadoSync.local,
    );
    await _dao.guardar(borrado);
    return borrado;
  }

  /// El "Deshacer" del §5. Se apoya en que nunca hicimos DELETE de verdad.
  ///
  /// Va con el constructor completo y no con `copiarCon` porque ese usa `??`
  /// para cada campo, y con `??` es imposible volver `eliminadoEn` a null.
  Future<Movimiento> restaurar(Movimiento movimiento) async {
    final ahora = DateTime.now();
    final restaurado = Movimiento(
      id: movimiento.id,
      numero: movimiento.numero,
      tipo: movimiento.tipo,
      centavos: movimiento.centavos,
      categoriaId: movimiento.categoriaId,
      concepto: movimiento.concepto,
      medio: movimiento.medio,
      fecha: movimiento.fecha,
      creadoEn: movimiento.creadoEn,
      actualizadoEn: ahora,
      cuentaAsociada: movimiento.cuentaAsociada,
      igvCentavos: movimiento.igvCentavos,
      contraparte: movimiento.contraparte,
      documentoContraparte: movimiento.documentoContraparte,
      numeroTransaccion: movimiento.numeroTransaccion,
      numeroRecibo: movimiento.numeroRecibo,
      rutaFoto: movimiento.rutaFoto,
      sync: EstadoSync.local,
    );
    await _dao.guardar(restaurado);
    return restaurado;
  }

  /// Sube lo pendiente y baja lo que cambió en la nube.
  ///
  /// Devuelve `false` si no había con qué sincronizar (sin internet, sin
  /// Firebase configurado); eso no es un error, es el caso normal en una bodega.
  Future<bool> sincronizar() async {
    if (!await _remoto.disponible()) return false;

    final pendientes = await _dao.pendientesDeSubir();
    if (pendientes.isNotEmpty) {
      await _remoto.subir(pendientes);
      await _dao.marcarRespaldados(pendientes);
    }

    final remotos = await _remoto.bajar();
    final aGuardar = <Movimiento>[];

    for (final remoto in remotos) {
      final local = await _dao.porId(remoto.id);
      // "El último cambio gana" (§2.3): sólo pisamos lo local si lo de la nube
      // es estrictamente más nuevo. Con fechas iguales se queda lo local, que
      // es lo que el usuario tiene delante.
      if (local == null || remoto.actualizadoEn.isAfter(local.actualizadoEn)) {
        aGuardar.add(remoto.copiarCon(sync: EstadoSync.respaldado));
      }
    }

    await _dao.guardarVarios(aGuardar);
    return true;
  }
}
