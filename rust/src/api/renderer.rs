//! Dart API of the tile renderer (R1-04). A thin layer over [`crate::engine::renderer::Renderer`];
//! see there for how tiles are scheduled and versioned.
//!
//! There is one renderer per process. All change functions are `sync`: they only update the page
//! mirror and wake the workers, and running them in call order on the Dart thread keeps changes
//! ordered (async calls run on a thread pool and could overtake each other).
//!
//! IDs are Dart `int`s (`i64`) and reinterpreted as `u64` on the Rust side.

use std::collections::HashSet;
use std::sync::{LazyLock, Mutex};

use flutter_rust_bridge::frb;

use crate::engine::geometry::{Point, Rect, Stroke};
use crate::engine::page::{Layer, PageKey};
use crate::engine::renderer::{PageViewport, Renderer, RendererConfig, TileEvent};
use crate::engine::tiles::{Scale, TileKey, TILE_PX};
use crate::frb_generated::StreamSink;

/// A finished tile, sent through the stream from [`renderer_tile_stream`].
pub struct TileUpdate {
    pub key: TileId,
    /// Grows with every change. Keep the highest version per tile; updates can arrive out of order.
    pub version: i64,
    /// `renderer_tile_size()`² pixels, RGBA with premultiplied alpha (`PixelFormat.rgba8888`).
    pub pixels: Vec<u8>,
}

/// Identifies a tile: page, layer (0 = background, 1 = ink), scale (device pixels per mm) and
/// position in the tile grid of that scale.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TileId {
    pub doc: i64,
    pub page: i64,
    pub layer: u8,
    pub scale: f32,
    pub x: u32,
    pub y: u32,
}

/// A tile that must arrive (in at least this version) before a change is visible.
pub struct PendingTile {
    pub key: TileId,
    pub version: i64,
}

/// A stroke: `points` holds x, y, width (mm) for each point.
pub struct StrokeData {
    pub id: i64,
    /// 0xAARRGGBB
    pub color: u32,
    pub points: Vec<f32>,
}

/// The visible part of a page.
pub struct PageViewportData {
    pub doc: i64,
    pub page: i64,
    /// Device pixels per mm.
    pub scale: f32,
    pub left: f32,
    pub top: f32,
    pub right: f32,
    pub bottom: f32,
}

static SINK: Mutex<Option<StreamSink<TileUpdate>>> = Mutex::new(None);

static RENDERER: LazyLock<Renderer> = LazyLock::new(|| {
    Renderer::new(
        RendererConfig::default(),
        Box::new(|event: TileEvent| {
            let sink = SINK.lock().unwrap_or_else(|e| e.into_inner());
            let Some(sink) = sink.as_ref() else { return false };
            sink.add(TileUpdate {
                key: tile_id(&event.key),
                version: event.version as i64,
                pixels: (*event.pixels).clone(),
            })
            .is_ok()
        }),
    )
});

fn page_key(doc: i64, page: i64) -> PageKey {
    PageKey { doc: doc as u64, page: page as u64 }
}

fn tile_id(key: &TileKey) -> TileId {
    TileId {
        doc: key.page.doc as i64,
        page: key.page.page as i64,
        layer: key.layer as u8,
        scale: key.scale.get(),
        x: key.x,
        y: key.y,
    }
}

fn tile_key(id: &TileId) -> TileKey {
    TileKey {
        page: page_key(id.doc, id.page),
        layer: if id.layer == 0 { Layer::Background } else { Layer::Ink },
        scale: Scale::new(id.scale),
        x: id.x,
        y: id.y,
    }
}

fn strokes(data: Vec<StrokeData>) -> Vec<Stroke> {
    data.into_iter()
        .map(|s| {
            let points = s.points.as_chunks::<3>().0.iter().map(|p| Point::new(p[0], p[1], p[2])).collect();
            Stroke::new(s.id as u64, s.color, points)
        })
        .collect()
}

