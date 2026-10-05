import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'package:betternotes/custom_widgets/custom_interactive_viewer.dart';
import 'package:betternotes/features/editor/components/top_bar/editor_top_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:betternotes/features/editor/models/tools/tool.dart';
import 'components/document_widget.dart';




import 'package:betternotes/core/providers/global_providers.dart';

import 'package:vector_math/vector_math_64.dart' as vect;



final editorIndex = 0;

class Editor extends ConsumerStatefulWidget {
  //final String pathToFile;



  const Editor({
    super.key,
    //required this.pathToFile,



  });


  @override
  ConsumerState<Editor> createState() => _EditorState();
}



class _EditorState extends ConsumerState<Editor> with WidgetsBindingObserver {

  //String currentFileName = 'noFileName';
  String pathToFile = 'noFileName';
  Orientation? _lastOrientation;


  final CustomTransformationController _customTransformationController = CustomTransformationController();
  final ScrollController _scrollController = ScrollController();
  double zoomedInSideSpace = 5.0;


  final GlobalKey<DocumentWidgetState> _documentWidgetKey = GlobalKey<DocumentWidgetState>();

  final ValueNotifier<int> currentPage = ValueNotifier<int>(0);
  int newCurrentPage = 0;
  int _activePointers = 0;
  bool _isZooming = false;
  Timer? _zoomStabilityTimer;

  int docIndex=0;

  late final doc= ref.read(documentsProvider)[docIndex];
  late final docCurrentPage = doc.currentPageIndex;
  late final double pageWidth = doc.pages[docCurrentPage].pageWidth;









