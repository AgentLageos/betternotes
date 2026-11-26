import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// FRB's own Int64List (BigInt-based on the web) for i64 vectors.
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart' as frb show Int64List;

import '../../../src/rust/api/mesh.dart';
import '../models/page/page_model.dart';
import '../models/page/stroke.dart';
import 'page_renderer.dart';

/// [PageRenderer] that draws strokes as GPU triangle meshes built in Rust (D15, R12-01).
///
/// Page changes go to Rust as deltas (sync calls that only store data); the meshes are built on a
/// Rust worker thread ([meshFetchPage]) and arrive as chunks of one colour each, drawn with
/// `Canvas.drawVertices`. Strokes being drawn get their mesh from [meshStroke], with the same
/// geometry, so a stroke looks the same before and after pen-up.
///
/// First in-app version: one detail level, all chunks of a page are re-sent after a change.
class MeshPageRenderer implements PageRenderer {
  MeshPageRenderer() {
    meshReset(); // Rust may still hold pages from before a hot restart
  }

  /// Pages open in Rust, with the latest version reported.
  final Map<PageKey, PageModel> _open = {};
  final Map<PageKey, PageMeshes> _meshes = {};

  /// Pages with a fetch running, and whether another one is needed when it returns.
  final Map<PageKey, bool> _fetching = {};

  /// Futures waiting until a page version is shown.
  final Map<PageKey, List<(BigInt, Completer<void>)>> _waiters = {};

  /// Meshes of [key] for painting. Created on demand, so a page widget can listen to it before
  /// the page is shown.
  PageMeshes meshes(PageKey key) => _meshes.putIfAbsent(key, PageMeshes._);

  @override
  void showPage(PageKey key, PageModel page) {
    if (_open.containsKey(key)) {
      _open[key] = page;
      return;
    }
    _open[key] = page;
    meshOpenPage(
      doc: key.docID,
      page: key.pageID,
      background: _strokeData(page.backgroundStrokes),
      strokes: _strokeData(page.strokes),
    );
    _fetch(key);
  }

  @override
  void hidePages(Iterable<PageKey> keys) {
    for (final key in keys) {
      if (_open.remove(key) == null) continue;
      meshClosePage(doc: key.docID, page: key.pageID);
      _drop(key);
    }
  }

  @override
  void closeDocument(int docID) {
    final keys = [for (final k in _open.keys) if (k.docID == docID) k];
    meshCloseDocument(doc: docID);
    for (final key in keys) {
      _open.remove(key);
      _drop(key);
    }
  }

  /// Completes when the change is on screen, so the page widget keeps drawing the committed
  /// strokes as active strokes until then (same mesh, so no visible change).
  @override
  Future<void> updateStrokes(PageKey key, PageModel page, List<Stroke> added, List<int> removedStrokeIDs) {
    if (!_open.containsKey(key)) return Future.value();
    _open[key] = page;
    BigInt version = BigInt.zero;
    if (removedStrokeIDs.isNotEmpty) {
      version = meshRemoveStrokes(doc: key.docID, page: key.pageID, ids: frb.Int64List.fromList(removedStrokeIDs));
    }
    if (added.isNotEmpty) {
      version = meshAddStrokes(doc: key.docID, page: key.pageID, strokes: _strokeData(added));
    }
    return _changed(key, version);
  }

  @override
  Future<void> updateBackground(PageKey key, PageModel page) {
    if (!_open.containsKey(key)) return Future.value();
    _open[key] = page;
    final version = meshSetBackground(doc: key.docID, page: key.pageID, strokes: _strokeData(page.backgroundStrokes));
    return _changed(key, version);
  }

  /// Meshes don't depend on the page size.
  @override
  Future<void> resizePage(PageKey key, PageModel page) async {
    if (_open.containsKey(key)) _open[key] = page;
  }

  /// Strokes not drawn because Flutter draws a preview of them (being erased, or selected and
  /// moved). Replaces the previous set.
  void setHidden(PageKey key, Iterable<int> strokeIDs) {
    if (!_open.containsKey(key)) return;
    final version = meshSetHidden(doc: key.docID, page: key.pageID, ids: frb.Int64List.fromList(strokeIDs.toList()));
    unawaited(_changed(key, version));
  }

  // ---- strokes being drawn ----

  final Expando<_StrokeMeshCache> _strokeCache = Expando();

