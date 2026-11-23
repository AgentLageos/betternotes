import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// FRB's own Int64List (BigInt-based on the web) for i64 vectors.
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart' as frb show Int64List;

import '../../../src/rust/api/renderer.dart';
import '../models/page/page_model.dart';
import '../models/page/stroke.dart';
import 'page_renderer.dart';
import 'rust_tile_store.dart';
import 'viewport_tracker.dart';

/// [PageRenderer] backed by the Rust renderer (R1-04): forwards page changes as deltas to Rust,
/// which renders tiles into the [RustTileStore]. `DrawerWidget` paints them and registers the page
/// with the [ViewportTracker].
///
/// The page colour is still painted by Flutter (`PageWidget`); the Rust background layer only
/// contains the line pattern (transparent page colour).
class RustPageRenderer implements PageRenderer {
  RustPageRenderer(this.store);

  final RustTileStore store;

  /// Pages open in Rust, with the latest version reported.
  final Map<PageKey, PageModel> _open = {};

  @override
  void showPage(PageKey key, PageModel page) {
    if (_open.containsKey(key)) {
      _open[key] = page;
      return;
    }
    _open[key] = page;
    store.openPage(key);
    rendererOpenPage(doc: key.docID, page: key.pageID, width: page.pageWidth, height: page.pageHeight, color: 0);
    rendererSetBackground(doc: key.docID, page: key.pageID, color: 0, strokes: _strokeData(page.backgroundStrokes));
    rendererAddStrokes(doc: key.docID, page: key.pageID, strokes: _strokeData(page.strokes));
  }

  @override
  void hidePages(Iterable<PageKey> keys) {
    for (final key in keys) {
      if (_open.remove(key) == null) continue;
      rendererClosePage(doc: key.docID, page: key.pageID);
      store.closePage(key);
    }
  }

  @override
  void closeDocument(int docID) {
    _open.removeWhere((key, _) => key.docID == docID);
    rendererCloseDocument(doc: docID);
    store.closeDocument(docID);
  }

  /// Completes once the visible tiles show the change, so callers can keep drawing a preview
  /// (e.g. the stroke just drawn) until then without a gap.
  @override
  Future<void> updateStrokes(PageKey key, PageModel page, List<Stroke> added, List<int> removedStrokeIDs) {
    if (!_open.containsKey(key)) return Future.value();
    _open[key] = page;
    final pending = <PendingTile>[
      if (removedStrokeIDs.isNotEmpty)
        ...rendererRemoveStrokes(doc: key.docID, page: key.pageID, ids: frb.Int64List.fromList(removedStrokeIDs)),
      if (added.isNotEmpty)
        ...rendererAddStrokes(doc: key.docID, page: key.pageID, strokes: _strokeData(added)),
    ];
    return store.waitFor(pending);
  }

  @override
  Future<void> updateBackground(PageKey key, PageModel page) async {
    if (!_open.containsKey(key)) return;
    _open[key] = page;
    rendererSetBackground(doc: key.docID, page: key.pageID, color: 0, strokes: _strokeData(page.backgroundStrokes));
  }

  @override
  Future<void> resizePage(PageKey key, PageModel page) async {
    if (!_open.containsKey(key)) return;
    _open[key] = page;
    rendererResizePage(doc: key.docID, page: key.pageID, width: page.pageWidth, height: page.pageHeight);
  }

  /// Strokes that are not drawn into the tiles because Flutter draws a preview of them (being
  /// erased, or selected and moved). Replaces the previous set.
  void setHidden(PageKey key, Iterable<int> strokeIDs) {
    if (!_open.containsKey(key)) return;
    rendererSetHidden(doc: key.docID, page: key.pageID, ids: frb.Int64List.fromList(strokeIDs.toList()));
  }

  static List<StrokeData> _strokeData(List<Stroke> strokes) => [
        for (final stroke in strokes)
          StrokeData(
            id: stroke.strokeID,
            color: stroke.color.toARGB32(),
            points: Float32List.fromList([
              for (final p in stroke.points) ...[p.pos.dx, p.pos.dy, p.width],
            ]),
          ),
      ];
}

/// Tile images from Rust, shared by all documents. Created on first use; only touched when the
/// Rust renderer is enabled (the Rust library must be loaded).
final rustTileStoreProvider = Provider<RustTileStore>((ref) {
  final store = RustTileStore();
  ref.onDispose(store.dispose);
  return store;
});

final viewportTrackerProvider = Provider<ViewportTracker>((ref) => ViewportTracker(ref.watch(rustTileStoreProvider)));

final rustPageRendererProvider = Provider<RustPageRenderer>((ref) => RustPageRenderer(ref.watch(rustTileStoreProvider)));
