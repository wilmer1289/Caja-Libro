import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../dominio/importe.dart';
import '../../dominio/negocio.dart';
import '../../estado/estado_caja.dart';
import '../widgets/enfoque.dart';

/// Los datos del negocio: lo que el Excel tiene en su hoja DATOS.
///
/// No es una pantalla de configuración cualquiera. Todo lo que se llena acá
/// sale impreso: el encabezado del Formato 1.1 exige período, RUC y razón
/// social; el 1.2 pide además el banco y el número de cuenta; y el saldo
/// inicial es literalmente la primera línea del libro.
///
/// Por eso cada campo explica para qué sirve, en vez de ser una etiqueta
/// suelta que el usuario tiene que adivinar.
///
/// Se abre en una ventana, como el registro de un movimiento, y no en una
/// pantalla aparte: son ocho datos, y taparle toda la app para pedirlos
/// hacía sentir que se había ido a otro lado.
class NegocioPagina extends StatefulWidget {
  const NegocioPagina({super.key, this.enDialogo = true});

  /// En escritorio va en una ventana centrada; en el celular, en una hoja
  /// que sube desde abajo.
  final bool enDialogo;

  static Future<void> abrir(BuildContext context) {
    final esEscritorio = MediaQuery.sizeOf(context).width >= 900;

    if (!esEscritorio) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Tokens.superficie,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.94,
          child: NegocioPagina(enDialogo: false),
        ),
      );
    }

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Tokens.cromo.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, _, _) {
        final pantalla = MediaQuery.sizeOf(context);
        return Center(
          child: SizedBox(
            width: (pantalla.width - 64).clamp(320.0, 860.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (pantalla.height - 48).clamp(360.0, 860.0),
              ),
              child: Material(
                color: Tokens.superficie,
                clipBehavior: Clip.antiAlias,
                elevation: 24,
                shadowColor: const Color(0x552A1A0C),
                borderRadius: BorderRadius.circular(24),
                child: const NegocioPagina(),
              ),
            ),
          ),
        );
      },
      // Entra creciendo apenas, igual que el registro de un movimiento.
      transitionBuilder: (context, animacion, _, hijo) {
        final curva = CurvedAnimation(
          parent: animacion,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: curva,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curva),
            child: hijo,
          ),
        );
      },
    );
  }

  @override
  State<NegocioPagina> createState() => _NegocioPaginaState();
}

class _NegocioPaginaState extends State<NegocioPagina> {
  late final TextEditingController _razon;
  late final TextEditingController _documento;
  late final TextEditingController _direccion;
  late final TextEditingController _banco;
  late final TextEditingController _cuenta;
  late final TextEditingController _saldoCaja;
  late final TextEditingController _saldoBanco;
  late final TextEditingController _tesorero;

  late DateTime _inicioPeriodo;
  bool _intentoGuardar = false;
  bool _guardando = false;

  /// Un error que no es de un campo en particular (no se pudo guardar). Va
  /// dentro de la ventana: un aviso abajo en la app quedaría tapado por ella.
  String? _errorGeneral;

  @override
  void initState() {
    super.initState();
    final n = context.read<EstadoCaja>().negocio;
    _razon = TextEditingController(text: n.razonSocial);
    _documento = TextEditingController(text: n.documento);
    _direccion = TextEditingController(text: n.direccion);
    _banco = TextEditingController(text: n.entidadFinanciera);
    _cuenta = TextEditingController(text: n.cuentaCorriente);
    _saldoCaja = TextEditingController(text: _aTexto(n.saldoInicialCaja));
    _saldoBanco = TextEditingController(text: _aTexto(n.saldoInicialBanco));
    _tesorero = TextEditingController(text: n.tesorero);

    final hoy = DateTime.now();
    _inicioPeriodo = n.inicioPeriodo ?? DateTime(hoy.year, hoy.month);
  }