fn pending(tiles: Vec<(TileKey, u64)>) -> Vec<PendingTile> {
    tiles.iter().map(|(k, v)| PendingTile { key: tile_id(k), version: *v as i64 }).collect()
}

/// Edge length of a tile in device pixels.
#[frb(sync)]
pub fn renderer_tile_size() -> u32 {
    TILE_PX
}

/// Closes all pages. Call once when the Dart side starts, before anything else (after a hot
/// restart Rust still has the old pages).
#[frb(sync)]
pub fn renderer_reset() {
    RENDERER.close_all();
}

/// The stream of finished tiles; replaces an earlier stream. This call is async and may run after
/// pages were opened: tiles finished before it are kept and sent once it runs.
pub fn renderer_tile_stream(sink: StreamSink<TileUpdate>) {
    *SINK.lock().unwrap_or_else(|e| e.into_inner()) = Some(sink);
    RENDERER.forget_all();
}

/// Opens (or replaces) an empty page. `width`/`height` in mm, `color` 0xAARRGGBB (the
/// background layer is filled with it; transparent leaves that to Flutter).
#[frb(sync)]
pub fn renderer_open_page(doc: i64, page: i64, width: f32, height: f32, color: u32) {
    RENDERER.open_page(page_key(doc, page), width, height, color);
}

#[frb(sync)]
pub fn renderer_close_page(doc: i64, page: i64) {
    RENDERER.close_page(page_key(doc, page));
}

#[frb(sync)]
pub fn renderer_close_document(doc: i64) {
    RENDERER.close_document(doc as u64);
}

/// Adds strokes on top; strokes with an existing ID replace the old one.
#[frb(sync)]
pub fn renderer_add_strokes(doc: i64, page: i64, strokes: Vec<StrokeData>) -> Vec<PendingTile> {
    pending(RENDERER.add_strokes(page_key(doc, page), self::strokes(strokes)))
}

#[frb(sync)]
pub fn renderer_remove_strokes(doc: i64, page: i64, ids: Vec<i64>) -> Vec<PendingTile> {
    let ids: Vec<u64> = ids.into_iter().map(|id| id as u64).collect();
    pending(RENDERER.remove_strokes(page_key(doc, page), &ids))
}

/// Sets the strokes that are not drawn (being erased or moved); replaces the previous set.
#[frb(sync)]
pub fn renderer_set_hidden(doc: i64, page: i64, ids: Vec<i64>) -> Vec<PendingTile> {
    let ids: HashSet<u64> = ids.into_iter().map(|id| id as u64).collect();
    pending(RENDERER.set_hidden(page_key(doc, page), ids))
}

/// Replaces page colour and line pattern.
#[frb(sync)]
pub fn renderer_set_background(doc: i64, page: i64, color: u32, strokes: Vec<StrokeData>) {
    RENDERER.set_background(page_key(doc, page), color, self::strokes(strokes));
}

#[frb(sync)]
pub fn renderer_resize_page(doc: i64, page: i64, width: f32, height: f32) {
    RENDERER.resize_page(page_key(doc, page), width, height);
}

/// Sets what is on screen (replaces the previous viewport). Pages not listed get no tiles.
#[frb(sync)]
pub fn renderer_set_viewport(viewports: Vec<PageViewportData>) {
    let viewports: Vec<PageViewport> = viewports
        .iter()
        .filter(|v| v.scale.is_finite() && v.scale > 0.0)
        .map(|v| PageViewport {
            page: page_key(v.doc, v.page),
            scale: v.scale,
            visible: Rect::from_ltrb(v.left, v.top, v.right, v.bottom),
        })
        .collect();
    RENDERER.set_viewport(&viewports);
}

/// The caller dropped these tiles; they are sent again when needed.
#[frb(sync)]
pub fn renderer_forget_tiles(keys: Vec<TileId>) {
    let keys: Vec<TileKey> = keys.iter().filter(|k| k.scale.is_finite() && k.scale > 0.0).map(tile_key).collect();
    RENDERER.forget_tiles(&keys);
}
