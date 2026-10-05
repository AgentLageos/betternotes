import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:betternotes/features/editor/components/drawer_widget.dart';
import 'package:betternotes/features/editor/models/tools/eraser_tool.dart';
import 'package:betternotes/features/editor/models/tools/laser_tool.dart';
import 'package:betternotes/features/editor/models/tools/selection_tool.dart';
import 'package:betternotes/features/editor/models/tools/shape_tool.dart';
import 'package:betternotes/features/editor/models/tools/pen_tool.dart';
import 'package:betternotes/features/editor/models/tools/tool.dart';
import 'package:betternotes/features/editor/models/page/image_model.dart';

import 'package:betternotes/features/editor/models/page/stroke.dart';
import 'package:betternotes/features/editor/models/page/point.dart';
import 'package:betternotes/core/providers/global_providers.dart';
import 'package:betternotes/features/editor/components/selection_drawer.dart';

import '../models/tools/line_tool.dart';





class PageWidget extends ConsumerStatefulWidget {
  int pageIndex = 0;
  final int pageID;





  //final GlobalKey<PageWidgetState> pageKey;

  PageWidget({
    super.key,
    required this.pageIndex,
    required this.pageID,

  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => PageWidgetState();
}

class PageWidgetState extends ConsumerState<PageWidget> {


  bool newStroke = true;

  double pageHeight=297;
  double pageWidth=210;

  Set<int> activePointers = {};



  //int selectedTool=0;


  double eraseRadius = 10.0;      //size of the eraser
  Offset? _eraserPosition;        //position of eraser
  Offset? _currentPosition;        //position of eraser

  final GlobalKey _canvasKey = GlobalKey();                                     //detecting if user writes out of bounds

  bool penUsed = false;

  //List<Stroke> erasedStrokes = [];                                              //stores all the strokes that get removed by the eraser in one move. needed for undo/redo
  bool eraserUsed = false;                                                      //used for undo, preventing adding command when eraser instead of pen was used

  int pageIndex = 0;

  late final pageID;

  double variableWidth = 0.5;

  List<Stroke> activeStrokes = [];
  List<Stroke> erasedStrokes = [];

  late double lastPressure;



  //late Tile tile;

  Rect rect = Rect.fromLTWH(0, 0, 53, 50);
  //late Tiles tiles;


  List<Stroke> selectionStrokes = [];           //used for displaying and calculation the selection area
  List<Stroke> laserStrokes = [];           //used for displaying the laserpointer
  Map<Stroke, Timer> laserTimers = {};
  bool selectionActive = false;
  int selectionOperation = -1;
  Offset oldPosition = Offset(0,0);

  List<ImageModel> activeImages = [];

  List<ImageModel> erasedImages = [];

  final int docID = 0;

  final int docIndex=0;
  final int editorIndex = 0;



//storing initial states of elements that are modified by selection, needed undo/redo with SelectionOperationCommand
  List<Stroke> rememberActiveStrokes = [];
  List<ImageModel> rememberActiveImages = [];



  late final settings = ref.read(settingsProvider);













  @override
  void initState() {

    super.initState();
    pageIndex = widget.pageIndex;
    pageID = widget.pageID;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      //ref.read(documentsProvider.notifier).initializeAllPageTiles(docID);
    });

  }

