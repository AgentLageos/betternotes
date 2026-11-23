import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:betternotes/features/editor/models/page/point.dart';
import 'package:flutter/material.dart';
import 'image_model.dart';
import 'stroke.dart';
import 'package:betternotes/core/utils/id_generator.dart';
import 'tile.dart';




class PageModel {
  final List<Stroke> strokes;
  List<Stroke> backgroundStrokes;
  final List<ImageModel> images;
  final double pageHeight;
  final double pageWidth;
  final Color pageColor;
  final int pageID;

  final List<double> verticalSpaces;
  final List<double> horizontalSpaces;

  final ImageModel? backgroundImage;



  List<List<Tile>> tiles = [[]];

  List<int> erasedIDs = [];

  final Rect rect = Rect.fromLTWH(0,0,20,20);

  final bool isTemp;


  PageModel({


    //required this.backgroundUpdate,


    List<double>? verticalSpaces,
    List<double>? horizontalSpaces,
    List<Stroke>? strokes,
    List<Stroke>? backgroundStrokes,
    List<ImageModel>? images,
    double? pageHeight,
    double? pageWidth,
    Color? pageColor,
    List<List<Tile>>? tiles,
    bool? isTemp,
    int? pageID,
    this.backgroundImage,


  }) :  pageID = pageID ?? IdGenerator.next(),

        strokes = strokes ?? [],
        backgroundStrokes = backgroundStrokes ?? [],
        images = images ?? [],
        pageHeight = pageHeight ?? 297,
        pageWidth = pageWidth ?? 210,
        pageColor = pageColor ?? Colors.white,
        tiles = tiles ?? [[]],

        verticalSpaces = verticalSpaces ?? [],
        horizontalSpaces = horizontalSpaces ?? [],
        isTemp = isTemp ?? false



  ;

  // copyWith for immutable updates
  PageModel copyWith({
    List<Stroke>? strokes,
    List<Stroke>? backgroundStrokes,
    List<ImageModel>? images,
    double? pageHeight,
    double? pageWidth,
    Color? pageColor,
    int? pageID,
    //bool? newImage,
    //bool? didUndo,
    //bool? didRedo,

    List<List<Tile>>? tiles,
    //bool? backgroundUpdate,

    List<double>? verticalSpaces,
    List<double>? horizontalSpaces,
    bool? isTemp,
    ImageModel? backgroundImage,

  }) {
    return PageModel(
      strokes: strokes ?? this.strokes,
      backgroundStrokes: backgroundStrokes ?? this.backgroundStrokes,
      images: images ?? this.images,
      pageHeight: pageHeight ?? this.pageHeight,
      pageWidth: pageWidth ?? this.pageWidth,
      pageColor: pageColor?? this.pageColor,
      pageID : pageID ?? this.pageID,
      tiles: tiles ?? this.tiles,
      //backgroundUpdate : backgroundUpdate ?? this.backgroundUpdate,
      verticalSpaces: verticalSpaces ?? this.verticalSpaces,
      horizontalSpaces: horizontalSpaces ?? this.horizontalSpaces,
      isTemp: isTemp ?? this.isTemp,
      backgroundImage: backgroundImage ?? this.backgroundImage,

    );
  }











  Future<void> initializeTiles() async {
    final newTiles = <List<Tile>>[];

    final rows = (pageHeight / rect.height).ceil();
    final cols = (pageWidth / rect.width).ceil();

    double newWidth;
    double newHeight;

    for (int row = 0; row < rows; row++) {
      final rowTiles = <Tile>[];
      for (int col = 0; col < cols; col++) {

        if (col >= cols-1) {newWidth = pageWidth-(cols-1)*rect.width;}       //sizing the most right and most down tiles so they have exactly the size of the page
        else {newWidth = rect.width;}

        if (row >= rows-1) {newHeight = pageHeight-(rows-1)*rect.height;}
        else {newHeight = rect.height;}

        rowTiles.add(
          Tile(Rect.fromLTWH(col * rect.width, row * rect.height, newWidth, newHeight,), //false,
          ),
        );
      }
      newTiles.add(rowTiles);
    }

    tiles = newTiles;

    await updateTiles(strokes, [], backgroundStrokes);

  }




