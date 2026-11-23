import 'dart:async';
import 'dart:isolate';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/isolates/initialize_tiles.dart' as iso;
import '../models/page/page_model.dart';
import '../models/page/tile.dart';
import 'page_tiles.dart';

/// Renders the tile grid of whole pages in background isolates (current Dart renderer, replaced
/// by the Rust renderer in Phase 5).
///
/// One pool of [poolSize] isolates for all documents. An isolate computes the stroke outlines per
/// tile; the main thread then rasterizes the tiles. Jobs wait in a queue when all isolates are busy.
class TileRenderer {
  static const int poolSize = 5;
  static const double scale = 20.0;

  int _running = 0;
  final Set<PageKey> _inFlight = {};
  final List<_TileJob> _queue = [];

  /// True when nothing is rendering or queued.
  bool get isIdle => _inFlight.isEmpty && _queue.isEmpty;

  /// Renders all tiles of [page]. Completes with null if the job was dropped: [stillWanted]
  /// returned false (checked before the job starts and between tile rows), the same page is
  /// already rendering, or a newer request for the page replaced this one in the queue.
  Future<List<List<Tile>>?> render(PageKey key, PageModel page, bool Function() stillWanted) {
    if (_inFlight.contains(key)) return Future.value(null);
    _queue.removeWhere((job) {
      if (job.key != key) return false;
      job.completer.complete(null);
      return true;
    });
    final job = _TileJob(key, page, stillWanted);
    _queue.add(job);
    _pump();
    return job.completer.future;
  }

  void _pump() {
    while (_running < poolSize && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      if (!job.stillWanted()) {
        job.completer.complete(null);
        continue;
      }
      _running++;
      _inFlight.add(job.key);
      unawaited(_run(job).then((tiles) {
        _inFlight.remove(job.key);
        job.completer.complete(tiles);
      }, onError: (Object e, StackTrace s) {
        print('tile_renderer: rendering page ${job.key.pageID} failed: $e');
        _inFlight.remove(job.key);
        job.completer.complete(null);
      }));
    }
  }

  Future<List<List<Tile>>?> _run(_TileJob job) async {
    final page = job.page;
    final receivePort = ReceivePort();
    final messages = StreamIterator(receivePort);
    Isolate? isolate;
    dynamic result;
    try {
      isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);
      await messages.moveNext();
      (messages.current as SendPort).send({
        'type': 'start',
        'data': [page.pageHeight, page.pageWidth, page.strokes, page.backgroundStrokes, tileRect, scale],
      });
      await messages.moveNext();
      result = messages.current;
    } finally {
      isolate?.kill(priority: Isolate.immediate);
      receivePort.close();
      // The isolate is done; the next job can start while this one rasterizes.
      _running--;
      _pump();
    }

    if (result.aborted == true || !job.stillWanted()) return null;

    for (int row = 0; row < result.tiles.length; row++) {
      for (int col = 0; col < result.tiles[0].length; col++) {
        await result.tiles[row][col].renderAfterIsolate(
          result.sameWidths[row][col],
          result.lefts[row][col],
          result.rights[row][col],
          result.tileStrokes[row][col],
          result.scale,
          result.backgroundSameWidths[row][col],
          result.backgroundTileStrokes[row][col],
          result.backgroundLefts[row][col],
          result.backgroundRights[row][col],
        );
      }
      if (!job.stillWanted()) return null;
    }
    return result.tiles;
  }
}

class _TileJob {
  _TileJob(this.key, this.page, this.stillWanted);

  final PageKey key;
  final PageModel page;
  final bool Function() stillWanted;
  final Completer<List<List<Tile>>?> completer = Completer();
}

final tileRendererProvider = Provider<TileRenderer>((ref) => TileRenderer());

void _isolateEntry(SendPort sendPort) async {
  bool cancelled = false;

  final receivePort = ReceivePort();

  sendPort.send(receivePort.sendPort);

  receivePort.listen((msg) async {
    if (msg['type'] == 'cancel') {
      cancelled = true;
    }
    else if (msg['type'] == 'start') {
      cancelled = false;

      final List args = msg['data'];

      final double pageHeight = args[0];
      final double pageWidth = args[1];
      final strokes = args[2];
      final backgroundStrokes = args[3];
      final Rect rect = args[4];
      final double scale = args[5];

      final tiles = <List<Tile>>[];
      final tileStrokes = [];
      final sameWidths = [];
      final rights = [];
      final lefts = [];
      final backgroundTileStrokes = [];
      final backgroundSameWidths = [];
      final backgroundRights = [];
      final backgroundLefts = [];

      final rows = (pageHeight / rect.height).ceil();
      final cols = (pageWidth / rect.width).ceil();

      for (int row = 0; row < rows; row++) {
        final rowTiles = <Tile>[];
        final rowTileStrokes = [];
        final rowSameWidths = [];
        final rowRights = [];
        final rowLefts = [];
        final rowBgTiles = [];
        final rowBgSameWidths = [];
        final rowBgRights = [];
        final rowBgLefts = [];

        for (int col = 0; col < cols; col++) {
          if (cancelled) {
            sendPort.send((aborted: true));
            cancelled = false;
            return;
          }

          final tile = Tile(
            Rect.fromLTWH(
              col * rect.width,
              row * rect.height,
              rect.width,
              rect.height,
            ),
          );

          final tileResult = iso.preCalculateSingleTile(
            tile,
            strokes,
            backgroundStrokes,
            scale,
          );

          rowTiles.add(tileResult.tile);
          rowTileStrokes.add(tileResult.tileStrokes);
          rowLefts.add(tileResult.lefts);
          rowRights.add(tileResult.rights);
          rowSameWidths.add(tileResult.sameWidths);

          rowBgTiles.add(tileResult.backgroundTileStrokes);
          rowBgLefts.add(tileResult.backgroundLefts);
          rowBgRights.add(tileResult.backgroundRights);
          rowBgSameWidths.add(tileResult.backgroundSameWidths);

          await Future.delayed(Duration.zero);
        }

        tiles.add(rowTiles);
        tileStrokes.add(rowTileStrokes);
        sameWidths.add(rowSameWidths);
        rights.add(rowRights);
        lefts.add(rowLefts);

        backgroundTileStrokes.add(rowBgTiles);
        backgroundSameWidths.add(rowBgSameWidths);
        backgroundRights.add(rowBgRights);
        backgroundLefts.add(rowBgLefts);
      }

      sendPort.send((aborted: false, tiles: tiles, tileStrokes: tileStrokes, sameWidths: sameWidths, rights: rights, lefts: lefts, backgroundTileStrokes: backgroundTileStrokes, backgroundSameWidths: backgroundSameWidths, backgroundRights: backgroundRights, backgroundLefts: backgroundLefts, scale: scale));
    }
  });
}