  @override
  void dispose() {
    activeStrokes.clear();
    //erasedStrokes.clear();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    //print("PageWidget build triggered. Reason: ${context.owner?.debugBuilding}");
    //debugPrintStack(maxFrames: 10);

    final docs = ref.watch(documentsProvider);



    final setup =ref.read(editorSetupProvider.select((setup) => setup[editorIndex]));
    //final Tool selectedTool = EraserTool();

    Tool selectedTool = ref.read(editorSetupProvider)[editorIndex].tools[setup.toolIndex];
    final selectionColor = setup.selectionColor;
    //final selectionColor = Colors.black;


    if (docIndex < 0 || docIndex >= docs.length) {
      return const SizedBox();

    }
    final doc = docs[docIndex];

    if (doc.pages.isEmpty) {
      return const SizedBox();
    }


    final page = docs[docIndex].pages.firstWhere((p) => p.pageID == pageID);
    pageIndex = doc.pageList.indexWhere((p) => p == pageID);




    double pageHeight = page.pageHeight;
    double pageWidth = page.pageWidth;


    return
      Center(
        child: Stack(
          children: [


            Container(
              key: _canvasKey,
              height: pageHeight,
              width: pageWidth,
              decoration: BoxDecoration(
                color: page.pageColor,
                boxShadow: [BoxShadow(color: Colors.grey.shade700, blurRadius: 4)],
              ),


            ),
            if (settings.debugMode && ref.read(documentsProvider)
              [docIndex].pages.firstWhere((p) => p.pageID == page.pageID) == page.pageID

            ) Container(
              height: pageHeight,
              width: pageWidth,
              decoration: BoxDecoration(
                //color: Colors.red.withAlpha(64),
                border: Border.all(
                  color: Colors.red,
                  width: 2,
                ),
              ),
            ),


            Listener(
                onPointerDown: (event) {
                  if(selectionActive){
                    handleSelectionStart(event, selectedTool);
                    return;
                  }

                  activePointers.add(event.pointer);
                  //print(activePointers);
                  _pointerMove(event, activePointers.length);
                },
                onPointerMove: (event) {_pointerMove(event, activePointers.length);},
                onPointerUp: _pointerUp,
                behavior: HitTestBehavior.opaque,

                child: Stack(
                    children: [
                      DrawerWidget(pageID: pageID, docID: docID, activeStrokes: activeStrokes, erasedStrokes: erasedStrokes, laserStrokes: laserStrokes,),
                      //ActiveDrawer(pageWidth: pageWidth, pageHeight: pageHeight, tiles: tiles, activeStrokes: activeStrokes, page: page, images: page.images),          //drawing currently active strokes, drawing images, manages smooth erasing behavior
                      //VVV  displaying selection outline and selection menu   VVV
                      SelectionDrawer(width: pageWidth, height: pageHeight, selectionStrokes: selectionStrokes, selectionActive: selectionActive, selectionOperation: selectionOperation, selectionColor: selectionColor, deleteSelection: () { deleteSelection(); }, copySelection: () { copySelection();}, colorSelection: () { colorSelection(ref); },),
                      if (settings.debugMode) Positioned(right: 16, bottom: 16, child: Text("${pageID}    ${pageIndex + 1}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700),),)       //displaying pagenumber and pageid, NEEDS TO BE HERE SO STYLUS IS RECOGNIZED OVER TEXT AND DOESNT GET OVERLAYED WHILE ERASING
                      else Positioned(right: 16, bottom: 16, child: Text("${pageIndex + 1}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700),),),
                      if(page.tiles[0].isEmpty)   Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                        ),
                      ),

                    ]
                )

            ),



            if (selectedTool is PenTool &&  _currentPosition != null)
              Positioned(
                left: _currentPosition!.dx - activeStrokes.last.width / 2,
                top: _currentPosition!.dy - activeStrokes.last.width / 2,
                child: IgnorePointer(
                  child: Container(
                    width: activeStrokes.last.width,
                    height: activeStrokes.last.width,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red, width: activeStrokes.last.width),
                    ),
                  ),
                ),
              ),
            if (selectedTool is EraserTool && _eraserPosition != null)
              Positioned(
                left: _eraserPosition!.dx - selectedTool.width,
                top: _eraserPosition!.dy - selectedTool.width,
                child: IgnorePointer(
                  child: Container(
                    width: selectedTool.width * 2,
                    height: selectedTool.width * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.3),
                      border: Border.all(color: Colors.black54, width: selectedTool.width / 20),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  }


  void _pointerMove(PointerEvent event, int activePointers) {

    //print("move");

    final setup = ref.read(editorSetupProvider.select((setup) => setup[editorIndex]));
    final color = setup.colors[setup.colorIndex];
    final width = setup.widths[setup.widthIndex];
    final selectedTool = setup.tools[setup.toolIndex];

    final docs = ref.read(documentsProvider);
    final page = docs[docIndex].pages.firstWhere((p) => p.pageID == pageID);

    //prevents writing next to page

    //print(activePointers);

    if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus || selectedTool.finger && activePointers == 1) {
      final RenderBox canvasBox = _canvasKey.currentContext!.findRenderObject() as RenderBox;
      final Offset localPosition = canvasBox.globalToLocal(event.position);
      //print("hi");
      if (selectedTool is PenTool) {                                                             //if pen (selectedTool==0)is selected

        //print("pentool");
        if(selectedTool.penType == PenType.normal || selectedTool.penType == PenType.fountain && selectedTool.finger) {
          addPointsToActiveStrokes(color, PointModel(pos: localPosition, width: width));
        }
        else if (selectedTool.penType == PenType.fountain) {
          double pressure = width*((event.pressure)*1.5);
          if(activeStrokes.isNotEmpty && activeStrokes.last.points.isNotEmpty){
            if (pressure-activeStrokes.last.points.last.width>0.1) pressure = activeStrokes.last.points.last.width+0.1;
            else if(pressure-activeStrokes.last.points.last.width<-0.1) pressure = activeStrokes.last.points.last.width-0.1;
          }


          addPointsToActiveStrokes(color, PointModel(pos: localPosition, width: pressure));

        }
        setState(() {});

      }
      else if (selectedTool is EraserTool) {                                                      //if erase (selectedTool==1) is selected

        eraseRadius = selectedTool.width;
        _eraserPosition = localPosition; //update eraser circle  position
        //erasedStrokes.insertAll(0, page.strokes.where((stroke) {final isInEraseRadius = stroke.points.any((point) => (point.pos - localPosition).distance < eraseRadius,);final notAlreadyErased = !erasedStrokes.contains(stroke);return isInEraseRadius && notAlreadyErased;}).toList(),);

        erasedStrokes.insertAll(0, page.strokes.where((stroke) {return !erasedStrokes.contains(stroke) && strokeHitByEraser(stroke, localPosition, eraseRadius);}).toList(),);


        for (final img in page.images) {
          final corners = getRotatedRectCorners(img.position, img.width, img.height, img.rotation);

          if (!circleIntersectsPolygonEdge(localPosition, eraseRadius, corners)) continue;

          erasedImages.add(img);

          //ref.read(documentsProvider.notifier).removeElements(docID, pageID, [], [img.imageID]);
          ref.read(documentsProvider.notifier).modifyElementsExecute(docID, pageID,[], [], [], [img.imageID]);
        }

        setState(() {});

      }

      else if (selectedTool is ShapeTool) {                                                      //if erase (selectedTool==1) is selected
        addShapePointsToActiveStroke(selectedTool, color, PointModel(pos: localPosition, width: width));
        setState(() {});
      }
      else if (selectedTool is LineTool) {                                                      //if erase (selectedTool==1) is selected
        addLinePointsToActiveStroke(selectedTool, color, PointModel(pos: localPosition, width: width));
        setState(() {});
      }
      if (selectedTool is LaserTool) {
        //if pen (selectedTool==0)is selected
        addPointsToLaserStrokes(selectedTool.color, PointModel(pos: localPosition, width: selectedTool.width,), selectedTool);

        setState(() {});

      }



      else if (selectedTool is SelectionTool && selectionActive==false) {
        addPointsToSelectionStrokes(setup.selectionColor, PointModel(pos : localPosition, width: 0.3), selectedTool);
        setState(() {});
        //print("renew");

      }
      else if (selectedTool is SelectionTool && selectionActive==true) {
        //print("setstate selectiuon");
        setState(() {
          //print("active");
          handleSelectionAction(localPosition);
        });

        //print(selectionStrokes.length);

      }

    }

  }



  Future<void> _pointerUp(PointerEvent event) async {

    //print("up");
    //ref.read(documentsProvider.notifier).initializeAllPageTiles(docID);

    //ref.read(documentsProvider.notifier).setBackgroundStrokesExecute(docID, pageID, 150, 150, Colors.black, 1);
    //tiles.updateBackground();

    activePointers.remove(event.pointer);

    final setup = ref.read(editorSetupProvider.select((setup) => setup[editorIndex]));
    final selectedTool = setup.tools[setup.toolIndex];


    if(selectionOperation == 0){
      //print("moved");
    }

    oldPosition=Offset(0,0);
    selectionOperation = -1;


    if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus || event.pressure!=variableWidth) {

      if (activeStrokes.length>0 && (selectedTool is PenTool || selectedTool is ShapeTool || selectedTool is LineTool)) {
        //print(activeStrokes.last.points.length);
        ref.read(documentsProvider.notifier).modifyElements(docIndex, pageID, activeStrokes, [], [], []);
        activeStrokes = [];
      }
      else if ((erasedImages.length>0 || erasedStrokes.length>0) && selectedTool is EraserTool) {
        Set<int>idsToRemove = erasedStrokes.map((s) => s.strokeID).toSet();
        List<int>erasedImageIDs = erasedImages.map((s) => s.imageID).toList();
        _eraserPosition = null;
        await ref.read(documentsProvider.notifier).modifyElements(docIndex, pageID, [], [], idsToRemove.toList(), erasedImages);
        erasedImages = [];
        erasedStrokes =[];
      }

      if (laserStrokes.length>0 && selectedTool is LaserTool) {
        finishAddingPointsToLaserStrokes(selectedTool.color, selectedTool);

      }




      else if(selectionStrokes.length>0 && selectionActive == false && selectionStrokes.last.points.length>0){

        //print(selectionStrokes.length);
        //print(selectionActive);
        //print("selection");




        final page = ref.read(documentsProvider.select((docs) => docs[docIndex].pages[pageIndex]));          //important: this isnt a copy of the provider but a reference! youre modifying the provider live by calling this!
        final strokes = page.strokes;
        final images = page.images;

        final Rect selectionBounds = selectionStrokes.last.getStrokeBounds();
        //Rect selectionHighlight = Rect.fromCenter(center: selectionBounds.center, width: 0, height: 0);
        Rect selectionHighlight = Rect.fromLTRB(0, 0, 0, 0);

        final setup = ref.read(editorSetupProvider.select((setup) => setup[editorIndex]));

        //print(selectionBounds);
        for (int i = 0; i<strokes.length; i++) {

          Rect strokeBounds = strokes[i].getStrokeBounds();

          if (!selectionBounds.overlaps(strokeBounds)) {
            continue;
          }

          if(setup.selectionMode==false && strokeInsideLasso(strokes[i], selectionStrokes.last)) {
            //tiles.erasedStrokes.add(strokes[i]);
            erasedStrokes.add(strokes[i].copyWithID());
            activeStrokes.add(strokes[i].copyWithID());
            selectionHighlight=adjustSelectionHighlight(selectionHighlight, strokeBounds);
          }
          else if (setup.selectionMode==true && strokeTouchesLasso(strokes[i], selectionStrokes.last)){
            //tiles.erasedStrokes.add(strokes[i]);
            erasedStrokes.add(strokes[i].copyWithID());
            activeStrokes.add(strokes[i].copyWithID());
            selectionHighlight=adjustSelectionHighlight(selectionHighlight, strokeBounds);
          }

        }

        for(final img in images){


          Rect imgBounds = Rect.fromLTWH(img.position.dx, img.position.dy, img.width, img.height);


          if (!selectionBounds.overlaps(imgBounds)){
            continue;
          }

          final imgStroke = Stroke(color: Colors.white, width: 0, points: [PointModel(pos: img.position, width:  0), PointModel(pos: img.position+Offset(0, img.height), width:  0), PointModel(pos: img.position+Offset(img.width, img.height), width:  0), PointModel(pos: img.position+Offset(img.width, 0), width:  0),]);

          if(setup.selectionMode==false && strokeInsideLasso(imgStroke, selectionStrokes.last)) {
            //tiles.erasedStrokes.add(strokes[i]);
            activeImages.add(img);
            erasedImages.add(img.copyWithID());
            selectionHighlight=adjustSelectionHighlight(selectionHighlight, imgBounds);
          }
          else if (setup.selectionMode==true && strokeTouchesLasso(imgStroke, selectionStrokes.last)){
            //tiles.erasedStrokes.add(strokes[i]);
            activeImages.add(img);
            erasedImages.add(img.copyWithID());
            selectionHighlight=adjustSelectionHighlight(selectionHighlight, imgBounds);
          }
        }


        selectionStrokes.last.points.clear();
        if(activeStrokes.length>0 || activeImages.length>0){

          selectionStrokes.last.points.add(PointModel(pos: selectionHighlight.topLeft, width: 0.3));
          selectionStrokes.last.points.add(PointModel(pos: selectionHighlight.bottomLeft, width: 0.3));
          selectionStrokes.last.points.add(PointModel(pos: selectionHighlight.bottomRight, width: 0.3));
          selectionStrokes.last.points.add(PointModel(pos: selectionHighlight.topRight, width: 0.3));
          selectionActive = true;

        }
        else selectionStrokes = [];



      }

      //print("setstate51");

      setState(() {
        //print("setstate52");
        newStroke = true;
        _eraserPosition = null;
        _currentPosition = null;
      });
      //print("setstate53");





    }

    //print(selectionOperation);
  }



  /*
  void setPageNumber(int number){
    pageIndex = number;                                                     //this is the important one
    //print("pagenumber"+pageNumber.toString());
    //print("setstate6");
    setState(() {

    });
  }
   */




  Future<void> handleSelectionStart(PointerEvent event, Tool tool) async {
    //print("hi");

    Offset pointer = event.localPosition;
    if (event.kind == PointerDeviceKind.touch){
      //print("touch");
      return;
    }


    //ref.read(documentsProvider.notifier).setNewImage(docID, pageID, false);

    //print(oldPosition);

    final stroke = selectionStrokes.first;

    final p0 = stroke.points[0].pos;
    final p1 = stroke.points[1].pos;
    final p2 = stroke.points[2].pos;
    final p3 = stroke.points[3].pos;

    const double hitRadius = 3;

    //startPointer = pointer;
    Offset rotatePointer = p0-(p0-p1)/4+(p3-p0)/2;              //when changing this also change the detection area in selection_drawer (search for line with same formula)



    Rect rect = Rect.fromPoints(p0, p2);

    Rect menuRect = stroke.getStrokeBounds();
    Rect sideMenu = Rect.fromLTWH(menuRect.right+3, menuRect.top+5, 6, 19);





    if (tool is SelectionTool){

    }
    if ((pointer - rotatePointer).distance < hitRadius && (tool is SelectionTool)) {
      //currentAction = SelectionAction.rotate;
      //selectionCenter = center;
      //print("rotate");
      selectionOperation = 1;         //rotating selection
      lastDistance = null;
      scaleCenter = null;
      lastVector = null;
      //return;
    }
    else if(((pointer - p0).distance < hitRadius || (pointer - p1).distance < hitRadius || (pointer - p2).distance < hitRadius || (pointer - p3).distance < hitRadius) && (tool is SelectionTool)){
      //print("scale");
      lastVector = null;
      //currentAction = SelectionAction.scaleCorner;
      //selectionCenter = center;
      selectionOperation = 2;           //scaling selection
      //return;

    }
    else if (rect.contains(pointer)  && (tool is SelectionTool)) {
      //print("move");
      //currentAction = SelectionAction.move;
      selectionOperation = 0;       //moving selection
      lastDistance = null;
      scaleCenter = null;
      lastVector = null;
      //return;
    }
    else if (sideMenu.contains(pointer)  && (tool is SelectionTool)) {
      selectionOperation = -1;
      lastDistance = null;
      scaleCenter = null;
      lastVector = null;
      //print("sidemenu");
    }
    else {
      //print("null");

      List<int>erasedStrokeIDs = erasedStrokes.map((s) => s.strokeID).toList();
      List<int>erasedImageIDs = erasedImages.map((s) => s.imageID).toList();

      List<ImageModel> copiedAddedImages = [];
      for (final i in activeImages) {
        copiedAddedImages.add(i.copyWithID());
      }

      await ref.read(documentsProvider.notifier).modifyElements(docID, pageID, activeStrokes, copiedAddedImages, erasedStrokeIDs, erasedImages);
      //await ref.read(documentsProvider.notifier).removeElements(docID, pageID, erasedStrokeIDs, []);
      //ref.read(documentsProvider.notifier).addElements(docID, pageID, activeStrokes, []);


      oldPosition = Offset(0,0);
      selectionOperation = -1;
      selectionActive = false;
      //tiles.updateErased();
      //tiles.update(activeStrokes);
      selectionStrokes = [];
     // tiles.erasedStrokes = [];
      erasedStrokes = [];
      activeStrokes = [];
      lastDistance = null;
      scaleCenter = null;
      activeImages = [];
      erasedImages = [];

      //print("selection finished");






    }


    //print(selectionOperation);


    if(selectionOperation==0 || selectionOperation==1 || selectionOperation==2) {


      //
      // print("case?");
      for(final image in activeImages){
        rememberActiveImages.add(image.copyWithID());
      }
      for(final stroke in activeStrokes) {
        rememberActiveStrokes.add(stroke.copyWithID());
      }
    }

  }



  void handleSelectionAction(Offset currentPosition){

    if (selectionOperation==0) {
      moveSelection(currentPosition);
    }
    else if(selectionOperation==1){
      rotateSelection(currentPosition);
    }
    else if(selectionOperation==2){
      scaleSelectionXY(currentPosition);
    }


  }


  void moveSelection(Offset currentPosition) {

    if(oldPosition==Offset(0,0)){
      oldPosition=currentPosition;
    }
    final Offset delta=currentPosition-oldPosition;



    for (final stroke in activeStrokes) {
      for (final p in stroke.points) {
        p.pos += delta;
      }
    }

    for (final image in activeImages) {
      //print("hi");
      image.position += delta;

    }

    for (PointModel p in selectionStrokes.last.points) {
      p.pos += delta;
    }

    oldPosition = currentPosition;


  }


  double? lastDistance;
  Offset? scaleCenter;

  void rotateSelection(Offset currentPosition) {

    if(oldPosition==Offset(0,0)){
      oldPosition=currentPosition;
    }

    final Rect bounds = selectionStrokes.last.getStrokeBounds();
    final Offset center = bounds.center;

    final double newAngle = atan2(
      currentPosition.dy - center.dy,
      currentPosition.dx - center.dx,
    );

    final double oldAngle = atan2(
      oldPosition.dy - center.dy,
      oldPosition.dx - center.dx,
    );

    final double deltaAngle = newAngle - oldAngle;

    for (final stroke in activeStrokes) {
      for (final p in stroke.points) {
        p.pos = rotatePoint(p.pos, center, deltaAngle);
      }
    }

    for (final image in activeImages) {
      image.rotation = image.rotation+deltaAngle;
    }

    for (final p in selectionStrokes.last.points) {
      p.pos = rotatePoint(p.pos, center, deltaAngle);
    }

    oldPosition = currentPosition;
  }

  Offset rotatePoint(Offset point, Offset center, double angle) {
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;

    final cosA = cos(angle);
    final sinA = sin(angle);

    return Offset(
      center.dx + dx * cosA - dy * sinA,
      center.dy + dx * sinA + dy * cosA,
    );
  }

  void scaleSelection(Offset currentPosition) {



    scaleCenter ??= selectionStrokes.last.getStrokeBounds().center;
    final center = scaleCenter!;

    final distance = (currentPosition - center).distance;

    if (lastDistance == null) {
      lastDistance = distance;
      return;
    }

    final double scale = distance / lastDistance!;

    for (final stroke in activeStrokes) {
      for (final p in stroke.points) {
        p.pos = scalePoint(p.pos, center, scale);
      }
    }

    for (final p in selectionStrokes.last.points) {
      p.pos = scalePoint(p.pos, center, scale);
    }

    lastDistance = distance;
  }


  Offset? lastVector;

  void scaleSelectionXY(Offset currentPosition) {


    scaleCenter ??= selectionStrokes.last.getStrokeBounds().center;
    final center = scaleCenter!;

    final vector = currentPosition - center;

    if (lastVector == null) {
      lastVector = vector;
      return;
    }

    double scaleX = 1;
    double scaleY = 1;

    if (lastVector!.dx.abs() > 0.001) {
      scaleX = vector.dx / lastVector!.dx;
    }

    if (lastVector!.dy.abs() > 0.001) {
      scaleY = vector.dy / lastVector!.dy;
    }

    for (final stroke in activeStrokes) {
      if (stroke.width!=-1) {
        stroke.width = max((stroke.width*sqrt((scaleX*scaleY).abs())), 0.001);
      }
      for (final p in stroke.points) {
        p.pos = scalePointXY(p.pos, center, scaleX, scaleY);

      }
    }

    for (final image in activeImages) {
      //print("hi");
      Offset bottomRight = image.position + Offset(image.width, image.height);
      image.position = scalePointXY(image.position, center, scaleX, scaleY);
      bottomRight = scalePointXY(bottomRight, center, scaleX, scaleY);
      image.width = bottomRight.dx - image.position.dx;
      image.height = bottomRight.dy - image.position.dy;
    }

    for (final p in selectionStrokes.last.points) {
      p.pos = scalePointXY(p.pos, center, scaleX, scaleY);
    }

    lastVector = vector;

  }

  Offset scalePoint(Offset point, Offset center, double scale) {
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;

    return Offset(
      center.dx + dx * scale,
      center.dy + dy * scale,
    );
  }


  Offset scalePointXY(Offset point, Offset center, double scaleX, double scaleY) {
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;

    return Offset(
      center.dx + dx * scaleX,
      center.dy + dy * scaleY,
    );
  }












  bool strokeInsideLasso(Stroke stroke, Stroke lasso) {

    for (final p in stroke.points) {
      if (!pointInPolygon(p, lasso)) {
        return false;
      }
    }
    return true;
  }

  bool strokeTouchesLasso(Stroke stroke, Stroke lasso) {
    for (final p in stroke.points) {
      if (pointInPolygon(p, lasso)) {
        return true;
      }
    }
    return false;
  }

  bool pointInPolygon(PointModel point, Stroke polygon) {
    bool inside = false;

    for (int i = 0, j = polygon.points.length - 1; i < polygon.points.length; j = i++) {
      final xi = polygon.points[i].pos.dx;
      final yi = polygon.points[i].pos.dy;
      final xj = polygon.points[j].pos.dx;
      final yj = polygon.points[j].pos.dy;

      final intersect = ((yi > point.pos.dy) != (yj > point.pos.dy)) &&
          (point.pos.dx <
              (xj - xi) * (point.pos.dy - yi) / (yj - yi + 0.0000001) + xi);

      if (intersect) inside = !inside;
    }

    return inside;
  }


  Rect adjustSelectionHighlight(Rect a, Rect b) {

    final left = a.left < b.left ? a.left : b.left;
    final top = a.top < b.top ? a.top : b.top;
    final right = a.right > b.right ? a.right : b.right;
    final bottom = a.bottom > b.bottom ? a.bottom : b.bottom;

    if (a == Rect.fromLTRB(0, 0, 0, 0)) {
      return b;
    }
    else {
      return Rect.fromLTRB(left, top, right, bottom);
    }


  }




  Future<void> deleteSelection() async {
    //print("hi");
    final idsToRemove = activeStrokes.map((s) => s.strokeID).toList();
    final imageIDsToRemove = activeImages.map((s) => s.imageID).toList();

    await ref.read(documentsProvider.notifier).modifyElements(docIndex, pageID, [], [], idsToRemove.toList(), activeImages);

    eraserUsed = false;


    activeImages = [];
    selectionActive = false;
    //tiles.updateErased();
    //tiles.update(activeStrokes);
    selectionStrokes = [];
    //tiles.erasedStrokes = [];
    erasedStrokes = [];
    //activeStrokes = [];
    //print("setstate l");
    //setState(() {});
    //rememberActiveStrokes = activeStrokes;
    activeStrokes = [];

    WidgetsBinding.instance.addPostFrameCallback((_) {            //TODO this is really funky there has to be a better way
      setState(() {

      });
    });

  }

  Future<void> copySelection() async {
    //print("copy");

    selectionOperation = -1;
    //selectionActive = false;

    //tiles.erasedStrokes = [];
    //erasedStrokes = [];
    //tiles.updateErased();
    //tiles.update(activeStrokes);
    activeStrokes = activeStrokes.map((s) => s.copy()).toList();
    erasedStrokes = [];

    activeImages = activeImages.map((s) => s.copy()).toList();
    erasedImages = [];



    oldPosition = Offset(1,1);
    moveSelection(Offset(3,3));
    oldPosition = Offset(0,0);
    /*
    setState(() {

    });

     */

    await ref.read(documentsProvider.notifier).modifyElements(docIndex, pageID, [], activeImages, [], []);
    //tiles.erasedStrokes.addAll(activeStrokes);
    //erasedStrokes.addAll(activeStrokes);

    //tiles.update(activeStrokes);
    //selectionStrokes = [];

    //activeStrokes = [];
    lastDistance = null;
    scaleCenter = null;

    //print(activeStrokes.length);



    //copiedStrokes = activeStrokes.map((s) => s.copy()).toList();
  }

  void colorSelection(WidgetRef ref) async {       //TODO IMPLEMENT ME
    print("page_widget: color");
    final color = ref.read(editorSetupProvider)[editorIndex].colors[ref.read(editorSetupProvider)[editorIndex].colorIndex];
    for (final s in activeStrokes) {
      s.color = color;
    }
    setState(() {});
    /*
    final newColor = await showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerDialog(currentColor: activeStrokes.first.color),
    );

    if (newColor != null) {
      for (final stroke in activeStrokes) {
        stroke.color = newColor;
      }
      setState(() {});
    }

     */
  }



  void addPointsToActiveStrokes(Color color, PointModel point) {
    if(activeStrokes.isEmpty) {
      activeStrokes = [];
      activeStrokes.add(Stroke(color: color, width: -1, points: [point]));
    }
    else if ((point.pos-activeStrokes.last.points.last.pos).distance > activeStrokes.last.points.last.width*0.1){               //only add new point when the gap exceeds a minimum distance
      activeStrokes.last.points.add(point);
    }
    //else print("tooclose");

  }

  void addPointsToSelectionStrokes(Color color, PointModel point, SelectionTool tool) {
    if(selectionStrokes.isEmpty) {
      selectionStrokes = [];
      selectionStrokes.add(Stroke(color: color, width: -1, points: [point]));

      if (tool.shape==SelectionShape.rect){
        for (int i = 0; i<4; i++){
          selectionStrokes.last.points.add(PointModel(pos: point.pos, width: point.width));      //needs to be this way because of copy and reference
        }
      }
      
    }
    else {
      if (tool.shape==SelectionShape.lasso){
        if ((point.pos-selectionStrokes.last.points.last.pos).distance > selectionStrokes.last.width*0.05){
          selectionStrokes.last.points.add(point);

        }
      }
      else if (tool.shape==SelectionShape.rect){
        if ((point.pos-selectionStrokes.last.points.last.pos).distance > selectionStrokes.last.points.first.width*5){               //only add new point when the gap exceeds a minimum distance
          selectionStrokes.last.points[1].pos = Offset(selectionStrokes.last.points[1].pos.dx, point.pos.dy);
          selectionStrokes.last.points[2].pos = point.pos;
          selectionStrokes.last.points[3].pos = Offset(point.pos.dx, selectionStrokes.last.points[3].pos.dy);
        }
      }

    }
    //else print("tooclose");


  }


  Offset initialPosition = Offset(0,0);

  void addShapePointsToActiveStroke(ShapeTool tool, Color color, PointModel point) {
    final grid = 5;



    if(activeStrokes.isEmpty) {
      activeStrokes = [];
      initialPosition = point.pos;
      activeStrokes.add(Stroke(color: color, width: -1, points: [point]));

      if(tool.shape == ShapeShape.line) activeStrokes.last.points.addAll([point.copy(), point.copy()]);
      if(tool.shape == ShapeShape.arrow) activeStrokes.last.points.addAll([point.copy(), point.copy(), point.copy(), point.copy(), point.copy()]);
      if(tool.shape == ShapeShape.rect) activeStrokes.last.points.addAll([point.copy(), point.copy(), point.copy(), point.copy()]);
      if(tool.shape == ShapeShape.triangle) activeStrokes.last.points.addAll([point.copy(), point.copy(), point.copy()]);
      if(tool.shape == ShapeShape.pentagon) activeStrokes.last.points.addAll([point.copy(), point.copy(), point.copy(), point.copy(), point.copy()]);
      if(tool.shape == ShapeShape.hexagon) activeStrokes.last.points.addAll([point.copy(), point.copy(), point.copy(), point.copy(), point.copy(), point.copy()]);
      if(tool.shape == ShapeShape.octagon) activeStrokes.last.points.addAll([point.copy(), point.copy(), point.copy(), point.copy(), point.copy(), point.copy() , point.copy(), point.copy()]);

    }
    else if ((point.pos-activeStrokes.last.points.last.pos).distance > activeStrokes.last.points.last.width*0.1 && tool.shapeOrigin == ShapeOrigin.corner){               //only add new point when the gap exceeds a minimum distance
      if(tool.shape == ShapeShape.line) activeStrokes.last.points.last = point;
      else if(tool.shape == ShapeShape.arrow) {
        //print(activeStrokes.last.points.first.pos);
        activeStrokes.last.points[2] = point;
        activeStrokes.last.points[4] = point;


        //print(activeStrokes.last.points[0].pos);

        /*
        if (tool.snapToGrid) {
          activeStrokes.last.points[0].pos = Offset((initialPosition.dx/5).roundToDouble()*5, (initialPosition.dy/5).roundToDouble()*5);
          activeStrokes.last.points[2].pos = Offset((initialPosition.dx/5).roundToDouble()*5, (initialPosition.dy/5).roundToDouble()*5);
          point.pos = Offset((point.pos.dx/5).roundToDouble()*5, (point.pos.dy/5).roundToDouble()*5);
          //b/activeStrokes.last.points[i].pos = Offset((activeStrokes.last.points[i].pos.dx/grid).roundToDouble()*grid, (activeStrokes.last.points[i].pos.dy/grid).roundToDouble()*grid);
        }

         */

        final dir = activeStrokes.last.points[2].pos - activeStrokes.last.points[0].pos;
        //print(dir);
        final length = dir.distance;
        final unit = Offset(dir.dx / length, dir.dy / length);
        final normal = Offset(-unit.dy, unit.dx);
        double arrowLength = 5*point.width;
        double arrowWidth = 5*point.width;
        final base = activeStrokes.last.points[2].pos - unit * arrowLength;
        activeStrokes.last.points[5].pos = base + normal * arrowWidth;
        activeStrokes.last.points[3].pos = base - normal * arrowWidth;
      }
      else if(tool.shape == ShapeShape.rect) {
        //print(activeStrokes.last.points.first.pos);
        activeStrokes.last.points[1].pos = Offset(activeStrokes.last.points[1].pos.dx, point.pos.dy);
        activeStrokes.last.points[2].pos = point.pos;
        activeStrokes.last.points[3].pos = Offset(point.pos.dx, activeStrokes.last.points[3].pos.dy) ;
      }
      else if(tool.shape == ShapeShape.circle) {
        Stroke newStroke = Stroke(color: activeStrokes.last.color, width: -1, strokeID: activeStrokes.last.strokeID, points: []);
        final radius = (point.pos-initialPosition).distance/2;
        double step = atan(2/radius).abs();

        double a = (point.pos.dx-initialPosition.dx)/2;
        double b = (point.pos.dy-initialPosition.dy)/2;

        if (tool.snapToGrid) {
          a = (a/5).roundToDouble()*5;
          b= (b/5).roundToDouble()*5;
          initialPosition = Offset((initialPosition.dx/5).roundToDouble()*5, (initialPosition.dy/5).roundToDouble()*5);
          point.pos = Offset((point.pos.dx/5).roundToDouble()*5, (point.pos.dy/5).roundToDouble()*5);
          //b/activeStrokes.last.points[i].pos = Offset((activeStrokes.last.points[i].pos.dx/grid).roundToDouble()*grid, (activeStrokes.last.points[i].pos.dy/grid).roundToDouble()*grid);
        }

        if(2*pi/step<30) step=2*pi/30;

        for(double i = 0; i<2*pi; i=i+step) {
          newStroke.points.add(PointModel(pos: initialPosition+(point.pos-initialPosition)/2+Offset(a*sin(i), b*cos(i)), width: point.width));
        }
        newStroke.points.add(PointModel(pos: newStroke.points.first.pos, width: point.width));

        activeStrokes.last = newStroke;

      }
      else if(tool.shape == ShapeShape.triangle) {
        //print(activeStrokes.last.points.first.pos);
        activeStrokes.last.points[1].pos = Offset(point.pos.dx, activeStrokes.last.points[0].pos.dy);
        activeStrokes.last.points[2].pos = Offset((point.pos-(point.pos-activeStrokes.last.points[0].pos)/2).dx, (activeStrokes.last.points[0].pos-activeStrokes.last.points[0].pos+point.pos).dy);
      }
      else if(tool.shape == ShapeShape.pentagon) {
        final middlePoint = initialPosition+(point.pos-initialPosition)/2;
        final dx = (point.pos-middlePoint).dx;
        final dy = (point.pos-middlePoint).dy;
        activeStrokes.last.points[0].pos = middlePoint+Offset(0, -dy);
        activeStrokes.last.points[5].pos = activeStrokes.last.points[0].pos;
        activeStrokes.last.points[1].pos = middlePoint+Offset(dx*sin(2*pi*1/5), -dy*cos(2*pi*1/5));
        activeStrokes.last.points[2].pos = middlePoint+Offset(dx*sin(2*pi*2/5), -dy*cos(2*pi*2/5));
        activeStrokes.last.points[3].pos = middlePoint+Offset(dx*sin(2*pi*3/5), -dy*cos(2*pi*3/5));
        activeStrokes.last.points[4].pos = middlePoint+Offset(dx*sin(2*pi*4/5), -dy*cos(2*pi*4/5));
      }
      else if(tool.shape == ShapeShape.hexagon) {
        final middlePoint = initialPosition+(point.pos-initialPosition)/2;
        final dx = (point.pos-middlePoint).dx;
        final dy = (point.pos-middlePoint).dy;
        activeStrokes.last.points[0].pos = middlePoint+Offset(dx*sin(2*pi/12), dy*cos(2*pi/12));
        activeStrokes.last.points[6].pos = activeStrokes.last.points[0].pos;
        activeStrokes.last.points[1].pos = middlePoint+Offset(dx*sin(2*pi*3/12), dy*cos(2*pi*3/12));
        activeStrokes.last.points[2].pos = middlePoint+Offset(dx*sin(2*pi*5/12), dy*cos(2*pi*5/12));
        activeStrokes.last.points[3].pos = middlePoint+Offset(dx*sin(2*pi*7/12), dy*cos(2*pi*7/12));
        activeStrokes.last.points[4].pos = middlePoint+Offset(dx*sin(2*pi*9/12), dy*cos(2*pi*9/12));
        activeStrokes.last.points[5].pos = middlePoint+Offset(dx*sin(2*pi*11/12), dy*cos(2*pi*11/12));
      }
      else if(tool.shape == ShapeShape.octagon) {
        final middlePoint = initialPosition+(point.pos-initialPosition)/2;
        final dx = (point.pos-middlePoint).dx;
        final dy = (point.pos-middlePoint).dy;
        activeStrokes.last.points[0].pos = middlePoint+Offset(dx*sin(2*pi/16), dy*cos(2*pi/16));
        activeStrokes.last.points[8].pos = activeStrokes.last.points[0].pos;
        activeStrokes.last.points[1].pos = middlePoint+Offset(dx*sin(2*pi*3/16), dy*cos(2*pi*3/16));
        activeStrokes.last.points[2].pos = middlePoint+Offset(dx*sin(2*pi*5/16), dy*cos(2*pi*5/16));
        activeStrokes.last.points[3].pos = middlePoint+Offset(dx*sin(2*pi*7/16), dy*cos(2*pi*7/16));
        activeStrokes.last.points[4].pos = middlePoint+Offset(dx*sin(2*pi*9/16), dy*cos(2*pi*9/16));
        activeStrokes.last.points[5].pos = middlePoint+Offset(dx*sin(2*pi*11/16), dy*cos(2*pi*11/16));
        activeStrokes.last.points[6].pos = middlePoint+Offset(dx*sin(2*pi*13/16), dy*cos(2*pi*13/16));
        activeStrokes.last.points[7].pos = middlePoint+Offset(dx*sin(2*pi*15/16), dy*cos(2*pi*15/16));
      }

    }
    else if((point.pos-activeStrokes.last.points.last.pos).distance > activeStrokes.last.points.last.width*0.1 && tool.shapeOrigin == ShapeOrigin.center) {
      if(tool.shape == ShapeShape.line) {
        activeStrokes.last.points.last = point;
        activeStrokes.last.points.first = PointModel(pos: point.pos-(point.pos-activeStrokes.last.points[1].pos)*2, width: point.width);
      }
      else if (tool.shape ==ShapeShape.arrow) {
        activeStrokes.last.points[2] = point;
        activeStrokes.last.points[4] = point;

        final dir = activeStrokes.last.points[2].pos - activeStrokes.last.points[0].pos;
        final length = dir.distance;
        final unit = Offset(dir.dx / length, dir.dy / length);
        final normal = Offset(-unit.dy, unit.dx);
        double arrowLength = 5*point.width;
        double arrowWidth = 5*point.width;
        final base = activeStrokes.last.points[2].pos - unit * arrowLength;
        activeStrokes.last.points[5].pos = base + normal * arrowWidth;
        activeStrokes.last.points[3].pos = base - normal * arrowWidth;
        activeStrokes.last.points.first = PointModel(pos: point.pos-(point.pos-activeStrokes.last.points[1].pos)*2, width: point.width);
      }
      else if(tool.shape == ShapeShape.rect) {
        activeStrokes.last.points[0].pos = activeStrokes.last.points[0].pos-point.pos+activeStrokes.last.points[2].pos;
        activeStrokes.last.points[4].pos = activeStrokes.last.points[0].pos;
        activeStrokes.last.points[1].pos = Offset(activeStrokes.last.points[0].pos.dx, point.pos.dy);
        activeStrokes.last.points[2].pos = point.pos;
        activeStrokes.last.points[3].pos = Offset(point.pos.dx, activeStrokes.last.points[0].pos.dy) ;
      }
      else if(tool.shape == ShapeShape.circle) {
        Stroke newStroke = Stroke(color: activeStrokes.last.color, width: -1, strokeID: activeStrokes.last.strokeID, points: []);
        double radius = (point.pos-initialPosition).distance;

        double step = atan(2/radius).abs();

        if(2*pi/step<30) step=2*pi/30;


        if (tool.snapToGrid) {
          radius = (radius/5).roundToDouble()*5;
          initialPosition = Offset((initialPosition.dx/5).roundToDouble()*5, (initialPosition.dy/5).roundToDouble()*5);
          point.pos = Offset((point.pos.dx/5).roundToDouble()*5, (point.pos.dy/5).roundToDouble()*5);
          //b/activeStrokes.last.points[i].pos = Offset((activeStrokes.last.points[i].pos.dx/grid).roundToDouble()*grid, (activeStrokes.last.points[i].pos.dy/grid).roundToDouble()*grid);
        }

        for(double i = 0; i<2*pi; i=i+step) {newStroke.points.add(PointModel(pos: initialPosition+Offset(radius*sin(i), radius*cos(i)), width: point.width));}
        newStroke.points.add(PointModel(pos: newStroke.points.first.pos, width: point.width));
        //print(newStroke.points.length);
        activeStrokes.last = newStroke;

      }
      else if(tool.shape == ShapeShape.triangle) {


        activeStrokes.last.points[0].pos = Offset((activeStrokes.last.points[0].pos-point.pos+activeStrokes.last.points[1].pos).dx, (activeStrokes.last.points[0].pos+point.pos-activeStrokes.last.points[1].pos).dy);

        activeStrokes.last.points[2].pos = Offset(activeStrokes.last.points[2].pos.dx, (activeStrokes.last.points[2].pos-point.pos+activeStrokes.last.points[1].pos).dy);
        activeStrokes.last.points[1].pos = point.pos;
        activeStrokes.last.points[3].pos = activeStrokes.last.points[0].pos;

      }
      else if(tool.shape == ShapeShape.pentagon) {
        final radius = (point.pos-initialPosition).distance;
        activeStrokes.last.points[0].pos = initialPosition+Offset(0, -radius);
        activeStrokes.last.points[5].pos = activeStrokes.last.points[0].pos;
        activeStrokes.last.points[1].pos = initialPosition+Offset(radius*sin(2*pi*1/5), -radius*cos(2*pi*1/5));
        activeStrokes.last.points[2].pos = initialPosition+Offset(radius*sin(2*pi*2/5), -radius*cos(2*pi*2/5));
        activeStrokes.last.points[3].pos = initialPosition+Offset(radius*sin(2*pi*3/5), -radius*cos(2*pi*3/5));
        activeStrokes.last.points[4].pos = initialPosition+Offset(radius*sin(2*pi*4/5), -radius*cos(2*pi*4/5));
      }
      else if(tool.shape == ShapeShape.hexagon) {
        final radius = (point.pos-initialPosition).distance;
        activeStrokes.last.points[0].pos = initialPosition+Offset(radius*sin(2*pi/12), radius*cos(2*pi/12));
        activeStrokes.last.points[6].pos = activeStrokes.last.points[0].pos;
        activeStrokes.last.points[1].pos = initialPosition+Offset(radius*sin(2*pi*3/12), radius*cos(2*pi*3/12));
        activeStrokes.last.points[2].pos = initialPosition+Offset(radius*sin(2*pi*5/12), radius*cos(2*pi*5/12));
        activeStrokes.last.points[3].pos = initialPosition+Offset(radius*sin(2*pi*7/12), radius*cos(2*pi*7/12));
        activeStrokes.last.points[4].pos = initialPosition+Offset(radius*sin(2*pi*9/12), radius*cos(2*pi*9/12));
        activeStrokes.last.points[5].pos = initialPosition+Offset(radius*sin(2*pi*11/12), radius*cos(2*pi*11/12));
      }
      else if(tool.shape == ShapeShape.octagon) {
        final middlePoint = initialPosition;
        final radius = (point.pos-initialPosition).distance;
        activeStrokes.last.points[0].pos = middlePoint+Offset(radius*sin(2*pi/16), radius*cos(2*pi/16));
        activeStrokes.last.points[8].pos = activeStrokes.last.points[0].pos;
        activeStrokes.last.points[1].pos = middlePoint+Offset(radius*sin(2*pi*3/16), radius*cos(2*pi*3/16));
        activeStrokes.last.points[2].pos = middlePoint+Offset(radius*sin(2*pi*5/16), radius*cos(2*pi*5/16));
        activeStrokes.last.points[3].pos = middlePoint+Offset(radius*sin(2*pi*7/16), radius*cos(2*pi*7/16));
        activeStrokes.last.points[4].pos = middlePoint+Offset(radius*sin(2*pi*9/16), radius*cos(2*pi*9/16));
        activeStrokes.last.points[5].pos = middlePoint+Offset(radius*sin(2*pi*11/16), radius*cos(2*pi*11/16));
        activeStrokes.last.points[6].pos = middlePoint+Offset(radius*sin(2*pi*13/16), radius*cos(2*pi*13/16));
        activeStrokes.last.points[7].pos = middlePoint+Offset(radius*sin(2*pi*15/16), radius*cos(2*pi*15/16));
      }
    }



    if (tool.snapToGrid) {

      if (tool.shape==ShapeShape.line || tool.shape==ShapeShape.rect || tool.shape==ShapeShape.triangle) {
        for (int i = 0; i<activeStrokes.last.points.length;i++) {
          activeStrokes.last.points[i].pos = Offset((activeStrokes.last.points[i].pos.dx/grid).roundToDouble()*grid, (activeStrokes.last.points[i].pos.dy/grid).roundToDouble()*grid);
        }
      }

    }



    //else print("tooclose");

  }

  void addLinePointsToActiveStroke(LineTool tool, Color color, PointModel point) {
    final grid = 5;



    if(activeStrokes.isEmpty) {
      activeStrokes = [];
      initialPosition = point.pos;
      activeStrokes.add(Stroke(color: color, width: -1, points: [point]));

      if(tool.line == LineType.line) activeStrokes.last.points.addAll([point.copy(), point.copy()]);
      if(tool.line == LineType.arrow) activeStrokes.last.points.addAll([point.copy(), point.copy(), point.copy(), point.copy(), point.copy()]);
      if(tool.line == LineType.dotted) activeStrokes.last.points.addAll([point.copy(), point.copy(), point.copy(), point.copy()]);
      if(tool.line == LineType.sine) activeStrokes.last.points.addAll([point.copy(), point.copy(), point.copy()]);

    }
    else if ((point.pos-activeStrokes.last.points.last.pos).distance > activeStrokes.last.points.last.width*0.1 && tool.lineOrigin == LineOrigin.corner){               //only add new point when the gap exceeds a minimum distance
      if(tool.line == LineType.line) activeStrokes.last.points.last = point;
      else if(tool.line == LineType.arrow) {
        //print(activeStrokes.last.points.first.pos);
        if (tool.snapToGrid) {
          activeStrokes.last.points[0].pos = Offset((initialPosition.dx/5).roundToDouble()*5, (initialPosition.dy/5).roundToDouble()*5);
          activeStrokes.last.points[1].pos = Offset((initialPosition.dx/5).roundToDouble()*5, (initialPosition.dy/5).roundToDouble()*5);
          point.pos = Offset((point.pos.dx/5).roundToDouble()*5, (point.pos.dy/5).roundToDouble()*5);
          //b/activeStrokes.last.points[i].pos = Offset((activeStrokes.last.points[i].pos.dx/grid).roundToDouble()*grid, (activeStrokes.last.points[i].pos.dy/grid).roundToDouble()*grid);
        }
        activeStrokes.last.points[2] = point;
        activeStrokes.last.points[4] = point;


        //print(activeStrokes.last.points[0].pos);






        final dir = activeStrokes.last.points[2].pos - activeStrokes.last.points[0].pos;
        //print(dir);
        double length = dir.distance;
        if (length == 0.0) length = 0.1;
        final unit = Offset(dir.dx / length, dir.dy / length);
        final normal = Offset(-unit.dy, unit.dx);
        double arrowLength = 5*point.width;
        double arrowWidth = 5*point.width;
        final base = activeStrokes.last.points[2].pos - unit * arrowLength;
        activeStrokes.last.points[5].pos = base + normal * arrowWidth;
        activeStrokes.last.points[3].pos = base - normal * arrowWidth;
      }
      else if (tool.line == LineType.dotted) {


      }

    }
    else if((point.pos-activeStrokes.last.points.last.pos).distance > activeStrokes.last.points.last.width*0.1 && tool.lineOrigin == LineOrigin.center) {
      if (tool.line == LineType.line) {
        activeStrokes.last.points.last = point;
        activeStrokes.last.points.first = PointModel(
            pos: point.pos - (point.pos - activeStrokes.last.points[1].pos) * 2,
            width: point.width);
      }
      else if (tool.line == LineType.arrow) {
        if (tool.snapToGrid) {
          activeStrokes.last.points[1].pos = Offset((initialPosition.dx/5).roundToDouble()*5, (initialPosition.dy/5).roundToDouble()*5);
          point.pos = Offset((point.pos.dx/5).roundToDouble()*5, (point.pos.dy/5).roundToDouble()*5);
        }
        activeStrokes.last.points[2] = point;
        activeStrokes.last.points[4] = point;
        final dir = activeStrokes.last.points[2].pos - activeStrokes.last.points[0].pos;
        double length = dir.distance;
        if (length == 0.0) length = 0.1;
        final unit = Offset(dir.dx / length, dir.dy / length);
        final normal = Offset(-unit.dy, unit.dx);
        double arrowLength = 5 * point.width;
        double arrowWidth = 5 * point.width;
        final base = activeStrokes.last.points[2].pos - unit * arrowLength;
        activeStrokes.last.points[5].pos = base + normal * arrowWidth;
        activeStrokes.last.points[3].pos = base - normal * arrowWidth;
        activeStrokes.last.points.first = PointModel(pos: point.pos - (point.pos - activeStrokes.last.points[1].pos) * 2, width: point.width);
      }
    }



    if (tool.snapToGrid) {

      if (tool.line==LineType.line) {
        for (int i = 0; i<activeStrokes.last.points.length;i++) {
          activeStrokes.last.points[i].pos = Offset((activeStrokes.last.points[i].pos.dx/grid).roundToDouble()*grid, (activeStrokes.last.points[i].pos.dy/grid).roundToDouble()*grid);
        }
      }
    }



    //else print("tooclose");

  }



  bool circleIntersectsRect(Offset center, double radius, Rect rect) {
    double closestX = center.dx.clamp(rect.left, rect.right);
    double closestY = center.dy.clamp(rect.top, rect.bottom);

    double dx = center.dx - closestX;
    double dy = center.dy - closestY;

    return (dx * dx + dy * dy) <= radius * radius;
  }


  bool strokeHitByEraser(Stroke stroke, Offset eraserPos, double eraseRadius) {
    if (stroke.points.isEmpty) return false;

    //bounding box check for early abort check
    double minX = stroke.points.first.pos.dx;
    double maxX = stroke.points.first.pos.dx;
    double minY = stroke.points.first.pos.dy;
    double maxY = stroke.points.first.pos.dy;

    for (final pt in stroke.points) {
      minX = min(minX, pt.pos.dx - pt.width / 2);
      maxX = max(maxX, pt.pos.dx + pt.width / 2);
      minY = min(minY, pt.pos.dy - pt.width / 2);
      maxY = max(maxY, pt.pos.dy + pt.width / 2);
    }

    if (eraserPos.dx < minX - eraseRadius ||
        eraserPos.dx > maxX + eraseRadius ||
        eraserPos.dy < minY - eraseRadius ||
        eraserPos.dy > maxY + eraseRadius) {
      return false; // eraser far away --> abort immediately
    }

    //stroke is  only one point
    if (stroke.points.length == 1) {
      final pt = stroke.points.first;
      final radius = eraseRadius + pt.width / 2;
      return (pt.pos - eraserPos).distance < radius;
    }

    // checks segments for strokes with 2+ points
    for (int i = 0; i < stroke.points.length - 1; i++) {
      final a = stroke.points[i].pos;
      final b = stroke.points[i + 1].pos;
      final radius = eraseRadius + max(stroke.points[i].width, stroke.points[i + 1].width)/2;

      if (distanceToSegment(eraserPos, a, b) < radius) {
        return true;
      }
    }

    return false;
  }

  void addPointsToLaserStrokes(Color color, PointModel point, LaserTool tool) {
    if(laserStrokes.isEmpty) {

      laserStrokes.add(Stroke(color: color, width: -1, points: [point]));
    }
    else if(laserStrokes.last.points.isEmpty) laserStrokes.last.points.add(point);
    else if ((point.pos-laserStrokes.last.points.last.pos).distance > laserStrokes.last.points.last.width*0.1 && tool.leaveTrail){               //only add new point when the gap exceeds a minimum distance
      laserStrokes.last.points.add(point);
    } else if(!tool.leaveTrail){
      laserStrokes.last.points.last.pos = point.pos;
    }
    //print("action");

  }
  void finishAddingPointsToLaserStrokes(Color color, LaserTool tool) {
    final stroke = laserStrokes.last;

    // Timer 1: startet nach 1 Sekunde
    if(tool.fadeOut) {

      final durationBegin = (tool.fadeOutDuration*100).toInt();
      final durationEnd = (tool.fadeOutDuration*900).toInt();


      final durationStep = 100;
      final alphaStep = (255*2/(tool.fadeOutDuration*9)).toInt();



      laserTimers[stroke] = Timer(Duration(milliseconds: durationBegin), () {
        if (!mounted || !laserStrokes.contains(stroke)) return;

        int alpha = 255;

        // smooth fade (~500ms)
        Timer.periodic(Duration(milliseconds: durationStep), (fadeTimer) {
          if (!mounted || !laserStrokes.contains(stroke)) {
            fadeTimer.cancel();
            return;
          }

          alpha -= alphaStep;

          if (alpha <= 0) {
            alpha = 0;
            fadeTimer.cancel();
          }

          setState(() {
            stroke.color = stroke.color.withAlpha(alpha);
          });
        });

        // deleting timer
        laserTimers[stroke] = Timer(Duration(milliseconds: durationEnd), () {
          if (!mounted) return;

          laserTimers[stroke]?.cancel();
          laserTimers.remove(stroke);

          setState(() {
            laserStrokes.remove(stroke);
          });
        });
      });

    }
    else {
      laserStrokes.removeLast();

    }


    // deine Reihenfolge bleibt exakt gleich
    laserStrokes.add(Stroke(color: color, width: -1, points: []));
  }



  double distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;

    if (abLengthSquared == 0) return (p - a).distance; // a == b

    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLengthSquared;
    if (t < 0) return (p - a).distance;
    if (t > 1) return (p - b).distance;

    final projection = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - projection).distance;
  }



  List<Offset> getRotatedRectCorners(Offset topLeft, double width, double height, double rotation) {
    final center = topLeft + Offset(width/2, height/2);

    List<Offset> corners = [
      topLeft,
      topLeft + Offset(width, 0),
      topLeft + Offset(width, height),
      topLeft + Offset(0, height),
    ];

    return corners.map((corner) {
      final vec = corner - center;
      final rotated = Offset(
        vec.dx * cos(rotation) - vec.dy * sin(rotation),
        vec.dx * sin(rotation) + vec.dy * cos(rotation),
      );
      return center + rotated;
    }).toList();
  }

  bool circleIntersectsPolygonEdge(Offset center, double radius, List<Offset> polygon) {
    for (int i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];

      if (distanceToSegment(center, a, b) <= radius) {
        return true;
      }
    }
    return false;
  }

}