  Future<void> updateTiles(List<Stroke> newStrokes, List<int> erasedStrokeIDs, List<Stroke> newBackgroundStrokes) async {


    final Set<Point<int>> changedTiles = {};

    for (int i = 0; i < tiles.length; i++) {
      // i is the row
      for (int j = 0; j < tiles[i].length; j++) {
        // j is the column within the row

        if(newBackgroundStrokes.isNotEmpty) {
          tiles[i][j].addBackgroundStrokesAsAbstractStrokes(newBackgroundStrokes);
          backgroundStrokes = newBackgroundStrokes;

        }

        for (int k = 0; k<erasedStrokeIDs.length; k++) {


          if (tiles[i][j].aStrokes.any((s) => erasedStrokeIDs.contains(s.strokeID))) {
            tiles[i][j].aStrokes.removeWhere((s) => erasedStrokeIDs.contains(s.strokeID));
            changedTiles.add(Point(i, j));
          }
        }

        final changed = tiles[i][j].addStrokesAsAbstractStrokes(newStrokes);


        if (changed || newBackgroundStrokes.isNotEmpty) changedTiles.add(Point(i, j));

      }
    }


    for (int i = 0; i < tiles.length; i++) {
      // i is the row
      for (int j = 0; j < tiles[i].length; j++) {
        // j is the column within the row

      }
    }


    final List<Future<void>> futures = [];

    for (var point in changedTiles) {
      futures.add(() async {
        if (newBackgroundStrokes.isNotEmpty) {
          await tiles[point.x][point.y].renderBackground(newBackgroundStrokes);
        }


        await tiles[point.x][point.y].renderAbstractStrokes(strokes);
      }());
    }

    await Future.wait(futures);


    erasedIDs = [];



  }






  void setBackgroundStrokesBySpacing(List<double> horizontalSpaces, List<double> verticalSpaces, Color strokeColor, double strokeWidth) {

    backgroundStrokes = [];

    double i = 0;

    if (verticalSpaces.isNotEmpty && verticalSpaces.first>0.1) {
      while (i < pageWidth) {
        for (int j = 0; j < verticalSpaces.length; j++) {
          i += verticalSpaces[j];
          backgroundStrokes.add(Stroke(color: strokeColor, width: strokeWidth, points: [PointModel(pos: Offset(i, 0), width: strokeWidth), PointModel(pos: Offset(i, pageHeight), width: strokeWidth)]));
        }
      }
    }

    if (horizontalSpaces.isNotEmpty && horizontalSpaces.first>0.1) {
      i = 0;
      while (i<pageHeight){
        for (int j = 0; j<horizontalSpaces.length; j++){
          i+=horizontalSpaces[j];
          backgroundStrokes.add(Stroke(color: strokeColor, width: strokeWidth, points: [PointModel(pos: Offset(0, i), width: strokeWidth), PointModel(pos: Offset(pageWidth, i), width: strokeWidth)]));
        }
      }
    }



  }


  void clearTiles(){
    tiles = [[]];
  }



  Map<String, dynamic> toJson() {
    return {
      //'pageID': pageID,
      'pageWidth': pageWidth,
      'pageHeight': pageHeight,
      'pageColor': pageColor.toARGB32(),
      'verticalSpaces': verticalSpaces,
      'horizontalSpaces': horizontalSpaces,

      'strokes': strokes.map((s) => s.toJson()).toList(),
      'backgroundStrokes': backgroundStrokes.map((s) => s.toJson()).toList(),
      'images': images.map((i) => i.toJson()).toList(),

      //'tiles': tiles.map((row) => row.map((tile) => tile.toJson()).toList()).toList(),
    };
  }

