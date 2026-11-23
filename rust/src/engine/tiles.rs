//! Tile grid: fixed-size pixel tiles at a given scale.
//!
//! A tile is always [`TILE_PX`] × [`TILE_PX`] device pixels. At scale `s` (device pixels per mm)
//! tile `(x, y)` covers the page area `[x, x + 1) × [y, y + 1)` in units of `TILE_PX / s` mm, so the
//! tile grid is aligned to the device pixel grid when the page origin is (R1-04/R1-05).
//!
//! During zoom gestures Dart shows tiles of the nearest power-of-two level ([`level_scale`],
//! [`nearest_level`]) scaled; when the gesture ends it requests tiles at the exact scale.

use super::geometry::Rect;
use super::page::{Layer, PageKey};

/// Edge length of a tile in device pixels.
pub const TILE_PX: u32 = 256;

/// Scale in device pixels per mm, usable as a hash key (exact f32 bit pattern).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Scale(u32);

impl Scale {
    /// Panics for non-positive or non-finite scales.
    pub fn new(px_per_mm: f32) -> Self {
        assert!(px_per_mm.is_finite() && px_per_mm > 0.0, "invalid scale {px_per_mm}");
        Scale(px_per_mm.to_bits())
    }

    pub fn get(self) -> f32 {
        f32::from_bits(self.0)
    }

    /// Edge length of a tile in mm at this scale.
    pub fn tile_mm(self) -> f32 {
        TILE_PX as f32 / self.get()
    }
}

/// Scale of zoom level `level`: 2^level pixels per mm.
pub fn level_scale(level: i32) -> f32 {
    2f32.powi(level)
}

/// The power-of-two level closest to `scale` (in log space).
pub fn nearest_level(scale: f32) -> i32 {
    scale.log2().round() as i32
}

/// One tile of one layer of a page at one scale.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct TileKey {
    pub page: PageKey,
    pub layer: Layer,
    pub scale: Scale,
    pub x: u32,
    pub y: u32,
}

impl TileKey {
    /// Page area covered by this tile in mm (may extend beyond the page at the right/bottom edge).
    pub fn rect(&self) -> Rect {
        let size = self.scale.tile_mm();
        Rect::from_ltwh(self.x as f32 * size, self.y as f32 * size, size, size)
    }
}

/// Number of tile columns and rows needed for a page of the given size.
pub fn grid_size(page_width: f32, page_height: f32, scale: Scale) -> (u32, u32) {
    let size = scale.tile_mm();
    ((page_width / size).ceil().max(1.0) as u32, (page_height / size).ceil().max(1.0) as u32)
}

/// Tiles `(x, y)` of a page that intersect `area` (in mm), within the page's grid.
/// `margin` adds that many tiles around the area (for prefetching neighbours).
pub fn tiles_in(page_width: f32, page_height: f32, scale: Scale, area: &Rect, margin: u32) -> Vec<(u32, u32)> {
    let (cols, rows) = grid_size(page_width, page_height, scale);
    let area = area.intersect(&Rect::from_ltwh(0.0, 0.0, page_width, page_height));
    if area.is_empty() {
        return Vec::new();
    }
    let size = scale.tile_mm();
    let first = |v: f32| ((v / size).floor().max(0.0) as u32).saturating_sub(margin);
    let last = |v: f32, count: u32| ((v / size).ceil() as u32 + margin).min(count);
    let (x0, x1) = (first(area.left), last(area.right, cols));
    let (y0, y1) = (first(area.top), last(area.bottom, rows));
    (y0..y1).flat_map(|y| (x0..x1).map(move |x| (x, y))).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn levels_round_in_log_space() {
        assert_eq!(nearest_level(1.0), 0);
        assert_eq!(nearest_level(5.0), 2); // log2(5) = 2.32
        assert_eq!(nearest_level(6.0), 3); // log2(6) = 2.58
        assert_eq!(level_scale(3), 8.0);
    }

    #[test]
    fn grid_covers_the_page() {
        // A4 at 4 px/mm: tiles are 64 mm, so 4 × 5 tiles.
        assert_eq!(grid_size(210.0, 297.0, Scale::new(4.0)), (4, 5));
        let key = TileKey { page: PageKey { doc: 1, page: 1 }, layer: Layer::Ink, scale: Scale::new(4.0), x: 3, y: 4 };
        assert_eq!(key.rect(), Rect::from_ltwh(192.0, 256.0, 64.0, 64.0));
    }

    #[test]
    fn tiles_in_area_with_margin() {
        let s = Scale::new(4.0); // 64 mm tiles
        let visible = Rect::from_ltwh(70.0, 70.0, 10.0, 10.0);
        assert_eq!(tiles_in(210.0, 297.0, s, &visible, 0), vec![(1, 1)]);
        assert_eq!(tiles_in(210.0, 297.0, s, &visible, 1).len(), 9);
        // Clipped to the page.
        assert_eq!(tiles_in(210.0, 297.0, s, &Rect::from_ltwh(-50.0, -50.0, 60.0, 60.0), 1).len(), 4);
        assert!(tiles_in(210.0, 297.0, s, &Rect::from_ltwh(300.0, 0.0, 10.0, 10.0), 1).is_empty());
    }
}
