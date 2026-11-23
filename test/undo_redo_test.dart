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

  testWidgets('undo of a stroke on a page that is no longer loaded', (tester) async {
    await tester.runAsync(() async {
      final docID = await open();
      final notifier = container.read(documentsProvider.notifier);
      final stroke = Stroke(color: Colors.black, width: 1, points: [PointModel(pos: const Offset(1, 1), width: 1)]);
      await notifier.modifyElements(docID, pages[0].pageID, [stroke], [], [], []);

      // Scroll far away so page A leaves the loaded window, then undo.
      await notifier.modifyPages(docID, [for (var i = 0; i < 5; i++) PageModel()], [3, 4, 5, 6, 7], []);
      await notifier.setCurrentPageIndex(docID, 7);
      await notifier.undo(docID); // undoes the page add
      await notifier.undo(docID); // should undo the stroke on A
      await notifier.setCurrentPageIndex(docID, 0);
      await notifier.updateIsolatedPages(docID);
      expect(doc().pages.firstWhere((p) => p.pageID == pages[0].pageID).strokes, isEmpty);
    });
  }, skip: true); // known issue, P4-02: undo on unloaded pages does nothing
}
