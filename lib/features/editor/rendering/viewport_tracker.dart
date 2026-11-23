import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../src/rust/api/renderer.dart';
import 'page_tiles.dart' show PageKey;
import 'rust_tile_store.dart';

/// Tells the Rust renderer what is on screen (R1-04).
///
/// Every page painted with Rust tiles registers its widget here. After every frame the tracker
/// reads each page's actual on-screen transform (so it doesn't need to know the editor's zoom or
/// layout), computes the visible part of the page and the scale, and sends the viewport to Rust
/// when it changed. Frames only happen when something changes, so this costs nothing while idle.
///
/// The scale is rounded up to a power of two (2^n device pixels per mm): tiles are rendered at
/// that level and drawn slightly scaled down. Exact scales after a zoom gesture are R1-05.
class ViewportTracker {
  ViewportTracker(this._store) {
    SchedulerBinding.instance.addPersistentFrameCallback(_afterFrame);
  }

  final RustTileStore _store;
  final Map<PageKey, BuildContext> _pages = {};
  List<PageViewportData> _last = const [];
  bool _dirty = true;

  /// [context] belongs to the widget that paints the page; its size is the page size in mm.
  void attach(PageKey key, BuildContext context) {
    _pages[key] = context;
    _dirty = true;
    SchedulerBinding.instance.scheduleFrame();
  }

  void detach(PageKey key, BuildContext context) {
    if (_pages[key] == context) {
      _pages.remove(key);
      _dirty = true;
      SchedulerBinding.instance.scheduleFrame();
    }
  }

  /// Runs after layout and paint of every frame (persistent callbacks run in registration order,
  /// after the rendering pipeline's own).
  void _afterFrame(Duration _) {
    if (_pages.isEmpty && !_dirty) return;
    final viewports = <PageViewportData>[];
    for (final MapEntry(key: key, value: context) in _pages.entries) {
      if (!context.mounted) continue;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;

      final view = View.maybeOf(context);
      if (view == null) continue;
      final dpr = view.devicePixelRatio;
      final screen = Offset.zero & (view.physicalSize / dpr);

      final transform = box.getTransformTo(null);
      final inverse = Matrix4.tryInvert(transform);
      if (inverse == null) continue;
      final visible = MatrixUtils.transformRect(inverse, screen).intersect(Offset.zero & box.size);

      final scale = levelScale(transform.getMaxScaleOnAxis() * dpr);
      _store.page(key)?.targetScale = scale;
      if (visible.width <= 0 || visible.height <= 0) continue;
      viewports.add(PageViewportData(
        doc: key.docID,
        page: key.pageID,
        scale: scale,
        left: visible.left,
        top: visible.top,
        right: visible.right,
        bottom: visible.bottom,
      ));
    }
    if (!_dirty && _sameViewports(viewports, _last)) return;
    _dirty = false;
    _last = viewports;
    rendererSetViewport(viewports: viewports);
  }

  static bool _sameViewports(List<PageViewportData> a, List<PageViewportData> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// The power-of-two scale at or above [scale] (device pixels per mm), clamped to 2^-2 .. 2^6.
  /// Powers of two are exact in f32, so tile keys from Rust compare equal.
  static double levelScale(double scale) {
    if (!scale.isFinite || scale <= 0) return 1;
    final level = (log(scale) / ln2 - 1e-6).ceil().clamp(-2, 6);
    return pow(2.0, level).toDouble();
  }
}
