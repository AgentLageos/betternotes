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
import '../rendering/page_tiles.dart';





class PageWidget extends ConsumerStatefulWidget {
  final int docID;
  final int pageIndex;
  final int pageID;





  const PageWidget({
    super.key,
    required this.docID,
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



  double eraseRadius = 10.0;      //size of the eraser
  Offset? _eraserPosition;        //position of eraser
  Offset? _currentPosition;        //position of eraser

  final GlobalKey _canvasKey = GlobalKey();                                     //detecting if user writes out of bounds

  bool penUsed = false;

  bool eraserUsed = false;                                                      //used for undo, preventing adding command when eraser instead of pen was used

  int pageIndex = 0;

  late final int pageID;

  double variableWidth = 0.5;

  List<Stroke> activeStrokes = [];
  List<Stroke> erasedStrokes = [];

  late double lastPressure;



  Rect rect = Rect.fromLTWH(0, 0, 53, 50);


  List<Stroke> selectionStrokes = [];           //used for displaying and calculation the selection area
  List<Stroke> laserStrokes = [];           //used for displaying the laserpointer
  Map<int, Timer> laserTimers = {};           //per laser strokeID
  bool selectionActive = false;
  int selectionOperation = -1;
  Offset oldPosition = Offset(0,0);

  List<ImageModel> activeImages = [];

  List<ImageModel> erasedImages = [];

  int get docID => widget.docID;
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
    });

  }

  @override
  void dispose() {
    activeStrokes.clear();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {


    final doc = ref.watch(documentProvider(docID));



    final setup =ref.read(editorSetupProvider.select((setup) => setup[editorIndex]));

    Tool selectedTool = ref.read(editorSetupProvider)[editorIndex].tools[setup.toolIndex];
    final selectionColor = setup.selectionColor;


    final page = doc.pages.where((p) => p.pageID == pageID).firstOrNull;
    if (page == null) {
      return const SizedBox();
    }
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
            if (settings.debugMode) Container(
              height: pageHeight,
              width: pageWidth,
              decoration: BoxDecoration(
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
                      if (settings.debugMode) Positioned(right: 16, bottom: 16, child: Text("$pageID    ${pageIndex + 1}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700),),)       //displaying pagenumber and pageid, NEEDS TO BE HERE SO STYLUS IS RECOGNIZED OVER TEXT AND DOESNT GET OVERLAYED WHILE ERASING
                      else Positioned(right: 16, bottom: 16, child: Text("${pageIndex + 1}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700),),),
                      if(ref.watch(pageTilesProvider.select((m) => m[(docID: docID, pageID: pageID)]?.isEmpty ?? true)))   Positioned.fill(
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
                      color: Colors.white.withValues(alpha: 0.3),
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


    final setup = ref.read(editorSetupProvider.select((setup) => setup[editorIndex]));
    final color = setup.colors[setup.colorIndex];
    final width = setup.widths[setup.widthIndex];
    final selectedTool = setup.tools[setup.toolIndex];

    final page = ref.read(documentProvider(docID)).pages.firstWhere((p) => p.pageID == pageID);

    //prevents writing next to page


    if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus || selectedTool.finger && activePointers == 1) {
      final RenderBox canvasBox = _canvasKey.currentContext!.findRenderObject() as RenderBox;
      final Offset localPosition = canvasBox.globalToLocal(event.position);
      if (selectedTool is PenTool) {                                                             //if pen (selectedTool==0)is selected

        if(selectedTool.penType == PenType.normal || selectedTool.penType == PenType.fountain && selectedTool.finger) {
          addPointsToActiveStrokes(color, PointModel(pos: localPosition, width: width));
        }
        else if (selectedTool.penType == PenType.fountain) {
          double pressure = width*((event.pressure)*1.5);
          if(activeStrokes.isNotEmpty && activeStrokes.last.points.isNotEmpty){
            if (pressure-activeStrokes.last.points.last.width>0.1) {
              pressure = activeStrokes.last.points.last.width+0.1;
            } else if(pressure-activeStrokes.last.points.last.width<-0.1) {
              pressure = activeStrokes.last.points.last.width-0.1;
            }
          }


          addPointsToActiveStrokes(color, PointModel(pos: localPosition, width: pressure));

        }
        setState(() {});

      }
      else if (selectedTool is EraserTool) {                                                      //if erase (selectedTool==1) is selected

        eraseRadius = selectedTool.width;
        _eraserPosition = localPosition; //update eraser circle  position

        erasedStrokes.insertAll(0, page.strokes.where((stroke) {return !erasedStrokes.contains(stroke) && strokeHitByEraser(stroke, localPosition, eraseRadius);}).toList(),);


        for (final img in page.images) {
          final corners = getRotatedRectCorners(img.position, img.width, img.height, img.rotation);

          if (!circleIntersectsPolygonEdge(localPosition, eraseRadius, corners)) continue;

          erasedImages.add(img);

          ref.read(documentProvider(docID).notifier).modifyElementsExecute(pageID,[], [], [], [img.imageID]);
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

      }
      else if (selectedTool is SelectionTool && selectionActive==true) {
        setState(() {
          handleSelectionAction(localPosition);
        });


      }

    }

  }



  Future<void> _pointerUp(PointerEvent event) async {


    activePointers.remove(event.pointer);

    final setup = ref.read(editorSetupProvider.select((setup) => setup[editorIndex]));
    final selectedTool = setup.tools[setup.toolIndex];


    if(selectionOperation == 0){
    }

    oldPosition=Offset(0,0);
    selectionOperation = -1;


    if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus || event.pressure!=variableWidth) {

      if (activeStrokes.isNotEmpty && (selectedTool is PenTool || selectedTool is ShapeTool || selectedTool is LineTool)) {
        unawaited(ref.read(documentProvider(docID).notifier).modifyElements(pageID, activeStrokes, [], [], []));
        activeStrokes = [];
      }
      else if ((erasedImages.isNotEmpty || erasedStrokes.isNotEmpty) && selectedTool is EraserTool) {
        Set<int>idsToRemove = erasedStrokes.map((s) => s.strokeID).toSet();
        _eraserPosition = null;
        await ref.read(documentProvider(docID).notifier).modifyElements(pageID, [], [], idsToRemove.toList(), erasedImages);
        erasedImages = [];
        erasedStrokes =[];
      }

      if (laserStrokes.isNotEmpty && selectedTool is LaserTool) {
        finishAddingPointsToLaserStrokes(selectedTool.color, selectedTool);

      }




      else if(selectionStrokes.isNotEmpty && selectionActive == false && selectionStrokes.last.points.isNotEmpty){


        // Looked up by ID: pageIndex is a position in the whole document, pages only holds the loaded window.
        final page = ref.read(documentProvider(docID)).pages.firstWhere((p) => p.pageID == pageID);
        final strokes = page.strokes;
        final images = page.images;

        final Rect selectionBounds = selectionStrokes.last.getStrokeBounds();
        Rect selectionHighlight = Rect.fromLTRB(0, 0, 0, 0);

        final setup = ref.read(editorSetupProvider.select((setup) => setup[editorIndex]));

        for (int i = 0; i<strokes.length; i++) {

          Rect strokeBounds = strokes[i].getStrokeBounds();

          if (!selectionBounds.overlaps(strokeBounds)) {
            continue;
          }

          if(setup.selectionMode==false && strokeInsideLasso(strokes[i], selectionStrokes.last)) {
            erasedStrokes.add(strokes[i]);
            activeStrokes.add(strokes[i]);
            selectionHighlight=adjustSelectionHighlight(selectionHighlight, strokeBounds);
          }
          else if (setup.selectionMode==true && strokeTouchesLasso(strokes[i], selectionStrokes.last)){
            erasedStrokes.add(strokes[i]);
            activeStrokes.add(strokes[i]);
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
            activeImages.add(img);
            erasedImages.add(img);
            selectionHighlight=adjustSelectionHighlight(selectionHighlight, imgBounds);
          }
          else if (setup.selectionMode==true && strokeTouchesLasso(imgStroke, selectionStrokes.last)){
            activeImages.add(img);
            erasedImages.add(img);
            selectionHighlight=adjustSelectionHighlight(selectionHighlight, imgBounds);
          }
        }


        selectionStrokes.last.points.clear();
        if(activeStrokes.isNotEmpty || activeImages.isNotEmpty){

          selectionStrokes.last.points.add(PointModel(pos: selectionHighlight.topLeft, width: 0.3));
          selectionStrokes.last.points.add(PointModel(pos: selectionHighlight.bottomLeft, width: 0.3));
          selectionStrokes.last.points.add(PointModel(pos: selectionHighlight.bottomRight, width: 0.3));
          selectionStrokes.last.points.add(PointModel(pos: selectionHighlight.topRight, width: 0.3));
          selectionActive = true;

        }
        else {
          selectionStrokes = [];
        }



      }


      setState(() {
        newStroke = true;
        _eraserPosition = null;
        _currentPosition = null;
      });


    }

  }



  Future<void> handleSelectionStart(PointerEvent event, Tool tool) async {

    Offset pointer = event.localPosition;
    if (event.kind == PointerDeviceKind.touch){
      return;
    }


    final stroke = selectionStrokes.first;

    final p0 = stroke.points[0].pos;
    final p1 = stroke.points[1].pos;
    final p2 = stroke.points[2].pos;
    final p3 = stroke.points[3].pos;

    const double hitRadius = 3;

    Offset rotatePointer = p0-(p0-p1)/4+(p3-p0)/2;              //when changing this also change the detection area in selection_drawer (search for line with same formula)



    Rect rect = Rect.fromPoints(p0, p2);

    Rect menuRect = stroke.getStrokeBounds();
    Rect sideMenu = Rect.fromLTWH(menuRect.right+3, menuRect.top+5, 6, 19);





    if (tool is SelectionTool){

    }
    if ((pointer - rotatePointer).distance < hitRadius && (tool is SelectionTool)) {
      selectionOperation = 1;         //rotating selection
      lastDistance = null;
      scaleCenter = null;
      lastVector = null;
    }
    else if(((pointer - p0).distance < hitRadius || (pointer - p1).distance < hitRadius || (pointer - p2).distance < hitRadius || (pointer - p3).distance < hitRadius) && (tool is SelectionTool)){
      lastVector = null;
      selectionOperation = 2;           //scaling selection

    }
    else if (rect.contains(pointer)  && (tool is SelectionTool)) {
      selectionOperation = 0;       //moving selection
      lastDistance = null;
      scaleCenter = null;
      lastVector = null;
    }
    else if (sideMenu.contains(pointer)  && (tool is SelectionTool)) {
      selectionOperation = -1;
      lastDistance = null;
      scaleCenter = null;
      lastVector = null;
    }
    else {

      List<int>erasedStrokeIDs = erasedStrokes.map((s) => s.strokeID).toList();

      List<ImageModel> copiedAddedImages = [];
      for (final i in activeImages) {
        copiedAddedImages.add(i);
      }

      await ref.read(documentProvider(docID).notifier).modifyElements(pageID, activeStrokes, copiedAddedImages, erasedStrokeIDs, erasedImages);


      oldPosition = Offset(0,0);
      selectionOperation = -1;
      selectionActive = false;
      selectionStrokes = [];
      erasedStrokes = [];
      activeStrokes = [];
      lastDistance = null;
      scaleCenter = null;
      activeImages = [];
      erasedImages = [];


    }


    if(selectionOperation==0 || selectionOperation==1 || selectionOperation==2) {


      for(final image in activeImages){
        rememberActiveImages.add(image);
      }
      for(final stroke in activeStrokes) {
        rememberActiveStrokes.add(stroke);
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



    _mapSelectionPoints((pos) => pos + delta);
    activeImages = [for (final image in activeImages) image.copyWith(position: image.position + delta)];

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

    _mapSelectionPoints((pos) => rotatePoint(pos, center, deltaAngle));
    activeImages = [for (final image in activeImages) image.copyWith(rotation: image.rotation + deltaAngle)];

    oldPosition = currentPosition;
  }

  /// Moves every point of the selected strokes and of the selection outline through [f].
  /// Builds new strokes: the selected strokes share their (immutable) points with the document.
  void _mapSelectionPoints(Offset Function(Offset pos) f) {
    List<PointModel> mapped(Stroke stroke) => [for (final p in stroke.points) p.copyWith(pos: f(p.pos))];
    activeStrokes = [for (final stroke in activeStrokes) stroke.copyWith(points: mapped(stroke))];
    final outline = selectionStrokes.last;
    selectionStrokes[selectionStrokes.length - 1] = outline.copyWith(points: mapped(outline));
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

    _mapSelectionPoints((pos) => scalePoint(pos, center, scale));

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

    activeStrokes = [
      for (final stroke in activeStrokes)
        if (stroke.width != -1)
          stroke.copyWith(width: max((stroke.width*sqrt((scaleX*scaleY).abs())), 0.001))
        else
          stroke
    ];
    _mapSelectionPoints((pos) => scalePointXY(pos, center, scaleX, scaleY));

    activeImages = [
      for (final image in activeImages)
        () {
          final topLeft = scalePointXY(image.position, center, scaleX, scaleY);
          final bottomRight = scalePointXY(image.position + Offset(image.width, image.height), center, scaleX, scaleY);
          return image.copyWith(position: topLeft, width: bottomRight.dx - topLeft.dx, height: bottomRight.dy - topLeft.dy);
        }(),
    ];

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
    final idsToRemove = activeStrokes.map((s) => s.strokeID).toList();

    await ref.read(documentProvider(docID).notifier).modifyElements(pageID, [], [], idsToRemove.toList(), activeImages);

    eraserUsed = false;


    activeImages = [];
    selectionActive = false;
    selectionStrokes = [];
    erasedStrokes = [];
    activeStrokes = [];

    WidgetsBinding.instance.addPostFrameCallback((_) {            //TODO this is really funky there has to be a better way
      setState(() {

      });
    });

  }

  Future<void> copySelection() async {

    selectionOperation = -1;

    activeStrokes = activeStrokes.map((s) => s.copy()).toList();
    erasedStrokes = [];

    activeImages = activeImages.map((s) => s.copy()).toList();
    erasedImages = [];



    oldPosition = Offset(1,1);
    moveSelection(Offset(3,3));
    oldPosition = Offset(0,0);

    await ref.read(documentProvider(docID).notifier).modifyElements(pageID, [], activeImages, [], []);


    lastDistance = null;
    scaleCenter = null;


  }

  void colorSelection(WidgetRef ref) async {       //TODO IMPLEMENT ME
    print("page_widget: color");
    final color = ref.read(editorSetupProvider)[editorIndex].colors[ref.read(editorSetupProvider)[editorIndex].colorIndex];
    activeStrokes = [for (final s in activeStrokes) s.copyWith(color: color)];
    setState(() {});
  }



  void addPointsToActiveStrokes(Color color, PointModel point) {
    if(activeStrokes.isEmpty) {
      activeStrokes = [];
      activeStrokes.add(Stroke(color: color, width: -1, points: [point]));
    }
    else if ((point.pos-activeStrokes.last.points.last.pos).distance > activeStrokes.last.points.last.width*0.1){               //only add new point when the gap exceeds a minimum distance
      activeStrokes.last.points.add(point);
    }

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
          selectionStrokes.last.points[1] = selectionStrokes.last.points[1].copyWith(pos: Offset(selectionStrokes.last.points[1].pos.dx, point.pos.dy));
          selectionStrokes.last.points[2] = selectionStrokes.last.points[2].copyWith(pos: point.pos);
          selectionStrokes.last.points[3] = selectionStrokes.last.points[3].copyWith(pos: Offset(point.pos.dx, selectionStrokes.last.points[3].pos.dy));
        }
      }

    }


  }


  Offset initialPosition = Offset(0,0);

  void addShapePointsToActiveStroke(ShapeTool tool, Color color, PointModel point) {
    final grid = 5;



    if(activeStrokes.isEmpty) {
      activeStrokes = [];
      initialPosition = point.pos;
      activeStrokes.add(Stroke(color: color, width: -1, points: [point]));

      if(tool.shape == ShapeShape.line) activeStrokes.last.points.addAll([point, point]);
      if(tool.shape == ShapeShape.arrow) activeStrokes.last.points.addAll([point, point, point, point, point]);
      if(tool.shape == ShapeShape.rect) activeStrokes.last.points.addAll([point, point, point, point]);
      if(tool.shape == ShapeShape.triangle) activeStrokes.last.points.addAll([point, point, point]);
      if(tool.shape == ShapeShape.pentagon) activeStrokes.last.points.addAll([point, point, point, point, point]);
      if(tool.shape == ShapeShape.hexagon) activeStrokes.last.points.addAll([point, point, point, point, point, point]);
      if(tool.shape == ShapeShape.octagon) activeStrokes.last.points.addAll([point, point, point, point, point, point , point, point]);

    }
    else if ((point.pos-activeStrokes.last.points.last.pos).distance > activeStrokes.last.points.last.width*0.1 && tool.shapeOrigin == ShapeOrigin.corner){               //only add new point when the gap exceeds a minimum distance
      if(tool.shape == ShapeShape.line) {
        activeStrokes.last.points.last = point;
      } else if(tool.shape == ShapeShape.arrow) {
        activeStrokes.last.points[2] = point;
        activeStrokes.last.points[4] = point;


        final dir = activeStrokes.last.points[2].pos - activeStrokes.last.points[0].pos;
        final length = dir.distance;
        final unit = Offset(dir.dx / length, dir.dy / length);
        final normal = Offset(-unit.dy, unit.dx);
        double arrowLength = 5*point.width;
        double arrowWidth = 5*point.width;
        final base = activeStrokes.last.points[2].pos - unit * arrowLength;
        activeStrokes.last.points[5] = activeStrokes.last.points[5].copyWith(pos: base + normal * arrowWidth);
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: base - normal * arrowWidth);
      }
      else if(tool.shape == ShapeShape.rect) {
        activeStrokes.last.points[1] = activeStrokes.last.points[1].copyWith(pos: Offset(activeStrokes.last.points[1].pos.dx, point.pos.dy));
        activeStrokes.last.points[2] = activeStrokes.last.points[2].copyWith(pos: point.pos);
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: Offset(point.pos.dx, activeStrokes.last.points[3].pos.dy) );
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
          point = point.copyWith(pos: Offset((point.pos.dx/5).roundToDouble()*5, (point.pos.dy/5).roundToDouble()*5));
        }

        if(2*pi/step<30) step=2*pi/30;

        for(double i = 0; i<2*pi; i=i+step) {
          newStroke.points.add(PointModel(pos: initialPosition+(point.pos-initialPosition)/2+Offset(a*sin(i), b*cos(i)), width: point.width));
        }
        newStroke.points.add(PointModel(pos: newStroke.points.first.pos, width: point.width));

        activeStrokes.last = newStroke;

      }
      else if(tool.shape == ShapeShape.triangle) {
        activeStrokes.last.points[1] = activeStrokes.last.points[1].copyWith(pos: Offset(point.pos.dx, activeStrokes.last.points[0].pos.dy));
        activeStrokes.last.points[2] = activeStrokes.last.points[2].copyWith(pos: Offset((point.pos-(point.pos-activeStrokes.last.points[0].pos)/2).dx, (activeStrokes.last.points[0].pos-activeStrokes.last.points[0].pos+point.pos).dy));
      }
      else if(tool.shape == ShapeShape.pentagon) {
        final middlePoint = initialPosition+(point.pos-initialPosition)/2;
        final dx = (point.pos-middlePoint).dx;
        final dy = (point.pos-middlePoint).dy;
        activeStrokes.last.points[0] = activeStrokes.last.points[0].copyWith(pos: middlePoint+Offset(0, -dy));
        activeStrokes.last.points[5] = activeStrokes.last.points[5].copyWith(pos: activeStrokes.last.points[0].pos);
        activeStrokes.last.points[1] = activeStrokes.last.points[1].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*1/5), -dy*cos(2*pi*1/5)));
        activeStrokes.last.points[2] = activeStrokes.last.points[2].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*2/5), -dy*cos(2*pi*2/5)));
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*3/5), -dy*cos(2*pi*3/5)));
        activeStrokes.last.points[4] = activeStrokes.last.points[4].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*4/5), -dy*cos(2*pi*4/5)));
      }
      else if(tool.shape == ShapeShape.hexagon) {
        final middlePoint = initialPosition+(point.pos-initialPosition)/2;
        final dx = (point.pos-middlePoint).dx;
        final dy = (point.pos-middlePoint).dy;
        activeStrokes.last.points[0] = activeStrokes.last.points[0].copyWith(pos: middlePoint+Offset(dx*sin(2*pi/12), dy*cos(2*pi/12)));
        activeStrokes.last.points[6] = activeStrokes.last.points[6].copyWith(pos: activeStrokes.last.points[0].pos);
        activeStrokes.last.points[1] = activeStrokes.last.points[1].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*3/12), dy*cos(2*pi*3/12)));
        activeStrokes.last.points[2] = activeStrokes.last.points[2].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*5/12), dy*cos(2*pi*5/12)));
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*7/12), dy*cos(2*pi*7/12)));
        activeStrokes.last.points[4] = activeStrokes.last.points[4].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*9/12), dy*cos(2*pi*9/12)));
        activeStrokes.last.points[5] = activeStrokes.last.points[5].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*11/12), dy*cos(2*pi*11/12)));
      }
      else if(tool.shape == ShapeShape.octagon) {
        final middlePoint = initialPosition+(point.pos-initialPosition)/2;
        final dx = (point.pos-middlePoint).dx;
        final dy = (point.pos-middlePoint).dy;
        activeStrokes.last.points[0] = activeStrokes.last.points[0].copyWith(pos: middlePoint+Offset(dx*sin(2*pi/16), dy*cos(2*pi/16)));
        activeStrokes.last.points[8] = activeStrokes.last.points[8].copyWith(pos: activeStrokes.last.points[0].pos);
        activeStrokes.last.points[1] = activeStrokes.last.points[1].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*3/16), dy*cos(2*pi*3/16)));
        activeStrokes.last.points[2] = activeStrokes.last.points[2].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*5/16), dy*cos(2*pi*5/16)));
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*7/16), dy*cos(2*pi*7/16)));
        activeStrokes.last.points[4] = activeStrokes.last.points[4].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*9/16), dy*cos(2*pi*9/16)));
        activeStrokes.last.points[5] = activeStrokes.last.points[5].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*11/16), dy*cos(2*pi*11/16)));
        activeStrokes.last.points[6] = activeStrokes.last.points[6].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*13/16), dy*cos(2*pi*13/16)));
        activeStrokes.last.points[7] = activeStrokes.last.points[7].copyWith(pos: middlePoint+Offset(dx*sin(2*pi*15/16), dy*cos(2*pi*15/16)));
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
        activeStrokes.last.points[5] = activeStrokes.last.points[5].copyWith(pos: base + normal * arrowWidth);
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: base - normal * arrowWidth);
        activeStrokes.last.points.first = PointModel(pos: point.pos-(point.pos-activeStrokes.last.points[1].pos)*2, width: point.width);
      }
      else if(tool.shape == ShapeShape.rect) {
        activeStrokes.last.points[0] = activeStrokes.last.points[0].copyWith(pos: activeStrokes.last.points[0].pos-point.pos+activeStrokes.last.points[2].pos);
        activeStrokes.last.points[4] = activeStrokes.last.points[4].copyWith(pos: activeStrokes.last.points[0].pos);
        activeStrokes.last.points[1] = activeStrokes.last.points[1].copyWith(pos: Offset(activeStrokes.last.points[0].pos.dx, point.pos.dy));
        activeStrokes.last.points[2] = activeStrokes.last.points[2].copyWith(pos: point.pos);
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: Offset(point.pos.dx, activeStrokes.last.points[0].pos.dy) );
      }
      else if(tool.shape == ShapeShape.circle) {
        Stroke newStroke = Stroke(color: activeStrokes.last.color, width: -1, strokeID: activeStrokes.last.strokeID, points: []);
        double radius = (point.pos-initialPosition).distance;

        double step = atan(2/radius).abs();

        if(2*pi/step<30) step=2*pi/30;


        if (tool.snapToGrid) {
          radius = (radius/5).roundToDouble()*5;
          initialPosition = Offset((initialPosition.dx/5).roundToDouble()*5, (initialPosition.dy/5).roundToDouble()*5);
          point = point.copyWith(pos: Offset((point.pos.dx/5).roundToDouble()*5, (point.pos.dy/5).roundToDouble()*5));
        }

        for(double i = 0; i<2*pi; i=i+step) {newStroke.points.add(PointModel(pos: initialPosition+Offset(radius*sin(i), radius*cos(i)), width: point.width));}
        newStroke.points.add(PointModel(pos: newStroke.points.first.pos, width: point.width));
        activeStrokes.last = newStroke;

      }
      else if(tool.shape == ShapeShape.triangle) {


        activeStrokes.last.points[0] = activeStrokes.last.points[0].copyWith(pos: Offset((activeStrokes.last.points[0].pos-point.pos+activeStrokes.last.points[1].pos).dx, (activeStrokes.last.points[0].pos+point.pos-activeStrokes.last.points[1].pos).dy));

        activeStrokes.last.points[2] = activeStrokes.last.points[2].copyWith(pos: Offset(activeStrokes.last.points[2].pos.dx, (activeStrokes.last.points[2].pos-point.pos+activeStrokes.last.points[1].pos).dy));
        activeStrokes.last.points[1] = activeStrokes.last.points[1].copyWith(pos: point.pos);
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: activeStrokes.last.points[0].pos);

      }
      else if(tool.shape == ShapeShape.pentagon) {
        final radius = (point.pos-initialPosition).distance;
        activeStrokes.last.points[0] = activeStrokes.last.points[0].copyWith(pos: initialPosition+Offset(0, -radius));
        activeStrokes.last.points[5] = activeStrokes.last.points[5].copyWith(pos: activeStrokes.last.points[0].pos);
        activeStrokes.last.points[1] = activeStrokes.last.points[1].copyWith(pos: initialPosition+Offset(radius*sin(2*pi*1/5), -radius*cos(2*pi*1/5)));
        activeStrokes.last.points[2] = activeStrokes.last.points[2].copyWith(pos: initialPosition+Offset(radius*sin(2*pi*2/5), -radius*cos(2*pi*2/5)));
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: initialPosition+Offset(radius*sin(2*pi*3/5), -radius*cos(2*pi*3/5)));
        activeStrokes.last.points[4] = activeStrokes.last.points[4].copyWith(pos: initialPosition+Offset(radius*sin(2*pi*4/5), -radius*cos(2*pi*4/5)));
      }
      else if(tool.shape == ShapeShape.hexagon) {
        final radius = (point.pos-initialPosition).distance;
        activeStrokes.last.points[0] = activeStrokes.last.points[0].copyWith(pos: initialPosition+Offset(radius*sin(2*pi/12), radius*cos(2*pi/12)));
        activeStrokes.last.points[6] = activeStrokes.last.points[6].copyWith(pos: activeStrokes.last.points[0].pos);
        activeStrokes.last.points[1] = activeStrokes.last.points[1].copyWith(pos: initialPosition+Offset(radius*sin(2*pi*3/12), radius*cos(2*pi*3/12)));
        activeStrokes.last.points[2] = activeStrokes.last.points[2].copyWith(pos: initialPosition+Offset(radius*sin(2*pi*5/12), radius*cos(2*pi*5/12)));
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: initialPosition+Offset(radius*sin(2*pi*7/12), radius*cos(2*pi*7/12)));
        activeStrokes.last.points[4] = activeStrokes.last.points[4].copyWith(pos: initialPosition+Offset(radius*sin(2*pi*9/12), radius*cos(2*pi*9/12)));
        activeStrokes.last.points[5] = activeStrokes.last.points[5].copyWith(pos: initialPosition+Offset(radius*sin(2*pi*11/12), radius*cos(2*pi*11/12)));
      }
      else if(tool.shape == ShapeShape.octagon) {
        final middlePoint = initialPosition;
        final radius = (point.pos-initialPosition).distance;
        activeStrokes.last.points[0] = activeStrokes.last.points[0].copyWith(pos: middlePoint+Offset(radius*sin(2*pi/16), radius*cos(2*pi/16)));
        activeStrokes.last.points[8] = activeStrokes.last.points[8].copyWith(pos: activeStrokes.last.points[0].pos);
        activeStrokes.last.points[1] = activeStrokes.last.points[1].copyWith(pos: middlePoint+Offset(radius*sin(2*pi*3/16), radius*cos(2*pi*3/16)));
        activeStrokes.last.points[2] = activeStrokes.last.points[2].copyWith(pos: middlePoint+Offset(radius*sin(2*pi*5/16), radius*cos(2*pi*5/16)));
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: middlePoint+Offset(radius*sin(2*pi*7/16), radius*cos(2*pi*7/16)));
        activeStrokes.last.points[4] = activeStrokes.last.points[4].copyWith(pos: middlePoint+Offset(radius*sin(2*pi*9/16), radius*cos(2*pi*9/16)));
        activeStrokes.last.points[5] = activeStrokes.last.points[5].copyWith(pos: middlePoint+Offset(radius*sin(2*pi*11/16), radius*cos(2*pi*11/16)));
        activeStrokes.last.points[6] = activeStrokes.last.points[6].copyWith(pos: middlePoint+Offset(radius*sin(2*pi*13/16), radius*cos(2*pi*13/16)));
        activeStrokes.last.points[7] = activeStrokes.last.points[7].copyWith(pos: middlePoint+Offset(radius*sin(2*pi*15/16), radius*cos(2*pi*15/16)));
      }
    }



    if (tool.snapToGrid) {

      if (tool.shape==ShapeShape.line || tool.shape==ShapeShape.rect || tool.shape==ShapeShape.triangle) {
        for (int i = 0; i<activeStrokes.last.points.length;i++) {
          activeStrokes.last.points[i] = activeStrokes.last.points[i].copyWith(pos: Offset((activeStrokes.last.points[i].pos.dx/grid).roundToDouble()*grid, (activeStrokes.last.points[i].pos.dy/grid).roundToDouble()*grid));
        }
      }

    }



  }

  void addLinePointsToActiveStroke(LineTool tool, Color color, PointModel point) {
    final grid = 5;



    if(activeStrokes.isEmpty) {
      activeStrokes = [];
      initialPosition = point.pos;
      activeStrokes.add(Stroke(color: color, width: -1, points: [point]));

      if(tool.line == LineType.line) activeStrokes.last.points.addAll([point, point]);
      if(tool.line == LineType.arrow) activeStrokes.last.points.addAll([point, point, point, point, point]);
      if(tool.line == LineType.dotted) activeStrokes.last.points.addAll([point, point, point, point]);
      if(tool.line == LineType.sine) activeStrokes.last.points.addAll([point, point, point]);

    }
    else if ((point.pos-activeStrokes.last.points.last.pos).distance > activeStrokes.last.points.last.width*0.1 && tool.lineOrigin == LineOrigin.corner){               //only add new point when the gap exceeds a minimum distance
      if(tool.line == LineType.line) {
        activeStrokes.last.points.last = point;
      } else if(tool.line == LineType.arrow) {
        if (tool.snapToGrid) {
          activeStrokes.last.points[0] = activeStrokes.last.points[0].copyWith(pos: Offset((initialPosition.dx/5).roundToDouble()*5, (initialPosition.dy/5).roundToDouble()*5));
          activeStrokes.last.points[1] = activeStrokes.last.points[1].copyWith(pos: Offset((initialPosition.dx/5).roundToDouble()*5, (initialPosition.dy/5).roundToDouble()*5));
          point = point.copyWith(pos: Offset((point.pos.dx/5).roundToDouble()*5, (point.pos.dy/5).roundToDouble()*5));
        }
        activeStrokes.last.points[2] = point;
        activeStrokes.last.points[4] = point;


        final dir = activeStrokes.last.points[2].pos - activeStrokes.last.points[0].pos;
        double length = dir.distance;
        if (length == 0.0) length = 0.1;
        final unit = Offset(dir.dx / length, dir.dy / length);
        final normal = Offset(-unit.dy, unit.dx);
        double arrowLength = 5*point.width;
        double arrowWidth = 5*point.width;
        final base = activeStrokes.last.points[2].pos - unit * arrowLength;
        activeStrokes.last.points[5] = activeStrokes.last.points[5].copyWith(pos: base + normal * arrowWidth);
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: base - normal * arrowWidth);
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
          activeStrokes.last.points[1] = activeStrokes.last.points[1].copyWith(pos: Offset((initialPosition.dx/5).roundToDouble()*5, (initialPosition.dy/5).roundToDouble()*5));
          point = point.copyWith(pos: Offset((point.pos.dx/5).roundToDouble()*5, (point.pos.dy/5).roundToDouble()*5));
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
        activeStrokes.last.points[5] = activeStrokes.last.points[5].copyWith(pos: base + normal * arrowWidth);
        activeStrokes.last.points[3] = activeStrokes.last.points[3].copyWith(pos: base - normal * arrowWidth);
        activeStrokes.last.points.first = PointModel(pos: point.pos - (point.pos - activeStrokes.last.points[1].pos) * 2, width: point.width);
      }
    }



    if (tool.snapToGrid) {

      if (tool.line==LineType.line) {
        for (int i = 0; i<activeStrokes.last.points.length;i++) {
          activeStrokes.last.points[i] = activeStrokes.last.points[i].copyWith(pos: Offset((activeStrokes.last.points[i].pos.dx/grid).roundToDouble()*grid, (activeStrokes.last.points[i].pos.dy/grid).roundToDouble()*grid));
        }
      }
    }



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
    else if(laserStrokes.last.points.isEmpty) {
      laserStrokes.last.points.add(point);
    }
    else if ((point.pos-laserStrokes.last.points.last.pos).distance > laserStrokes.last.points.last.width*0.1 && tool.leaveTrail){               //only add new point when the gap exceeds a minimum distance
      laserStrokes.last.points.add(point);
    } else if(!tool.leaveTrail){
      laserStrokes.last.points.last = laserStrokes.last.points.last.copyWith(pos: point.pos);
    }

  }
  void finishAddingPointsToLaserStrokes(Color color, LaserTool tool) {
    // Strokes are immutable, so the fade replaces the stroke; it is found again by its ID.
    final strokeID = laserStrokes.last.strokeID;
    int indexOfStroke() => laserStrokes.indexWhere((s) => s.strokeID == strokeID);

    // Timer 1: starts after 1 second
    if(tool.fadeOut) {

      final durationBegin = (tool.fadeOutDuration*100).toInt();
      final durationEnd = (tool.fadeOutDuration*900).toInt();


      final durationStep = 100;
      final alphaStep = (255*2/(tool.fadeOutDuration*9)).toInt();



      laserTimers[strokeID] = Timer(Duration(milliseconds: durationBegin), () {
        if (!mounted || indexOfStroke() == -1) return;

        int alpha = 255;

        // smooth fade (~500ms)
        Timer.periodic(Duration(milliseconds: durationStep), (fadeTimer) {
          if (!mounted || indexOfStroke() == -1) {
            fadeTimer.cancel();
            return;
          }

          alpha -= alphaStep;

          if (alpha <= 0) {
            alpha = 0;
            fadeTimer.cancel();
          }

          setState(() {
            final index = indexOfStroke();
            laserStrokes[index] = laserStrokes[index].copyWith(color: laserStrokes[index].color.withAlpha(alpha));
          });
        });

        // deleting timer
        laserTimers[strokeID] = Timer(Duration(milliseconds: durationEnd), () {
          if (!mounted) return;

          laserTimers[strokeID]?.cancel();
          laserTimers.remove(strokeID);

          setState(() {
            laserStrokes.removeWhere((s) => s.strokeID == strokeID);
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