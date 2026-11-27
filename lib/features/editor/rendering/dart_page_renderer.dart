import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/page/page_model.dart';
import '../models/page/stroke.dart';
import 'page_renderer.dart';
import 'page_tiles.dart';
import 'tile_renderer.dart';

/// The current Dart renderer behind [PageRenderer]: 20 mm tiles rendered by the [TileRenderer]
/// isolate pool, stored in [pageTilesProvider] where `DrawerWidget` paints them from.
/// Replaced by the Rust renderer in Phase 5 (R5-03).
class DartPageRenderer implements PageRenderer {
  DartPageRenderer(this._ref);

  final Ref _ref;

  /// Latest version of every shown page. A page is "wanted" while it is in here; a finished
  /// render is dropped if the page was hidden meanwhile, and repeated if the page changed.
  final Map<PageKey, PageModel> _pages = {};

  PageTilesNotifier get _tiles => _ref.read(pageTilesProvider.notifier);

  bool _hasTiles(PageKey key) => !(_ref.read(pageTilesProvider)[key]?.isEmpty ?? true);

  @override
  void showPage(PageKey key, PageModel page) {
    _pages[key] = page;
    if (!_hasTiles(key)) unawaited(_render(key));
  }

  @override
  void hidePages(Iterable<PageKey> keys) {
    final list = keys.toList();
    for (final key in list) {
      _pages.remove(key);
    }
    _tiles.remove(list);
  }

  @override
  void closeDocument(int docID) {
    _pages.removeWhere((key, _) => key.docID == docID);
    _tiles.removeDocument(docID);
  }

  @override
  Future<void> updateStrokes(PageKey key, PageModel page, List<Stroke> added, List<int> removedStrokeIDs) async {
    if (!_pages.containsKey(key)) return;
    _pages[key] = page;
    final tiles = _ref.read(pageTilesProvider)[key];
    if (tiles == null || tiles.isEmpty) return;      //the running render picks up the new version
    await updateTileGrid(tiles.grid, page.strokes, added, removedStrokeIDs, const []);
    if (_pages.containsKey(key)) _tiles.touch(key);
  }

  @override
  Future<void> updateBackground(PageKey key, PageModel page) async {
    if (!_pages.containsKey(key)) return;
    _pages[key] = page;
    final tiles = _ref.read(pageTilesProvider)[key];
    if (tiles == null || tiles.isEmpty) return;
    await updateTileGrid(tiles.grid, page.strokes, const [], const [], page.backgroundStrokes);
    if (_pages.containsKey(key)) _tiles.touch(key);
  }

  @override
  Future<void> resizePage(PageKey key, PageModel page) async {
    if (!_pages.containsKey(key)) return;
    _pages[key] = page;
    final grid = await renderPageTiles(page);
    if (_pages.containsKey(key)) {
      _tiles.set(key, grid);
    } else {
      disposeTileGrid(grid);
    }
  }

  /// Renders the tiles of page [key] in the isolate pool. If the page changed meanwhile, the newer
  /// version is rendered afterwards.
  Future<void> _render(PageKey key) async {
    final page = _pages[key];
    if (page == null) return;
    final grid = await _ref.read(tileRendererProvider).render(key, page, () => _pages.containsKey(key));
    if (grid == null) return;
    final current = _pages[key];
    if (current == null) {
      disposeTileGrid(grid);
      return;
    }
    _tiles.set(key, grid);
    if (!identical(current, page)) unawaited(_render(key));
  }
}
