import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/page/page_model.dart';
import '../models/page/stroke.dart';
import '../models/page/tile.dart';

/// Render state of the current Dart renderer: one tile grid per page, keyed by document and page
/// (the same file can be open twice, with the same page IDs).
///
/// Kept out of [PageModel] (P4-01): pages are immutable values shared with older states and the
/// undo history, while tiles are a mutable cache that the renderer updates in place.
/// Only [DartPageRenderer] writes to it; widgets read it. Replaced by the Rust renderer in Phase 5 (R5-03).

/// Identifies a page of an open document.
typedef PageKey = ({int docID, int pageID});

/// Tile size in mm.
const Rect tileRect = Rect.fromLTWH(0, 0, 20, 20);

/// The tile grid of one page. [version] changes on every update, so widgets watching the
/// provider rebuild even though the grid itself is updated in place.
class PageTiles {
  const PageTiles(this.grid, this.version);

  final List<List<Tile>> grid;
  final int version;

  bool get isEmpty => grid.isEmpty || grid.first.isEmpty;
}

class PageTilesNotifier extends Notifier<Map<PageKey, PageTiles>> {
  @override
  Map<PageKey, PageTiles> build() => const {};

  /// Stores [grid] as the tiles of [key]. The images of a replaced grid are disposed.
  void set(PageKey key, List<List<Tile>> grid) {
    final old = state[key];
    state = {...state, key: PageTiles(grid, (old?.version ?? 0) + 1)};
    if (old != null && !identical(old.grid, grid)) disposeTileGrid(old.grid);
  }

  /// Signals that the grid of [key] was updated in place.
  void touch(PageKey key) {
    final tiles = state[key];
    if (tiles == null) return;
    state = {...state, key: PageTiles(tiles.grid, tiles.version + 1)};
  }

  /// Drops the tiles of [keys] (pages that left the loaded window) and disposes their images.
  void remove(Iterable<PageKey> keys) {
    final drop = keys.where(state.containsKey).toSet();
    if (drop.isEmpty) return;
    final dropped = [for (final key in drop) state[key]!.grid];
    state = {
      for (final entry in state.entries)
        if (!drop.contains(entry.key)) entry.key: entry.value,
    };
    dropped.forEach(disposeTileGrid);
  }

  /// Drops all tiles of document [docID] (closed).
  void removeDocument(int docID) => remove([for (final key in state.keys) if (key.docID == docID) key]);
}

final pageTilesProvider = NotifierProvider<PageTilesNotifier, Map<PageKey, PageTiles>>(PageTilesNotifier.new);

/// Disposes the images of all tiles in [grid] (R0-01). Only call this once no widget paints the
/// grid any more: the state change replacing it rebuilds the painters before the next frame.
void disposeTileGrid(List<List<Tile>> grid) {
  for (final row in grid) {
    for (final tile in row) {
      tile.disposeImages();
    }
  }
}

/// Empty tile grid covering a page of the given size. The last row and column are cut to the
/// page size.
List<List<Tile>> createTileGrid(double pageWidth, double pageHeight) {
  final rows = (pageHeight / tileRect.height).ceil();
  final cols = (pageWidth / tileRect.width).ceil();
  return [
    for (int row = 0; row < rows; row++)
      [
        for (int col = 0; col < cols; col++)
          Tile(Rect.fromLTWH(
            col * tileRect.width,
            row * tileRect.height,
            col >= cols - 1 ? pageWidth - (cols - 1) * tileRect.width : tileRect.width,
            row >= rows - 1 ? pageHeight - (rows - 1) * tileRect.height : tileRect.height,
          )),
      ],
  ];
}

/// New tile grid for [page] with all its strokes rendered.
Future<List<List<Tile>>> renderPageTiles(PageModel page) async {
  final grid = createTileGrid(page.pageWidth, page.pageHeight);
  await updateTileGrid(grid, page.strokes, page.strokes, const [], page.backgroundStrokes);
  return grid;
}

/// Updates [tiles] in place: removes [erasedStrokeIDs], adds [newStrokes], replaces the background
/// with [newBackgroundStrokes] if not empty, and re-renders the changed tiles.
/// [pageStrokes] are all strokes of the page after the change.
Future<void> updateTileGrid(List<List<Tile>> tiles, List<Stroke> pageStrokes, List<Stroke> newStrokes,
    List<int> erasedStrokeIDs, List<Stroke> newBackgroundStrokes) async {
  final Set<Point<int>> changedTiles = {};

  for (int i = 0; i < tiles.length; i++) {
    for (int j = 0; j < tiles[i].length; j++) {
      if (newBackgroundStrokes.isNotEmpty) {
        tiles[i][j].addBackgroundStrokesAsAbstractStrokes(newBackgroundStrokes);
      }

      if (erasedStrokeIDs.isNotEmpty &&
          tiles[i][j].aStrokes.any((s) => erasedStrokeIDs.contains(s.strokeID))) {
        tiles[i][j].aStrokes.removeWhere((s) => erasedStrokeIDs.contains(s.strokeID));
        changedTiles.add(Point(i, j));
      }

      final changed = tiles[i][j].addStrokesAsAbstractStrokes(newStrokes);
      if (changed || newBackgroundStrokes.isNotEmpty) changedTiles.add(Point(i, j));
    }
  }

  await Future.wait([
    for (final point in changedTiles)
      () async {
        if (newBackgroundStrokes.isNotEmpty) {
          await tiles[point.x][point.y].renderBackground(newBackgroundStrokes);
        }
        await tiles[point.x][point.y].renderAbstractStrokes(pageStrokes);
      }(),
  ]);
}
