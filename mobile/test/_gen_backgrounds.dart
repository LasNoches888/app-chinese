// One-off tool, not a real test: renders the app's decorative background
// artwork (ink-wash style mountains, sun and clouds) into assets/images/ as
// transparent PNGs. Drawn with pure Canvas primitives because flutter_test
// has no real fonts or image decoders — anything glyph-based renders as an
// empty box here. Run with `flutter test test/_gen_backgrounds.dart`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _coral = Color(0xFFFF7A59);
const _violet = Color(0xFF6C5CE7);
const _teal = Color(0xFF23C58F);

Future<void> _renderToFile(
  WidgetTester tester,
  CustomPainter painter,
  String path,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(painter: painter, size: size),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

/// A stylised 祥云-ish cloud: three overlapping discs sitting on a rounded
/// bar, which reads as a cloud at low opacity without needing a real
/// illustration.
void _cloud(Canvas canvas, Offset at, double s, Color color) {
  final p = Paint()..color = color;
  canvas.drawCircle(at.translate(-s * 0.55, s * 0.05), s * 0.40, p);
  canvas.drawCircle(at.translate(0, -s * 0.20), s * 0.56, p);
  canvas.drawCircle(at.translate(s * 0.58, s * 0.02), s * 0.42, p);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: at.translate(0, s * 0.30),
        width: s * 2.2,
        height: s * 0.60,
      ),
      Radius.circular(s * 0.30),
    ),
    p,
  );
}

/// Builds a mountain ridge: a jagged top edge through [peaks] (in 0..1
/// fractions of the canvas) filled down to the bottom of the canvas.
Path _ridge(double w, double h, List<Offset> peaks) {
  final path = Path()..moveTo(0, peaks.first.dy * h);
  for (final peak in peaks) {
    path.lineTo(peak.dx * w, peak.dy * h);
  }
  path
    ..lineTo(w, h)
    ..lineTo(0, h)
    ..close();
  return path;
}

/// Full-page backdrop: sun, drifting clouds and three receding mountain
/// ridges. Fully transparent apart from the artwork, so it can be tinted by
/// whatever surface it is laid over in either theme.
class _ScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawCircle(
      Offset(w * 0.74, h * 0.15),
      w * 0.15,
      Paint()..color = _coral.withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      Offset(w * 0.74, h * 0.15),
      w * 0.22,
      Paint()..color = _coral.withValues(alpha: 0.09),
    );

    _cloud(
      canvas,
      Offset(w * 0.22, h * 0.13),
      w * 0.10,
      _violet.withValues(alpha: 0.13),
    );
    _cloud(
      canvas,
      Offset(w * 0.52, h * 0.26),
      w * 0.07,
      _violet.withValues(alpha: 0.10),
    );
    _cloud(
      canvas,
      Offset(w * 0.86, h * 0.34),
      w * 0.08,
      _coral.withValues(alpha: 0.10),
    );

    // Far ridge — palest and highest, then two closer, darker ranges.
    canvas.drawPath(
      _ridge(w, h, const [
        Offset(0.00, 0.62),
        Offset(0.16, 0.50),
        Offset(0.29, 0.60),
        Offset(0.46, 0.44),
        Offset(0.63, 0.58),
        Offset(0.80, 0.47),
        Offset(1.00, 0.60),
      ]),
      Paint()..color = _violet.withValues(alpha: 0.10),
    );
    canvas.drawPath(
      _ridge(w, h, const [
        Offset(0.00, 0.76),
        Offset(0.20, 0.63),
        Offset(0.38, 0.74),
        Offset(0.57, 0.60),
        Offset(0.78, 0.72),
        Offset(1.00, 0.66),
      ]),
      Paint()..color = _violet.withValues(alpha: 0.15),
    );
    canvas.drawPath(
      _ridge(w, h, const [
        Offset(0.00, 0.88),
        Offset(0.24, 0.79),
        Offset(0.48, 0.89),
        Offset(0.72, 0.78),
        Offset(1.00, 0.86),
      ]),
      Paint()..color = _teal.withValues(alpha: 0.16),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Artwork for the inside of the brand gradient banner — white-on-gradient
/// mountains, sun and a small flight of birds.
class _HeaderArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawCircle(
      Offset(w * 0.78, h * 0.30),
      h * 0.24,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    _cloud(
      canvas,
      Offset(w * 0.30, h * 0.24),
      h * 0.13,
      Colors.white.withValues(alpha: 0.16),
    );

    canvas.drawPath(
      _ridge(w, h, const [
        Offset(0.00, 0.72),
        Offset(0.18, 0.52),
        Offset(0.34, 0.68),
        Offset(0.55, 0.46),
        Offset(0.76, 0.66),
        Offset(1.00, 0.56),
      ]),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
    canvas.drawPath(
      _ridge(w, h, const [
        Offset(0.00, 0.88),
        Offset(0.26, 0.74),
        Offset(0.52, 0.90),
        Offset(0.80, 0.76),
        Offset(1.00, 0.84),
      ]),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    // Two small birds: a pair of shallow arcs each.
    final bird = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.014
      ..strokeCap = StrokeCap.round;
    void drawBird(Offset at, double s) {
      canvas.drawPath(
        Path()
          ..moveTo(at.dx - s, at.dy)
          ..quadraticBezierTo(at.dx - s * 0.5, at.dy - s * 0.55, at.dx, at.dy)
          ..quadraticBezierTo(
            at.dx + s * 0.5,
            at.dy - s * 0.55,
            at.dx + s,
            at.dy,
          ),
        bird,
      );
    }

    drawBird(Offset(w * 0.46, h * 0.24), h * 0.07);
    drawBird(Offset(w * 0.58, h * 0.15), h * 0.05);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  testWidgets('generate page backdrop', (tester) async {
    await _renderToFile(
      tester,
      _ScenePainter(),
      'assets/images/bg_scene.png',
      const Size(1080, 1500),
    );
  });

  testWidgets('generate header artwork', (tester) async {
    await _renderToFile(
      tester,
      _HeaderArtPainter(),
      'assets/images/bg_header.png',
      const Size(1000, 380),
    );
  });
}
