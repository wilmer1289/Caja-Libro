import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/saludo.dart';
import '../../core/tema.dart';
import '../../datos/auth/autenticador.dart';
import '../widgets/aparece.dart';
import '../widgets/enfoque.dart';
import '../widgets/presionable.dart';
import 'login_escritorio.dart';
import 'login_movil.dart';
import 'panel_personajes.dart';
import 'personajes.dart';

/// Ancho a partir del cual se usa el login de escritorio.
const anchoEscritorioLogin = 900.0;

/// Cuánto dura el festejo de los personajes antes de pasar a la app. Corto a
/// propósito: es un premio, no una espera.
const duracionFestejo = Duration(milliseconds: 700);

/// Pantalla de inicio de sesión (§3.1).
///
/// Acá vive todo el estado y se arman las dos piezas —el panel de los
/// personajes y el formulario—. La disposición la resuelven `LoginEscritorio`
/// y `LoginMovil`, que no comparten una sola línea de lógica con esto.
///
/// No hay pantalla de registro a propósito: las cuentas se crean a mano desde
/// la consola de Firebase.
class LoginPagina extends StatefulWidget {
  const LoginPagina({
    super.key,
    required this.autenticador,
    required this.onEntrar,
  });

  /// Quién decide si el usuario y la contraseña son correctos. Se inyecta para
  /// poder pasar de cuentas fijas a Firebase sin tocar esta pantalla.
  final Autenticador autenticador;

  /// Recibe el nombre del usuario que entró.
  final ValueChanged<String> onEntrar;

  @override
  State<LoginPagina> createState() => _LoginPaginaState();
}

class _LoginPaginaState extends State<LoginPagina> {
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  final _focoUsuario = FocusNode();
  final _focoClave = FocusNode();

  /// Clave para ubicar el panel en pantalla y saber, desde cualquier punto,
  /// hacia dónde queda el cursor.
  final _panel = GlobalKey();

  /// Hacia dónde apunta el cursor. Es lo que miran cuando no se está
  /// escribiendo el usuario.
  Offset _miradaCursor = Offset.zero;

  bool _revelada = false;
  bool _intentoEntrar = false;
  bool _verificando = false;
  bool _exito = false;

  /// Sube con cada error y con el éxito, para que los personajes reaccionen
  /// cada vez, aunque sea el segundo error seguido.
  int _reaccion = 0;

  /// Error del par usuario+contraseña, distinto de los errores de cada campo:
  /// no es que falte algo, es que lo que se escribió no coincide.
  String? _errorEntrada;

  Animo get _animo => _exito
      ? Animo.feliz
      : _errorEntrada != null
      ? Animo.triste
      : Animo.normal;

  /// Se tapan los ojos mientras se escribe la contraseña, salvo que el usuario
  /// la haya puesto a la vista, o que estén tristes: ahí miran al piso.
  bool get _ojosCerrados =>
      _focoClave.hasFocus && !_revelada && _animo == Animo.normal;

  /// Lo que dicen en el globo. El orden importa: gana lo más reciente.
  String get _frase {
    if (_exito) return '¡Vamos!';
    if (_verificando) return 'Un segundo…';
    if (_errorEntrada != null) return 'Uy, algo no coincide';
    if (_focoClave.hasFocus) {
      return _revelada ? 'Bueno, ahora sí se ve' : 'Tranquilo, no miramos';
    }
    if (_focoUsuario.hasFocus) return 'Mirando lo que escribes…';
    return '¡Hola! Te estábamos esperando';
  }

  @override
  void initState() {
    super.initState();
    _focoUsuario.addListener(() => setState(() {}));
    _focoClave.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    _focoUsuario.dispose();
    _focoClave.dispose();
    super.dispose();
  }

  /// Mientras se escribe el usuario, los ojos van hacia el campo y avanzan
  /// con el texto, como si lo fueran leyendo. En escritorio el campo está a
  /// la derecha del panel; en el celular, debajo.
  Offset _mirada(bool esEscritorio) {
    if (!_focoUsuario.hasFocus) return _miradaCursor;
    final avance = (_usuario.text.length / 22).clamp(0.0, 1.0);
    return esEscritorio
        ? Offset(0.45 + avance * 0.55, 0.15)
        : Offset(-0.6 + avance * 1.2, 1);
  }

