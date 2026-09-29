import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tema.dart';

/// Cómo están los personajes. Cambia con lo que pasa en el login.
enum Animo { normal, triste, feliz }

/// Los cuatro personajes del login (§3.1), portados del prototipo del §6.
///
/// El prototipo eran cuatro `<g>` de SVG con clases CSS; acá es un solo
/// `CustomPainter`. Dibujar a mano en vez de cargar un SVG evita una
/// dependencia más y, sobre todo, permite mover cada pupila por separado:
/// con un SVG habría que manipular el árbol del documento en cada frame.
///
/// Las coordenadas son las mismas del prototipo (lienzo 230×150) para que
/// cualquiera pueda comparar los dos archivos lado a lado.
class Personajes extends StatefulWidget {
  const Personajes({
    super.key,
    required this.mirada,
    required this.ojosCerrados,
    this.animo = Animo.normal,
    this.reaccion = 0,
    this.margenInferior = 46,
    this.conArco = false,
  });

  /// Hacia dónde miran, de −1 a 1 en cada eje. (0,0) es al frente.
  final Offset mirada;

  /// Ojos cerrados mientras se escribe la contraseña.
  final bool ojosCerrados;

  final Animo animo;

  /// Cada vez que cambia, reaccionan según el ánimo: tristes se sacuden,
  /// felices saltan. Es un contador y no un booleano para que la reacción se
  /// repita aunque el ánimo no cambie, por ejemplo con dos errores seguidos.
  final int reaccion;

  /// Espacio reservado debajo de las figuras.
  final double margenInferior;

  /// Un arco crema detrás, como una ventana iluminada donde están parados.
  final bool conArco;

  /// Dónde cae, dentro de un widget de `tamano`, un punto del lienzo del
  /// prototipo. Sirve para poner algo justo encima de un personaje, como el
  /// globo de diálogo, sin adivinar coordenadas.
  static Offset ubicar(
    Size tamano,
    Offset punto, {
    double margenInferior = 46,
    bool conArco = false,
  }) {
    return _Encuadre.de(
      tamano,
      margenInferior: margenInferior,
      conArco: conArco,
    ).aplicar(punto);
  }

  @override
  State<Personajes> createState() => _PersonajesState();
}

