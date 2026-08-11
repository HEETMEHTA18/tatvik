import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

class MovingAsciiBackground extends StatefulWidget {
  final bool isDark;
  const MovingAsciiBackground({super.key, required this.isDark});

  @override
  State<MovingAsciiBackground> createState() => _MovingAsciiBackgroundState();
}

class AsciiStream {
  double x;
  double y;
  double speed;
  double fontSize;
  double baseOpacity;
  List<String> glyphs;
  Color baseColor;

  AsciiStream({
    required this.x,
    required this.y,
    required this.speed,
    required this.fontSize,
    required this.baseOpacity,
    required this.glyphs,
    required this.baseColor,
  });
}

class FloatingWord {
  double x;
  double y;
  double speedX;
  double speedY;
  double fontSize;
  double opacity;
  String text;
  Color color;
  double angle;
  double rotationSpeed;

  FloatingWord({
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.fontSize,
    required this.opacity,
    required this.text,
    required this.color,
    required this.angle,
    required this.rotationSpeed,
  });
}

class _MovingAsciiBackgroundState extends State<MovingAsciiBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  final List<AsciiStream> _streams = [];
  final List<FloatingWord> _floatingWords = [];

  double _lastWidth = 0;
  double _lastHeight = 0;

  final math.Random _random = math.Random();

  // Cache of TextPainters to avoid layout on every frame
  final Map<String, TextPainter> _painterCache = {};

  static const List<String> _glyphs = [
    '{',
    '}',
    '[',
    ']',
    '(',
    ')',
    '<',
    '>',
    '/',
    '\\',
    '!',
    '@',
    '#',
    '\$',
    '%',
    '^',
    '&',
    '*',
    '-',
    '+',
    '=',
    '|',
    ';',
    ':',
    ',',
    '.',
    '?',
    '~',
    '_',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  static const List<String> _techWords = [
    'TATVIK',
    'FLUTTER',
    'DART',
    'PYTHON',
    'KUBERNETES',
    'AI.INSIGHTS',
    'DEVELOPER.DNA',
    'PROMPT.HUB',
    'GIT.SYNC',
    'ROAST.ME',
    'ROADMAP',
    'AUTODEV',
    'TELEMETRY',
    'SYSTEM.OK',
    'BUILD.SUCCESS',
    'MAIN.DART',
    'REPOS',
    'CHAT.MENTOR',
    'PIPELINE',
    'INTEGRATE',
  ];

  @override
  void initState() {
    super.initState();
    final bool isMobileBrowser =
        kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    _ticker = createTicker((elapsed) {
      if (isMobileBrowser) return;
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      final delta = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
      _lastElapsed = elapsed;
      if (mounted) {
        _updateParticles(delta);
      }
    });
    if (!isMobileBrowser) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _painterCache.forEach((_, painter) => painter.dispose());
    _painterCache.clear();
    super.dispose();
  }

  // Soft glowing neon/pastel palettes based on theme
  List<Color> _getThemeColors() {
    if (widget.isDark) {
      return [
        const Color(0xFF06B6D4), // Neon Cyan
        const Color(0xFF8B5CF6), // Neon Violet
        const Color(0xFF10B981), // Neon Emerald Green
        const Color(0xFF3B82F6), // Cool Blue
        const Color(0xFFEC4899), // Neon Pink
      ];
    } else {
      return [
        const Color(0xFF4F46E5), // Indigo
        const Color(0xFF0D9488), // Soft Teal
        const Color(0xFF7C3AED), // Muted Purple
        const Color(0xFF2563EB), // Royal Blue
        const Color(0xFFDB2777), // Pink/Magenta
      ];
    }
  }

  void _initializeLayout(double width, double height) {
    _streams.clear();
    _floatingWords.clear();
    _painterCache.clear();

    _lastWidth = width;
    _lastHeight = height;

    final colors = _getThemeColors();

    // 1. Initialize falling streams
    // Space columns about 24px apart
    final double columnWidth = 24.0;
    final int columnCount = (width / columnWidth).ceil();

    for (int i = 0; i < columnCount; i++) {
      // Don't fill every column (have about 60% occupancy for a clean, non-cluttered background)
      if (_random.nextDouble() > 0.6) continue;

      final double colX = i * columnWidth + _random.nextDouble() * 6 - 3;
      final double startY =
          -_random.nextDouble() * height -
          200; // start off-screen at random heights
      final double speed =
          60.0 + _random.nextDouble() * 110.0; // 60 to 170 px/sec
      final double fontSize = 9.0 + _random.nextDouble() * 5.0; // 9 to 14 pt
      final double baseOpacity = widget.isDark
          ? (0.07 + _random.nextDouble() * 0.13) // 0.07 to 0.20
          : (0.05 + _random.nextDouble() * 0.08); // 0.05 to 0.13

      final int tailLength = 8 + _random.nextInt(12); // 8 to 20 chars
      final List<String> glyphs = List.generate(
        tailLength,
        (_) => _glyphs[_random.nextInt(_glyphs.length)],
      );

      final baseColor = colors[_random.nextInt(colors.length)];

      _streams.add(
        AsciiStream(
          x: colX,
          y: startY,
          speed: speed,
          fontSize: fontSize,
          baseOpacity: baseOpacity,
          glyphs: glyphs,
          baseColor: baseColor,
        ),
      );
    }

    // 2. Initialize floating tech words
    // Draw 3 to 6 words depending on screen size
    final int wordCount = width > 800 ? 5 : 3;
    for (int i = 0; i < wordCount; i++) {
      _floatingWords.add(_generateFloatingWord(width, height, initial: true));
    }
  }

  FloatingWord _generateFloatingWord(
    double width,
    double height, {
    bool initial = false,
  }) {
    final colors = _getThemeColors();
    final word = _techWords[_random.nextInt(_techWords.length)];

    // Choose start edge
    double x, y;
    final speedX =
        (10.0 + _random.nextDouble() * 20.0) * (_random.nextBool() ? 1 : -1);
    final speedY =
        (5.0 + _random.nextDouble() * 15.0) * (_random.nextBool() ? 1 : -1);

    if (initial) {
      x = _random.nextDouble() * width;
      y = _random.nextDouble() * height;
    } else {
      // Spawn on a random boundary screen edge
      if (_random.nextBool()) {
        x = speedX > 0 ? -150 : width + 150;
        y = _random.nextDouble() * height;
      } else {
        x = _random.nextDouble() * width;
        y = speedY > 0 ? -50 : height + 50;
      }
    }

    final double fontSize = 14.0 + _random.nextDouble() * 10.0; // 14 to 24 pt
    final double opacity = widget.isDark
        ? (0.04 + _random.nextDouble() * 0.08) // 0.04 to 0.12
        : (0.03 + _random.nextDouble() * 0.05); // 0.03 to 0.08

    final baseColor = colors[_random.nextInt(colors.length)];

    return FloatingWord(
      x: x,
      y: y,
      speedX: speedX,
      speedY: speedY,
      fontSize: fontSize,
      opacity: opacity,
      text: word,
      color: baseColor,
      angle: _random.nextDouble() * math.pi * 0.15 - 0.075, // slight tilt
      rotationSpeed: (_random.nextDouble() * 0.04 - 0.02),
    );
  }

  void _updateParticles(double delta) {
    if (_lastWidth == 0 || _lastHeight == 0) return;

    // 1. Update falling streams
    for (final stream in _streams) {
      stream.y += stream.speed * delta;

      // Calculate length of the stream in pixels
      final double totalStreamHeight =
          stream.glyphs.length * stream.fontSize * 1.3;

      // Reset if it goes off screen
      if (stream.y - totalStreamHeight > _lastHeight) {
        stream.y = -totalStreamHeight - _random.nextDouble() * 200;
        stream.speed = 60.0 + _random.nextDouble() * 110.0;
        stream.baseOpacity = widget.isDark
            ? (0.07 + _random.nextDouble() * 0.13)
            : (0.05 + _random.nextDouble() * 0.08);

        final colors = _getThemeColors();
        stream.baseColor = colors[_random.nextInt(colors.length)];
      }

      // Small chance to mutate characters for matrix flicker
      for (int i = 0; i < stream.glyphs.length; i++) {
        if (_random.nextDouble() < 0.015) {
          stream.glyphs[i] = _glyphs[_random.nextInt(_glyphs.length)];
        }
      }
    }

    // 2. Update floating words
    for (int i = 0; i < _floatingWords.length; i++) {
      final word = _floatingWords[i];
      word.x += word.speedX * delta;
      word.y += word.speedY * delta;
      word.angle += word.rotationSpeed * delta;

      // Reset if off-screen with buffer
      if (word.x < -250 ||
          word.x > _lastWidth + 250 ||
          word.y < -150 ||
          word.y > _lastHeight + 150) {
        _floatingWords[i] = _generateFloatingWord(_lastWidth, _lastHeight);
      }
    }

    // Force repaint
    setState(() {});
  }

  // Highly optimized TextPainter retrieval from cache
  TextPainter _getPainter(String text, double fontSize, Color color) {
    final key = '$text-$fontSize-${color.toARGB32()}';

    var painter = _painterCache[key];
    if (painter == null) {
      painter = TextPainter(
        text: TextSpan(
          text: text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: fontSize,
            color: color,
            fontWeight: text.length > 1 ? FontWeight.bold : FontWeight.w500,
            letterSpacing: text.length > 1 ? 1.5 : 0,
          ).copyWith(
            fontFamilyFallback: const [
              'Menlo',
              'Consolas',
              'Courier New',
              'monospace',
              'sans-serif',
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      painter.layout();

      // Clean cache if too large to prevent leaks
      if (_painterCache.length > 1200) {
        _painterCache.forEach((_, p) => p.dispose());
        _painterCache.clear();
      }

      _painterCache[key] = painter;
    }
    return painter;
  }

  @override
  void didUpdateWidget(covariant MovingAsciiBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If theme changes, clear cache and regenerate streams with appropriate color schema
    if (oldWidget.isDark != widget.isDark) {
      _painterCache.forEach((_, p) => p.dispose());
      _painterCache.clear();
      _initializeLayout(_lastWidth, _lastHeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;

        // Initialize streams and words on first load or when size changes significantly
        if (_streams.isEmpty ||
            (width - _lastWidth).abs() > 50 ||
            (height - _lastHeight).abs() > 50) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _initializeLayout(width, height);
              });
            }
          });
        }

        return RepaintBoundary(
          child: CustomPaint(
            size: Size(width, height),
            painter: AsciiPainter(
              streams: _streams,
              floatingWords: _floatingWords,
              isDark: widget.isDark,
              getPainter: _getPainter,
            ),
          ),
        );
      },
    );
  }
}

