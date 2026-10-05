import 'dart:ui';
import '../../features/editor/models/page/stroke.dart';

void drawStrokes2(Canvas canvas, List<Stroke> strokes, double scale, double blur) {
  for (final stroke in strokes) {
    if (stroke.points.isEmpty) continue;

    final paint = Paint()
      ..color = stroke.color
      ..isAntiAlias = true
      //..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
    ;


    if (stroke.points.length == 1) {
      final p = stroke.points.first.pos * scale;
      final w = stroke.points.first.width * scale;
      canvas.drawCircle(p, w / 2, paint);
      continue;
    }

    final sameWidth = stroke.points.every((p) => p.width == stroke.points.first.width);

    if (sameWidth) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.points.first.width * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i].pos * scale;
        final p1 = stroke.points[i + 1].pos * scale;
        canvas.drawLine(p0, p1, paint);
      }
    } else {
      final left = <Offset>[];
      final right = <Offset>[];

      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i].pos * scale;
        final p1 = stroke.points[i + 1].pos * scale;
        final w0 = stroke.points[i].width * scale;
        final w1 = stroke.points[i + 1].width * scale;

        final dir = p1 - p0;
        final distance = dir.distance;
        final normal = distance < 0.01 ? const Offset(0, 1) : Offset(-dir.dy, dir.dx) / distance;

        left.add(p0 + normal * w0 / 2);
        right.add(p0 - normal * w0 / 2);

        if (i == stroke.points.length - 2) {
          left.add(p1 + normal * w1 / 2);
          right.add(p1 - normal * w1 / 2);
        }
      }

      if (left.isNotEmpty && right.isNotEmpty) {
        final path = Path()..moveTo(left.first.dx, left.first.dy);
        for (int i = 0; i < left.length - 1; i++) {
          final mid = (left[i] + left[i + 1]) / 2;
          path.quadraticBezierTo(left[i].dx, left[i].dy, mid.dx, mid.dy);
        }
        for (int i = right.length - 1; i > 0; i--) {
          final mid = (right[i] + right[i - 1]) / 2;
          path.quadraticBezierTo(right[i].dx, right[i].dy, mid.dx, mid.dy);
        }
        path.close();

        canvas.drawCircle(stroke.points.first.pos * scale, stroke.points.first.width * scale / 2, paint);
        canvas.drawCircle(stroke.points.last.pos * scale, stroke.points.last.width * scale / 2, paint);

        paint..style = PaintingStyle.fill;
        canvas.drawPath(path, paint);
      }
    }
  }
}



void drawStrokes2AfterIsolate(Canvas canvas, List<Stroke> strokes, double scale, double blur, List<bool> sameWidths, List<List<Offset>> lefts, List<List<Offset>> rights) {


  final paint = Paint()..isAntiAlias = true;
  for (int k=0;k<strokes.length; k++) {
    final stroke = strokes[k];
    if (stroke.points.isEmpty) continue;


    paint.color = stroke.color;


    if (stroke.points.length == 1) {
      final p = stroke.points.first.pos * scale;
      final w = stroke.points.first.width * scale;
      canvas.drawCircle(p, w / 2, paint);
      continue;
    }


    if (sameWidths[k]) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.points.first.width * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i].pos * scale;
        final p1 = stroke.points[i + 1].pos * scale;
        canvas.drawLine(p0, p1, paint);
      }
    } else {

      //print("drawStrokes: ${lefts[k].length}");


      if (lefts[k].isNotEmpty && rights[k].isNotEmpty) {
        final path = Path()..moveTo(lefts[k].first.dx, lefts[k].first.dy);
        for (int i = 0; i < lefts[k].length - 1; i++) {
          final mid = (lefts[k][i] + lefts[k][i + 1]) / 2;
          path.quadraticBezierTo(lefts[k][i].dx, lefts[k][i].dy, mid.dx, mid.dy);
        }
        for (int i = rights[k].length - 1; i > 0; i--) {
          final mid = (rights[k][i] + rights[k][i - 1]) / 2;
          path.quadraticBezierTo(rights[k][i].dx, rights[k][i].dy, mid.dx, mid.dy);
        }
        path.close();

        canvas.drawCircle(stroke.points.first.pos * scale, stroke.points.first.width * scale / 2, paint);
        canvas.drawCircle(stroke.points.last.pos * scale, stroke.points.last.width * scale / 2, paint);

        paint..style = PaintingStyle.fill;
        canvas.drawPath(path, paint);
      }
    }
  }
}