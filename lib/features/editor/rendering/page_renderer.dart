import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/page/page_model.dart';
import '../models/page/stroke.dart';
import 'dart_page_renderer.dart';
import 'page_tiles.dart';

export 'page_tiles.dart' show PageKey;

/// Renders the strokes and backgrounds of the loaded pages of all open documents (R1-01).
///
/// The document side (`DocumentNotifier`) owns the page data (D4) and only reports changes here as
/// deltas; it never touches tiles or images. The methods mirror the planned Rust API
/// (`open_page`, `close_page`, `add_strokes`/`remove_strokes`, `set_background`), so the Rust
/// renderer can be put behind this interface without changing the callers.
///
/// Every call passes the page as it is after the change. A renderer that is still working on an
/// older version renders the newer one afterwards.
abstract class PageRenderer {
  /// [page] is loaded and shown (it entered the loaded window). Renders it, unless it is
  /// rendered already.
  void showPage(PageKey key, PageModel page);

  /// The pages [keys] left the loaded window: drop their render state and cancel pending work.
  void hidePages(Iterable<PageKey> keys);

  /// Document [docID] was closed: drop the render state of all its pages.
  void closeDocument(int docID);

  /// Strokes [added] were added to and [removedStrokeIDs] removed from the shown page [page].
  ///
  /// Completes when the change is visible (or can't become visible, e.g. the page was hidden), so
  /// the caller can keep drawing a preview of the strokes until then without a gap.
  Future<void> updateStrokes(PageKey key, PageModel page, List<Stroke> added, List<int> removedStrokeIDs);

  /// The background strokes (line pattern) of the shown page [page] changed.
  Future<void> updateBackground(PageKey key, PageModel page);

  /// The size of the shown page [page] changed: render it from scratch.
  Future<void> resizePage(PageKey key, PageModel page);
}

/// The Dart renderer (default; the fallback on platforms the mesh renderer isn't tested on).
final dartPageRendererProvider = Provider<PageRenderer>((ref) => DartPageRenderer(ref));