class AsciiPainter extends CustomPainter {
  final List<AsciiStream> streams;
  final List<FloatingWord> floatingWords;
  final bool isDark;
  final TextPainter Function(String, double, Color) getPainter;

  AsciiPainter({
    required this.streams,
    required this.floatingWords,
    required this.isDark,
    required this.getPainter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw floating tech words first so they are behind/deeper
    for (final word in floatingWords) {
      canvas.save();
      // Translate to center of word
      canvas.translate(word.x, word.y);
      canvas.rotate(word.angle);

      final painter = getPainter(
        word.text,
        word.fontSize,
        word.color.withValues(alpha: word.opacity),
      );
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));

      canvas.restore();
    }

    // 2. Draw vertical falling streams
    for (final stream in streams) {
      double currentY = stream.y;

      for (int i = 0; i < stream.glyphs.length; i++) {
        // Skip drawing if it hasn't reached the screen yet
        if (currentY < -stream.fontSize) {
          currentY += stream.fontSize * 1.35;
          continue;
        }

        // Stop drawing if it went off screen
        if (currentY > size.height) {
          break;
        }

        final isHead = i == 0;
        final double opacityStep = (1.0 - (i / stream.glyphs.length)).clamp(
          0.0,
          1.0,
        );

        Color charColor;
        if (isHead) {
          // Glow effect at the head
          final double headOpacity = (stream.baseOpacity * 1.4).clamp(0.0, 1.0);
          charColor = isDark
              ? Colors.white.withValues(alpha: headOpacity)
              : stream.baseColor.withValues(alpha: headOpacity);
        } else {
          charColor = stream.baseColor.withValues(
            alpha: stream.baseOpacity * opacityStep,
          );
        }

        final painter = getPainter(
          stream.glyphs[i],
          stream.fontSize,
          charColor,
        );
        painter.paint(canvas, Offset(stream.x - painter.width / 2, currentY));

        currentY += stream.fontSize * 1.35; // vertical char gap
      }
    }
  }

  @override
  bool shouldRepaint(covariant AsciiPainter oldDelegate) {
    // Repainting is handled via stream updates and state triggering
    return true;
  }
}
