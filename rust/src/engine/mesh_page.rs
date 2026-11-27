//! Page mirror for the mesh renderer (R12-01, first in-app version).
//!
//! Dart owns the documents (D4) and reports changes per page: strokes added or removed, strokes
//! hidden (being erased or moved by a selection), background strokes replaced. These calls only
//! store data and bump the page's version. Meshes are built when Dart asks for them
//! ([`MeshPages::fetch`], meant to run off the UI thread): each stroke's mesh is built once and
//! kept; the page's visible strokes are then packed into chunks for `Canvas.drawVertices`.
//!
//! Chunks hold strokes of one colour (one draw call each, painted with that colour), keep the
//! stroke order (so overlaps look the same as with the old renderer) and have at most
//! [`CHUNK_VERTICES`] vertices (cheap to re-send after a change, R7-05).
//!
//! Not yet (later roadmap items): detail levels by zoom (R8-03), re-sending only changed chunks
//! (R8-02), selection moves without rebuilding (R10-03).
use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex};

use super::geometry::Point;
use super::mesh::{stroke_mesh, MeshParams, StrokeMesh};

/// Soft size limit of a chunk (R7-05: ~8k vertices keeps re-sending a chunk under 1 ms).
pub const CHUNK_VERTICES: usize = 8000;
/// Hard limit of one `Vertices` object (16-bit indices).
const MAX_VERTICES: usize = 65535;

/// Tolerance (mm) of the single detail level used for now: 0.4 px at 8× zoom on the tablet
/// (13.3 px/mm at fit width in landscape × 8 ≈ 106 px/mm).
pub const TOLERANCE: f32 = 0.004;

pub fn params() -> MeshParams {
    MeshParams::for_tolerance(TOLERANCE)
}

/// A stroke as sent by Dart.
#[derive(Clone, Debug)]
pub struct StrokeInput {
    pub id: i64,
    /// 0xAARRGGBB
    pub color: u32,
    /// Freehand (smoothed) or shape (straight segments), Dart `Stroke.kind`.
    pub smooth: bool,
    pub points: Vec<Point>,
}

/// Triangles of one colour, ready for `Vertices.raw`.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct ColorChunk {
    pub color: u32,
    pub positions: Vec<f32>,
    pub indices: Vec<u16>,
}

#[derive(Clone, Debug, Default)]
pub struct PageMeshes {
    /// Version of the page these meshes show (Dart drops results older than what it has).
    pub version: u64,
    pub background: Vec<ColorChunk>,
    pub ink: Vec<ColorChunk>,
}

struct StrokeEntry {
    input: StrokeInput,
    mesh: Option<Arc<StrokeMesh>>,
}

#[derive(Default)]
struct Page {
    version: u64,
    background: Vec<StrokeEntry>,
    ink: Vec<StrokeEntry>,
    hidden: HashSet<i64>,
}

impl Page {
    fn bump(&mut self) {
        self.version += 1;
    }
}

pub type PageKey = (i64, i64);

/// All open pages. Every method locks only briefly; mesh building happens outside the lock.
#[derive(Default)]
pub struct MeshPages {
    pages: Mutex<HashMap<PageKey, Arc<Mutex<Page>>>>,
}

fn entries(strokes: Vec<StrokeInput>) -> Vec<StrokeEntry> {
    strokes.into_iter().map(|input| StrokeEntry { input, mesh: None }).collect()
}

impl MeshPages {
    fn page(&self, key: PageKey) -> Option<Arc<Mutex<Page>>> {
        self.pages.lock().unwrap().get(&key).cloned()
    }

    pub fn reset(&self) {
        self.pages.lock().unwrap().clear();
    }

    pub fn open_page(&self, key: PageKey, background: Vec<StrokeInput>, strokes: Vec<StrokeInput>) {
        let page = Page { version: 1, background: entries(background), ink: entries(strokes), hidden: HashSet::new() };
        self.pages.lock().unwrap().insert(key, Arc::new(Mutex::new(page)));
    }

    pub fn close_page(&self, key: PageKey) {
        self.pages.lock().unwrap().remove(&key);
    }

    pub fn close_document(&self, doc: i64) {
        self.pages.lock().unwrap().retain(|(d, _), _| *d != doc);
    }

    /// Adds strokes (a stroke with an existing ID replaces it in place). Returns the new version.
    pub fn add_strokes(&self, key: PageKey, strokes: Vec<StrokeInput>) -> u64 {
        let Some(page) = self.page(key) else { return 0 };
        let mut page = page.lock().unwrap();
        for input in strokes {
            if let Some(e) = page.ink.iter_mut().find(|e| e.input.id == input.id) {
                *e = StrokeEntry { input, mesh: None };
            } else {
                page.ink.push(StrokeEntry { input, mesh: None });
            }
        }
        page.bump();
        page.version
    }

