import 'dart:ui';

import 'package:betternotes/core/utils/draw_strokes.dart';
import 'package:flutter/material.dart';

import 'package:flutter/cupertino.dart';

import 'package:betternotes/features/editor/models/page/stroke.dart';
import 'package:betternotes/features/editor/models/page/point.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:core';

import '../../../core/providers/global_providers.dart';
import '../models/page/image_model.dart';
import '../models/page/page_model.dart';
import '../models/page/tile2.dart';





class DrawerWidget extends ConsumerStatefulWidget {
  final int pageID;
  final int docID;
  final List<Stroke> activeStrokes;
  final List<Stroke> erasedStrokes;
  final List<Stroke> laserStrokes;


  const DrawerWidget({
    Key? key,
    required this.pageID,
    required this.docID,
    required this.activeStrokes,
    required this.erasedStrokes,
    required this.laserStrokes,

  }) : super(key: key);


  @override
  ConsumerState<ConsumerStatefulWidget> createState() => DrawerWidgetState();
}


class DrawerWidgetState extends ConsumerState<DrawerWidget> {

  late final docID = widget.docID;
  late final pageID = widget.pageID;

  late final debugMode = ref.read(settingsProvider).debugMode;



  bool erased = false;
  bool active = false;
  //List<int> erasedStrokeIDs = [];
  List<Stroke> oldErasedStrokes = [];
  List<Stroke> oldActiveStrokes = [];



  //late final tiles = Tiles(ref, pageID, docID);



  @override
  Widget build(BuildContext context) {

  //print("drawer_widget: drawing");


    //final List<Stroke> activeStrokes = [];
    final activeStrokes = widget.activeStrokes;


    final erasedStrokes = widget.erasedStrokes;
    final laserStrokes = widget.laserStrokes;

    final page = ref.watch(
      documentsProvider.select((docs) {
        final doc = docs.where((d) => d.docID == docID);
        if (doc.isEmpty) return null;

        final pages = doc.first.pages.where((p) => p.pageID == pageID);
        if (pages.isEmpty) return null;

        return pages.first;
      }),
    );

    if (page == null) {
      return const SizedBox();
    }



    //List<int> erasedStrokeIDs = page.erasedIDs;

    if(erasedStrokes.isNotEmpty) {
      //erasedStrokeIDs = erasedStrokes.map((s) => s.strokeID).toList();
      oldErasedStrokes = erasedStrokes;
      erased = true;
    }
    if(erasedStrokes.isEmpty && !erased) {
      oldErasedStrokes = [];
      //print("cleared");
    }

    if(erasedStrokes.isEmpty) {
      erased = false;
      //print("setfalse");
    }



    if(activeStrokes.isNotEmpty) {
      //erasedStrokeIDs = erasedStrokes.map((s) => s.strokeID).toList();
      oldActiveStrokes = activeStrokes;
      active = true;
    }
    if(activeStrokes.isEmpty && !active) {
      oldActiveStrokes = [];
    }

    if(activeStrokes.isEmpty) {
      active = false;
      //print("setfalse");
    }




    //print(erasedStrokes.length);
    //print(oldErasedStrokes.length);
    //print(erased);

      final tiles = page.tiles;


    return ClipRect(
      child: CustomPaint(
        size: Size(page.pageWidth, page.pageHeight),
        painter: ActivePainter(
          tiles: tiles,
          activeStrokes: oldActiveStrokes,
          erasedStrokes: erasedStrokes,
          page: page,
          images: page.images,
          debugMode: debugMode,
          laserStrokes: laserStrokes,
          backgroundImage: page.backgroundImage,
        ),
      ),
    );

  }

}


class ActivePainter extends CustomPainter {
  final List<List<Tile>> tiles;
  final List<Stroke> erasedStrokes;
  //final List<int> erasedStrokeIDs;
  final List<Stroke> activeStrokes;
  final PageModel page;
  final List<ImageModel> images;
  final ImageModel? backgroundImage;
  final bool debugMode;
  //final List<ui.Image> images;
  final List<Stroke> laserStrokes;

  ActivePainter({required this.tiles, //required this.erasedStrokes,
    required this.activeStrokes, required this.page, required this.images, required this.debugMode, required this.erasedStrokes, required this.laserStrokes, required this.backgroundImage //required this.erasedStrokeIDs
  }) //: super(repaint: tiles)

  ;

