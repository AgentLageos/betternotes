//! The renderer's mirror of a page (D4): geometry needed for drawing plus change versions.

use std::collections::HashSet;
use std::sync::Arc;

use super::geometry::{Rect, Stroke};

/// Identifies a page of an open document (the same file can be open twice with the same page IDs).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct PageKey {
    pub doc: u64,
    pub page: u64,
}

/// Tiles are rendered in separate layers, so editing strokes doesn't re-render the background.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Layer {
    /// Page colour and line pattern (later also PDF pages).
    Background = 0,
    /// Strokes.
    Ink = 1,
}

impl Layer {
    pub const ALL: [Layer; 2] = [Layer::Background, Layer::Ink];
}

/// Everything needed to draw a page. Cheap to clone: render jobs take a snapshot and draw it
/// without holding the renderer lock; changes copy the stroke list (of `Arc`s) on write.
#[derive(Clone, Debug)]
pub struct PageGeometry {
    pub width: f32,
    pub height: f32,
    /// Page colour as 0xAARRGGBB, drawn into the background layer.
    pub color: u32,
    pub background: Arc<Vec<Arc<Stroke>>>,
    /// Strokes in drawing order.
    pub ink: Arc<Vec<Arc<Stroke>>>,
    /// IDs of ink strokes that are not drawn (being erased or moved by a selection; Flutter draws
    /// the preview on top).
    pub hidden: Arc<HashSet<u64>>,
}

impl PageGeometry {
    pub fn new(width: f32, height: f32, color: u32) -> Self {
        Self { width, height, color, background: Arc::default(), ink: Arc::default(), hidden: Arc::default() }
    }

    pub fn rect(&self) -> Rect {
        Rect::from_ltwh(0.0, 0.0, self.width, self.height)
    }

    pub fn strokes(&self, layer: Layer) -> &[Arc<Stroke>] {
        match layer {
            Layer::Background => &self.background,
            Layer::Ink => &self.ink,
        }
    }
}

/// Size of a version cell in mm.
const VERSION_CELL_MM: f32 = 8.0;

/// Change versions of a page layer on a coarse grid of [`VERSION_CELL_MM`] cells.
///
/// A change bumps the cells its area touches to a new version; the version of a tile is the
/// highest version of the cells it covers. That makes versions independent of the zoom level:
/// a tile at any scale knows whether its content changed since it was rendered.
#[derive(Clone, Debug)]
pub struct VersionGrid {
    cols: usize,
    rows: usize,
    cells: Vec<u64>,
}

impl VersionGrid {
    pub fn new(width: f32, height: f32, version: u64) -> Self {
        let cols = ((width / VERSION_CELL_MM).ceil() as usize).max(1);
        let rows = ((height / VERSION_CELL_MM).ceil() as usize).max(1);
        Self { cols, rows, cells: vec![version; cols * rows] }
    }

    /// Cell index range covered by `rect`, clamped to the grid. None if `rect` is outside.
    fn range(&self, rect: &Rect) -> Option<(std::ops::Range<usize>, std::ops::Range<usize>)> {
        if rect.is_empty() {
            return None;
        }
        let clamp = |v: f32, max: usize| (v.max(0.0) as usize).min(max);
        let c0 = clamp((rect.left / VERSION_CELL_MM).floor(), self.cols);
        let c1 = clamp((rect.right / VERSION_CELL_MM).ceil(), self.cols);
        let r0 = clamp((rect.top / VERSION_CELL_MM).floor(), self.rows);
        let r1 = clamp((rect.bottom / VERSION_CELL_MM).ceil(), self.rows);
        (c0 < c1 && r0 < r1).then_some((r0..r1, c0..c1))
    }

    pub fn bump(&mut self, rect: &Rect, version: u64) {
        if let Some((rows, cols)) = self.range(rect) {
            for r in rows {
                for c in cols.clone() {
                    self.cells[r * self.cols + c] = version;
                }
            }
        }
    }

    pub fn bump_all(&mut self, version: u64) {
        self.cells.fill(version);
    }