class _PersonajesState extends State<Personajes> with TickerProviderStateMixin {
  /// Flotación suave. Cuatro segundos es el mismo período que el `bob` del CSS.
  late final AnimationController _flote = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  /// El parpadeo va en su propio ciclo, de duración prima respecto al flote,
  /// para que las dos animaciones no caigan siempre juntas y se vea mecánico.
  late final AnimationController _parpadeo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5300),
  )..repeat();

  late final AnimationController _sacudida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  late final AnimationController _salto = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void didUpdateWidget(Personajes anterior) {
    super.didUpdateWidget(anterior);
    if (widget.reaccion == anterior.reaccion) return;

    switch (widget.animo) {
      case Animo.triste:
        _sacudida.forward(from: 0);
      case Animo.feliz:
        _salto.forward(from: 0);
      case Animo.normal:
        break;
    }
  }

  @override
  void dispose() {
    _flote.dispose();
    _parpadeo.dispose();
    _sacudida.dispose();
    _salto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respeta "reducir movimiento" del sistema: los personajes siguen ahí,
    // siguen mirando y siguen cambiando de cara, sólo que quietos.
    final quietos = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: Listenable.merge([_flote, _parpadeo, _sacudida, _salto]),
      builder: (context, _) => CustomPaint(
        painter: _PintorPersonajes(
          mirada: widget.mirada,
          ojosCerrados: widget.ojosCerrados,
          animo: widget.animo,
          flote: quietos ? 0 : _flote.value,
          parpadeo: quietos ? 0 : _parpadeo.value,
          sacudida: quietos ? 0 : _sacudida.value,
          salto: quietos ? 0 : _salto.value,
          margenInferior: widget.margenInferior,
          conArco: widget.conArco,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Cómo se pasa del lienzo del prototipo al tamaño del widget.
///
/// Es una clase aparte porque la usan dos: el pintor, para dibujar, y
/// `Personajes.ubicar`, para que otros sepan dónde quedó cada personaje.
class _Encuadre {
  const _Encuadre(this.escala, this.dx, this.dy);

  final double escala;
  final double dx;
  final double dy;

  /// Lo que ocupan las figuras dentro del lienzo de 230×150. Se encuadra el
  /// contenido real y no el lienzo nominal: si no, quedan chiquitas y
  /// perdidas en un panel alto.
  static const _contenido = Rect.fromLTRB(18, 22, 204, 112);

  /// Con el arco, el contenido crece: el arco sube más que los personajes.
  static const _contenidoConArco = Rect.fromLTRB(12, 2, 210, 114);

  static const _margenLateral = 18.0;
  static const _margenSuperior = 24.0;

  /// Como el preserveAspectRatio="xMidYMax meet" del prototipo: entra
  /// completo, centrado en horizontal y apoyado abajo.
  factory _Encuadre.de(
    Size tamano, {
    required double margenInferior,
    required bool conArco,
  }) {
    final c = conArco ? _contenidoConArco : _contenido;
    final ancho = tamano.width - _margenLateral * 2;
    final alto = tamano.height - _margenSuperior - margenInferior;
    if (ancho <= 0 || alto <= 0) return const _Encuadre(0, 0, 0);

    final escala = math.min(ancho / c.width, alto / c.height);
    final izquierda = _margenLateral + (ancho - c.width * escala) / 2;
    final arriba = tamano.height - margenInferior - c.height * escala;

    // El desplazamiento descuenta el origen del contenido para que su esquina
    // caiga justo en la esquina del área disponible.
    return _Encuadre(
      escala,
      izquierda - c.left * escala,
      arriba - c.top * escala,
    );
  }

  Offset aplicar(Offset punto) =>
      Offset(dx + punto.dx * escala, dy + punto.dy * escala);
}

/// Un personaje: su silueta, sus ojos y, si tiene, su boca.
class _Figura {
  _Figura({
    required this.cuerpo,
    required this.color,
    required this.ojos,
    required this.colorOjo,
    required this.radioPupila,
    required this.anchoCerrado,
    required this.caidaCerrado,
    required this.grosorCerrado,
    required this.fase,
    this.radioBlanco,
    this.boca,
    this.grosorBoca = 2.6,
    this.colorBoca,
    this.borde,
    this.grosorBorde = 2.4,
  });

  final Path cuerpo;
  final Color color;
  final List<Offset> ojos;
  final Color colorOjo;
  final double radioPupila;

  /// Sólo el personaje negro tiene esclerótica blanca detrás de la pupila.
  final double? radioBlanco;

  /// El ojo cerrado es una curva hacia abajo: mitad de ancho, cuánto baja y
  /// qué tan grueso es el trazo. El ojo feliz es la misma curva al revés.
  final double anchoCerrado;
  final double caidaCerrado;
  final double grosorCerrado;

  /// La boca cambia con el ánimo, por eso es una función y no un trazo fijo.
  final Path Function(Animo)? boca;
  final double grosorBoca;

  /// La boca va del color de los ojos, salvo que se diga otro: la del
  /// personaje crema es una rayita naranja, como su borde.
  final Color? colorBoca;

  /// Contorno, sólo para el personaje crema: sin él, sobre el escenario claro
  /// del resumen se perdería.
  final Color? borde;
  final double grosorBorde;

  /// Desfase de flote, parpadeo y salto, para que no se muevan al unísono.
  final double fase;
}

class _PintorPersonajes extends CustomPainter {
  _PintorPersonajes({
    required this.mirada,
    required this.ojosCerrados,
    required this.animo,
    required this.flote,
    required this.parpadeo,
    required this.sacudida,
    required this.salto,
    required this.margenInferior,
    required this.conArco,
  });

  final Offset mirada;
  final bool ojosCerrados;
  final Animo animo;
  final double flote;
  final double parpadeo;
  final double sacudida;
  final double salto;
  final double margenInferior;
  final bool conArco;

  /// Cuánto se desplaza la pupila en cada eje, igual que en el JS del §6.
  static const _recorridoPupilaX = 2.6;
  static const _recorridoPupilaY = 2.4;

  static final List<_Figura> _figuras = [
    // Morado, atrás y alto.
    _Figura(
      cuerpo: Path()
        ..addRRect(RRect.fromLTRBR(46, 22, 104, 108, const Radius.circular(6))),
      color: const Color(0xFF5B3BE6),
      ojos: const [Offset(66, 52), Offset(84, 52)],
      colorOjo: const Color(0xFF1C0F5E),
      radioPupila: 3.4,
      anchoCerrado: 5,
      caidaCerrado: 4,
      grosorCerrado: 2.4,
      fase: 0,
    ),
    // Negro, vertical y con ojos blancos.
    _Figura(
      cuerpo: Path()
        ..addRRect(
          RRect.fromLTRBR(108, 52, 148, 110, const Radius.circular(13)),
        ),
      color: const Color(0xFF1B1A19),
      ojos: const [Offset(120, 74), Offset(136, 74)],
      colorOjo: const Color(0xFF000000),
      radioPupila: 3.6,
      radioBlanco: 7.5,
      anchoCerrado: 6,
      caidaCerrado: 5,
      grosorCerrado: 2.6,
      fase: 0.1,
    ),
    // Naranja: media luna adelante, el más grande y el más expresivo.
    _Figura(
      cuerpo: Path()
        ..moveTo(18, 110)
        ..arcToPoint(const Offset(110, 110), radius: const Radius.circular(46))
        ..close(),
      color: Tokens.marca,
      ojos: const [Offset(52, 90), Offset(76, 90)],
      colorOjo: const Color(0xFF3A1602),
      radioPupila: 3.6,
      anchoCerrado: 6,
      caidaCerrado: 5,
      grosorCerrado: 2.6,
      boca: (animo) => switch (animo) {
        Animo.normal =>
          Path()
            ..moveTo(56, 100)
            ..quadraticBezierTo(64, 107, 72, 100),
        Animo.triste =>
          Path()
            ..moveTo(57, 104)
            ..quadraticBezierTo(64, 98, 71, 104),
        Animo.feliz =>
          Path()
            ..moveTo(54.5, 99)
            ..quadraticBezierTo(64, 111, 73.5, 99),
      },
      fase: 0.2,
    ),
    // Crema: la cúpula chica de la derecha, con su borde naranja. Antes era
    // un arco amarillo delgado; en crema acompaña al grafito sin gritar.
    _Figura(
      cuerpo: Path()
        ..moveTo(150, 110)
        ..arcToPoint(const Offset(202, 110), radius: const Radius.circular(26))
        ..close(),
      color: const Color(0xFFF6F0E6),
      borde: Tokens.marca,
      grosorBorde: 2.6,
      ojos: const [Offset(168, 92), Offset(186, 92)],
      colorOjo: const Color(0xFF3A1602),
      radioPupila: 3,
      anchoCerrado: 5,
      caidaCerrado: 4,
      grosorCerrado: 2.2,
      boca: (animo) => switch (animo) {
        Animo.normal =>
          Path()
            ..moveTo(190, 100)
            ..lineTo(206, 100),
        // Torcida: un "meh" de desilusión.
        Animo.triste =>
          Path()
            ..moveTo(190, 102)
            ..lineTo(206, 99),
        Animo.feliz =>
          Path()
            ..moveTo(190, 99)
            ..quadraticBezierTo(198, 104, 206, 99),
      },
      grosorBoca: 2.4,
      colorBoca: Tokens.marca,
      fase: 0.3,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final encuadre = _Encuadre.de(
      size,
      margenInferior: margenInferior,
      conArco: conArco,
    );
    if (encuadre.escala == 0) return;

    canvas.save();
    canvas.translate(encuadre.dx, encuadre.dy);
    canvas.scale(encuadre.escala);

    if (conArco) _pintarArco(canvas);

    // La sacudida es un vaivén que se va apagando: un "no" con la cabeza.
    final sacudidaX = sacudida == 0
        ? 0.0
        : math.sin(sacudida * math.pi * 5) * 5 * (1 - sacudida);

    for (final figura in _figuras) {
      canvas.save();
      canvas.translate(
        sacudidaX,
        _desplazamientoFlote(figura.fase) + _desplazamientoSalto(figura.fase),
      );
      _pintarFigura(canvas, figura);
      canvas.restore();
    }

    canvas.restore();
  }

  /// La cúpula de fondo, apenas más clara que el grafito, con una sombra a
  /// los pies y una línea de piso que se desvanece a los costados. Es lo que
  /// los apoya en algún lado: sin esto parecían recortes pegados.
  void _pintarArco(Canvas canvas) {
    const caja = Rect.fromLTRB(22, 4, 200, 110);
    final arco = Path()
      ..moveTo(22, 110)
      ..lineTo(22, 93)
      ..arcToPoint(const Offset(200, 93), radius: const Radius.circular(89))
      ..lineTo(200, 110)
      ..close();

    canvas.drawPath(
      arco,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.11),
            Colors.white.withValues(alpha: 0.04),
          ],
        ).createShader(caja),
    );

    // Sombra de contacto: sólo dentro de la cúpula, que es donde se ve.
    canvas.save();
    canvas.clipPath(arco);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(111, 110.5), width: 176, height: 7),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    canvas.restore();

    const piso = Rect.fromLTWH(-20, 109.6, 262, 1.1);
    canvas.drawRect(
      piso,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.25, 0.75, 1],
        ).createShader(piso),
    );
  }

  /// Sube 3 y vuelve, como el `bob` del CSS.
  double _desplazamientoFlote(double fase) {
    if (flote == 0) return 0;
    final t = (flote + fase) % 1;
    return -1.5 * (1 - math.cos(2 * math.pi * t));
  }

  /// Saltito de festejo, uno detrás del otro.
  double _desplazamientoSalto(double fase) {
    if (salto == 0) return 0;
    final t = ((salto - fase * 0.6) / 0.6).clamp(0.0, 1.0);
    return -math.sin(t * math.pi) * 16;
  }

  /// El parpadeo es un instante muy corto dentro del ciclo. Cada figura lo
  /// tiene en un momento distinto gracias a su fase.
  bool _estaParpadeando(double fase) {
    if (parpadeo == 0) return false;
    final t = (parpadeo + fase) % 1;
    return t > 0.94 && t < 0.975;
  }

  void _pintarFigura(Canvas canvas, _Figura figura) {
    canvas.drawPath(figura.cuerpo, Paint()..color = figura.color);
    final borde = figura.borde;
    if (borde != null) {
      canvas.drawPath(
        figura.cuerpo,
        Paint()
          ..color = borde
          ..style = PaintingStyle.stroke
          ..strokeWidth = figura.grosorBorde
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (animo == Animo.feliz) {
      _pintarOjosCurvos(canvas, figura, felices: true);
    } else if (ojosCerrados || _estaParpadeando(figura.fase)) {
      _pintarOjosCurvos(canvas, figura, felices: false);
    } else {
      // La esclerótica es parte del ojo abierto: con los ojos cerrados tiene
      // que desaparecer. Si se dibujara siempre, la curva blanca del personaje
      // negro caería sobre blanco y no se vería nada.
      final radioBlanco = figura.radioBlanco;
      if (radioBlanco != null) {
        final blanco = Paint()..color = Colors.white;
        for (final ojo in figura.ojos) {
          canvas.drawCircle(ojo, radioBlanco, blanco);
        }
      }
      _pintarPupilas(canvas, figura);
    }

    final boca = figura.boca;
    if (boca != null) {
      canvas.drawPath(
        boca(animo),
        Paint()
          ..color = figura.colorBoca ?? figura.colorOjo
          ..style = PaintingStyle.stroke
          ..strokeWidth = figura.grosorBoca
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _pintarPupilas(Canvas canvas, _Figura figura) {
    // Tristes miran al piso, sin importar dónde esté el cursor.
    final direccion = animo == Animo.triste
        ? Offset(mirada.dx * 0.3, 0.95)
        : mirada;
    final corrimiento = Offset(
      direccion.dx * _recorridoPupilaX,
      direccion.dy * _recorridoPupilaY,
    );

    final pincel = Paint()..color = figura.colorOjo;
    for (final ojo in figura.ojos) {
      canvas.drawCircle(ojo + corrimiento, figura.radioPupila, pincel);
    }
  }

  /// Ojos cerrados (curva hacia abajo) o felices (la misma curva hacia arriba,
  /// el "^^" de los dibujos).
  void _pintarOjosCurvos(
    Canvas canvas,
    _Figura figura, {
    required bool felices,
  }) {
    // En el personaje negro el trazo va en blanco para que se vea.
    final color = figura.radioBlanco != null ? Colors.white : figura.colorOjo;
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = figura.grosorCerrado
      ..strokeCap = StrokeCap.round;

    final w = figura.anchoCerrado;
    final caida = figura.caidaCerrado;

    for (final ojo in figura.ojos) {
      final curva = felices
          ? (Path()
              ..moveTo(ojo.dx - w, ojo.dy + 1.5)
              ..quadraticBezierTo(
                ojo.dx,
                ojo.dy - caida,
                ojo.dx + w,
                ojo.dy + 1.5,
              ))
          : (Path()
              ..moveTo(ojo.dx - w, ojo.dy)
              ..quadraticBezierTo(ojo.dx, ojo.dy + caida, ojo.dx + w, ojo.dy));
      canvas.drawPath(curva, pincel);
    }
  }

  @override
  bool shouldRepaint(_PintorPersonajes anterior) {
    return anterior.mirada != mirada ||
        anterior.ojosCerrados != ojosCerrados ||
        anterior.animo != animo ||
        anterior.flote != flote ||
        anterior.parpadeo != parpadeo ||
        anterior.sacudida != sacudida ||
        anterior.salto != salto ||
        anterior.margenInferior != margenInferior ||
        anterior.conArco != conArco;
  }
}
