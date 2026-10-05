import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:betternotes/features/editor/models/page/abstract_stroke.dart';

import '../../../features/editor/models/page/page_model.dart';
import '../../../features/editor/models/page/stroke.dart';
import '../../../features/editor/models/page/tile2.dart';


Future<({
  List<List<Tile>> tiles,
  List<List<List<List<Offset>>>> rights,
  List<List<List<List<Offset>>>> lefts,
  List<List<List<Stroke>>> tileStrokes,
  List<List<List<bool>>> sameWidths,
  List<List<List<List<Offset>>>> backgroundRights,
  List<List<List<List<Offset>>>> backgroundLefts,
  List<List<List<Stroke>>> backgroundTileStrokes,
  List<List<List<bool>>> backgroundSameWidths
})>  preCalcTiles(double pageHeight, double pageWidth, List<Stroke> strokes, List<Stroke> backgroundStrokes, Rect rect, double scale) async {

  final result = await Isolate.run(() {

    final newTiles = <List<Tile>>[];

    final rows = (pageHeight / rect.height).ceil();
    final cols = (pageWidth / rect.width).ceil();

    for (int row = 0; row < rows; row++) {
      final rowTiles = <Tile>[];

      for (int col = 0; col < cols; col++) {
        final tile = Tile(Rect.fromLTWH(
          col * rect.width, row * rect.height, rect.width, rect.height,));

        tile.addBackgroundStrokesAsAbstractStrokes(backgroundStrokes);
        tile.addStrokesAsAbstractStrokes(strokes);

        rowTiles.add(tile); // ❗ FIXED (du hattest doppeltes Tile-Building)
      }
      newTiles.add(rowTiles);
    }

    final result = preCalcPaths(strokes, backgroundStrokes, newTiles, scale);

    return (
      tiles: newTiles,
      rights: result.rights,
      lefts: result.lefts,
      tileStrokes: result.tileStrokes,
      sameWidths: result.sameWidths,
      backgroundRights: result.backgroundRights,
      backgroundLefts: result.backgroundLefts,
      backgroundTileStrokes: result.backgroundTileStrokes,
      backgroundSameWidths: result.backgroundSameWidths,
    );

  });

  return result;
}



