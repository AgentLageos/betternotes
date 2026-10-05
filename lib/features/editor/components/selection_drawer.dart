import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter/cupertino.dart';

import 'package:betternotes/features/editor/models/page/stroke.dart';
import 'dart:core';


class SelectionDrawer extends StatelessWidget {
  final double width;
  final double height;
  final List<Stroke> selectionStrokes;
  final bool selectionActive;
  final int selectionOperation;
  final Color selectionColor;
  final VoidCallback deleteSelection;
  final VoidCallback copySelection;
  final VoidCallback colorSelection;

  const SelectionDrawer({
    Key? key,
    required this.width,
    required this.height,
    required this.selectionStrokes,
    required this.selectionActive,
    required this.selectionOperation,
    required this.selectionColor,
    required this.deleteSelection,
    required this.copySelection,
    required this.colorSelection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [

        CustomPaint(
          size: Size(width, height),
          painter: SelectionPainter(
            selectionStrokes: selectionStrokes,
            selectionActive: selectionActive,
            selectionOperation: selectionOperation,
          ),
        ),
        if (selectionActive && selectionStrokes.isNotEmpty && selectionOperation == -1)..._buildOverlayButtons(),

      ],
    );
  }

  List<Widget> _buildOverlayButtons() {
    final strokeBounds = selectionStrokes.last.getStrokeBounds();
    return [
      Positioned(
        left: strokeBounds.right - 7 + 3,
        top: strokeBounds.top - 15,
        child: Transform.scale(
          scale: 0.3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: deleteSelection,
                child: Icon(Icons.delete, color: selectionColor, size: 20),
              ),
              GestureDetector(
                onTap: copySelection,
                child: Icon(Icons.copy, color: selectionColor, size: 20),
              ),
              GestureDetector(
                onTap: colorSelection,
                child: Icon(Icons.color_lens, color: selectionColor, size: 20),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}







class SelectionPainter extends CustomPainter {
  final List<Stroke> selectionStrokes;
  final bool selectionActive;
  final int selectionOperation;

  SelectionPainter({required this.selectionStrokes, required this.selectionActive, required this.selectionOperation});

  @override
  void paint(Canvas canvas, Size size) {


    for (int i=0; i<selectionStrokes.length; i++) {

      final stroke = selectionStrokes[i];
      final points = stroke.points;
      if (points.isEmpty) continue;



      if (stroke.points.isNotEmpty) {
        Path path = Path();

        path.moveTo(stroke.points[0].pos.dx, stroke.points[0].pos.dy);

        for (int j = 1; j < stroke.points.length; j++) {
          Offset p = stroke.points[j].pos;
          path.lineTo(p.dx, p.dy);
        }

        path.close();

        Paint fillPaint = Paint()
          ..color = stroke.color.withOpacity(0.3)
          ..style = PaintingStyle.fill;

        // Fläche zeichnen
        canvas.drawPath(path, fillPaint);

        // 2️⃣ Kontur / Stroke in voller Farbe
        Paint strokePaint = Paint()
          ..color = stroke.color // volle Deckkraft
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke.points.first.width; // z.B. Thickness des Stifts

        // Kontur zeichnen
        canvas.drawPath(path, strokePaint);
      }

      if (selectionActive){
        Paint paint = Paint()
          ..color = stroke.color
          ..style = PaintingStyle.fill
          ..strokeWidth = stroke.points.first.width
          ..isAntiAlias = true;
        final double size = 2;

        Offset p0 = stroke.points[0].pos;                           //  p0-------p3
        Offset p1 = stroke.points[1].pos;                           //  |         |
        Offset p2 = stroke.points[2].pos;                           //  |         |
        Offset p3 = stroke.points[3].pos;                           //  p1-------p2

        canvas.drawRect(Rect.fromCenter(center: p0, width: size, height: size), paint);
        canvas.drawRect(Rect.fromCenter(center: p1, width: size, height: size), paint);
        canvas.drawRect(Rect.fromCenter(center: p2, width: size, height: size), paint);
        canvas.drawRect(Rect.fromCenter(center: p3, width: size, height: size), paint);


        Offset middlePoint = p1+(p3-p1)/2;
        Offset upperPoint = p0-(p0-p1)/4+(p3-p0)/2;                           //when changing this also change the detection area in page_widget (search for line with same formula)


        canvas.drawLine(middlePoint, upperPoint, paint);

        final radius = ((p1-p0)/4).distance;

        paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.points.first.width
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;
        canvas.drawCircle(upperPoint, 1, paint);
        canvas.drawCircle(p2-(p2-p0)/2, radius, paint);

        if (selectionOperation==-1){
          Rect menuRect = stroke.getStrokeBounds();
          canvas.drawRect(Rect.fromLTWH(menuRect.right+3, menuRect.top+5, 6, 19), paint);
        }


      }

    }

  }




  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) {
    return true;
  }
}