  /// Paints a stroke that isn't part of the page meshes yet (being drawn, a pending committed
  /// stroke, a moved selection). Its mesh is cached until its points change.
  void paintStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;
    final signature = Object.hashAll([
      stroke.color.toARGB32(),
      stroke.kind,
      for (final p in stroke.points) ...[p.pos.dx, p.pos.dy, p.width],
    ]);
    var cached = _strokeCache[stroke];
    if (cached == null || cached.signature != signature) {
      cached?.dispose();
      cached = _StrokeMeshCache(signature, [
        for (final c in meshStroke(stroke: _strokeData([stroke]).single)) _ColorMesh.fromChunk(c),
      ]);
      _strokeCache[stroke] = cached;
    }
    for (final m in cached.meshes) {
      m.draw(canvas);
    }
  }

  // ---- internals ----

  Future<void> _changed(PageKey key, BigInt version) {
    if (version == BigInt.zero) return Future.value(); // page not open in Rust
    final completer = Completer<void>();
    (_waiters[key] ??= []).add((version, completer));
    _fetch(key);
    return completer.future;
  }

  /// Fetches the page's meshes; a change during a running fetch triggers one more fetch.
  void _fetch(PageKey key) {
    if (_fetching.containsKey(key)) {
      _fetching[key] = true;
      return;
    }
    _fetching[key] = false;
    meshFetchPage(doc: key.docID, page: key.pageID).then((data) {
      final again = _fetching.remove(key) ?? false;
      if (data != null && _open.containsKey(key)) {
        meshes(key)._apply(data);
        _completeWaiters(key, data.version);
      }
      if (again && _open.containsKey(key)) _fetch(key);
    }, onError: (Object e) {
      _fetching.remove(key);
      print('mesh_page_renderer: fetch $key failed: $e');
    });
  }

  void _completeWaiters(PageKey key, BigInt shown) {
    final list = _waiters[key];
    if (list == null) return;
    list.removeWhere((w) {
      if (w.$1 > shown) return false;
      w.$2.complete();
      return true;
    });
  }

  void _drop(PageKey key) {
    _meshes.remove(key)?._clear();
    for (final w in _waiters.remove(key) ?? const []) {
      w.$2.complete();
    }
  }

  static List<MeshStroke> _strokeData(List<Stroke> strokes) => [
        for (final stroke in strokes)
          MeshStroke(
            id: stroke.strokeID,
            color: stroke.color.toARGB32(),
            smooth: stroke.kind == StrokeKind.freehand,
            points: Float32List.fromList([
              for (final p in stroke.points) ...[p.pos.dx, p.pos.dy, p.width],
            ]),
          ),
      ];
}

/// Meshes of one page; notifies when new ones arrived (the page repaints).
class PageMeshes extends ChangeNotifier {
  PageMeshes._();

  BigInt _version = BigInt.zero;
  List<_ColorMesh> _background = const [];
  List<_ColorMesh> _ink = const [];

  void _apply(MeshPageData data) {
    if (data.version <= _version && _version != BigInt.zero) return; // older than what is shown
    final old = [..._background, ..._ink];
    _version = data.version;
    _background = [for (final c in data.background) _ColorMesh.fromChunk(c)];
    _ink = [for (final c in data.ink) _ColorMesh.fromChunk(c)];
    notifyListeners();
    // Pictures recorded before keep their own reference, so the old meshes can go now.
    for (final m in old) {
      m.dispose();
    }
  }

  void _clear() {
    for (final m in [..._background, ..._ink]) {
      m.dispose();
    }
    _background = const [];
    _ink = const [];
    _version = BigInt.zero;
    notifyListeners();
  }

  /// Line pattern.
  void paintBackground(Canvas canvas) {
    for (final m in _background) {
      m.draw(canvas);
    }
  }

  void paintInk(Canvas canvas) {
    for (final m in _ink) {
      m.draw(canvas);
    }
  }
}

class _ColorMesh {
  _ColorMesh.fromChunk(MeshChunk c)
      : _paint = (Paint()..color = Color(c.color)),
        vertices = ui.Vertices.raw(ui.VertexMode.triangles, c.positions, indices: c.indices);

  final Paint _paint;
  final ui.Vertices vertices;

  /// Plain meshes without vertex colours, drawn in the paint's colour (srcOver; Impeller's MSAA
  /// smooths the edges, design doc §4.5).
  void draw(Canvas canvas) => canvas.drawVertices(vertices, BlendMode.srcOver, _paint);

  void dispose() => vertices.dispose();
}

class _StrokeMeshCache {
  _StrokeMeshCache(this.signature, this.meshes);

  final int signature;
  final List<_ColorMesh> meshes;

  void dispose() {
    for (final m in meshes) {
      m.dispose();
    }
  }
}

/// The mesh renderer, shared by all documents that use it. Only created when the developer
/// setting is on (the Rust library must be loaded).
final meshPageRendererProvider = Provider<MeshPageRenderer>((ref) => MeshPageRenderer());

/// Whether newly opened documents use the mesh renderer (developer setting, R12-01). Takes
/// precedence over the Rust tile renderer setting.
final meshRendererEnabledProvider = NotifierProvider<RustRendererEnabledNotifier, bool>(RustRendererEnabledNotifier.new);