    /// Highest version in `rect` (0 if `rect` is outside the page).
    pub fn version_in(&self, rect: &Rect) -> u64 {
        let Some((rows, cols)) = self.range(rect) else { return 0 };
        let mut max = 0;
        for r in rows {
            for c in cols.clone() {
                max = max.max(self.cells[r * self.cols + c]);
            }
        }
        max
    }
}

/// A page as the renderer knows it: geometry plus per-layer versions.
#[derive(Clone, Debug)]
pub struct PageMirror {
    geometry: PageGeometry,
    versions: [VersionGrid; 2],
}

/// Strokes paint a little beyond their bounds (anti-aliasing); bump a margin around them.
const CHANGE_MARGIN_MM: f32 = 1.0;

impl PageMirror {
    /// New empty page; all cells start at `version`.
    pub fn new(width: f32, height: f32, color: u32, version: u64) -> Self {
        Self {
            geometry: PageGeometry::new(width, height, color),
            versions: [VersionGrid::new(width, height, version), VersionGrid::new(width, height, version)],
        }
    }

    pub fn geometry(&self) -> &PageGeometry {
        &self.geometry
    }

    pub fn version_in(&self, layer: Layer, rect: &Rect) -> u64 {
        self.versions[layer as usize].version_in(rect)
    }

    /// Adds strokes on top. A stroke whose ID already exists replaces the old one (which is
    /// removed from its position), like `DocumentNotifier.modifyElementsExecute`.
    pub fn add_strokes(&mut self, strokes: Vec<Stroke>, version: u64) {
        if strokes.is_empty() {
            return;
        }
        let ids: Vec<u64> = strokes.iter().map(|s| s.id).collect();
        self.remove_strokes(&ids, version);
        let grid = &mut self.versions[Layer::Ink as usize];
        let ink = Arc::make_mut(&mut self.geometry.ink);
        for stroke in strokes {
            grid.bump(&stroke.bounds().inflate(CHANGE_MARGIN_MM), version);
            ink.push(Arc::new(stroke));
        }
    }

    /// Removes the strokes with the given IDs (unknown IDs are ignored).
    pub fn remove_strokes(&mut self, ids: &[u64], version: u64) {
        if ids.is_empty() || !self.geometry.ink.iter().any(|s| ids.contains(&s.id)) {
            return;
        }
        let grid = &mut self.versions[Layer::Ink as usize];
        Arc::make_mut(&mut self.geometry.ink).retain(|s| {
            let remove = ids.contains(&s.id);
            if remove {
                grid.bump(&s.bounds().inflate(CHANGE_MARGIN_MM), version);
            }
            !remove
        });
    }

    /// Sets the hidden ink strokes (replaces the previous set). Only strokes whose state changes
    /// mark their area as changed.
    pub fn set_hidden(&mut self, ids: HashSet<u64>, version: u64) {
        if *self.geometry.hidden == ids {
            return;
        }
        let old = std::mem::take(&mut self.geometry.hidden);
        let grid = &mut self.versions[Layer::Ink as usize];
        for stroke in self.geometry.ink.iter() {
            if old.contains(&stroke.id) != ids.contains(&stroke.id) {
                grid.bump(&stroke.bounds().inflate(CHANGE_MARGIN_MM), version);
            }
        }
        self.geometry.hidden = Arc::new(ids);
    }

    /// Changes the page size, keeping the content. Everything counts as changed.
    pub fn resize(&mut self, width: f32, height: f32, version: u64) {
        self.geometry.width = width;
        self.geometry.height = height;
        self.versions = [VersionGrid::new(width, height, version), VersionGrid::new(width, height, version)];
    }