  static Future<PageModel> fromJson(Map<String, dynamic> json, {List<ArchiveFile>? archivedImages, int? pageID}) async {

    List<ImageModel> images = [];

    if(archivedImages != null) {

      if (archivedImages.isNotEmpty){
        images = (await Future.wait(
          (json['images'] as List).map(
                (img) async {
              final result = await ImageModel.fromJson(
                Map<String, dynamic>.from(img),
                archivedImages,
              );
              return result;
            },
          ),
        )).whereType<ImageModel>().toList();


      }
    }



    final strokes = (json['strokes'] as List<dynamic>?)?.map((s) => Stroke.fromJson(Map<String, dynamic>.from(s))).toList() ?? [];

    final backgroundStrokes = (json['backgroundStrokes'] as List<dynamic>?)?.map((s) => Stroke.fromJson(Map<String, dynamic>.from(s))).toList() ?? [];

    final verticalSpaces = (json['verticalSpaces'] as List<dynamic>?)?.where((e) => e != null).map((e) => (e as num).toDouble()).toList() ?? [];

    final horizontalSpaces = (json['horizontalSpaces'] as List<dynamic>?)?.where((e) => e != null).map((e) => (e as num).toDouble()).toList() ?? [];


    final page = PageModel(
      strokes: strokes,
      backgroundStrokes: backgroundStrokes,
      images: images,
      pageWidth: json['pageWidth']?.toDouble() ?? 210,
      pageHeight: json['pageHeight']?.toDouble() ?? 297,
      pageColor: Color(json['pageColor'] ?? 4294967295),
      tiles: [[]],
      verticalSpaces: verticalSpaces,
      horizontalSpaces: horizontalSpaces,
      pageID: pageID ?? IdGenerator.next(),
    );

    return page;
  }


  /// Encodes the page for a `.bnf` page record.
  /// Returns the record bytes and the image blocks (block ID -> encoded image) the page references.
  Future<({Uint8List bytes, Map<int, Uint8List> images})> encode() async {
    final builder = BytesBuilder();
    final pageIdData = ByteData(8)..setUint64(0, pageID, Endian.little);
    builder.add(pageIdData.buffer.asUint8List());
    final pageWidthData = ByteData(8)..setFloat64(0, pageWidth, Endian.little);
    builder.add(pageWidthData.buffer.asUint8List());
    final pageHeightData = ByteData(8)..setFloat64(0, pageHeight, Endian.little);
    builder.add(pageHeightData.buffer.asUint8List());
    final pageColorData = ByteData(4)..setUint32(0, pageColor.toARGB32(), Endian.little);
    builder.add(pageColorData.buffer.asUint8List());
    final verticalCount = ByteData(4)..setUint32(0, verticalSpaces.length, Endian.little);
    builder.add(verticalCount.buffer.asUint8List());
    for (final space in verticalSpaces) {
      final data = ByteData(8)..setFloat64(0, space, Endian.little);
      builder.add(data.buffer.asUint8List());
    }
    final horizontalCount = ByteData(4)..setUint32(0, horizontalSpaces.length, Endian.little);
    builder.add(horizontalCount.buffer.asUint8List());
    for (final space in horizontalSpaces) {
      final data = ByteData(8)..setFloat64(0, space, Endian.little);
      builder.add(data.buffer.asUint8List());
    }
    final strokeCount = ByteData(4)..setUint32(0, strokes.length, Endian.little);
    builder.add(strokeCount.buffer.asUint8List());
    for (final stroke in strokes) {
      final strokeBytes = stroke.toBytes();

      // length of the stroke block
      final length = ByteData(8)
        ..setUint64(0, strokeBytes.length, Endian.little);

      builder.add(length.buffer.asUint8List());

      // Stroke-Daten
      builder.add(strokeBytes);
    }

    final backgroundStrokeCount = ByteData(4)..setUint32(0, backgroundStrokes.length, Endian.little,);

    builder.add(backgroundStrokeCount.buffer.asUint8List(),);

    for (final stroke in backgroundStrokes) {
      final strokeBytes = stroke.toBytes();
      final length = ByteData(8)..setUint64(0, strokeBytes.length, Endian.little);
      builder.add(length.buffer.asUint8List());
      builder.add(strokeBytes);
    }
    // Images are stored as separate image blocks; the page only holds placement + block ID.
    final imageBlocks = <int, Uint8List>{};
    final imageCount = ByteData(4)..setUint32(0, images.length, Endian.little);
    builder.add(imageCount.buffer.asUint8List());
    for (final image in images) {
      final encoded = await image.encode();
      builder.add(encoded.bytes);
      imageBlocks[encoded.blockID] = encoded.image;
    }
    final backgroundImage = this.backgroundImage;
    builder.addByte(backgroundImage == null ? 0 : 1);
    if (backgroundImage != null) {
      final encoded = await backgroundImage.encode();
      builder.add(encoded.bytes);
      imageBlocks[encoded.blockID] = encoded.image;
    }
    return (bytes: builder.takeBytes(), images: imageBlocks);
  }







