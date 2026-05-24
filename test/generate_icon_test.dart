import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generate Png icon', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Scale 512 base coordinate system up to 1024
    canvas.scale(2.0, 2.0);

    // Background Gradient
    final bgRect = const ui.Rect.fromLTWH(0, 0, 512, 512);
    final bgPaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        const ui.Offset(512, 512),
        [const ui.Color(0xFF00C6FF), const ui.Color(0xFF0072FF)],
      );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(bgRect, const ui.Radius.circular(110)),
      bgPaint,
    );

    // Shield Shadow (glow)
    final shadowPaint = ui.Paint()
      ..color = const ui.Color(0x4D000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 15);
    final shieldPath = ui.Path()
      ..moveTo(256, 120)
      ..lineTo(150, 160)
      ..lineTo(150, 280)
      ..cubicTo(150, 370, 230, 420, 256, 430)
      ..cubicTo(282, 420, 362, 370, 362, 280)
      ..lineTo(362, 160)
      ..close();
    canvas.drawPath(shieldPath.shift(const ui.Offset(0, 10)), shadowPaint);

    // Shield
    final shieldPaint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    canvas.drawPath(shieldPath, shieldPaint);

    // B / Checkmark Stroke
    final strokePaint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..color = const ui.Color(0xFF0083B0)
      ..strokeWidth = 36
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;

    // Left stalk
    final p1 = ui.Path()
      ..moveTo(210, 200)
      ..lineTo(210, 340);
    canvas.drawPath(p1, strokePaint);

    // Top loop
    final p2 = ui.Path()
      ..moveTo(210, 200)
      ..cubicTo(290, 200, 310, 220, 310, 240)
      ..cubicTo(310, 260, 290, 270, 240, 270);
    canvas.drawPath(p2, strokePaint);

    // Bottom loop/checkmark
    final p3 = ui.Path()
      ..moveTo(220, 270)
      ..cubicTo(290, 270, 320, 290, 320, 315)
      ..lineTo(260, 360)
      ..lineTo(200, 320);
    canvas.drawPath(p3, strokePaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(1024, 1024);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    final dir = Directory('assets');
    if (!dir.existsSync()) {
      dir.createSync();
    }
    final file = File('assets/icon.png');
    file.writeAsBytesSync(buffer);
    debugPrint('PNG Generated successfully!');
  });
}