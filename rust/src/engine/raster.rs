//! Rasterization of one tile with tiny-skia (D6).
//!
//! Stroke drawing follows `lib/core/utils/draw_strokes.dart`, so strokes look like in the Dart
//! renderer:
//! - one point: a filled circle with the point's width as diameter
//! - all points the same width: a polyline with round caps and joins
//! - varying widths: a filled outline (left/right offsets along the segment normals, smoothed
//!   with quadratic curves through the midpoints) plus a circle at both ends
//!
//! Differences:
//! - same-width strokes are stroked as one path instead of segment by segment, so
//!   semi-transparent strokes no longer get darker spots where segments overlap
//! - the varying-width outline reaches the end points (see [`outline`])

use tiny_skia::{FillRule, LineCap, LineJoin, Paint, PathBuilder, Pixmap, Transform};

use super::geometry::{Point, Rect, Stroke};
use super::page::{Layer, PageGeometry};
use super::tiles::TILE_PX;

/// Extra margin (in device pixels) around a tile when picking strokes, for anti-aliasing.
const AA_MARGIN_PX: f32 = 2.0;

/// Tiles are drawn with this many pixels of padding on each side and then cropped. tiny-skia
/// anti-aliases paths slightly differently where they are clipped at the pixmap edge, and the
/// effect reaches several pixels inward for flat edges. Without padding that showed as seams of up
/// to 55/255 at tile borders; 8 px still left 8× more differences at borders than elsewhere at
/// 11.3 px/mm; with 16 px borders are no different from the rest (`tests/reference_images.rs`).
/// Costs ~27 % more pixels per tile.
const PADDING_PX: u32 = 16;

/// Renders layer `layer` of tile `(x, y)` at `scale` (device pixels per mm) into a new
/// [`TILE_PX`]² pixmap. Pixels outside the page stay transparent.
pub fn render_tile(page: &PageGeometry, layer: Layer, scale: f32, x: u32, y: u32) -> Pixmap {
    let tile_px = TILE_PX as f32;
    let pad = PADDING_PX as f32;
    let mut pixmap = Pixmap::new(TILE_PX + 2 * PADDING_PX, TILE_PX + 2 * PADDING_PX).expect("tile size is non-zero");
    let origin_x = x as f32 * tile_px;
    let origin_y = y as f32 * tile_px;
    // mm -> pixels of the padded pixmap
    let transform = Transform::from_row(scale, 0.0, 0.0, scale, pad - origin_x, pad - origin_y);

    let tile_mm = Rect::from_ltwh(origin_x / scale, origin_y / scale, tile_px / scale, tile_px / scale);
    let visible = tile_mm.inflate((AA_MARGIN_PX + pad) / scale);

    if layer == Layer::Background {
        if let Some(rect) = to_skia_rect(&page.rect().intersect(&tile_mm.inflate(pad / scale))) {
            pixmap.fill_rect(rect, &paint(page.color), transform, None);
        }
    }

    for stroke in page.strokes(layer) {
        if stroke.bounds().overlaps(&visible) && !(layer == Layer::Ink && page.hidden.contains(&stroke.id)) {
            draw_stroke(&mut pixmap, stroke, transform);
        }
    }

    let mut tile = crop(&pixmap, PADDING_PX);

    // Clear what lies beyond the page (last column/row of tiles).
    let page_right = (page.width * scale - origin_x).ceil();
    let page_bottom = (page.height * scale - origin_y).ceil();
    if page_right < tile_px || page_bottom < tile_px {
        clear_outside(&mut tile, page_right.max(0.0) as u32, page_bottom.max(0.0) as u32);
    }
    tile
}

/// The [`TILE_PX`]² area of `padded` starting at (`pad`, `pad`).
fn crop(padded: &Pixmap, pad: u32) -> Pixmap {
    let mut tile = Pixmap::new(TILE_PX, TILE_PX).expect("tile size is non-zero");
    let src_stride = padded.width() as usize * 4;
    let row_bytes = TILE_PX as usize * 4;
    let src = padded.data();
    for (row, dst) in tile.data_mut().chunks_exact_mut(row_bytes).enumerate() {
        let start = (row + pad as usize) * src_stride + pad as usize * 4;
        dst.copy_from_slice(&src[start..start + row_bytes]);
    }
    tile
}