  /// No se valida la forma: hoy los usuarios son nombres sueltos y mañana, con
  /// Firebase, van a ser correos. Con exigir que no esté vacío alcanza.
  String? get _errorUsuario {
    if (!_intentoEntrar) return null;
    if (_usuario.text.trim().isEmpty) return 'Escribe tu usuario';
    return null;
  }

  String? get _errorClave {
    if (!_intentoEntrar) return null;
    if (_clave.text.isEmpty) return 'Escribe tu contraseña';
    return null;
  }

  /// Convierte la posición del puntero en una mirada de −1 a 1 por eje,
  /// medida desde el centro del panel. Es el mismo cálculo del JS del §6.
  void _mirarHacia(Offset posicionGlobal) {
    final caja = _panel.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null || !caja.hasSize) return;

    final centro = caja.localToGlobal(caja.size.center(Offset.zero));
    final dx = (posicionGlobal.dx - centro.dx) / (caja.size.width / 2);
    final dy = (posicionGlobal.dy - centro.dy) / (caja.size.height / 2);

    final nueva = Offset(dx.clamp(-1, 1), dy.clamp(-1, 1));
    if (nueva != _miradaCursor) setState(() => _miradaCursor = nueva);
  }

  Future<void> _entrar() async {
    if (_verificando) return;

    setState(() {
      _intentoEntrar = true;
      _errorEntrada = null;
    });
    if (_errorUsuario != null || _errorClave != null) return;

    setState(() => _verificando = true);

    final resultado = await widget.autenticador.entrar(
      usuario: _usuario.text,
      clave: _clave.text,
    );
    if (!mounted) return;

    switch (resultado) {
      case EntradaOk(:final nombre):
        // Un instante de festejo antes de pasar: los personajes saltan y
        // dicen "¡Vamos!". Es el premio por entrar, y dura menos de un segundo.
        HapticFeedback.lightImpact();
        setState(() {
          _exito = true;
          _reaccion++;
        });
        await Future<void>.delayed(duracionFestejo);
        if (!mounted) return;
        widget.onEntrar(nombre);
      case EntradaFallida(:final mensaje):
        HapticFeedback.mediumImpact();
        setState(() {
          _verificando = false;
          _errorEntrada = mensaje;
          _reaccion++;
        });
    }
  }

  /// No hay recuperación automática porque las cuentas se crean a mano.
  void _avisarOlvido() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Pídele una contraseña nueva a quien administra las cuentas.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final esEscritorio =
        MediaQuery.sizeOf(context).width >= anchoEscritorioLogin;

    final panel = KeyedSubtree(
      key: _panel,
      child: PanelPersonajes(
        mirada: _mirada(esEscritorio),
        ojosCerrados: _ojosCerrados,
        animo: _animo,
        reaccion: _reaccion,
        frase: _frase,
        compacto: !esEscritorio,
      ),
    );

    final contenido = esEscritorio
        ? LoginEscritorio(panel: panel, formulario: _formulario(grande: true))
        : LoginMovil(panel: panel, formulario: _formulario(grande: false));

    // Toda la pantalla escucha el puntero, no sólo el panel: los ojos siguen
    // el cursor también mientras se recorre el formulario.
    return MouseRegion(
      onHover: (evento) => _mirarHacia(evento.position),
      child: Listener(
        onPointerDown: (e) => _mirarHacia(e.position),
        onPointerMove: (e) => _mirarHacia(e.position),
        child: contenido,
      ),
    );
  }

  /// `grande` en escritorio: hay aire de sobra y el saludo puede ser el
  /// protagonista, como en la referencia. En el celular, el botón de entrar
  /// tiene que entrar en la pantalla sin desplazarse.
  Widget _formulario({required bool grande}) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // El saludo cambia con la hora: a las siete de la mañana la app dice
          // algo distinto que a las diez de la noche.
          Aparece(
            child: Text(
              Saludo.porHora(),
              style: TextStyle(
                fontSize: grande ? 40 : 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                height: 1.1,
                color: Tokens.texto,
              ),
            ),
          ),
          SizedBox(height: grande ? 10 : 6),
          Aparece(
            retraso: const Duration(milliseconds: 70),
            child: Text(
              Saludo.bienvenida,
              style: TextStyle(
                fontSize: grande ? 17 : 15,
                color: Tokens.texto2,
              ),
            ),
          ),
          SizedBox(height: grande ? 36 : 26),

          Aparece(
            retraso: const Duration(milliseconds: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Etiqueta('Usuario'),
                Enfoque(
                  activo: _errorUsuario == null,
                  child: TextField(
                    controller: _usuario,
                    focusNode: _focoUsuario,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _focoClave.requestFocus(),
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Tu usuario',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: grande ? 19 : 14,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.person_outline_rounded, size: 22),
                      ),
                      errorText: _errorUsuario,
                    ),
                    // Al corregir algo, el aviso de "incorrectos" deja de
                    // aplicar, y los personajes se reponen.
                    onChanged: (_) => setState(() => _errorEntrada = null),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Aparece(
            retraso: const Duration(milliseconds: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Etiqueta('Contraseña'),
                Enfoque(
                  activo: _errorClave == null,
                  child: TextField(
                    controller: _clave,
                    focusNode: _focoClave,
                    obscureText: !_revelada,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _entrar(),
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Tu contraseña',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: grande ? 19 : 14,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.lock_outline_rounded, size: 22),
                      ),
                      errorText: _errorClave,
                      suffixIcon: IconButton(
                        tooltip: _revelada
                            ? 'Ocultar contraseña'
                            : 'Mostrar contraseña',
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (hijo, animacion) =>
                              ScaleTransition(scale: animacion, child: hijo),
                          child: Icon(
                            _revelada
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            key: ValueKey(_revelada),
                            size: 20,
                          ),
                        ),
                        // Al revelarla, los personajes vuelven a abrir los ojos.
                        onPressed: () => setState(() => _revelada = !_revelada),
                      ),
                    ),
                    onChanged: (_) => setState(() => _errorEntrada = null),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _avisarOlvido,
              style: TextButton.styleFrom(
                foregroundColor: Tokens.marcaOscura,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: const TextStyle(
                  fontFamily: Tokens.tipografia,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: Tokens.marcaOscura,
                ),
              ),
              child: const Text('Olvidé mi contraseña'),
            ),
          ),

          // El aviso de error entra animado: aparecer de golpe no se nota, y
          // este mensaje es justo el que hay que notar.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _errorEntrada == null
                ? SizedBox(width: double.infinity, height: grande ? 18 : 6)
                : Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 14),
                    child: _AvisoError(_errorEntrada!),
                  ),
          ),

          Aparece(
            retraso: const Duration(milliseconds: 260),
            child: Presionable(
              child: _BotonEntrar(
                verificando: _verificando,
                exito: _exito,
                onPressed: _entrar,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El botón principal: naranja con un degradado apenas visible y un brillo
/// arriba, que es lo que lo hace ver "presionable" y no una franja plana.
class _BotonEntrar extends StatelessWidget {
  const _BotonEntrar({
    required this.verificando,
    required this.exito,
    required this.onPressed,
  });

  final bool verificando;
  final bool exito;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget contenido;
    if (exito) {
      contenido = const Icon(
        Icons.check_rounded,
        key: ValueKey('exito'),
        color: Colors.white,
        size: 24,
      );
    } else if (verificando) {
      contenido = const SizedBox(
        key: ValueKey('cargando'),
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
      );
    } else {
      contenido = const Row(
        key: ValueKey('texto'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Entrar a mi caja'),
          SizedBox(width: 10),
          Icon(Icons.arrow_forward_rounded, size: 21),
        ],
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: exito
              ? const [Color(0xFF4FA07E), Tokens.entro]
              : const [Color(0xFFFB8533), Tokens.marca],
        ),
        boxShadow: [
          BoxShadow(
            color: (exito ? Tokens.entro : Tokens.marca).withValues(
              alpha: 0.32,
            ),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        // Brillo en el borde de arriba, como luz que cae sobre el botón.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: verificando ? null : onPressed,
          child: Center(
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (hijo, animacion) => FadeTransition(
                    opacity: animacion,
                    child: ScaleTransition(scale: animacion, child: hijo),
                  ),
                  child: contenido,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El error del par usuario+contraseña va junto al botón y no bajo un campo:
/// no hay forma de saber cuál de los dos está mal.
class _AvisoError extends StatelessWidget {
  const _AvisoError(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Tokens.salio.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Tokens.radio),
        border: Border.all(color: Tokens.salio.withValues(alpha: 0.18)),
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

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Tokens.texto,
        ),
      ),
    );
  }
}
