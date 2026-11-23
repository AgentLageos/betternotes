import 'dart:io';

import 'package:betternotes/core/bnf/bnf_repository.dart';
import 'package:betternotes/core/providers/global_providers.dart';
import 'package:betternotes/features/editor/data/document_file.dart';
import 'package:betternotes/features/editor/models/page/document_model.dart';
import 'package:betternotes/features/editor/models/page/page_model.dart';
import 'package:betternotes/features/editor/models/page/point.dart';
import 'package:betternotes/features/editor/models/page/stroke.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Undo/redo of page changes through [DocumentsNotifier], with a real `.bnf` file behind it.

void main() {
  late Directory dir;
  late ProviderContainer container;
  late String path;
  late List<PageModel> pages; // A, B, C (heights 100, 200, 300)

  DocumentModel doc() => container.read(documentsProvider).single;
  List<int> ids(List<int> indexes) => [for (final i in indexes) pages[i].pageID];

  Future<int> open() async {
    final docID = await container.read(documentsProvider.notifier).loadDoc(path);
    return docID!;
  }

  /// Closes the document and waits until background tile rendering has finished, so nothing
  /// touches the container after the test.
  Future<void> settle(int docID) async {
    final notifier = container.read(documentsProvider.notifier);
    for (var i = 0; i < 200 && (notifier.pageIDsBeingRendered.isNotEmpty || notifier.isolateQueue.isNotEmpty); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await notifier.closeDoc(docID);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('undo_redo_test');
    path = p.join(dir.path, 'doc.bnf');
    pages = [for (final h in [100.0, 200.0, 300.0]) PageModel(pageWidth: 210, pageHeight: h)];
    final model = DocumentModel(
      pages: pages,
      created: DateTime(2026),
      author: 'a',
      title: 't',
      pageList: [for (final page in pages) page.pageID],
      pageHeights: [for (final page in pages) page.pageHeight],
    );
    await (await createDocumentFile(path, model)).close();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await dir.delete(recursive: true);
  });

  testWidgets('add page, undo, redo', (tester) async {
    await tester.runAsync(() async {
      final docID = await open();
      final notifier = container.read(documentsProvider.notifier);
      final added = PageModel(pageWidth: 210, pageHeight: 50);

      await notifier.modifyPages(docID, [added], [1], []);
      expect(doc().pageList, [pages[0].pageID, added.pageID, pages[1].pageID, pages[2].pageID]);
      expect(doc().pageHeights, [100, 50, 200, 300]);

      await notifier.undo(docID);
      expect(doc().pageList, ids([0, 1, 2]));
      expect(doc().pageHeights, [100, 200, 300]);

      await notifier.redo(docID);
      expect(doc().pageList, [pages[0].pageID, added.pageID, pages[1].pageID, pages[2].pageID]);
      expect(doc().pageHeights, [100, 50, 200, 300]);
      await settle(docID);
    });
  });

  testWidgets('delete page, undo, redo, undo', (tester) async {
    await tester.runAsync(() async {
      final docID = await open();
      final notifier = container.read(documentsProvider.notifier);

      await notifier.modifyPages(docID, [], [], [pages[1].pageID]);
      expect(doc().pageList, ids([0, 2]));
      expect(doc().pageHeights, [100, 300]);

      await notifier.undo(docID);
      expect(doc().pageList, ids([0, 1, 2]));
      expect(doc().pageHeights, [100, 200, 300]);

      await notifier.redo(docID);
      expect(doc().pageList, ids([0, 2]));
      expect(doc().pageHeights, [100, 300]);

      await notifier.undo(docID);
      expect(doc().pageList, ids([0, 1, 2]));
      expect(doc().pageHeights, [100, 200, 300]);
      await settle(docID);
    });
  });

  testWidgets('stroke undo/redo on a loaded page', (tester) async {
    await tester.runAsync(() async {
      final docID = await open();
      final notifier = container.read(documentsProvider.notifier);
      final stroke = Stroke(color: Colors.black, width: 1, points: [PointModel(pos: const Offset(1, 1), width: 1)]);

      await notifier.modifyElements(docID, pages[0].pageID, [stroke], [], [], []);
      PageModel first() => doc().pages.firstWhere((p) => p.pageID == pages[0].pageID);
      expect(first().strokes.map((s) => s.strokeID), [stroke.strokeID]);

      await notifier.undo(docID);
      expect(first().strokes, isEmpty);
      await notifier.redo(docID);
      expect(first().strokes.map((s) => s.strokeID), [stroke.strokeID]);
      await settle(docID);
    });
  });

  testWidgets('page changes are saved, deleted pages dropped on close', (tester) async {
    await tester.runAsync(() async {
      final docID = await open();
      final notifier = container.read(documentsProvider.notifier);
      final added = PageModel(pageWidth: 210, pageHeight: 50);

      await notifier.modifyPages(docID, [added], [3], [pages[0].pageID]);
      await settle(docID);

      final repo = await BnfRepository.open(path);
      expect(repo.metadata['pageList'], [pages[1].pageID, pages[2].pageID, added.pageID]);
      expect(repo.metadata['pageHeights'], [200, 300, 50]);
      expect(repo.pageIDs, {pages[1].pageID, pages[2].pageID, added.pageID});
      expect(repo.garbageBytes, 0);
    });
  });

  testWidgets('undo/redo of a stroke on a page that is no longer loaded', (tester) async {
    await tester.runAsync(() async {
      final docID = await open();
      final notifier = container.read(documentsProvider.notifier);
      final stroke = Stroke(color: Colors.black, width: 1, points: [PointModel(pos: const Offset(1, 1), width: 1)]);
      await notifier.modifyElements(docID, pages[0].pageID, [stroke], [], [], []);

      // Add pages and move the window away so page A is no longer loaded.
      await notifier.modifyPages(docID, [for (var i = 0; i < 5; i++) PageModel()], [3, 4, 5, 6, 7], []);
      await notifier.setCurrentPageIndex(docID, 7);
      expect(doc().pages.any((p) => p.pageID == pages[0].pageID), isFalse);

      await notifier.undo(docID); // the page add
      await notifier.setCurrentPageIndex(docID, 2);
      await notifier.updateIsolatedPages(docID);
      expect(doc().pages.any((p) => p.pageID == pages[0].pageID && !p.isTemp), isFalse);

      await notifier.undo(docID); // the stroke on A, which is not loaded
      expect(doc().commandIndex, 0);
      final repo = await BnfRepository.open(path);
      expect(repo.pageIDs, contains(pages[0].pageID));

      await notifier.setCurrentPageIndex(docID, 0);
      await notifier.updateIsolatedPages(docID);
      PageModel first() => doc().pages.firstWhere((p) => p.pageID == pages[0].pageID);
      expect(first().strokes, isEmpty);

      // Redo while A is loaded again.
      await notifier.redo(docID);
      expect(first().strokes.map((s) => s.strokeID), [stroke.strokeID]);
      await settle(docID);
    });
  });

  testWidgets('deleting a page that is not loaded can be undone', (tester) async {
    await tester.runAsync(() async {
      final docID = await open(); // window: A, B (C is not loaded)
      final notifier = container.read(documentsProvider.notifier);
      expect(doc().pages.any((p) => p.pageID == pages[2].pageID && !p.isTemp), isFalse);

      await notifier.modifyPages(docID, [], [], [pages[2].pageID]);
      expect(doc().pageList, ids([0, 1]));

      await notifier.undo(docID);
      expect(doc().pageList, ids([0, 1, 2]));
      expect(doc().pageHeights, [100, 200, 300]);
      await notifier.setCurrentPageIndex(docID, 2);
      await notifier.updateIsolatedPages(docID);
      expect(doc().pages.firstWhere((p) => p.pageID == pages[2].pageID).pageHeight, 300);
      await settle(docID);
    });
  });

  testWidgets('moving a selection does not change the undo history', (tester) async {
    await tester.runAsync(() async {
      final docID = await open();
      final notifier = container.read(documentsProvider.notifier);
      final stroke = Stroke(color: Colors.black, width: 1, strokeType: StrokeType.dotted,
          points: [PointModel(pos: const Offset(1, 1), width: 1), PointModel(pos: const Offset(2, 2), width: 1)]);
      await notifier.modifyElements(docID, pages[0].pageID, [stroke], [], [], []);

      // What page_widget does when a selection is moved: a moved copy with the same ID replaces it.
      final original = doc().pages.first.strokes.single;
      final moved = original.copyWith(points: [for (final p in original.points) p.copyWith(pos: p.pos + const Offset(10, 0))]);
      await notifier.modifyElements(docID, pages[0].pageID, [moved], [], [original.strokeID], []);
      expect(doc().pages.first.strokes.single.points.first.pos, const Offset(11, 1));
      expect(doc().pages.first.strokes.single.strokeType, StrokeType.dotted);

      await notifier.undo(docID);
      expect(doc().pages.first.strokes.single.points.first.pos, const Offset(1, 1));
      await notifier.undo(docID);
      expect(doc().pages.first.strokes, isEmpty);
      await notifier.redo(docID);
      expect(doc().pages.first.strokes.single.points.first.pos, const Offset(1, 1));
      await notifier.redo(docID);
      expect(doc().pages.first.strokes.single.points.first.pos, const Offset(11, 1));
      await settle(docID);
    });
  });

  testWidgets('history is capped and undone commands are dropped by a new one', (tester) async {
    await tester.runAsync(() async {
      final docID = await open();
      final notifier = container.read(documentsProvider.notifier);
      Stroke dot(double x) => Stroke(color: Colors.black, width: 1, points: [PointModel(pos: Offset(x, 1), width: 1)]);

      for (var i = 0; i < 12; i++) {
        await notifier.modifyElements(docID, pages[0].pageID, [dot(i.toDouble())], [], [], []);
      }
      expect(doc().commands.length, doc().maxAmountCommands);
      expect(doc().commandIndex, doc().maxAmountCommands);

      await notifier.undo(docID);
      await notifier.undo(docID);
      await notifier.modifyElements(docID, pages[0].pageID, [dot(50)], [], [], []);
      expect(doc().commandIndex, doc().commands.length);
      expect(doc().commands.length, doc().maxAmountCommands - 1);
      expect(doc().pages.first.strokes.length, 11);
      await settle(docID);
    });
  });
}