    pub fn remove_strokes(&self, key: PageKey, ids: &[i64]) -> u64 {
        let Some(page) = self.page(key) else { return 0 };
        let mut page = page.lock().unwrap();
        let ids: HashSet<i64> = ids.iter().copied().collect();
        page.ink.retain(|e| !ids.contains(&e.input.id));
        page.bump();
        page.version
    }

    /// Strokes not drawn (being erased, or moved by a selection). Replaces the previous set.
    pub fn set_hidden(&self, key: PageKey, ids: &[i64]) -> u64 {
        let Some(page) = self.page(key) else { return 0 };
        let mut page = page.lock().unwrap();
        page.hidden = ids.iter().copied().collect();
        page.bump();
        page.version
    }

    pub fn set_background(&self, key: PageKey, strokes: Vec<StrokeInput>) -> u64 {
        let Some(page) = self.page(key) else { return 0 };
        let mut page = page.lock().unwrap();
        page.background = entries(strokes);
        page.bump();
        page.version
    }

    /// Builds missing stroke meshes (outside the lock) and packs the visible strokes into chunks.
    /// None if the page isn't open.
    pub fn fetch(&self, key: PageKey) -> Option<PageMeshes> {
        let page = self.page(key)?;
        // 1) Collect strokes without a mesh.
        let todo: Vec<StrokeInput> = {
            let p = page.lock().unwrap();
            p.background.iter().chain(&p.ink).filter(|e| e.mesh.is_none()).map(|e| e.input.clone()).collect()
        };
        // 2) Build them without holding the lock (Dart's change calls stay fast).
        let params = params();
        let built: HashMap<i64, Arc<StrokeMesh>> =
            todo.into_iter().map(|s| (s.id, Arc::new(stroke_mesh(&s.points, s.smooth, &params)))).collect();
        // 3) Store them (entries replaced meanwhile keep needing a mesh) and pack.
        let mut p = page.lock().unwrap();
        let store = |list: &mut Vec<StrokeEntry>| {
            for e in list.iter_mut() {
                if e.mesh.is_none() {
                    e.mesh = match built.get(&e.input.id) {
                        Some(m) => Some(m.clone()),
                        None => Some(Arc::new(stroke_mesh(&e.input.points, e.input.smooth, &params))),
                    };
                }
            }
        };
        store(&mut p.background);
        store(&mut p.ink);
        let no_hidden = HashSet::new();
        Some(PageMeshes {
            version: p.version,
            background: pack(p.background.iter().map(|e| (e.input.color, e.mesh.as_deref().unwrap())), &no_hidden, &[]),
            ink: pack(
                p.ink.iter().map(|e| (e.input.color, e.mesh.as_deref().unwrap())),
                &p.hidden,
                &p.ink.iter().map(|e| e.input.id).collect::<Vec<_>>(),
            ),
        })
    }
}

/// Packs stroke meshes in order into chunks of one colour. `ids` (same order) are checked against
/// `hidden`; an empty `ids` means nothing is hidden.
fn pack<'a>(meshes: impl Iterator<Item = (u32, &'a StrokeMesh)>, hidden: &HashSet<i64>, ids: &[i64]) -> Vec<ColorChunk> {
    let mut chunks: Vec<ColorChunk> = Vec::new();
    for (i, (color, mesh)) in meshes.enumerate() {
        if ids.get(i).is_some_and(|id| hidden.contains(id)) || mesh.indices.is_empty() {
            continue;
        }
        append(&mut chunks, color, mesh);
    }
    chunks
}

/// Appends one stroke mesh, starting a new chunk on a colour change or when the chunk is full.
pub fn append(chunks: &mut Vec<ColorChunk>, color: u32, mesh: &StrokeMesh) {
    let n = mesh.vertex_count();
    let fits = |c: &ColorChunk| c.color == color && (c.positions.len() / 2 == 0 || c.positions.len() / 2 + n <= CHUNK_VERTICES);
    if n > MAX_VERTICES {
        append_split(chunks, color, mesh);
        return;
    }
    if !chunks.last().is_some_and(fits) {
        chunks.push(ColorChunk { color, ..Default::default() });
    }
    let c = chunks.last_mut().unwrap();
    let base = (c.positions.len() / 2) as u32;
    if base as usize + n > MAX_VERTICES {
        chunks.push(ColorChunk { color, ..Default::default() });
        return append(chunks, color, mesh);
    }
    c.positions.extend_from_slice(&mesh.positions);
    c.indices.extend(mesh.indices.iter().map(|&i| (i + base) as u16));
}