  /// Decodes bytes produced by [encode]. [readImage] returns the content of an image block.
  static Future<PageModel> decode(Uint8List bytes, Future<Uint8List?> Function(int blockID) readImage) async {
    final data = ByteData.sublistView(bytes);

    int offset = 0;

    final pageID = data.getUint64(offset, Endian.little,);
    offset += 8;
    final pageWidth = data.getFloat64(offset, Endian.little,);
    offset += 8;
    final pageHeight = data.getFloat64(offset, Endian.little,);
    offset += 8;

    final colorValue = data.getUint32(offset, Endian.little,);

    offset += 4;

    final pageColor = Color(colorValue);


    final verticalCount = data.getUint32(offset, Endian.little,);
    offset += 4;
    final verticalSpaces = <double>[];
    for (int i = 0; i < verticalCount; i++) {
      verticalSpaces.add(data.getFloat64(offset, Endian.little,),);
      offset += 8;
    }
    final horizontalCount = data.getUint32(offset, Endian.little,);
    offset += 4;
    final horizontalSpaces = <double>[];
    for (int i = 0; i < horizontalCount; i++) {
      horizontalSpaces.add(data.getFloat64(offset, Endian.little,),);
      offset += 8;
    }


    final strokeCount = data.getUint32(offset, Endian.little,);
    offset += 4;
    final strokes = <Stroke>[];

    for (int i = 0; i < strokeCount; i++) {
      // length of the stroke block
      final strokeLength = data.getUint64(offset, Endian.little,);
      offset += 8;
      // Stroke Bytes
      final strokeBytes = bytes.sublist(offset, offset + strokeLength,);
      offset += strokeLength;
      final stroke = Stroke.fromBytes(strokeBytes,);
      strokes.add(stroke);
    }

    final backgroundStrokeCount = data.getUint32(offset, Endian.little,);
    offset += 4;
    final backgroundStrokes = <Stroke>[];
    for (int i = 0; i < backgroundStrokeCount; i++) {
      final strokeLength = data.getUint64(offset, Endian.little,);
      offset += 8;
      final strokeBytes = bytes.sublist(offset, offset + strokeLength,);
      offset += strokeLength;
      final stroke = Stroke.fromBytes(strokeBytes,);
      backgroundStrokes.add(stroke);
    }

    final imageCount = data.getUint32(offset, Endian.little,);
    offset += 4;
    final images = <ImageModel>[];
    for (int i = 0; i < imageCount; i++) {
      images.add(await ImageModel.decode(
          Uint8List.sublistView(bytes, offset, offset + ImageModel.encodedLength), readImage));
      offset += ImageModel.encodedLength;
    }

    ImageModel? backgroundImage;
    final hasBackgroundImage = data.getUint8(offset) == 1;
    offset += 1;
    if (hasBackgroundImage) {
      backgroundImage = await ImageModel.decode(
          Uint8List.sublistView(bytes, offset, offset + ImageModel.encodedLength), readImage);
      offset += ImageModel.encodedLength;
    }

    return PageModel(
      strokes: strokes,
      backgroundStrokes: backgroundStrokes,
      images: images,
      pageHeight: pageHeight,
      pageWidth: pageWidth,
      pageColor: pageColor,
      pageID: pageID,
      verticalSpaces: verticalSpaces,
      horizontalSpaces: horizontalSpaces,
      tiles: [[]],
      backgroundImage: backgroundImage,
    );
  }








}