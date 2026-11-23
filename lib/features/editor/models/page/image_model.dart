import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/widgets.dart';
import 'package:betternotes/core/utils/id_generator.dart';
import 'dart:typed_data';


/// Encoded form (PNG, JPEG, ...) of a [ui.Image], computed at most once and shared by all copies of an
/// [ImageModel] (they all point to the same image).
class _EncodedImage {
  _EncodedImage(this.bytes);

  Uint8List? bytes;
}

class ImageModel {
  double width;
  double height;
  Offset position;
  double rotation;
  final ui.Image image;
  final int imageID;
  final _EncodedImage _encoded;

  /// [encodedBytes]: the file bytes (PNG, JPEG, ...) [image] was decoded from, if known.
  /// They are stored as they are, so the image isn't re-encoded on save.
  ImageModel({
    required this.height,
    required this.width,
    required this.position,
    required this.rotation,
    required this.image,
    //required this.path,
    int? imageID,
    Uint8List? encodedBytes,
  }) : imageID = imageID ?? IdGenerator.next(), _encoded = _EncodedImage(encodedBytes);

  ImageModel._shared({
    required this.height,
    required this.width,
    required this.position,
    required this.rotation,
    required this.image,
    required this.imageID,
    required _EncodedImage encoded,
  }) : _encoded = encoded;

  ImageModel copyWith({
    double? height,
    double? width,
    Offset? position,
    //int? path,

    int? imageID
  }) {
    return ImageModel._shared(
      height: height ?? this.height,
      width: width ?? this.width,
      position: position ?? this.position,
      rotation: rotation,
      image: image,
      imageID: imageID ?? this.imageID,
      encoded: _encoded,
    );
  }

  Rect getBounds() {
    return Rect.fromLTRB(position.dx, position.dy, position.dx+width, position.dy+height);
  }

  ImageModel copy() {
    return ImageModel._shared(
      position: position,
      height: height,
      width: width,
      rotation: rotation,
      image: image,
      imageID: IdGenerator.next(),
      encoded: _encoded,
    );
  }

  ImageModel copyWithID() {
    return ImageModel._shared(
      position: position,
      height: height,
      width: width,
      rotation: rotation,
      image: image,
      imageID: imageID,
      encoded: _encoded,
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

  /// Encoded bytes of [image]: the bytes it was decoded from, or a PNG encoded on the first
  /// call and cached.
  Future<Uint8List> encodedBytes() async {
    final cached = _encoded.bytes;
    if (cached != null) return cached;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Image could not be converted');
    }
    return _encoded.bytes = byteData.buffer.asUint8List();
  }

  /// ID of the image block holding [encoded] in a `.bnf` file: a 53-bit FNV-1a hash of the content,
  /// so the same picture is stored only once per file. (53 bits: exact integers on the web too.)
  static int contentID(Uint8List encoded) {
    // FNV-1a, 64 bit (wrapping multiplication on the native int).
    var hash = 0xcbf29ce484222325;
    for (final byte in encoded) {
      hash ^= byte;
      hash *= 0x100000001b3;
    }
    return hash & 0x1FFFFFFFFFFFFF;
  }

  /// Encodes the placement of this image plus a reference to its image block.
  /// Returns the bytes for the page record and the image block (ID + encoded image) to store with it.
  Future<({Uint8List bytes, int blockID, Uint8List image})> encode() async {
    final encoded = await encodedBytes();
    final blockID = contentID(encoded);
    final data = ByteData(56)
      ..setFloat64(0, width, Endian.little)
      ..setFloat64(8, height, Endian.little)
      ..setFloat64(16, position.dx, Endian.little)
      ..setFloat64(24, position.dy, Endian.little)
      ..setFloat64(32, rotation, Endian.little)
      ..setUint64(40, imageID, Endian.little)
      ..setUint64(48, blockID, Endian.little);
    return (bytes: data.buffer.asUint8List(), blockID: blockID, image: encoded);
  }

  /// Length of the bytes produced by [encode].
  static const int encodedLength = 56;

  /// Decodes bytes produced by [encode]. [readImage] returns the content of an image block.
  static Future<ImageModel> decode(Uint8List bytes, Future<Uint8List?> Function(int blockID) readImage) async {
    final data = ByteData.sublistView(bytes);
    final blockID = data.getUint64(48, Endian.little);
    final encoded = await readImage(blockID);
    if (encoded == null) {
      throw Exception('Image block $blockID is missing');
    }
    final codec = await ui.instantiateImageCodec(encoded);
    final frame = await codec.getNextFrame();
    return ImageModel(
      width: data.getFloat64(0, Endian.little),
      height: data.getFloat64(8, Endian.little),
      position: Offset(data.getFloat64(16, Endian.little), data.getFloat64(24, Endian.little)),
      rotation: data.getFloat64(32, Endian.little),
      image: frame.image,
      imageID: data.getUint64(40, Endian.little),
      encodedBytes: encoded,
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

    final bytes = png.content;

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;


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