/// A stroke too big for one `Vertices` object: split by triangles (very long strokes only).
fn append_split(chunks: &mut Vec<ColorChunk>, color: u32, mesh: &StrokeMesh) {
    let mut remap: HashMap<u32, u16> = HashMap::new();
    let mut current = ColorChunk { color, ..Default::default() };
    for t in mesh.indices.chunks(3) {
        if current.positions.len() / 2 + 3 > MAX_VERTICES {
            chunks.push(std::mem::replace(&mut current, ColorChunk { color, ..Default::default() }));
            remap.clear();
        }
        for &i in t {
            let local = *remap.entry(i).or_insert_with(|| {
                current.positions.push(mesh.positions[2 * i as usize]);
                current.positions.push(mesh.positions[2 * i as usize + 1]);
                (current.positions.len() / 2 - 1) as u16
            });
            current.indices.push(local);
        }
    }
    if !current.indices.is_empty() {
        chunks.push(current);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn line(id: i64, color: u32, y: f32) -> StrokeInput {
        StrokeInput { id, color, smooth: true, points: vec![Point::new(0.0, y, 0.5), Point::new(10.0, y, 0.5)] }
    }

    fn vertices(chunks: &[ColorChunk]) -> usize {
        chunks.iter().map(|c| c.positions.len() / 2).sum()
    }

    #[test]
    fn fetch_builds_and_hides() {
        let pages = MeshPages::default();
        let key = (1, 1);
        pages.open_page(key, vec![], vec![line(1, 0xff000000, 0.0), line(2, 0xff000000, 2.0)]);
        let all = pages.fetch(key).unwrap();
        assert_eq!(all.ink.len(), 1, "same colour, one chunk");
        let v = pages.set_hidden(key, &[2]);
        let hidden = pages.fetch(key).unwrap();
        assert_eq!(hidden.version, v);
        assert_eq!(vertices(&hidden.ink) * 2, vertices(&all.ink));
    }

    #[test]
    fn colours_split_chunks_and_keep_order() {
        let pages = MeshPages::default();
        let key = (1, 2);
        pages.open_page(key, vec![], vec![line(1, 0xff000000, 0.0), line(2, 0xffff0000, 1.0), line(3, 0xff000000, 2.0)]);
        let m = pages.fetch(key).unwrap();
        assert_eq!(m.ink.iter().map(|c| c.color).collect::<Vec<_>>(), vec![0xff000000, 0xffff0000, 0xff000000]);
    }

    #[test]
    fn same_points_give_the_same_triangles_as_a_single_stroke_mesh() {
        // Pen-up: the page draws the committed stroke exactly like the active stroke before.
        let s = StrokeInput {
            id: 7,
            color: 0xff000000,
            smooth: true,
            points: (0..80).map(|i| Point::new(i as f32 * 0.1, (i as f32 * 0.2).sin(), 0.4)).collect(),
        };
        let mut single = Vec::new();
        append(&mut single, s.color, &stroke_mesh(&s.points, true, &params()));
        let pages = MeshPages::default();
        pages.open_page((1, 3), vec![], vec![s]);
        assert_eq!(pages.fetch((1, 3)).unwrap().ink, single);
    }

    #[test]
    fn chunks_respect_the_size_limit() {
        let pages = MeshPages::default();
        let strokes: Vec<StrokeInput> = (0..300)
            .map(|i| StrokeInput {
                id: i,
                color: 0xff000000,
                smooth: true,
                points: (0..40).map(|k| Point::new(k as f32 * 0.2, (k as f32 * 0.7 + i as f32).sin(), 0.4)).collect(),
            })
            .collect();
        pages.open_page((1, 4), vec![], strokes);
        let m = pages.fetch((1, 4)).unwrap();
        assert!(m.ink.len() > 1);
        assert!(m.ink.iter().all(|c| c.positions.len() / 2 <= CHUNK_VERTICES));
        assert!(m.ink.iter().all(|c| c.indices.iter().all(|&i| (i as usize) < c.positions.len() / 2)));
    }

    #[test]
    fn huge_strokes_are_split() {
        let mesh = stroke_mesh(
            &(0..40000).map(|k| Point::new(k as f32 * 0.05, (k as f32 * 0.3).sin(), 0.4)).collect::<Vec<_>>(),
            true,
            &params(),
        );
        assert!(mesh.vertex_count() > MAX_VERTICES);
        let mut chunks = Vec::new();
        append(&mut chunks, 0xff000000, &mesh);
        assert!(chunks.len() > 1);
        assert_eq!(chunks.iter().map(|c| c.indices.len()).sum::<usize>(), mesh.indices.len());
        assert!(chunks.iter().all(|c| c.indices.iter().all(|&i| (i as usize) < c.positions.len() / 2)));
    }

    #[test]
    fn changes_bump_the_version_and_replace_by_id() {
        let pages = MeshPages::default();
        let key = (2, 1);
        pages.open_page(key, vec![], vec![line(1, 0xff000000, 0.0)]);
        let v1 = pages.add_strokes(key, vec![line(1, 0xff0000ff, 0.0)]);
        let m = pages.fetch(key).unwrap();
        assert_eq!(m.version, v1);
        assert_eq!(m.ink.len(), 1);
        assert_eq!(m.ink[0].color, 0xff0000ff);
        let v2 = pages.remove_strokes(key, &[1]);
        assert!(v2 > v1);
        assert!(pages.fetch(key).unwrap().ink.is_empty());
        pages.close_page(key);
        assert!(pages.fetch(key).is_none());
    }
}
