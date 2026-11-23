import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../src/rust/api/renderer.dart';
import 'page_tiles.dart' show PageKey;

/// Tile images received from the Rust renderer (R1-04), per page.
///
/// Receives [TileUpdate]s from the renderer's stream, turns the pixels into `ui.Image`s and keeps
/// the newest version per tile (updates can arrive out of order). An image stays until its
/// replacement is decoded, so pages never show empty frames while re-rendering. Images are
/// disposed when replaced, when their page closes and by the LRU budget; evicted tiles are reported
/// to Rust ([rendererForgetTiles]) so they are sent again when needed.
class RustTileStore {
  RustTileStore() {
    rendererReset();            //Rust may still have pages from before a hot restart
    _subscription = rendererTileStream().listen(_onTile, onError: (Object e) => print('rust_tile_store: stream error: $e'));
  }

  /// Edge length of a tile in device pixels.
  static final int tileSize = rendererTileSize();

  /// Budget for decoded tile images (~384 tiles of 256 KB).
  static const int budgetBytes = 96 << 20;

  /// Tiles painted within this time are never evicted.
  static const int _keepMs = 1000;

  late final StreamSubscription<TileUpdate> _subscription;
  final Map<PageKey, PageTileImages> _pages = {};
  final Map<TileId, int> _decoding = {};
  final List<_Waiter> _waiters = [];
  final Stopwatch _clock = Stopwatch()..start();
  int _bytes = 0;

  /// Tile images of [key], or null if the page isn't open.
  PageTileImages? page(PageKey key) => _pages[key];

  PageTileImages openPage(PageKey key) => _pages.putIfAbsent(key, () => PageTileImages._(key, this));

  void closePage(PageKey key) {
    final page = _pages.remove(key);
    if (page == null) return;
    for (final tile in page._tiles.values) {
      _bytes -= tile.bytes;
      tile.image.dispose();
    }
    page._tiles.clear();
    page._changed();          //not disposed: a painter may still listen until its widget rebuilds
    _checkWaiters();
  }

  void closeDocument(int docID) {
    for (final key in [for (final k in _pages.keys) if (k.docID == docID) k]) {
      closePage(key);
    }
  }

  /// Completes when all [tiles] are shown in at least the given version, when they can no longer
  /// arrive (page closed), or after [timeout] (e.g. the viewport moved and Rust dropped them).
  Future<void> waitFor(List<PendingTile> tiles, {Duration timeout = const Duration(milliseconds: 500)}) {
    final remaining = {for (final t in tiles) t.key: t.version};
    final waiter = _Waiter(remaining);
    if (waiter.update(this)) return Future.value();
    waiter.timer = Timer(timeout, () {
      _waiters.remove(waiter);
      if (!waiter.completer.isCompleted) waiter.completer.complete();
    });
    _waiters.add(waiter);
    return waiter.completer.future;
  }

  int? _versionOf(TileId id) => _pages[(docID: id.doc, pageID: id.page)]?._tiles[id]?.version;

  void _checkWaiters() {
    _waiters.removeWhere((w) {
      if (!w.update(this)) return false;
      w.timer?.cancel();
      if (!w.completer.isCompleted) w.completer.complete();
      return true;
    });
  }

  void _onTile(TileUpdate update) {
    final id = update.key;
    final page = _pages[(docID: id.doc, pageID: id.page)];
    if (page == null) return;          //closed meanwhile
    final version = update.version;
    if ((page._tiles[id]?.version ?? -1) >= version || (_decoding[id] ?? -1) >= version) return;
    _decoding[id] = version;

    ui.decodeImageFromPixels(update.pixels, tileSize, tileSize, ui.PixelFormat.rgba8888, (image) {
      if (_decoding[id] == version) _decoding.remove(id);
      final current = page._tiles[id];
      if (!identical(_pages[page.key], page) || (current?.version ?? -1) >= version) {
        image.dispose();             //page closed or a newer version arrived first
        return;
      }
      final bytes = tileSize * tileSize * 4;
      page._tiles[id] = _TileImage(version, image, bytes, _clock.elapsedMilliseconds);
      _bytes += bytes - (current?.bytes ?? 0);
      current?.image.dispose();
      page._changed();
      _checkWaiters();             //in the same frame as the repaint, so a preview can go away without a gap
      _evict();
    });
  }