  @override
  void initState() {
    super.initState();



    //currentFileName = Provider.of<GlobalState>(context, listen: false).currentFileName;
    //pathToFile = widget.pathToFile;
    pathToFile = ref.read(documentsProvider)[0].pathToFile;
    print("editor: pathToFile: $pathToFile");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        adjustZoom();

      });
    });


    WidgetsBinding.instance.addObserver(this);
    _customTransformationController.addListener(_onTransformationChanged);

  }

  double middle = 0;

  double minScale = 0.2;
  double maxScale = 8.0;


  bool _lastTapWasFinger = false;

  @override
  Widget build(BuildContext context) {                        //actucally visible elements

    //late final doc= ref.read(documentsProvider)[docIndex];

    final setup =ref.read(editorSetupProvider.select((setup) => setup[editorIndex]));
    Tool selectedTool = ref.watch(editorSetupProvider)[editorIndex].tools[setup.toolIndex];
    bool finger = !selectedTool.finger;

    final currentPage = ref.watch(documentsProvider)[docIndex].currentPageIndex;


    return Scaffold(
      //backgroundColor: Colors.grey[300],                                //background behind pages
      backgroundColor: HSLColor.fromColor(Theme.of(context).colorScheme.surface).withLightness((HSLColor.fromColor(Theme.of(context).colorScheme.surface).lightness * 0.8).clamp(0.0, 1.0)).toColor(),
      appBar: EditorTopBar(
          //onAddPage: _addPage, onRemovePage: _removePage, onSave: saveAsBnf, onUndo: undo, onRedo: redo, currentPage: currentPage, page: _documentWidgetKey.currentState?.getPage(currentPage.value)
      ),           //topbar menu
      body: LayoutBuilder(                                              //pages
          builder: (context, constraints) {

            middle = constraints.maxHeight / 2;
            return Stack(children: [
              Listener(                                                    //detecting stylus input for drawing
                onPointerDown: (event) {
                  _activePointers++;
                  _lastTapWasFinger = event.kind == PointerDeviceKind.touch;        //detecting finger input for scrolling/moving/zooming
                },
                onPointerUp: (event) => _activePointers = max(0, _activePointers - 1),
                onPointerCancel: (event) => _activePointers = max(0, _activePointers - 1),
                child: GestureDetector(
                  onDoubleTapDown: (TapDownDetails details) {if (_lastTapWasFinger) {doubleTap(details.localPosition);}},
                  child: CustomInteractiveViewer(
                    customTransformationController: _customTransformationController,
                    panEnabled: finger,
                    scaleEnabled: true,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: minScale,
                    maxScale: maxScale,
                    child: SizedBox(
                        width: constraints.maxWidth,
                        //height: constraints.maxHeight,
                        child: DocumentWidget()
                    ),
                  ),
                ),
              ),
              Positioned(right: 16, bottom: 16, child: Text("currentPageIndex: ${currentPage}", style: TextStyle(fontSize: 24, color: Colors.blueGrey),),),


              /*
              Positioned(
                top: constraints.maxHeight / 2,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: Colors.red,
                ),
              ),

               */

            ],

            );

          },
        ),






    );
  }








  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _customTransformationController
        .removeListener(_onTransformationChanged);
    _customTransformationController.dispose();

    _scrollController.dispose();

    currentPage.dispose();

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final currentOrientation = MediaQuery.of(context).orientation;
    if (currentOrientation != _lastOrientation) {
      _lastOrientation = currentOrientation;
      _onOrientationChanged(currentOrientation);
    }
  }

  void adjustZoom() {
    late final doc= ref.read(documentsProvider)[docIndex];
    late final docCurrentPage = doc.currentPageIndex;
    late final double pageWidth = doc.pages[docCurrentPage].pageWidth;
    double translateX = _customTransformationController.value.getTranslation().x;
    double translateY = _customTransformationController.value.getTranslation().y;
    double zoom = (MediaQuery.of(context).size.width - 2*zoomedInSideSpace) / pageWidth;
    final matrix = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(zoom);

    _customTransformationController.value = matrix;

  }

  void doubleTap(Offset position) {
    late final doc= ref.read(documentsProvider)[docIndex];
    late final docCurrentPage = doc.currentPageIndex;
    late final double pageWidth = doc.pages[docCurrentPage].pageWidth;
    final transformation = _customTransformationController.value;
    final currentZoom = transformation.getMaxScaleOnAxis();
    double translateY = transformation.getTranslation().y;
    double translateX = transformation.getTranslation().x;
    double targetZoom = (MediaQuery.of(context).size.width - 2 * zoomedInSideSpace) / pageWidth;


    bool zoomingIn = currentZoom != targetZoom;
    double newZoom = zoomingIn ? targetZoom : 1.6;


    final tapY = position.dy;
    final tapX = position.dx;
    final newTranslateY = newZoom/currentZoom*(translateY-tapY)+tapY;           //this formula makes it that the position youve double clicked is still in the same place on the screen after the zooming
    final newTranslateX = newZoom/currentZoom*(translateX-tapX)+tapX;           //not sure how effective this is for x, since the x value is limited by the page boundries

    final newMatrix = Matrix4.identity()
      ..translate(newTranslateX, newTranslateY)
      ..scale(newZoom)
    ;
    _customTransformationController.value = newMatrix;
  }

  void _onOrientationChanged(Orientation newOrientation) {                      //when user rotates device
    WidgetsBinding.instance.addPostFrameCallback((_) {                          //has to be done 1 frame later
      late final doc= ref.read(documentsProvider)[docIndex];
      late final docCurrentPage = doc.currentPageIndex;
      late final double pageWidth = doc.pages[docCurrentPage].pageWidth;

      final screenSize = MediaQuery.of(context).size;
      final screenWidth = screenSize.width;

      double zoom = _customTransformationController.value.getMaxScaleOnAxis();

      double translateX = _customTransformationController.value.getTranslation().x;
      double translateY = _customTransformationController.value.getTranslation().y;

      double centerX = -screenWidth * (zoom - 1) / 2;
      double centerOffsetX = (pageWidth * zoom - screenWidth) / 2;


      if (pageWidth * zoom < (screenWidth) - 2 * zoomedInSideSpace) {
        translateX = centerX;
      } else if (translateX > centerX + centerOffsetX + zoomedInSideSpace) {
        translateX = centerX + centerOffsetX + zoomedInSideSpace;
      } else if (translateX < centerX - centerOffsetX - zoomedInSideSpace) {
        translateX = centerX - centerOffsetX - zoomedInSideSpace;
      }

      if (translateY > 0) {
        translateY = 0;
      }

      final matrix = Matrix4.identity()
        ..translate(translateX, translateY)
        ..scale(zoom);

      _customTransformationController.value = matrix;
    });
  }

  bool _isUpdatingTransform = false;






  int counter = 0;

  double oldZoom = 0;

  Future<void> _onTransformationChanged() async {

    late final doc= ref.read(documentsProvider)[docIndex];
    int currentPage = doc.currentPageIndex;
    if (currentPage>doc.pageHeights.length-1) {
      currentPage = doc.pageHeights.length-1;
    }

    //print("editor: ref currentPage: $currentPage");

    //print(currentPage);
    late final double pageWidth = doc.pages[0].pageWidth;



    if (_isUpdatingTransform) return;

    _isUpdatingTransform = true;



    try {
      final screenWidth = MediaQuery.of(context).size.width;
      double zoom = _customTransformationController.value.getMaxScaleOnAxis();
      double translateX = _customTransformationController.value.getTranslation().x;
      double translateY = _customTransformationController.value.getTranslation().y;
      double centerX = -screenWidth * (zoom - 1) / 2; //formula for calculating the centered position depending on device screen and zoom level
      double centerOffsetX = (pageWidth * zoom - screenWidth) / 2; //how much the page is moved to left or right when zoomed in and not entire page is visible


      if (pageWidth * zoom < (screenWidth) - 2 *
          zoomedInSideSpace) { //if the entire width of the page is visible center the page
        translateX = centerX;
      }
      else if ((translateX > centerX + centerOffsetX +
          zoomedInSideSpace)) { //zoomed in enough that only part of width is visible, prevents it from moving the page too far to the right
        translateX = centerX + centerOffsetX + zoomedInSideSpace;
      }
      else if ((translateX < centerX - centerOffsetX -
          zoomedInSideSpace)) { //zoomed in enough that only part of width is visible, prevents it from moving the page too far to the left
        translateX = centerX - centerOffsetX - zoomedInSideSpace;
      }


      if (translateY > 0) {
        translateY = 0;
      }


      final scrollY = -(translateY + middle * (zoom - 1)) / zoom;

      bool zoomChanged = (zoom - oldZoom).abs() > 0.00001;
      
      if (zoomChanged) {
        _isZooming = true;
        _zoomStabilityTimer?.cancel();
        _zoomStabilityTimer = Timer(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _isZooming = false;
            });
          }
        });
      }

      if (!_isZooming && _activePointers <= 1) {
        double scroll = 0;

        for (int i = 0; i < doc.pageHeights.length; i++) {
          if (scroll <= scrollY + middle && scrollY + middle <= scroll + doc.pageHeights[i] + 24) {
            newCurrentPage = i;
            break;
          }
          scroll = scroll + doc.pageHeights[i] + 24;
        }

        if (currentPage != newCurrentPage) {
          currentPage = newCurrentPage;
          print("editor: scrollY = $scrollY, zoom=$zoom translateY = $translateY");
          print("editor: setcurrentpage $newCurrentPage");
          ref.read(documentsProvider.notifier).setCurrentPageIndex3(0, newCurrentPage);
        }
      }

      oldZoom = zoom;

      counter++;
      if (counter > 10) {
        //ref.read(documentsProvider.notifier).checkPagesMapped(0);
        counter = 0;
      }

      final matrix = Matrix4.identity()
        ..translate(translateX, translateY)
        ..scale(zoom);

      //_customTransformationController.value = matrix;

      if (!_matrixEquals(_customTransformationController.value, matrix)) {
        _customTransformationController.value = matrix;
      }
    }
    finally {
      _isUpdatingTransform = false;
    }
  }


  bool _matrixEquals(Matrix4 a, Matrix4 b) {
    for (int i = 0; i < 16; i++) {
      if (a.storage[i] != b.storage[i]) return false;
    }
    return true;
  }

}