/// Draws one stroke. `transform` maps mm to pixmap pixels.
pub fn draw_stroke(pixmap: &mut Pixmap, stroke: &Stroke, transform: Transform) {
    let points = &stroke.points;
    let Some(first) = points.first() else { return };
    let paint = paint(stroke.color);

    if points.len() == 1 {
        fill_circle(pixmap, first, &paint, transform);
        return;
    }

    let same_width = points.iter().all(|p| p.width == first.width);
    if same_width {
        if points.iter().all(|p| p.x == first.x && p.y == first.y) {
            // Zero-length polyline (a dot; Stroke.frozen() doubles single points).
            fill_circle(pixmap, first, &paint, transform);
            return;
        }
        let mut pb = PathBuilder::new();
        pb.move_to(first.x, first.y);
        for p in &points[1..] {
            pb.line_to(p.x, p.y);
        }
        if let Some(path) = pb.finish() {
            let style = tiny_skia::Stroke {
                width: first.width,
                line_cap: LineCap::Round,
                line_join: LineJoin::Round,
                ..Default::default()
            };
            pixmap.stroke_path(&path, &paint, &style, transform, None);
        }
        return;
    }

    if let Some(path) = outline(points) {
        fill_circle(pixmap, first, &paint, transform);
        fill_circle(pixmap, points.last().unwrap(), &paint, transform);
        pixmap.fill_path(&path, &paint, FillRule::Winding, transform, None);
    }
}

/// Outline of a stroke with varying width (same construction as `drawStrokes` in Dart).
fn outline(points: &[Point]) -> Option<tiny_skia::Path> {
    let mut left = Vec::with_capacity(points.len());
    let mut right = Vec::with_capacity(points.len());
    for (i, pair) in points.windows(2).enumerate() {
        let (p0, p1) = (pair[0], pair[1]);
        let (dx, dy) = (p1.x - p0.x, p1.y - p0.y);
        let distance = (dx * dx + dy * dy).sqrt();
        let (nx, ny) = if distance < 0.01 { (0.0, 1.0) } else { (-dy / distance, dx / distance) };
        left.push((p0.x + nx * p0.width / 2.0, p0.y + ny * p0.width / 2.0));
        right.push((p0.x - nx * p0.width / 2.0, p0.y - ny * p0.width / 2.0));
        if i == points.len() - 2 {
            left.push((p1.x + nx * p1.width / 2.0, p1.y + ny * p1.width / 2.0));
            right.push((p1.x - nx * p1.width / 2.0, p1.y - ny * p1.width / 2.0));
        }
    }

    // Unlike the Dart version, the outline runs to the last point on both sides and back to the
    // first: the Dart path stopped at the middle of the last segment, which left a visible gap
    // before the end cap when points are far apart.
    let n = left.len();
    let mut pb = PathBuilder::new();
    pb.move_to(left[0].0, left[0].1);
    for i in 0..n - 1 {
        let mid = ((left[i].0 + left[i + 1].0) / 2.0, (left[i].1 + left[i + 1].1) / 2.0);
        pb.quad_to(left[i].0, left[i].1, mid.0, mid.1);
    }
    pb.line_to(left[n - 1].0, left[n - 1].1);
    pb.line_to(right[n - 1].0, right[n - 1].1);
    for i in (1..n).rev() {
        let mid = ((right[i].0 + right[i - 1].0) / 2.0, (right[i].1 + right[i - 1].1) / 2.0);
        pb.quad_to(right[i].0, right[i].1, mid.0, mid.1);
    }
    pb.line_to(right[0].0, right[0].1);
    pb.close();
    pb.finish()
}

fn fill_circle(pixmap: &mut Pixmap, p: &Point, paint: &Paint, transform: Transform) {
    if let Some(circle) = PathBuilder::from_circle(p.x, p.y, p.width / 2.0) {
        pixmap.fill_path(&circle, paint, FillRule::Winding, transform, None);
    }
}

fn paint(argb: u32) -> Paint<'static> {
    let mut paint = Paint::default();
    paint.set_color_rgba8((argb >> 16) as u8, (argb >> 8) as u8, argb as u8, (argb >> 24) as u8);
    paint.anti_alias = true;
    paint
}