  /// Evicts least recently painted tiles until the budget holds (never tiles painted recently).
  void _evict() {
    if (_bytes <= budgetBytes) return;
    final now = _clock.elapsedMilliseconds;
    final candidates = <(PageTileImages, TileId, _TileImage)>[
      for (final page in _pages.values)
        for (final entry in page._tiles.entries)
          if (now - entry.value.lastUsed > _keepMs) (page, entry.key, entry.value),
    ]..sort((a, b) => a.$3.lastUsed.compareTo(b.$3.lastUsed));

    final forgotten = <TileId>[];
    for (final (page, id, tile) in candidates) {
      if (_bytes <= budgetBytes) break;
      page._tiles.remove(id);
      _bytes -= tile.bytes;
      tile.image.dispose();
      forgotten.add(id);
    }
    if (forgotten.isNotEmpty) rendererForgetTiles(keys: forgotten);
  }

  void dispose() {
    unawaited(_subscription.cancel());
    for (final key in [..._pages.keys]) {
      closePage(key);
    }
  }
}

class _TileImage {
  _TileImage(this.version, this.image, this.bytes, this.lastUsed);

  final int version;
  final ui.Image image;
  final int bytes;
  int lastUsed;
}

class _Waiter {
  _Waiter(this.remaining);

  final Map<TileId, int> remaining;
  final Completer<void> completer = Completer();
  Timer? timer;

  /// Drops tiles that arrived or can't arrive any more; true when nothing is left.
  bool update(RustTileStore store) {
    remaining.removeWhere((id, version) {
      if (store._pages[(docID: id.doc, pageID: id.page)] == null) return true;
      return (store._versionOf(id) ?? -1) >= version;
    });
    return remaining.isEmpty;
  }
}

/// The tile images of one page. Notifies when tiles arrive or [targetScale] changes.
class PageTileImages extends ChangeNotifier {
  PageTileImages._(this.key, this._store);

  final PageKey key;
  final RustTileStore _store;
  final Map<TileId, _TileImage> _tiles = {};

  double _targetScale = 0;

  /// Device pixels per mm the page is shown at, rounded to a tile scale (set by the
  /// [ViewportTracker]). Tiles of this scale are painted; others only fill gaps.
  double get targetScale => _targetScale;

  set targetScale(double value) {
    if (value == _targetScale) return;
    _targetScale = value;
    notifyListeners();
  }

  bool get hasTiles => _tiles.isNotEmpty;

  void _changed() => notifyListeners();

  static final Paint _paint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = false;           //anti-aliased image edges would show as seams between tiles

  /// Paints [layer] (0 = background, 1 = ink) in page coordinates (mm). Missing tiles of the
  /// target scale are filled with tiles of the closest other scale that has some, clipped to
  /// the missing tile (never two scales on top of each other: transparent ink would double).
  void paintLayer(Canvas canvas, int layer, Size pageSize) {
    final byScale = <double, Map<(int, int), _TileImage>>{};
    for (final entry in _tiles.entries) {
      if (entry.key.layer != layer) continue;
      (byScale[entry.key.scale] ??= {})[(entry.key.x, entry.key.y)] = entry.value;
    }
    if (byScale.isEmpty) return;

    final scale = _targetScale > 0 ? _targetScale : byScale.keys.reduce(max);
    final now = _store._clock.elapsedMilliseconds;
    final tileMm = RustTileStore.tileSize / scale;
    final cols = (pageSize.width / tileMm).ceil();
    final rows = (pageSize.height / tileMm).ceil();
    final exact = byScale[scale] ?? const {};
    final others = byScale.keys.where((s) => s != scale).toList()
      ..sort((a, b) => (log(a / scale)).abs().compareTo((log(b / scale)).abs()));

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final dst = Rect.fromLTWH(x * tileMm, y * tileMm, tileMm, tileMm);
        final tile = exact[(x, y)];
        if (tile != null) {
          _draw(canvas, tile, dst, now);
          continue;
        }
        for (final other in others) {
          final otherMm = RustTileStore.tileSize / other;
          final tiles = byScale[other]!;
          final found = <(Rect, _TileImage)>[
            for (int oy = (dst.top / otherMm).floor(); oy < (dst.bottom / otherMm).ceil(); oy++)
              for (int ox = (dst.left / otherMm).floor(); ox < (dst.right / otherMm).ceil(); ox++)
                if (tiles[(ox, oy)] case final t?) (Rect.fromLTWH(ox * otherMm, oy * otherMm, otherMm, otherMm), t),
          ];
          if (found.isEmpty) continue;
          canvas.save();
          canvas.clipRect(dst);
          for (final (rect, t) in found) {
            _draw(canvas, t, rect, now);
          }
          canvas.restore();
          break;
        }
      }
    }
  }

  void _draw(Canvas canvas, _TileImage tile, Rect dst, int now) {
    tile.lastUsed = now;
    final size = RustTileStore.tileSize.toDouble();
    canvas.drawImageRect(tile.image, Rect.fromLTWH(0, 0, size, size), dst, _paint);
  }
}