  @override
  void dispose() {
    for (final c in [
      _razon,
      _documento,
      _direccion,
      _banco,
      _cuenta,
      _saldoCaja,
      _saldoBanco,
      _tesorero,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Vacío cuando es cero: un "0.00" de arranque invita a borrarlo antes de
  /// escribir, y eso es un paso de más.
  static String _aTexto(int centavos) =>
      centavos == 0 ? '' : (centavos / 100).toStringAsFixed(2);

  static int? _aCentavos(String texto) {
    if (texto.trim().isEmpty) return 0;
    return Importe.leer(texto, permitirNegativo: true);
  }

  String? get _errorRazon {
    if (!_intentoGuardar) return null;
    if (_razon.text.trim().isEmpty) return 'Escribe el nombre del negocio';
    return null;
  }

  String? get _errorDocumento {
    if (!_intentoGuardar) return null;
    final texto = _documento.text.trim();
    if (texto.isEmpty) return 'Escribe el RUC o el DNI';
    // 8 dígitos el DNI, 11 el RUC. Puede haber documentos de otro tipo, pero
    // en el Formato 1.1 va uno de estos dos.
    if (texto.length != 8 && texto.length != 11) {
      return 'El DNI tiene 8 dígitos y el RUC 11';
    }
    return null;
  }

  /// La caja no puede abrir en negativo: no hay billetes de menos. El banco
  /// sí (un sobregiro), por eso sólo se revisa que el número se entienda.
  String? get _errorSaldoCaja {
    if (!_intentoGuardar) return null;
    final c = _aCentavos(_saldoCaja.text);
    if (c == null) return 'Ese monto no se entiende. Ejemplo: 250.50';
    if (c < 0) return 'La caja no puede empezar en negativo';
    return null;
  }

  String? get _errorSaldoBanco {
    if (!_intentoGuardar) return null;
    if (_aCentavos(_saldoBanco.text) == null) {
      return 'Ese monto no se entiende. Ejemplo: 250.50';
    }
    return null;
  }

  Future<void> _elegirPeriodo() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _inicioPeriodo.isAfter(hoy) ? hoy : _inicioPeriodo,
      firstDate: DateTime(2020),
      lastDate: hoy,
      helpText: 'Primer día del período',
    );
    if (!mounted || elegida == null) return;
    // Siempre el día 1: el libro va por mes completo.
    setState(() => _inicioPeriodo = DateTime(elegida.year, elegida.month));
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _intentoGuardar = true;
      _errorGeneral = null;
    });
    if (_errorRazon != null ||
        _errorDocumento != null ||
        _errorSaldoCaja != null ||
        _errorSaldoBanco != null) {
      return;
    }

    final caja = _aCentavos(_saldoCaja.text)!;
    final banco = _aCentavos(_saldoBanco.text)!;

    setState(() => _guardando = true);