fn to_skia_rect(rect: &Rect) -> Option<tiny_skia::Rect> {
    if rect.is_empty() {
        return None;
    }
    tiny_skia::Rect::from_ltrb(rect.left, rect.top, rect.right, rect.bottom)
}

/// Makes all pixels at or beyond column `right` / row `bottom` transparent.
fn clear_outside(pixmap: &mut Pixmap, right: u32, bottom: u32) {
    let width = pixmap.width() as usize;
    let (right, bottom) = (right as usize, bottom as usize);
    for (row, chunk) in pixmap.data_mut().chunks_exact_mut(width * 4).enumerate() {
        if row >= bottom {
            chunk.fill(0);
        } else if right < width {
            chunk[right * 4..].fill(0);
        }
    }
}

/// The pixels as RGBA bytes with premultiplied alpha: the format of Flutter's
/// `decodeImageFromPixels(..., PixelFormat.rgba8888, ...)` (documented as premultiplied), and
/// tiny-skia's own format, so no conversion is needed.
pub fn into_rgba(pixmap: Pixmap) -> Vec<u8> {
    pixmap.take()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;

    fn page_with(strokes: Vec<Stroke>) -> PageGeometry {
        let mut page = PageGeometry::new(210.0, 297.0, 0xffffffff);
        page.ink = Arc::new(strokes.into_iter().map(Arc::new).collect());
        page
    }

    fn alpha_at(pixmap: &Pixmap, x: u32, y: u32) -> u8 {
        pixmap.pixel(x, y).unwrap().alpha()
    }

    #[test]
    fn single_point_and_doubled_point_draw_a_dot() {
        for points in [vec![Point::new(8.0, 8.0, 4.0)], vec![Point::new(8.0, 8.0, 4.0); 2]] {
            let tile = render_tile(&page_with(vec![Stroke::new(1, 0xff000000, points)]), Layer::Ink, 16.0, 0, 0);
            assert_eq!(alpha_at(&tile, 128, 128), 255, "centre of the dot");
            assert_eq!(alpha_at(&tile, 128, 128 + 40), 0, "outside the 2 mm radius");
        }
    }

    #[test]
    fn strokes_are_cut_at_the_page_edge() {
        // Page 20 mm wide at 16 px/mm: the page ends at x = 320 px, inside tile 1 (256..512).
        let mut page = page_with(vec![Stroke::new(1, 0xff000000, vec![Point::new(0.0, 5.0, 2.0), Point::new(40.0, 5.0, 2.0)])]);
        page.width = 20.0;
        let tile = render_tile(&page, Layer::Ink, 16.0, 1, 0);
        assert_eq!(alpha_at(&tile, 10, 80), 255);
        assert_eq!(alpha_at(&tile, 100, 80), 0);
    }

    #[test]
    fn background_fills_only_the_page() {
        let mut page = page_with(vec![]);
        page.width = 20.0;
        page.color = 0xff336699;
        let tile = render_tile(&page, Layer::Background, 16.0, 1, 0);
        let p = tile.pixel(10, 10).unwrap();
        assert_eq!((p.red(), p.green(), p.blue(), p.alpha()), (0x33, 0x66, 0x99, 255));
        assert_eq!(alpha_at(&tile, 100, 10), 0);
    }

    #[test]
    fn premultiplied_output() {
        let tile = render_tile(&page_with(vec![Stroke::new(1, 0x80ff0000, vec![Point::new(8.0, 8.0, 4.0)])]), Layer::Ink, 16.0, 0, 0);
        let rgba = into_rgba(tile);
        let i = (128 * TILE_PX as usize + 128) * 4;
        assert_eq!(&rgba[i..i + 4], &[128, 0, 0, 128]);
    }

    #[test]
    fn hidden_strokes_are_not_drawn() {
        let mut page = page_with(vec![Stroke::new(1, 0xff000000, vec![Point::new(8.0, 8.0, 4.0)])]);
        page.hidden = Arc::new([1].into_iter().collect());
        let tile = render_tile(&page, Layer::Ink, 16.0, 0, 0);
        assert_eq!(alpha_at(&tile, 128, 128), 0);
    }
}
