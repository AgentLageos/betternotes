import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';


import 'package:betternotes/core/utils/draw_strokes.dart';
import 'package:flutter/material.dart';

import 'package:flutter/cupertino.dart';

import 'package:betternotes/features/editor/models/page/stroke.dart';


import 'package:betternotes/features/editor/models/page/abstract_stroke.dart';
import 'package:betternotes/features/editor/models/page/point.dart';

import 'package:betternotes/core/providers/global_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';



import 'dart:core';

class Tile extends ChangeNotifier{
  final Rect rect;
  ui.Image? image;
  ui.Image? backgroundImage;
  List<AbstractStroke> aStrokes = [];
  List<AbstractStroke> aBackgroundStrokes = [];



  Tile(
      this.rect,
      );





  Future<void> renderAbstractStrokes(List<Stroke> strokes) async {

    //print(aStrokes.length);

    double scale = 20.0;     //scale = 200 is way too high, at most!! 50
    final recorder = ui.PictureRecorder();
    //print(rect.left);
    final canvas = Canvas(recorder, Rect.fromLTWH(0,0, rect.width * scale, rect.height * scale));
    canvas.translate(-rect.left * scale, -rect.top * scale);

    List<Stroke> tileStrokes = [];


    //Stopwatch stopwatch = Stopwatch();
    //stopwatch.start();


    final strokeMap = {for (var s in strokes) s.strokeID: s,};


    for (int i=0; i<aStrokes.length; i++) {

      final stroke = strokeMap[aStrokes[i].strokeID];
      if (stroke == null) continue;


      Color color = stroke.color;
      double width = stroke.width;

      tileStrokes.add(Stroke(color : color, width: width, points: []));

      //if (0<=aStrokes[i].pointIndexes.first-2) tileStrokes[i].points.add(stroke.points[aStrokes[i].pointIndexes.first-2]);
      if (0<=aStrokes[i].pointIndexes.first-1) tileStrokes[i].points.add(stroke.points[aStrokes[i].pointIndexes.first-1]);
      aStrokes[i].pointIndexes.forEach((j) {
        //tileStrokes[i].points.add(strokes[aStrokes[i].strokeIndex].points[j]);
        //tileStrokes[i].points.add(strokes.firstWhere((s) => s.strokeID == aStrokes[i].strokeID).points[j]);
        tileStrokes[i].points.add(stroke.points[j]);
      });

      if (stroke.points.length>aStrokes[i].pointIndexes.last+1) tileStrokes[i].points.add(stroke.points[aStrokes[i].pointIndexes.last+1]);
      //if (stroke.points.length>aStrokes[i].pointIndexes.last+2) tileStrokes[i].points.add(stroke.points[aStrokes[i].pointIndexes.last+2]);

    }


    //print('Dauer1: ${stopwatch.elapsedMilliseconds} Millisekunden');

    drawStrokes2(canvas, tileStrokes, scale, 0.5);

    //stopwatch.stop();
    //print('Dauer: ${stopwatch.elapsedMilliseconds} Millisekunden');

    //image?.dispose();
    final picture = recorder.endRecording();

    final newImage = await picture.toImage((rect.width*scale).toInt(), (rect.height*scale).toInt());
    image =newImage;

    //this.isDirty=false;

    //print(image);


    //notifyListeners();
    //print("rendered");

  }


