import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/widgets.dart';
import 'package:betternotes/core/utils/id_generator.dart';
import 'dart:typed_data';


class ImageModel {
  double width;
  double height;
  Offset position;
  double rotation;
  //final int path;
  final ui.Image image;
  final int imageID;

  ImageModel({
    required this.height,
    required this.width,
    required this.position,
    required this.rotation,
    required this.image,
    //required this.path,
    int? imageID
  }) : imageID = imageID ?? IdGenerator.next();

  ImageModel copyWith({
    double? height,
    double? width,
    Offset? position,
    //int? path,

    int? imageID
  }) {
    return ImageModel(
      height: height ?? this.height,
      width: width ?? this.width,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      image: image ?? this.image,
      //path : path ?? this.path,
      imageID: imageID ?? this.imageID
    );
  }

  Rect getBounds() {
    return Rect.fromLTRB(position.dx, position.dy, position.dx+width, position.dy+height);
  }

  ImageModel copy() {
    return ImageModel(
      position: position,
      height: height,
      width: width,
      rotation: rotation,
      image: image,
      //path: path,
      imageID: IdGenerator.next(),
    );
  }

  ImageModel copyWithID() {
    return ImageModel(
      position: position,
      height: height,
      width: width,
      rotation: rotation,
      image: image,
      imageID: imageID,
    );
  }




  Map<String, dynamic> toJson() {
    return {
      'dx': position.dx,
      'dy': position.dy,
      'rotation': rotation,
      'width': width,
      'height': height,
      'imageID': imageID,
    };
  }

  Future<Uint8List> toBytes() async {
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Image konnte nicht konvertiert werden');
    }

    final pngBytes = byteData.buffer.asUint8List();
    final builder = BytesBuilder();
    final width = ByteData(8)..setFloat64(0, this.width, Endian.little);
    final height = ByteData(8)..setFloat64(0, this.height, Endian.little);
    final positionX = ByteData(8)..setFloat64(0, position.dx, Endian.little);
    final positionY = ByteData(8)..setFloat64(0, position.dy, Endian.little);
    final rotation = ByteData(8)..setFloat64(0, this.rotation, Endian.little);
    final imageID = ByteData(8)..setUint64(0, this.imageID, Endian.little);
    final pngLength = ByteData(8)..setUint64(0, pngBytes.length, Endian.little);

    builder.add(width.buffer.asUint8List());
    builder.add(height.buffer.asUint8List());
    builder.add(positionX.buffer.asUint8List());
    builder.add(positionY.buffer.asUint8List());
    builder.add(rotation.buffer.asUint8List());
    builder.add(imageID.buffer.asUint8List());
    builder.add(pngLength.buffer.asUint8List());
    builder.add(pngBytes);

    return builder.takeBytes();
  }

  static Future<ImageModel> fromBytes(Uint8List bytes) async {
    final data = ByteData.sublistView(bytes);

    int offset = 0;
    final width = data.getFloat64(offset, Endian.little,);
    offset += 8;
    final height = data.getFloat64(offset, Endian.little,);
    offset += 8;
    final positionX = data.getFloat64(offset, Endian.little,);
    offset += 8;
    final positionY = data.getFloat64(offset, Endian.little,);
    offset += 8;
    final rotation = data.getFloat64(offset, Endian.little,);
    offset += 8;
    final imageID = data.getUint64(offset, Endian.little,);
    offset += 8;
    final pngLength = data.getUint64(offset, Endian.little,);
    offset += 8;
    final pngBytes = bytes.sublist(offset, offset + pngLength,);
    final codec = await ui.instantiateImageCodec(pngBytes,);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    return ImageModel(
      width: width,
      height: height,
      position: Offset(
        positionX,
        positionY,
      ),
      rotation: rotation,
      image: image,
      imageID: imageID,
    );
  }



  static Future<ImageModel?> fromJson(Map<String, dynamic> json, List<ArchiveFile> archivedImages) async {


    final imageID = json['imageID'];


    final fileName = "$imageID.png";

    ArchiveFile? png;

    try {
      png = archivedImages.firstWhere((f) => f.name == fileName);
    } catch (_) {
      print("Couldnt find png image file in archive");
      return null;
    }

    final bytes = png.content as Uint8List;

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;


    /*
    final bytes = await loadImageBytes(json['imageID']);

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

     */




    return ImageModel(
      width: json['width']?.toDouble() ?? 0.0,
      height: json['height']?.toDouble() ?? 0.0,
      position: Offset(
        json['dx']?.toDouble() ?? 0.0,
        json['dy']?.toDouble() ?? 0.0,
      ),
      rotation: json['rotation']?.toDouble() ?? 0.0,
      image: uiImage,
      imageID: imageID,
    );
  }




}