({
  List<List<List<List<Offset>>>> rights,
  List<List<List<List<Offset>>>> lefts,
  List<List<List<Stroke>>> tileStrokes,
  List<List<List<bool>>> sameWidths,
  List<List<List<List<Offset>>>> backgroundRights,
  List<List<List<List<Offset>>>> backgroundLefts,
  List<List<List<Stroke>>> backgroundTileStrokes,
  List<List<List<bool>>> backgroundSameWidths
}) preCalcPaths(List<Stroke> strokes, List<Stroke> backgroundStrokes, List<List<Tile>> tiles, double scale) {


  List<List<List<Stroke>>> tileStrokes = [];
  List<List<List<bool>>> sameWidths = [];
  List<List<List<List<Offset>>>> rights = [];
  List<List<List<List<Offset>>>> lefts = [];
  List<List<List<Stroke>>> backgroundTileStrokes = [];
  List<List<List<bool>>> backgroundSameWidths = [];
  List<List<List<List<Offset>>>> backgroundRights = [];
  List<List<List<List<Offset>>>> backgroundLefts = [];



  for (int row = 0; row < tiles.length; row++) {

    List<List<Stroke>> rowTileStrokes = [];
    List<List<bool>> rowSameWidths = [];
    List<List<List<Offset>>> rowRights = [];
    List<List<List<Offset>>> rowLefts = [];
    List<List<Stroke>> rowBackgroundTileStrokes = [];
    List<List<bool>> rowBackgroundSameWidths = [];
    List<List<List<Offset>>> rowBackgroundRights = [];
    List<List<List<Offset>>> rowBackgroundLefts = [];

    for (int col = 0; col < tiles[0].length; col++) {

      final strokeMap = {for (var s in strokes) s.strokeID: s,};

      List<Stroke> tileTileStrokes = [];
      List<bool> tileSameWidths = [];
      List<List<Offset>> tileRights = [];
      List<List<Offset>> tileLefts = [];
      List<Stroke> tileBackgroundTileStrokes = [];
      List<bool> tileBackgroundSameWidths = [];
      List<List<Offset>> tileBackgroundRights = [];
      List<List<Offset>> tileBackgroundLefts = [];

      final aStrokes = tiles[row][col].aStrokes;
      for (int i=0; i<aStrokes.length; i++) {

        final stroke = strokeMap[aStrokes[i].strokeID];
        if (stroke == null) continue;


        Color color = stroke.color;
        double width = stroke.width;

        tileTileStrokes.add(Stroke(color : color, width: width, points: []));

        aStrokes[i].pointIndexes.forEach((j) {
          tileTileStrokes[i].points.add(stroke.points[j]);
        });

        final sameWidth = tileTileStrokes[i].points.every((p) => p.width == tileTileStrokes[i].points.first.width);


        final left = <Offset>[];
        final right = <Offset>[];

        if (sameWidth) {
          for (int j = 0; j < tileTileStrokes[i].points.length - 1; j++) {
            final p0 = tileTileStrokes[i].points[j].pos * scale;
            final p1 = tileTileStrokes[i].points[j + 1].pos * scale;
            final w0 = tileTileStrokes[i].points[j].width * scale;
            final w1 = tileTileStrokes[i].points[j + 1].width * scale;
            final dir = p1 - p0;
            final distance = dir.distance;
            final normal = distance < 0.01 ? const Offset(0, 1) : Offset(-dir.dy, dir.dx) / distance;

            left.add(p0 + normal * w0 / 2);
            right.add(p0 - normal * w0 / 2);

            if (j == tileTileStrokes[i].points.length - 2) {
              left.add(p1 + normal * w1 / 2);
              right.add(p1 - normal * w1 / 2);
            }
          }

        }

        tileRights.add(right);
        tileLefts.add(left);
        tileSameWidths.add(sameWidth);

      }


      final backgroundStrokeMap = {for (var s in backgroundStrokes) s.strokeID: s,};

      final aBackgroundStrokes = tiles[row][col].aBackgroundStrokes;
      for (int i=0; i<aBackgroundStrokes.length; i++) {


        final backgroundStroke = backgroundStrokeMap[aBackgroundStrokes[i].strokeID];
        if (backgroundStroke == null) continue;
        //print("hi");

        Color color = backgroundStroke.color;
        double width = backgroundStroke.width;

        tileBackgroundTileStrokes.add(Stroke(color : color, width: width, points: []));

        aBackgroundStrokes[i].pointIndexes.forEach((j) {
          tileBackgroundTileStrokes[i].points.add(backgroundStroke.points[j]);
        });

        final sameWidth = tileBackgroundTileStrokes[i].points.every((p) => p.width == tileBackgroundTileStrokes[i].points.first.width);


        final left = <Offset>[];
        final right = <Offset>[];

        if (sameWidth) {
          for (int j = 0; j < tileBackgroundTileStrokes[i].points.length - 1; j++) {
            final p0 = tileBackgroundTileStrokes[i].points[j].pos * scale;
            final p1 = tileBackgroundTileStrokes[i].points[j + 1].pos * scale;
            final w0 = tileBackgroundTileStrokes[i].points[j].width * scale;
            final w1 = tileBackgroundTileStrokes[i].points[j + 1].width * scale;
            final dir = p1 - p0;
            final distance = dir.distance;
            final normal = distance < 0.01 ? const Offset(0, 1) : Offset(-dir.dy, dir.dx) / distance;

            left.add(p0 + normal * w0 / 2);
            right.add(p0 - normal * w0 / 2);

            if (j == tileBackgroundTileStrokes[i].points.length - 2) {
              left.add(p1 + normal * w1 / 2);
              right.add(p1 - normal * w1 / 2);
            }
          }

        }

        tileBackgroundRights.add(right);
        tileBackgroundLefts.add(left);
        tileBackgroundSameWidths.add(sameWidth);
      }

      rowTileStrokes.add(tileTileStrokes);
      rowLefts.add(tileLefts);
      rowRights.add(tileRights);
      rowSameWidths.add(tileSameWidths);

      rowBackgroundTileStrokes.add(tileBackgroundTileStrokes);
      rowBackgroundLefts.add(tileBackgroundLefts);
      rowBackgroundRights.add(tileBackgroundRights);
      rowBackgroundSameWidths.add(tileBackgroundSameWidths);

      //print(rowBackgroundTileStrokes[0].length);
    }

    tileStrokes.add(rowTileStrokes);
    lefts.add(rowLefts);
    rights.add(rowRights);
    sameWidths.add(rowSameWidths);

    backgroundTileStrokes.add(rowBackgroundTileStrokes);
    backgroundLefts.add(rowBackgroundLefts);
    backgroundRights.add(rowBackgroundRights);
    backgroundSameWidths.add(rowBackgroundSameWidths);

  }

  //print(backgroundTileStrokes[0][0].length);




  return (
  rights: rights,
  lefts: lefts,
  tileStrokes: tileStrokes,
  sameWidths: sameWidths,
  backgroundRights: backgroundRights,
  backgroundLefts: backgroundLefts,
  backgroundTileStrokes: backgroundTileStrokes,
  backgroundSameWidths: backgroundSameWidths,
  );

}