  Future<void> renderBackground(List<Stroke> backgroundStrokes) async {
    //print(aBackgroundStrokes.length);

    //print(aStrokes.length);

    double scale = 4.0;     //scale = 200 is way too high, at most 50
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0,0, rect.width * scale, rect.height * scale));
    canvas.translate(-rect.left * scale, -rect.top * scale);

    List<Stroke> tileStrokes = [];

    final strokeMap = {for (var s in backgroundStrokes) s.strokeID: s,};

    for (int i=0; i<aBackgroundStrokes.length; i++) {

      final backgroundStroke = strokeMap[aBackgroundStrokes[i].strokeID];
      if (backgroundStroke == null) continue;


      Color color = backgroundStroke.color;
      double width = backgroundStroke.width;

      tileStrokes.add(Stroke(color : color, width: width, points: []));

      aBackgroundStrokes[i].pointIndexes.forEach((j) {
        //tileStrokes[i].points.add(strokes[aStrokes[i].strokeIndex].points[j]);
        tileStrokes[i].points.add(backgroundStroke.points[j]);
      });

    }

    drawStrokes2(canvas, tileStrokes, scale, 2);

    final picture = recorder.endRecording();

    final newImage = await picture.toImage((rect.width*scale).toInt(), (rect.height*scale).toInt());
    backgroundImage = newImage;

  }




  bool checkIfPointsInRect(Offset p0, Offset p1, double width) {
    width=width/2;
    double x0=p0.dx;
    double x1=p1.dx;
    double y0=p0.dy;
    double y1=p1.dy;

    if(p1.dx>=p0.dx) {
      x1 =p1.dx+width;
      x0 =p0.dx-width;
    }
    else {
      x1 =p1.dx-width;
      x0 =p0.dx+width;
    }

    if(p1.dy>=p0.dy) {
      y1 =p1.dy+width;
      y0 =p0.dy-width;
    }
    else {
      y1 =p1.dy-width;
      y0 =p0.dy+width;
    }


    return rect.overlaps(Rect.fromPoints(Offset(x0, y0), Offset(x1, y1)));
  }

  bool checkIfStrokeInRect(Stroke stroke) {
    List<PointModel> points = stroke.points;


    if (points.isEmpty) return false;
    if (stroke.width!=-1){
      if (points.length == 1) {
        //only one point check rect  around
        Offset p = points.first.pos;
        double w = stroke.width / 2;
        Rect pointRect = Rect.fromLTWH(p.dx - w, p.dy - w, w * 2, w * 2);
        return rect.overlaps(pointRect);
      }

      //check segments
      for (int i = 0; i < points.length - 1; i++) {
        Offset p0 = points[i].pos;
        Offset p1 = points[i + 1].pos;
        double w0 = stroke.width/ 2;
        double w1 = stroke.width / 2;

        //rect for segments
        double left = min(p0.dx - w0, p1.dx - w1);
        double right = max(p0.dx + w0, p1.dx + w1);
        double top = min(p0.dy - w0, p1.dy - w1);
        double bottom = max(p0.dy + w0, p1.dy + w1);

        Rect segmentRect = Rect.fromLTRB(left, top, right, bottom);

        if (rect.overlaps(segmentRect)) {
          return true;
        }
      }
    }

    if (points.length == 1) {
      //rect around  point with half width
      Offset p = points.first.pos;
      double w = points.first.width / 2;
      Rect pointRect = Rect.fromLTWH(p.dx - w, p.dy - w, w * 2, w * 2);
      return rect.overlaps(pointRect);
    }

    //check segments
    for (int i = 0; i < points.length - 1; i++) {
      Offset p0 = points[i].pos;
      Offset p1 = points[i + 1].pos;
      double w0 = points[i].width/ 2;
      double w1 = points[i].width / 2;

      //calculate  rect  around segments
      double left = min(p0.dx - w0, p1.dx - w1);
      double right = max(p0.dx + w0, p1.dx + w1);
      double top = min(p0.dy - w0, p1.dy - w1);
      double bottom = max(p0.dy + w0, p1.dy + w1);

      Rect segmentRect = Rect.fromLTRB(left, top, right, bottom);

      if (rect.overlaps(segmentRect)) {
        return true;
      }
    }

    return false;
  }



  void addStrokeAsAbstractStroke(Stroke stroke) {

    final alreadyExists = aStrokes.any((s) => s.strokeID == stroke.strokeID);
    if (alreadyExists) return;      //abort if stroke is already there

    List<AbstractStroke> newAbstractStrokes = [];

    int j = -1;

    if (stroke.points.length < 2) {
      stroke.points.add(stroke.points.first);
    }

    double width = stroke.width;

    for (int i = 0; i < stroke.points.length - 1; i++) {



      if (width == -1) {
        width = stroke.points[i].width + 14;
      }

      if (checkIfPointsInRect(stroke.points[i].pos, stroke.points[i + 1].pos, width)) {

        if (j != i) {
          newAbstractStrokes.add(AbstractStroke(
            pointIndexes: {i, i + 1},
            strokeID: stroke.strokeID,
          ));
        } else {
          newAbstractStrokes.last.pointIndexes.addAll({i, i + 1});
        }

        j = i + 1;
      }
    }

    aStrokes.addAll(newAbstractStrokes);
  }


  void addBackgroundStrokeAsAbstractStroke(Stroke stroke) {

    List<AbstractStroke> newAbstractStrokes = [];

    int j = -1;

    if(stroke.points.length<2) {
      stroke.points.add(stroke.points.first);
    }

    double width = stroke.width;

    for (int i=0; i<stroke.points.length-1; i++) {

      if (checkIfPointsInRect(stroke.points[i].pos, stroke.points[i+1].pos, width)) {
        if (j!=i) {
          newAbstractStrokes.add(AbstractStroke(pointIndexes: {i, i+1}, strokeID: stroke.strokeID));
        } else {
          newAbstractStrokes.last.pointIndexes.addAll({i, i+1});
        }
        j=i+1;
      }
    }
    aBackgroundStrokes.addAll(newAbstractStrokes);
    //print("indexes:");
    //print(aBackgroundStrokes.first.pointIndexes.length);

  }



  bool addBackgroundStrokesAsAbstractStrokes(List<Stroke> strokes) {

    List<AbstractStroke> newAStrokes = [];

    for (int i=0; i<strokes.length; i++) {
      if (!rect.overlaps(strokes[i].getStrokeBounds())) continue;   //if not even the outer bounds overlap skip this stroke immediately
      final newAStroke = checkIfStrokeInTileAndReturnAStroke(strokes[i]);
      if(newAStroke != null) newAStrokes.addAll(newAStroke);
    }

    if (newAStrokes.isNotEmpty) {
      aBackgroundStrokes = newAStrokes;
      return true;
    }
    return false;

  }

  bool addStrokesAsAbstractStrokes(List<Stroke> strokes) {

    List<AbstractStroke> newAStrokes = [];

    for (int i=0; i<strokes.length; i++) {
      final alreadyExists = aStrokes.any((s) => s.strokeID == strokes[i].strokeID);
      if (alreadyExists) continue;      //abort if stroke is already there
      if (!rect.overlaps(strokes[i].getStrokeBounds())) continue;   //if not even the outer bounds overlap skip this stroke immediately
      final newAStroke = checkIfStrokeInTileAndReturnAStroke(strokes[i]);
      if(newAStroke != null) newAStrokes.addAll(newAStroke);
    }
    
    if (newAStrokes.isNotEmpty) {
      aStrokes.addAll(newAStrokes);
      return true;
    }
    return false;
    
  }





  List<AbstractStroke>? checkIfStrokeInTileAndReturnAStroke(Stroke stroke) {
    List<AbstractStroke> aStrokes = [];


    if (stroke.points.length == 1) {
      if (rect.overlaps(Rect.fromCircle(center: stroke.points.first.pos, radius: stroke.points.first.width/2))) {
        aStrokes.add(AbstractStroke(pointIndexes: {0}, strokeID: stroke.strokeID));
      }
    }

    int j = -1;         //strokes going in and out of tiles are problematic
    bool connected = false;

    for (int i = 0; i<stroke.points.length-1; i++) {


      bool skip = false;
      connected = false;
      //if(j==1)

      final p0 = stroke.points[i];
      final p1 = stroke.points[i + 1];

      bool p0Inside = rect.overlaps(Rect.fromCircle(center: p0.pos, radius: p0.width / 2));
      bool p1Inside = rect.overlaps(Rect.fromCircle(center: p1.pos, radius: p1.width / 2));



      if (p0Inside) {
        //print("j: $j  i: $i");
        if (j!=i) {
          //print("1");

          aStrokes.add(AbstractStroke(pointIndexes: {i}, strokeID: stroke.strokeID));
          //if(i-1>0) aStrokes.last.pointIndexes.add(i-1);            //creating overlaps
          //if(i-2>0) aStrokes.last.pointIndexes.add(i-2);
          //if(i+1<stroke.points.length) aStrokes.last.pointIndexes.add(i+1);
          //if(i+2<stroke.points.length) aStrokes.last.pointIndexes.add(i+2);
        }
        else aStrokes.last.pointIndexes.add(i);
        connected = true;
      }
      if (p1Inside) {

        if(j!=i && !connected) {
          //print(2);

          aStrokes.add(AbstractStroke(pointIndexes: {i+1}, strokeID: stroke.strokeID));
          //aStrokes.last.pointIndexes.add(i);                        //creating overlaps
          //if(i-1>0) aStrokes.last.pointIndexes.add(i-1);
        }
        else aStrokes.last.pointIndexes.add(i+1);
        connected = true;
      }


      // if both inside next step can be skipped
      if (p0Inside && p1Inside) skip = true;


      double r = max(p0.width, p1.width) / 2;
      Rect expanded = Rect.fromPoints(p0.pos, p1.pos).inflate(r);
      if (!rect.overlaps(expanded)) skip = true;


      if (!skip) {
        if(trapezoidIntersectsRect(stroke.points[i].pos, stroke.points[i].width, stroke.points[i+1].pos, stroke.points[i+1].width, rect)) {
          connected = true;
          //aStrokes.last.pointIndexes.addAll({i, i+1});
          if(j!=i) {
            //print(3);
            aStrokes.add(AbstractStroke(pointIndexes: {i, i+1}, strokeID: stroke.strokeID));
            //if (i-1>0) aStrokes.last.pointIndexes.add(i-1);
            //if (i+2<stroke.points.length) aStrokes.last.pointIndexes.add(i+2);
            //if (i-2>0) aStrokes.last.pointIndexes.add(i-2);
            //if (i+3<stroke.points.length) aStrokes.last.pointIndexes.add(i+3);
          }
          else aStrokes.last.pointIndexes.addAll({i,i+1});
          j=i+1;
        }
      }


      if (connected) j=i+1;


    }

    //print(aStrokes.length);
    //print(aStrokes.first.pointIndexes.length);
    return aStrokes;
    return null;
  }



  bool trapezoidIntersectsRect(
      Offset p0,
      double w0,
      Offset p1,
      double w1,
      Rect rect,
      ) {
    if (p0 == p1) {
      double r = w0 / 2;
      Rect pointRect = Rect.fromLTWH(p0.dx - r, p0.dy - r, 2 * r, 2 * r);
      return rect.overlaps(pointRect);
    }

    //direction
    final dx = p1.dx - p0.dx;
    final dy = p1.dy - p0.dy;
    final len = sqrt(dx * dx + dy * dy);

    //normal
    final nx = -dy / len;
    final ny = dx / len;

    final r0 = w0 / 2;
    final r1 = w1 / 2;

    //trapezoid
    final a = Offset(p0.dx + nx * r0, p0.dy + ny * r0);
    final b = Offset(p0.dx - nx * r0, p0.dy - ny * r0);
    final c = Offset(p1.dx - nx * r1, p1.dy - ny * r1);
    final d = Offset(p1.dx + nx * r1, p1.dy + ny * r1);

    final trapezoid = [a, b, c, d];

    //bounding box test, fast
    final trapRect = _boundingRect(trapezoid);
    if (!rect.overlaps(trapRect)) return false;

    //point in rect
    for (final p in trapezoid) {
      if (rect.contains(p)) return true;
    }

    final rectCorners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];

    for (final p in rectCorners) {
      if (_pointInPolygon(p, trapezoid)) return true;
    }

    //edges  overlap
    final trapEdges = [
      [a, b],
      [b, c],
      [c, d],
      [d, a],
    ];

    final rectEdges = [
      [rect.topLeft, rect.topRight],
      [rect.topRight, rect.bottomRight],
      [rect.bottomRight, rect.bottomLeft],
      [rect.bottomLeft, rect.topLeft],
    ];

    for (final e1 in trapEdges) {
      for (final e2 in rectEdges) {
        if (_lineIntersectsLine(e1[0], e1[1], e2[0], e2[1])) {
          return true;
        }
      }
    }

    return false;
  }

  Rect _boundingRect(List<Offset> pts) {
    double minX = pts.first.dx;
    double maxX = pts.first.dx;
    double minY = pts.first.dy;
    double maxY = pts.first.dy;

    for (final p in pts) {
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  bool _pointInPolygon(Offset p, List<Offset> poly) {
    int count = 0;

    for (int i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];

      if (((a.dy > p.dy) != (b.dy > p.dy)) &&
          (p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx)) {
        count++;
      }
    }

    return count % 2 == 1;
  }

  bool _lineIntersectsLine(Offset p1, Offset p2, Offset q1, Offset q2) {
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

    final r = p2 - p1;
    final s = q2 - q1;

    final denom = cross(r, s);
    if (denom == 0) return false;

    final t = cross(q1 - p1, s) / denom;
    final u = cross(q1 - p1, r) / denom;

    return t >= 0 && t <= 1 && u >= 0 && u <= 1;
  }




  Future<void> renderAfterIsolate(
      List<bool> sameWidths,
      List<List<Offset>> lefts,
      List<List<Offset>> rights,
      List<Stroke> tileStrokes,
      double scale,
      List<bool> backgroundSameWidths,
      List<Stroke> tileBackgroundStrokes,
      List<List<Offset>> backgroundLefts,
      List<List<Offset>> backgroundRights,
      ) async {

    final blur = 2.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0,0, rect.width * scale, rect.height * scale));
    canvas.translate(-rect.left * scale, -rect.top * scale);

    //print(tileStrokes.length);

    drawStrokes2AfterIsolate(canvas, tileStrokes, scale, blur, sameWidths, lefts, rights);

    final picture = recorder.endRecording();

    final newImage = await picture.toImage((rect.width*scale).toInt(), (rect.height*scale).toInt());
    image = newImage;

    scale = 4.0;     //scale = 200 is way too high, at most 50
    final backgroundRecorder = ui.PictureRecorder();
    final backgroundCanvas = Canvas(backgroundRecorder, Rect.fromLTWH(0,0, rect.width * scale, rect.height * scale));
    backgroundCanvas.translate(-rect.left * scale, -rect.top * scale);
    drawStrokes2AfterIsolate(backgroundCanvas, tileBackgroundStrokes, scale, blur, backgroundSameWidths, backgroundLefts, backgroundRights);
    final backgroundPicture = backgroundRecorder.endRecording();
    final newBackgroundImage = await backgroundPicture.toImage((rect.width*scale).toInt(), (rect.height*scale).toInt());
    backgroundImage = newBackgroundImage;




  }

}