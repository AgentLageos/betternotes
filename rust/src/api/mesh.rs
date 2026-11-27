//! Dart-facing API of the mesh renderer (roadmap D15, R12-01).
//!
//! Change calls are `sync` and only store data (they keep their order and return the page version
//! after the change). [`mesh_fetch_page`] is async: it builds missing meshes on a worker thread
//! and returns all chunks of the page; Dart drops results older than what it already shows.
//! [`mesh_stroke`] builds the mesh of a single stroke synchronously for strokes being drawn, with
//! the same geometry as the page meshes, so a stroke doesn't change at pen-up.
use std::sync::LazyLock;

use flutter_rust_bridge::frb;

use crate::engine::geometry::Point;
use crate::engine::mesh::stroke_mesh;
use crate::engine::mesh_page::{self, ColorChunk, MeshPages, StrokeInput};

static PAGES: LazyLock<MeshPages> = LazyLock::new(MeshPages::default);

/// A stroke for the mesh renderer. `points` holds x, y, width per point (mm).
pub struct MeshStroke {
    pub id: i64,
    /// 0xAARRGGBB
    pub color: u32,
    /// Freehand stroke (smoothed); false for shapes and lines (straight segments).
    pub smooth: bool,
    pub points: Vec<f32>,
}

/// Triangles of one colour; `indices` refer to x, y pairs in `positions`.
pub struct MeshChunk {
    pub color: u32,
    pub positions: Vec<f32>,
    pub indices: Vec<u16>,
}

pub struct MeshPageData {
    pub version: u64,
    pub background: Vec<MeshChunk>,
    pub ink: Vec<MeshChunk>,
}

fn input(s: MeshStroke) -> StrokeInput {
    StrokeInput {
        id: s.id,
        color: s.color,
        smooth: s.smooth,
        points: s.points.chunks_exact(3).map(|p| Point::new(p[0], p[1], p[2])).collect(),
    }
}

fn inputs(strokes: Vec<MeshStroke>) -> Vec<StrokeInput> {
    strokes.into_iter().map(input).collect()
}

fn chunk(c: ColorChunk) -> MeshChunk {
    MeshChunk { color: c.color, positions: c.positions, indices: c.indices }
}

/// Drops all pages (after a hot restart Rust may still hold pages of the previous run).
#[frb(sync)]
pub fn mesh_reset() {
    PAGES.reset();
}

#[frb(sync)]
pub fn mesh_open_page(doc: i64, page: i64, background: Vec<MeshStroke>, strokes: Vec<MeshStroke>) {
    PAGES.open_page((doc, page), inputs(background), inputs(strokes));
}

#[frb(sync)]
pub fn mesh_close_page(doc: i64, page: i64) {
    PAGES.close_page((doc, page));
}

#[frb(sync)]
pub fn mesh_close_document(doc: i64) {
    PAGES.close_document(doc);
}

/// Adds strokes (same ID replaces). Returns the page version after the change (0: not open).
#[frb(sync)]
pub fn mesh_add_strokes(doc: i64, page: i64, strokes: Vec<MeshStroke>) -> u64 {
    PAGES.add_strokes((doc, page), inputs(strokes))
}

#[frb(sync)]
pub fn mesh_remove_strokes(doc: i64, page: i64, ids: Vec<i64>) -> u64 {
    PAGES.remove_strokes((doc, page), &ids)
}

/// Strokes not drawn (being erased or moved by a selection); replaces the previous set.
#[frb(sync)]
pub fn mesh_set_hidden(doc: i64, page: i64, ids: Vec<i64>) -> u64 {
    PAGES.set_hidden((doc, page), &ids)
}

#[frb(sync)]
pub fn mesh_set_background(doc: i64, page: i64, strokes: Vec<MeshStroke>) -> u64 {
    PAGES.set_background((doc, page), inputs(strokes))
}

/// All chunks of a page (None if it isn't open). Runs on a worker thread.
pub fn mesh_fetch_page(doc: i64, page: i64) -> Option<MeshPageData> {
    PAGES.fetch((doc, page)).map(|m| MeshPageData {
        version: m.version,
        background: m.background.into_iter().map(chunk).collect(),
        ink: m.ink.into_iter().map(chunk).collect(),
    })
}

/// Mesh of one stroke (being drawn), same geometry as the page meshes. Usually one chunk; very
/// long strokes are split.
#[frb(sync)]
pub fn mesh_stroke(stroke: MeshStroke) -> Vec<MeshChunk> {
    let s = input(stroke);
    let mesh = stroke_mesh(&s.points, s.smooth, &mesh_page::params());
    let mut chunks = Vec::new();
    if !mesh.indices.is_empty() {
        mesh_page::append(&mut chunks, s.color, &mesh);
    }
    chunks.into_iter().map(chunk).collect()
}