({
List<List<Tile>> tiles,
List<List<List<List<Offset>>>> rights,
List<List<List<List<Offset>>>> lefts,
List<List<List<Stroke>>> tileStrokes,
List<List<List<bool>>> sameWidths,
List<List<List<List<Offset>>>> backgroundRights,
List<List<List<List<Offset>>>> backgroundLefts,
List<List<List<Stroke>>> backgroundTileStrokes,
List<List<List<bool>>> backgroundSameWidths
}) preCalculation(double pageHeight, double pageWidth, Rect rect, List<Stroke> strokes, List<Stroke> backgroundStrokes, double scale, {required bool Function() cancelledChecker,}) {


  bool canceled = false;


  final tiles = <List<Tile>>[];

  final rows = (pageHeight / rect.height).ceil();
  final cols = (pageWidth / rect.width).ceil();

  for (int row = 0; row < rows; row++) {
    final rowTiles = <Tile>[];

    for (int col = 0; col < cols; col++) {


      final tile = Tile(Rect.fromLTWH(
        col * rect.width, row * rect.height, rect.width, rect.height,));

      tile.addBackgroundStrokesAsAbstractStrokes(backgroundStrokes);
      tile.addStrokesAsAbstractStrokes(strokes);

      rowTiles.add(tile); // ❗ FIXED (du hattest doppeltes Tile-Building)
    }
    tiles.add(rowTiles);
  }






  List<List<List<Stroke>>> tileStrokes = [];
  List<List<List<bool>>> sameWidths = [];
  List<List<List<List<Offset>>>> rights = [];
  List<List<List<List<Offset>>>> lefts = [];
  List<List<List<Stroke>>> backgroundTileStrokes = [];
  List<List<List<bool>>> backgroundSameWidths = [];
  List<List<List<List<Offset>>>> backgroundRights = [];
  List<List<List<List<Offset>>>> backgroundLefts = [];



  for (int row = 0; row < tiles.length; row++) {

    List<List<Stroke>> rowTileStrokes = [];
    List<List<bool>> rowSameWidths = [];
    List<List<List<Offset>>> rowRights = [];
    List<List<List<Offset>>> rowLefts = [];
    List<List<Stroke>> rowBackgroundTileStrokes = [];
    List<List<bool>> rowBackgroundSameWidths = [];
    List<List<List<Offset>>> rowBackgroundRights = [];
    List<List<List<Offset>>> rowBackgroundLefts = [];

    for (int col = 0; col < tiles[0].length; col++) {

      final strokeMap = {for (var s in strokes) s.strokeID: s,};

      List<Stroke> tileTileStrokes = [];
      List<bool> tileSameWidths = [];
      List<List<Offset>> tileRights = [];
      List<List<Offset>> tileLefts = [];
      List<Stroke> tileBackgroundTileStrokes = [];
      List<bool> tileBackgroundSameWidths = [];
      List<List<Offset>> tileBackgroundRights = [];
      List<List<Offset>> tileBackgroundLefts = [];

      final aStrokes = tiles[row][col].aStrokes;
      for (int i=0; i<aStrokes.length; i++) {

        final stroke = strokeMap[aStrokes[i].strokeID];
        if (stroke == null) continue;


        Color color = stroke.color;
        double width = stroke.width;

        tileTileStrokes.add(Stroke(color : color, width: width, points: []));


        if (0<=aStrokes[i].pointIndexes.first-1) tileTileStrokes[i].points.add(stroke.points[aStrokes[i].pointIndexes.first-1]);
        aStrokes[i].pointIndexes.forEach((j) {
          tileTileStrokes[i].points.add(stroke.points[j]);
        });

        if (stroke.points.length>aStrokes[i].pointIndexes.last+1) tileTileStrokes[i].points.add(stroke.points[aStrokes[i].pointIndexes.last+1]);

        final sameWidth = tileTileStrokes[i].points.every((p) => p.width == tileTileStrokes[i].points.first.width);


        final left = <Offset>[];
        final right = <Offset>[];

        if (!sameWidth) {
          for (int j = 0; j < tileTileStrokes[i].points.length - 1; j++) {
            final p0 = tileTileStrokes[i].points[j].pos * scale;
            final p1 = tileTileStrokes[i].points[j + 1].pos * scale;
            final w0 = tileTileStrokes[i].points[j].width * scale;
            final w1 = tileTileStrokes[i].points[j + 1].width * scale;
            final dir = p1 - p0;
            final distance = dir.distance;
            final normal = distance < 0.01 ? const Offset(0, 1) : Offset(-dir.dy, dir.dx) / distance;

            left.add(p0 + normal * w0 / 2);
            right.add(p0 - normal * w0 / 2);

            if (j == tileTileStrokes[i].points.length - 2) {
              left.add(p1 + normal * w1 / 2);
              right.add(p1 - normal * w1 / 2);
            }
          }

        }

        tileRights.add(right);
        tileLefts.add(left);
        tileSameWidths.add(sameWidth);

      }


      final backgroundStrokeMap = {for (var s in backgroundStrokes) s.strokeID: s,};

      final aBackgroundStrokes = tiles[row][col].aBackgroundStrokes;
      for (int i=0; i<aBackgroundStrokes.length; i++) {


        final backgroundStroke = backgroundStrokeMap[aBackgroundStrokes[i].strokeID];
        if (backgroundStroke == null) continue;
        //print("hi");

        Color color = backgroundStroke.color;
        double width = backgroundStroke.width;

        tileBackgroundTileStrokes.add(Stroke(color : color, width: width, points: []));

        aBackgroundStrokes[i].pointIndexes.forEach((j) {
          tileBackgroundTileStrokes[i].points.add(backgroundStroke.points[j]);
        });

        final sameWidth = tileBackgroundTileStrokes[i].points.every((p) => p.width == tileBackgroundTileStrokes[i].points.first.width);


        final left = <Offset>[];
        final right = <Offset>[];

        if (!sameWidth) {
          for (int j = 0; j < tileBackgroundTileStrokes[i].points.length - 1; j++) {
            final p0 = tileBackgroundTileStrokes[i].points[j].pos * scale;
            final p1 = tileBackgroundTileStrokes[i].points[j + 1].pos * scale;
            final w0 = tileBackgroundTileStrokes[i].points[j].width * scale;
            final w1 = tileBackgroundTileStrokes[i].points[j + 1].width * scale;
            final dir = p1 - p0;
            final distance = dir.distance;
            final normal = distance < 0.01 ? const Offset(0, 1) : Offset(-dir.dy, dir.dx) / distance;

            left.add(p0 + normal * w0 / 2);
            right.add(p0 - normal * w0 / 2);

            if (j == tileBackgroundTileStrokes[i].points.length - 2) {
              left.add(p1 + normal * w1 / 2);
              right.add(p1 - normal * w1 / 2);
            }
          }

        }

        tileBackgroundRights.add(right);
        tileBackgroundLefts.add(left);
        tileBackgroundSameWidths.add(sameWidth);
      }

      rowTileStrokes.add(tileTileStrokes);
      rowLefts.add(tileLefts);
      rowRights.add(tileRights);
      rowSameWidths.add(tileSameWidths);

      rowBackgroundTileStrokes.add(tileBackgroundTileStrokes);
      rowBackgroundLefts.add(tileBackgroundLefts);
      rowBackgroundRights.add(tileBackgroundRights);
      rowBackgroundSameWidths.add(tileBackgroundSameWidths);

      //print(rowBackgroundTileStrokes[0].length);
    }

    tileStrokes.add(rowTileStrokes);
    lefts.add(rowLefts);
    rights.add(rowRights);
    sameWidths.add(rowSameWidths);

    backgroundTileStrokes.add(rowBackgroundTileStrokes);
    backgroundLefts.add(rowBackgroundLefts);
    backgroundRights.add(rowBackgroundRights);
    backgroundSameWidths.add(rowBackgroundSameWidths);

  }

  //print(backgroundTileStrokes[0][0].length);


  return (
  tiles: tiles,
  rights: rights,
  lefts: lefts,
  tileStrokes: tileStrokes,
  sameWidths: sameWidths,
  backgroundRights: backgroundRights,
  backgroundLefts: backgroundLefts,
  backgroundTileStrokes: backgroundTileStrokes,
  backgroundSameWidths: backgroundSameWidths,
  );

}



