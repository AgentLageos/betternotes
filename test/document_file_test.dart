import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:betternotes/core/bnf/bnf_repository.dart';
import 'package:betternotes/features/editor/data/document_file.dart';
import 'package:betternotes/features/editor/models/page/document_model.dart';
import 'package:betternotes/features/editor/models/page/image_model.dart';
import 'package:betternotes/features/editor/models/page/page_model.dart';
import 'package:betternotes/features/editor/models/page/point.dart';
import 'package:betternotes/features/editor/models/page/stroke.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Encodes and decodes pages through a real `.bnf` file (models + repository together).

Future<ui.Image> solidImage(int width, int height, Color color) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = color);
  return recorder.endRecording().toImage(width, height);
}

Stroke stroke(double x, {StrokeType type = StrokeType.normal}) => Stroke(
      color: const Color(0xFF112233),
      width: 1.5,
      strokeType: type,
      points: [
        PointModel(pos: Offset(x, 1), width: 1),
        PointModel(pos: Offset(x + 2, 3), width: 1.2),
      ],
    );

void expectSameStrokes(List<Stroke> actual, List<Stroke> expected) {
  expect(actual.length, expected.length);
  for (var i = 0; i < expected.length; i++) {
    expect(actual[i].strokeID, expected[i].strokeID);
    expect(actual[i].color.toARGB32(), expected[i].color.toARGB32());
    expect(actual[i].width, expected[i].width);
    expect(actual[i].strokeType, expected[i].strokeType);
    expect([for (final pt in actual[i].points) (pt.pos, pt.width)],
        [for (final pt in expected[i].points) (pt.pos, pt.width)]);
  }
}

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('document_file_test'));
  tearDown(() async => dir.delete(recursive: true));

  testWidgets('page with strokes and images survives save -> load', (tester) async {
    await tester.runAsync(() async {
      final picture = await solidImage(8, 4, Colors.red);
      final image = ImageModel(height: 20, width: 40, position: const Offset(5, 6), rotation: 0.5, image: picture);
      final copy = image.copy(); // same picture -> must be stored once
      final background = ImageModel(height: 297, width: 210, position: Offset.zero, rotation: 0, image: await solidImage(2, 3, Colors.blue));

      final page = PageModel(
        pageWidth: 210,
        pageHeight: 297,
        pageColor: const Color(0xFFFAFAFA),
        strokes: [stroke(1), stroke(10, type: StrokeType.dotted)],
        backgroundStrokes: [stroke(50)],
        images: [image, copy],
        backgroundImage: background,
        verticalSpaces: [5, 10],
        horizontalSpaces: [7],
      );
      final empty = PageModel(pageWidth: 100, pageHeight: 100);

      final doc = DocumentModel(
        pages: [page, empty],
        created: DateTime(2026, 1, 2),
        author: 'a',
        title: 't',
        pageList: [page.pageID, empty.pageID],
        pageHeights: [297, 100],
      );
      final path = p.join(dir.path, 'doc.bnf');
      await (await createDocumentFile(path, doc)).close();

      final repo = await BnfRepository.open(path);
      expect(repo.imageIDs.length, 2); // image + copy share one block, plus background
      expect(repo.metadata['pageList'], [page.pageID, empty.pageID]);

      final records = await repo.readPages([page.pageID, empty.pageID]);
      final loaded = await decodePages(repo, [records[page.pageID]!, records[empty.pageID]!]);

      final p0 = loaded[0];
      expect(p0.pageID, page.pageID);
      expect((p0.pageWidth, p0.pageHeight), (210.0, 297.0));
      expect(p0.pageColor.toARGB32(), 0xFFFAFAFA);
      expect(p0.verticalSpaces, [5.0, 10.0]);
      expect(p0.horizontalSpaces, [7.0]);
      expectSameStrokes(p0.strokes, page.strokes);
      expectSameStrokes(p0.backgroundStrokes, page.backgroundStrokes);
      expect([for (final i in p0.images) (i.imageID, i.position, i.width, i.height, i.rotation)],
          [for (final i in page.images) (i.imageID, i.position, i.width, i.height, i.rotation)]);
      expect((p0.images[0].image.width, p0.images[0].image.height), (8, 4));
      expect(p0.backgroundImage!.image.height, 3);
      expect(loaded[1].backgroundImage, isNull);
      expect(loaded[1].images, isEmpty);

      // Saving the loaded page again writes nothing: same bytes, images already stored.
      final encoded = await encodePages([p0]);
      expect(await repo.write(pages: encoded.pages, images: encoded.images, metadata: doc.toMetadata()), isFalse);
    });
  });

  testWidgets('original encoded bytes are stored as they are', (tester) async {
    await tester.runAsync(() async {
      final picture = await solidImage(3, 3, Colors.green);
      final png = (await picture.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final model = ImageModel(height: 1, width: 1, position: Offset.zero, rotation: 0, image: picture, encodedBytes: png);
      final encoded = await model.encode();
      expect(identical(encoded.image, png), isTrue);
      expect(encoded.blockID, ImageModel.contentID(png));
      expect(ImageModel.contentID(png), lessThan(1 << 53));
      expect(ImageModel.contentID(Uint8List.fromList([...png, 0])), isNot(encoded.blockID));
    });
  });

  test('models are immutable', () {
    final stroke = stroke1();
    final page = PageModel(strokes: [stroke]);
    expect(() => page.strokes.add(stroke), throwsUnsupportedError);
    expect(() => page.strokes.single.points.add(stroke.points.first), throwsUnsupportedError);
    expect(identical(stroke.points, page.strokes.single.points), isFalse); // frozen copy, caller's list untouched

    final doc = DocumentModel(pages: [page], created: DateTime(2026), author: '', title: '', pageList: [page.pageID]);
    expect(() => doc.pageList.add(1), throwsUnsupportedError);
    expect(() => doc.pages.clear(), throwsUnsupportedError);
    expect(doc.copyWith(currentPageIndex: 3).docID, doc.docID);
  });

  test('single-point strokes are stored with one segment', () {
    final dot = Stroke(color: Colors.black, width: 1, points: [const PointModel(pos: Offset(1, 2), width: 1)]);
    expect(dot.frozen().points.length, 2);
    expect(PageModel(strokes: [dot]).strokes.single.points.length, 2);
  });
}

Stroke stroke1() => Stroke(color: Colors.black, width: 1, points: [const PointModel(pos: Offset(1, 1), width: 1), const PointModel(pos: Offset(2, 2), width: 1)]);