  @override
  void paint(Canvas canvas, Size size) {

    var drawnStrokesIDs = <int>[];

    //print("draw");


    final erasedStrokeIDs = erasedStrokes.map((s) => s.strokeID).toList();

    for (int row = 0; row < tiles.length; row++) {
      for (int col = 0; col < tiles[0].length; col++) {
        final tile = tiles[row][col];

        if (tile.backgroundImage != null) {
          canvas.drawImageRect(
            tile.backgroundImage!,
            Rect.fromLTWH(
              0,
              0,
              tile.backgroundImage!.width.toDouble(),
              tile.backgroundImage!.height.toDouble(),
            ),
            tile.rect,
            Paint()..filterQuality = FilterQuality.high,
          );
        }


        for (int i = 0; i<erasedStrokes.length; i++) {
          if (tile.checkIfStrokeInRect(erasedStrokes[i])) {                     //check if this tile is affected by erasing
            canvas.drawRect(tile.rect, Paint()..color = page.pageColor);
            if (tile.backgroundImage != null) {
              canvas.drawImageRect(
                tile.backgroundImage!,
                Rect.fromLTWH(0, 0, tile.backgroundImage!.width.toDouble(), tile.backgroundImage!.height.toDouble()),
                tile.rect,
                  Paint()..filterQuality = FilterQuality.high,
              );
            } //else canvas.drawRect(tile.rect, Paint()..color = page.pageColor);
            break;
          }
        }




      }
    }


    Paint paint = Paint();

    final background = backgroundImage?.image;
    if (backgroundImage != null && background != null) {

      final src = Rect.fromLTWH(0, 0, background.width.toDouble(), background.height.toDouble(),);
      Rect dst = Rect.fromPoints(backgroundImage!.position, backgroundImage!.position + Offset(backgroundImage!.width, backgroundImage!.height),);
      final center = dst.center;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(backgroundImage!.rotation);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawImageRect(background, src, dst, paint);
      canvas.restore();
    }

    for(final image in images){
      //final image = images.first;
      Rect src = Rect.fromLTWH(0, 0, image.image.width.toDouble(), image.image.height.toDouble(),);
      Rect dst = Rect.fromPoints(image.position, image.position + Offset(image.width, image.height),);
      final center = dst.center;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(image.rotation);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawImageRect(image.image, src, dst, paint);
      canvas.restore();
    }





    for (int row = 0; row < tiles.length; row++) {
      for (int col = 0; col < tiles[0].length; col++) {
        final tile = tiles[row][col];

        bool drawTile = true;


        //else canvas.drawRect(tile.rect, Paint()..color = page.pageColor);


        for (int i = 0; i<erasedStrokes.length; i++) {
          if (tile.checkIfStrokeInRect(erasedStrokes[i])) {                     //check if this tile is affected by erasing
            //canvas.drawRect(tile.rect, Paint()..color = page.pageColor);

            if (debugMode) canvas.drawRect(tile.rect, Paint()..color = Colors.red.withOpacity(0.4));

            for (final abs in tile.aStrokes) {          //add the other strokes that the tile touches to the active strokes, but not the ones being erased
              if (erasedStrokeIDs.any((s) => s == abs.strokeID)) continue;
              if (!drawnStrokesIDs.contains(abs.strokeID)) {
                drawnStrokesIDs.add(abs.strokeID);
              }
            }
            drawTile = false;
            break;
          }
        }
        if (tile.image != null && drawTile) {
          canvas.drawImageRect(
            tile.image!,
            Rect.fromLTWH(0, 0, tile.image!.width.toDouble(),
                tile.image!.height.toDouble()),
            tile.rect,
            Paint()..filterQuality = FilterQuality.high

          );
        }

        if(debugMode) {
          final border = Paint()..color = Colors.purpleAccent..style = PaintingStyle.stroke..strokeWidth = 0.3;
          canvas.drawRect(tile.rect, border);
        }




      }
    }


    final idSet = drawnStrokesIDs.toSet();


    List<Stroke> strokes = page.strokes.where((s) => idSet.contains(s.strokeID)).toList();
    //tiles.vektorStrokes.addAll(activeStrokes);
    //strokes = tiles.vektorStrokes;
    strokes.addAll(activeStrokes);
    //print("activestrokes: $strokes");

    //List<Stroke> strokes =activeStrokes;
    //print(strokes.length);

    //strokes.addAll(tiles.vektorStrokes);


    drawStrokes2(canvas, strokes, 1, 0);


    if (laserStrokes.isNotEmpty) {

      List<Stroke> laserCores = [];
      for (int i = 0; i<laserStrokes.length; i++) {
        List<PointModel> points= [];
        for (int j= 0; j<laserStrokes[i].points.length; j++){
          points.add(PointModel(pos: laserStrokes[i].points[j].pos, width: laserStrokes[i].points[j].width/2));
        }
        laserCores.add(Stroke(color: Colors.white.withAlpha(laserStrokes[i].color.alpha), width: -1, points: points));
      }

      //laserCores.addAll(laserStrokes);

      drawStrokes2(canvas, laserStrokes, 1, 0);
      drawStrokes2(canvas, laserCores, 1, 0);

    }



  }


  @override
  bool shouldRepaint(covariant ActivePainter oldDelegate) {
    //return oldDelegate.tiles != tiles || oldDelegate.activeStrokes != activeStrokes || oldDelegate.images != images;
    return false;
  }
}

