
import 'package:flutter/widgets.dart';
import 'package:betternotes/core/utils/id_generator.dart';
import 'package:betternotes/features/editor/models/page/point.dart';

import 'dart:typed_data';
import 'dart:ui';


enum StrokeType {
  normal,
  dotted,

}
extension StrokeTypeExtension on StrokeType {
  String toJson() => name;
  static StrokeType fromJson(String value) => StrokeType.values.firstWhere((e) => e.name == value);
}

/// How the renderer builds a stroke's shape (R8-01): freehand strokes are smoothed through their
/// points, shapes and lines keep their straight segments and sharp corners.
enum StrokeKind {
  freehand,
  shape,
}
extension StrokeKindExtension on StrokeKind {
  String toJson() => name;
  static StrokeKind fromJson(String value) => StrokeKind.values.firstWhere((e) => e.name == value);
}

/// A stroke. Immutable (D1): all fields are final, changes produce a new stroke.
///
/// [points] is stored as given, without copying, so the stroke being drawn can grow its own list
/// cheaply. Once a stroke goes into a document it must not change any more: the document stores
/// [frozen] strokes, whose point list is unmodifiable.
class Stroke {
  final Color color;
  final double width;
  final List<PointModel> points;
  final int strokeID;

  final StrokeType strokeType;

  /// Freehand (smoothed) or shape (straight segments). Defaults to freehand.
  final StrokeKind kind;

  Stroke({
    required this.color,
    required this.width,
    required this.points,
    int? strokeID,
    StrokeType? strokeType,
    StrokeKind? kind,
    bool frozen = false,
  }) : strokeID = strokeID ?? IdGenerator.next(),
      strokeType = strokeType ?? StrokeType.normal,
      kind = kind ?? StrokeKind.freehand,
      _isFrozen = frozen
  ;

  /// Whether [points] is known to be unmodifiable (set by [frozen]).
  final bool _isFrozen;

  Stroke copyWith({
    Color? color,
    double? width,
    List<PointModel>? points,
    int? strokeID,
    StrokeType? strokeType,
    StrokeKind? kind,
  }) {
    return Stroke(
      color: color ?? this.color,
      width: width ?? this.width,
      points: points ?? this.points,
      strokeID : strokeID ?? this.strokeID,
      strokeType: strokeType ?? this.strokeType,
      kind: kind ?? this.kind,
      frozen: points == null && _isFrozen,
    );
  }

  Rect getStrokeBounds() {

    double minX;
    double maxX;
    double minY;
    double maxY;

    if (width==-1) {
      minX = points.first.pos.dx-points.first.width;
      maxX = points.first.pos.dx+points.first.width;
      minY = points.first.pos.dy-points.first.width;
      maxY = points.first.pos.dy+points.first.width;

      for (var p in points) {
        if (p.pos.dx-p.width < minX) minX = p.pos.dx-p.width;
        if (p.pos.dx+p.width > maxX) maxX = p.pos.dx+p.width;
        if (p.pos.dy-p.width < minY) minY = p.pos.dy-p.width;
        if (p.pos.dy+p.width > maxY) maxY = p.pos.dy+p.width;
      }

    }
    else {
      minX = points.first.pos.dx-width;
      maxX = points.first.pos.dx+width;
      minY = points.first.pos.dy-width;
      maxY = points.first.pos.dy+width;

      for (var p in points) {
        if (p.pos.dx-width < minX) minX = p.pos.dx-width;
        if (p.pos.dx+width > maxX) maxX = p.pos.dx+width;
        if (p.pos.dy-width < minY) minY = p.pos.dy-width;
        if (p.pos.dy+width > maxY) maxY = p.pos.dy+width;
      }
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Same stroke with a new ID. Points are immutable, so the point list can be shared.
  Stroke copy() => copyWith(strokeID: IdGenerator.next());

  /// This stroke with an unmodifiable point list (for storing in a document).
  /// A single point is doubled, so every stored stroke has at least one segment (the renderer
  /// needs that for dots).
  Stroke frozen() => _isFrozen ? this : Stroke(
        color: color,
        width: width,
        points: List.unmodifiable(points.length == 1 ? [points.first, points.first] : points),
        strokeID: strokeID,
        strokeType: strokeType,
        kind: kind,
        frozen: true,
      );



  Map<String, dynamic> toJson() {
    return {
      'color': color.toARGB32(),
      'width': width,
      'points': points.map((point) => point.toJson()).toList(),
      'strokeType': strokeType.toJson(),
      'kind': kind.toJson(),
      //'strokeID': strokeID,
    };
  }

  factory Stroke.fromJson(Map<String, dynamic> json) {
    return Stroke(
      color: Color(json['color']),
      width: json['width']?.toDouble() ?? 0.0,
      points: (json['points'] as List).map((pointJson) => PointModel.fromJson(Map<String, dynamic>.from(pointJson))).toList(), //reconstruct  point from json
      strokeType: StrokeTypeExtension.fromJson(json['strokeType'] ?? 'normal'),
      kind: StrokeKindExtension.fromJson(json['kind'] ?? 'freehand'),
      //strokeID: json['strokeID'] ?? IdGenerator.next(), // strokeID from the JSON or a newly generated ID
    );
  }




  Uint8List toBytes() {
    final builder = BytesBuilder();
    final strokeId = ByteData(8)..setUint64(0, strokeID, Endian.little);

    builder.add(strokeId.buffer.asUint8List());

    final colorData = ByteData(4)..setUint32(0, color.toARGB32(), Endian.little);

    builder.add(colorData.buffer.asUint8List());

    final widthData = ByteData(8)..setFloat64(0, width, Endian.little);

    builder.add(widthData.buffer.asUint8List());

    final strokeType = ByteData(1)..setUint8(0, this.strokeType.index);

    builder.add(strokeType.buffer.asUint8List());

    builder.addByte(kind.index);

    final pointCount = ByteData(4)..setUint32(0, points.length, Endian.little);

    builder.add(pointCount.buffer.asUint8List());

    for (final point in points) {
      final x = ByteData(8)..setFloat64(0,point.pos.dx, Endian.little,);
      builder.add(x.buffer.asUint8List());

      final y = ByteData(8)..setFloat64(0, point.pos.dy, Endian.little,);
      builder.add(y.buffer.asUint8List());

      final pointWidth = ByteData(8)..setFloat64(0, point.width, Endian.little,);
      builder.add(pointWidth.buffer.asUint8List());
    }

    return builder.takeBytes();
  }



  static Stroke fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);

    int offset = 0;

    final strokeID = data.getUint64(offset, Endian.little,);

    offset += 8;

    final colorValue = data.getUint32(offset, Endian.little,);
    offset += 4;
    final color = Color(colorValue);

    final width = data.getFloat64(offset, Endian.little,);
    offset += 8;
    final strokeTypeIndex = data.getUint8(offset);
    offset += 1;
    final strokeType = StrokeType.values[strokeTypeIndex];
    final kind = StrokeKind.values[data.getUint8(offset)];
    offset += 1;

    final pointCount = data.getUint32(offset, Endian.little,);
    offset += 4;

    final points = <PointModel>[];

    for (int i = 0; i < pointCount; i++) {
      final x = data.getFloat64(offset, Endian.little,);

      offset += 8;

      final y = data.getFloat64(offset, Endian.little);

      offset += 8;

      final pointWidth = data.getFloat64(offset, Endian.little);

      offset += 8;

      points.add(PointModel(pos: Offset(x, y), width: pointWidth));
    }

    return Stroke(color: color, width: width, points: points, strokeID: strokeID, strokeType: strokeType, kind: kind).frozen();
  }



}