({
Tile tile,
List<List<Offset>> rights,
List<List<Offset>> lefts,
List<Stroke> tileStrokes,
List<bool> sameWidths,
List<List<Offset>> backgroundRights,
List<List<Offset>> backgroundLefts,
List<Stroke> backgroundTileStrokes,
List<bool> backgroundSameWidths
}) preCalculateSingleTile(Tile tile, List<Stroke> strokes, List<Stroke> backgroundStrokes, double scale) {


  tile.addBackgroundStrokesAsAbstractStrokes(backgroundStrokes);
  tile.addStrokesAsAbstractStrokes(strokes);

  final strokeMap = {for (var s in strokes) s.strokeID: s,};

  List<Stroke> tileTileStrokes = [];
  List<bool> tileSameWidths = [];
  List<List<Offset>> tileRights = [];
  List<List<Offset>> tileLefts = [];
  List<Stroke> tileBackgroundTileStrokes = [];
  List<bool> tileBackgroundSameWidths = [];
  List<List<Offset>> tileBackgroundRights = [];
  List<List<Offset>> tileBackgroundLefts = [];

  final aStrokes = tile.aStrokes;
  for (int i=0; i<aStrokes.length; i++) {

    final stroke = strokeMap[aStrokes[i].strokeID];
    if (stroke == null) continue;


    Color color = stroke.color;
    double width = stroke.width;

    tileTileStrokes.add(Stroke(color : color, width: width, points: []));


    if (0<=aStrokes[i].pointIndexes.first-1) tileTileStrokes[i].points.add(stroke.points[aStrokes[i].pointIndexes.first-1]);
    aStrokes[i].pointIndexes.forEach((j) {
      tileTileStrokes[i].points.add(stroke.points[j]);
    });

    if (stroke.points.length>aStrokes[i].pointIndexes.last+1) tileTileStrokes[i].points.add(stroke.points[aStrokes[i].pointIndexes.last+1]);

    final sameWidth = tileTileStrokes[i].points.every((p) => p.width == tileTileStrokes[i].points.first.width);


    final left = <Offset>[];
    final right = <Offset>[];

    if (!sameWidth) {
      for (int j = 0; j < tileTileStrokes[i].points.length - 1; j++) {
        final p0 = tileTileStrokes[i].points[j].pos * scale;
        final p1 = tileTileStrokes[i].points[j + 1].pos * scale;
        final w0 = tileTileStrokes[i].points[j].width * scale;
        final w1 = tileTileStrokes[i].points[j + 1].width * scale;
        final dir = p1 - p0;
        final distance = dir.distance;
        final normal = distance < 0.01 ? const Offset(0, 1) : Offset(-dir.dy, dir.dx) / distance;

        left.add(p0 + normal * w0 / 2);
        right.add(p0 - normal * w0 / 2);

        if (j == tileTileStrokes[i].points.length - 2) {
          left.add(p1 + normal * w1 / 2);
          right.add(p1 - normal * w1 / 2);
        }
      }

    }

    tileRights.add(right);
    tileLefts.add(left);
    tileSameWidths.add(sameWidth);

  }


  final backgroundStrokeMap = {for (var s in backgroundStrokes) s.strokeID: s,};

  final aBackgroundStrokes = tile.aBackgroundStrokes;
  for (int i=0; i<aBackgroundStrokes.length; i++) {


    final backgroundStroke = backgroundStrokeMap[aBackgroundStrokes[i].strokeID];
    if (backgroundStroke == null) continue;
    //print("hi");

    Color color = backgroundStroke.color;
    double width = backgroundStroke.width;

    tileBackgroundTileStrokes.add(Stroke(color : color, width: width, points: []));

    aBackgroundStrokes[i].pointIndexes.forEach((j) {
      tileBackgroundTileStrokes[i].points.add(backgroundStroke.points[j]);
    });

    final sameWidth = tileBackgroundTileStrokes[i].points.every((p) => p.width == tileBackgroundTileStrokes[i].points.first.width);


    final left = <Offset>[];
    final right = <Offset>[];

    if (!sameWidth) {
      for (int j = 0; j < tileBackgroundTileStrokes[i].points.length - 1; j++) {
        final p0 = tileBackgroundTileStrokes[i].points[j].pos * scale;
        final p1 = tileBackgroundTileStrokes[i].points[j + 1].pos * scale;
        final w0 = tileBackgroundTileStrokes[i].points[j].width * scale;
        final w1 = tileBackgroundTileStrokes[i].points[j + 1].width * scale;
        final dir = p1 - p0;
        final distance = dir.distance;
        final normal = distance < 0.01 ? const Offset(0, 1) : Offset(-dir.dy, dir.dx) / distance;

        left.add(p0 + normal * w0 / 2);
        right.add(p0 - normal * w0 / 2);

        if (j == tileBackgroundTileStrokes[i].points.length - 2) {
          left.add(p1 + normal * w1 / 2);
          right.add(p1 - normal * w1 / 2);
        }
      }

    }

    tileBackgroundRights.add(right);
    tileBackgroundLefts.add(left);
    tileBackgroundSameWidths.add(sameWidth);
  }

  //print(backgroundTileStrokes[0][0].length);


  return (
  tile: tile,
  rights: tileRights,
  lefts: tileLefts,
  tileStrokes: tileTileStrokes,
  sameWidths: tileSameWidths,
  backgroundRights: tileBackgroundRights,
  backgroundLefts: tileBackgroundLefts,
  backgroundTileStrokes: tileBackgroundTileStrokes,
  backgroundSameWidths: tileBackgroundSameWidths,
  );

}