    final estado = context.read<EstadoCaja>();
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    try {
      await estado.guardarNegocio(
        Negocio(
          razonSocial: _razon.text.trim(),
          documento: _documento.text.trim(),
          direccion: _direccion.text.trim(),
          entidadFinanciera: _banco.text.trim(),
          cuentaCorriente: _cuenta.text.trim(),
          saldoInicialCaja: caja,
          saldoInicialBanco: banco,
          inicioPeriodo: _inicioPeriodo,
          tesorero: _tesorero.text.trim(),
        ),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      navegador.pop();
      mensajero
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Tokens.entroVivo,
                  size: 20,
                ),
                SizedBox(width: 10),
                Text('Datos del negocio guardados'),
              ],
            ),
          ),
        );
    } catch (e) {
      if (mounted) {
        setState(() => _errorGeneral = 'No se pudieron guardar los datos. $e');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        final ancho = medidas.maxWidth >= 640;

        /// Dos o tres campos lado a lado en una ventana ancha; uno debajo del
        /// otro en el celular.
        Widget fila(List<Widget> campos) {
          if (!ancho) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: campos,
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < campos.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: campos[i]),
              ],
            ],
          );
        }

        final cuerpo = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Bloque(
              icono: Icons.storefront_outlined,
              titulo: 'Identificación',
              bajada: 'Va en el encabezado del Formato 1.1 y en cada recibo.',
            ),
            _Campo(
              etiqueta: 'Nombre o razón social',
              ayuda: 'Como figura en tu RUC. Ej. LIBERTAD SA',
              controlador: _razon,
              error: _errorRazon,
              capitalizar: TextCapitalization.characters,
              onCambio: () => setState(() {}),
            ),
            fila([
              _Campo(
                etiqueta: 'RUC o DNI',
                ayuda: 'RUC si tienes empresa, DNI si no.',
                controlador: _documento,
                error: _errorDocumento,
                soloNumeros: true,
                largoMaximo: 11,
                onCambio: () => setState(() {}),
              ),
              _Campo(
                etiqueta: 'Dirección',
                ayuda: 'Opcional. Sale impresa en los recibos.',
                controlador: _direccion,
                capitalizar: TextCapitalization.words,
                onCambio: () => setState(() {}),
              ),
            ]),
            const SizedBox(height: 8),
            const _Bloque(
              icono: Icons.event_available_outlined,
              titulo: 'Período y saldos de apertura',
              bajada:
                  'Con cuánta plata abres el libro: es la primera línea '
                  'del Formato 1.1.',
            ),
            fila([
              _CampoFecha(
                etiqueta: 'El libro empieza en',
                ayuda: 'El mes desde el que llevas las cuentas.',
                fecha: _inicioPeriodo,
                onTocar: _elegirPeriodo,
              ),
              _Campo(
                etiqueta: 'Saldo inicial en caja',
                ayuda: 'El efectivo que tenías el primer día.',
                controlador: _saldoCaja,
                error: _errorSaldoCaja,
                prefijo: 'S/ ',
                decimal: true,
                onCambio: () => setState(() {}),
              ),
              _Campo(
                etiqueta: 'Saldo inicial en banco',
                ayuda: 'Lo que tenías en la cuenta y en Yape.',
                controlador: _saldoBanco,
                error: _errorSaldoBanco,
                prefijo: 'S/ ',
                decimal: true,
                onCambio: () => setState(() {}),
              ),
            ]),
            const SizedBox(height: 8),
            const _Bloque(
              icono: Icons.account_balance_outlined,
              titulo: 'Cuenta bancaria',
              bajada:
                  'Sólo hace falta para el Formato 1.2, el de la cuenta '
                  'corriente.',
            ),
            fila([
              _Campo(
                etiqueta: 'Entidad financiera',
                ayuda: 'Ej. BBVA, BCP, Interbank.',
                controlador: _banco,
                capitalizar: TextCapitalization.characters,
                onCambio: () => setState(() {}),
              ),
              _Campo(
                etiqueta: 'Número de cuenta corriente',
                ayuda: 'El Formato 1.2 lo pide en su encabezado.',
                controlador: _cuenta,
                onCambio: () => setState(() {}),
              ),
            ]),
            const SizedBox(height: 8),
            const _Bloque(
              icono: Icons.badge_outlined,
              titulo: 'Caja',
              bajada:
                  'Quién firma por el negocio en los recibos y en las '
                  'actas de arqueo.',
            ),
            _Campo(
              etiqueta: 'Responsable de caja (tesorero/a)',
              ayuda:
                  'Sale ya puesto en cada recibo. Si ese día atiende otra '
                  'persona, se cambia ahí mismo sin tocar esto.',
              controlador: _tesorero,
              capitalizar: TextCapitalization.words,
              onCambio: () => setState(() {}),
            ),
            if (_errorGeneral != null) _AvisoError(_errorGeneral!),
          ],
        );

        final guardar = FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          icon: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 20),
          label: const Text('Guardar datos'),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cabecera(
              conManija: !widget.enDialogo,
              onCerrar: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  ancho ? 28 : 20,
                  18,
                  ancho ? 28 : 20,
                  12,
                ),
                child: cuerpo,
              ),
            ),
            // El pie queda fijo: el botón de guardar siempre a la vista.
            Container(
              padding: EdgeInsets.fromLTRB(
                ancho ? 28 : 20,
                14,
                ancho ? 28 : 20,
                18 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              decoration: const BoxDecoration(
                color: Tokens.fondo,
                border: Border(top: BorderSide(color: Tokens.borde)),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  guardar,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.conManija, required this.onCerrar});

  /// En la hoja del celular, la rayita de arriba que invita a arrastrarla.
  final bool conManija;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, conManija ? 10 : 20, 16, 18),
      decoration: const BoxDecoration(
        color: Tokens.marcaSuave,
        border: Border(bottom: BorderSide(color: Color(0xFFF7DCC6))),
      ),
      child: Column(
        children: [
          if (conManija) ...[
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Tokens.marca.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Tokens.marca,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos del negocio',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Tokens.texto,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Lo que sale impreso en tus libros y recibos',
                      style: TextStyle(fontSize: 13, color: Tokens.texto2),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close_rounded, size: 22),
                onPressed: onCerrar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// El título de un grupo de campos, con su explicación.
class _Bloque extends StatelessWidget {
  const _Bloque({
    required this.icono,
    required this.titulo,
    required this.bajada,
  });

  final IconData icono;
  final String titulo;
  final String bajada;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Tokens.marcaSuave,
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 18, color: Tokens.marca),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Tokens.texto,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  bajada,
                  style: const TextStyle(fontSize: 12.5, color: Tokens.texto2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un campo: la etiqueta arriba y la ayuda abajo. Con la ayuda abajo, los
/// campos que van lado a lado quedan alineados aunque las ayudas midan
/// distinto.
class _Campo extends StatelessWidget {
  const _Campo({
    required this.etiqueta,
    required this.ayuda,
    required this.controlador,
    required this.onCambio,
    this.error,
    this.prefijo,
    this.soloNumeros = false,
    this.decimal = false,
    this.largoMaximo,
    this.capitalizar = TextCapitalization.none,
  });

  final String etiqueta;
  final String ayuda;
  final TextEditingController controlador;
  final VoidCallback onCambio;
  final String? error;
  final String? prefijo;
  final bool soloNumeros;
  final bool decimal;
  final int? largoMaximo;
  final TextCapitalization capitalizar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Etiqueta(etiqueta),
          Enfoque(
            activo: error == null,
            child: TextField(
              controller: controlador,
              textCapitalization: capitalizar,
              keyboardType: decimal
                  ? const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    )
                  : soloNumeros
                  ? TextInputType.number
                  : TextInputType.text,
              inputFormatters: [
                if (soloNumeros) FilteringTextInputFormatter.digitsOnly,
                if (decimal)
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
                if (largoMaximo != null)
                  LengthLimitingTextInputFormatter(largoMaximo),
              ],
              decoration: InputDecoration(
                prefixText: prefijo,
                hintText: decimal ? '0.00' : null,
                errorText: error,
                errorMaxLines: 2,
              ),
              onChanged: (_) => onCambio(),
            ),
          ),
          if (error == null) ...[
            const SizedBox(height: 5),
            Text(
              ayuda,
              maxLines: 2,
              style: const TextStyle(fontSize: 11.5, color: Tokens.texto2),
            ),
          ],
        ],
      ),
    );
  }
}

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    required this.etiqueta,
    required this.ayuda,
    required this.fecha,
    required this.onTocar,
  });

  final String etiqueta;
  final String ayuda;
  final DateTime fecha;
  final VoidCallback onTocar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Etiqueta(etiqueta),
          OutlinedButton.icon(
            onPressed: onTocar,
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(Formato.capitalizar(Formato.mes(fecha))),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            ayuda,
            maxLines: 2,
            style: const TextStyle(fontSize: 11.5, color: Tokens.texto2),
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Tokens.texto,
        ),
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  const _AvisoError(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Tokens.salioSuave,
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.salio.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Tokens.salio,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Tokens.salio,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