    /// Replaces page colour and line pattern.
    pub fn set_background(&mut self, color: u32, strokes: Vec<Stroke>, version: u64) {
        self.geometry.color = color;
        self.geometry.background = Arc::new(strokes.into_iter().map(Arc::new).collect());
        self.versions[Layer::Background as usize].bump_all(version);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::engine::geometry::Point;

    fn stroke(id: u64, x: f32, y: f32) -> Stroke {
        Stroke::new(id, 0xff000000, vec![Point::new(x, y, 1.0), Point::new(x + 1.0, y, 1.0)])
    }

    #[test]
    fn changes_bump_only_the_touched_area() {
        let mut page = PageMirror::new(210.0, 297.0, 0xffffffff, 1);
        page.add_strokes(vec![stroke(1, 20.0, 20.0)], 2);
        assert_eq!(page.version_in(Layer::Ink, &Rect::from_ltwh(16.0, 16.0, 8.0, 8.0)), 2);
        assert_eq!(page.version_in(Layer::Ink, &Rect::from_ltwh(100.0, 100.0, 8.0, 8.0)), 1);
        assert_eq!(page.version_in(Layer::Background, &Rect::from_ltwh(16.0, 16.0, 8.0, 8.0)), 1);
        // A tile covering both areas has the newest version.
        assert_eq!(page.version_in(Layer::Ink, &page.geometry().rect()), 2);

        page.remove_strokes(&[1], 3);
        assert_eq!(page.version_in(Layer::Ink, &Rect::from_ltwh(16.0, 16.0, 8.0, 8.0)), 3);
        assert!(page.geometry().ink.is_empty());
    }

    #[test]
    fn adding_an_existing_id_replaces_the_stroke() {
        let mut page = PageMirror::new(210.0, 297.0, 0xffffffff, 1);
        page.add_strokes(vec![stroke(1, 20.0, 20.0), stroke(2, 50.0, 50.0)], 2);
        page.add_strokes(vec![stroke(1, 100.0, 100.0)], 3);
        let ink = &page.geometry().ink;
        assert_eq!(ink.iter().map(|s| s.id).collect::<Vec<_>>(), vec![2, 1]);
        assert_eq!(ink[1].points[0].x, 100.0);
        // Old and new position are both marked as changed.
        assert_eq!(page.version_in(Layer::Ink, &Rect::from_ltwh(16.0, 16.0, 8.0, 8.0)), 3);
        assert_eq!(page.version_in(Layer::Ink, &Rect::from_ltwh(96.0, 96.0, 8.0, 8.0)), 3);
    }

    #[test]
    fn snapshots_are_not_affected_by_later_changes() {
        let mut page = PageMirror::new(210.0, 297.0, 0xffffffff, 1);
        page.add_strokes(vec![stroke(1, 20.0, 20.0)], 2);
        let snapshot = page.geometry().clone();
        page.add_strokes(vec![stroke(2, 30.0, 30.0)], 3);
        assert_eq!(snapshot.ink.len(), 1);
        assert_eq!(page.geometry().ink.len(), 2);
    }

    #[test]
    fn hiding_bumps_only_strokes_that_change() {
        let mut page = PageMirror::new(210.0, 297.0, 0xffffffff, 1);
        page.add_strokes(vec![stroke(1, 20.0, 20.0), stroke(2, 100.0, 100.0)], 2);
        let at = |page: &PageMirror, x: f32| page.version_in(Layer::Ink, &Rect::from_ltwh(x - 4.0, x - 4.0, 8.0, 8.0));
        page.set_hidden([1].into_iter().collect(), 3);
        assert_eq!((at(&page, 20.0), at(&page, 100.0)), (3, 2));
        page.set_hidden([1].into_iter().collect(), 4); // unchanged: no bump
        assert_eq!(at(&page, 20.0), 3);
        page.set_hidden([2].into_iter().collect(), 5);
        assert_eq!((at(&page, 20.0), at(&page, 100.0)), (5, 5));
    }

    #[test]
    fn rects_outside_the_page_have_version_zero() {
        let page = PageMirror::new(210.0, 297.0, 0xffffffff, 5);
        assert_eq!(page.version_in(Layer::Ink, &Rect::from_ltwh(300.0, 0.0, 10.0, 10.0)), 0);
        assert_eq!(page.version_in(Layer::Ink, &Rect::from_ltwh(-20.0, -20.0, 10.0, 10.0)), 0);
    }
}
