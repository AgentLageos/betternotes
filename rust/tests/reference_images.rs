//! Renders the sample page to PNG and compares it against reference images in
//! `tests/reference/`. Missing references are written (and the test passes); to update them after
//! an intended change, run `BN_UPDATE_REFERENCE=1 cargo test --test reference_images` and look at
//! the new images before committing them.

mod common;

use std::path::PathBuf;
use std::sync::Arc;

use bn_renderer::engine::geometry::{Point, Stroke};
use bn_renderer::engine::page::{Layer, PageGeometry};
use bn_renderer::engine::raster::{draw_stroke, render_tile};
use bn_renderer::engine::tiles::{grid_size, Scale, TILE_PX};
use tiny_skia::{Pixmap, PixmapPaint, Transform};

fn sample_page() -> PageGeometry {
    let mut page = PageGeometry::new(common::A4.0, common::A4.1, common::PAGE_COLOR);
    page.background = Arc::new(common::ruled_background().into_iter().map(Arc::new).collect());
    page.ink = Arc::new(common::sample_ink().into_iter().map(Arc::new).collect());
    page
}

/// The whole page assembled from tiles (background, then ink on top), cropped to the page.
fn page_from_tiles(page: &PageGeometry, scale: f32) -> Pixmap {
    let (cols, rows) = grid_size(page.width, page.height, Scale::new(scale));
    let width = (page.width * scale).ceil() as u32;
    let height = (page.height * scale).ceil() as u32;
    let mut out = Pixmap::new(width, height).unwrap();
    for y in 0..rows {
        for x in 0..cols {
            for layer in Layer::ALL {
                let tile = render_tile(page, layer, scale, x, y);
                out.draw_pixmap((x * TILE_PX) as i32, (y * TILE_PX) as i32, tile.as_ref(), &PixmapPaint::default(), Transform::identity(), None);
            }
        }
    }
    out
}

/// The whole page drawn in one pass, without tiles.
fn page_in_one_pass(page: &PageGeometry, scale: f32) -> Pixmap {
    let mut out = Pixmap::new((page.width * scale).ceil() as u32, (page.height * scale).ceil() as u32).unwrap();
    let transform = Transform::from_scale(scale, scale);
    out.fill_rect(tiny_skia::Rect::from_xywh(0.0, 0.0, page.width, page.height).unwrap(), &{
        let mut p = tiny_skia::Paint::default();
        let c = page.color;
        p.set_color_rgba8((c >> 16) as u8, (c >> 8) as u8, c as u8, (c >> 24) as u8);
        p
    }, transform, None);
    for stroke in page.background.iter().chain(page.ink.iter()) {
        draw_stroke(&mut out, stroke, transform);
    }
    out
}

/// (number of pixels differing by more than `tolerance` in any channel, largest difference)
fn diff(a: &Pixmap, b: &Pixmap, tolerance: u8) -> (usize, u8) {
    assert_eq!((a.width(), a.height()), (b.width(), b.height()), "image sizes differ");
    let mut count = 0;
    let mut max = 0;
    for (pa, pb) in a.data().chunks_exact(4).zip(b.data().chunks_exact(4)) {
        let d = pa.iter().zip(pb).map(|(x, y)| x.abs_diff(*y)).max().unwrap();
        max = max.max(d);
        if d > tolerance {
            count += 1;
        }
    }
    (count, max)
}

fn reference_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/reference")
}

fn check_reference(name: &str, image: &Pixmap) {
    let dir = reference_dir();
    let path = dir.join(format!("{name}.png"));
    let update = std::env::var_os("BN_UPDATE_REFERENCE").is_some();
    if update || !path.exists() {
        std::fs::create_dir_all(&dir).unwrap();
        image.save_png(&path).unwrap();
        eprintln!("wrote reference image {}", path.display());
        return;
    }
    let reference = Pixmap::load_png(&path).unwrap();
    let (count, max) = diff(image, &reference, 2);
    if count > 0 {
        let actual = dir.join(format!("{name}.actual.png"));
        image.save_png(&actual).unwrap();
        panic!("{name}: {count} pixels differ (max {max}); see {}", actual.display());
    }
}

#[test]
fn sample_page_matches_reference() {
    check_reference("sample_page_4px", &page_from_tiles(&sample_page(), 4.0));
}

#[test]
fn zoomed_tile_matches_reference() {
    // Tile (7, 4) at 32 px/mm covers 56..64 × 32..40 mm: the wave crossing the highlighter.
    let page = sample_page();
    let mut out = render_tile(&page, Layer::Background, 32.0, 7, 4);
    let ink = render_tile(&page, Layer::Ink, 32.0, 7, 4);
    out.draw_pixmap(0, 0, ink.as_ref(), &PixmapPaint::default(), Transform::identity(), None);
    check_reference("zoomed_tile_32px", &out);
}

/// Pixels within `band` px of a tile border that differ by more than `tolerance`:
/// (x, y, largest channel difference).
fn border_differences(a: &Pixmap, b: &Pixmap, band: u32, tolerance: u8) -> Vec<(u32, u32, u8)> {
    let near = |v: u32| {
        let m = v % TILE_PX;
        m < band || m >= TILE_PX - band
    };
    let mut out = Vec::new();
    for (i, (pa, pb)) in a.data().chunks_exact(4).zip(b.data().chunks_exact(4)).enumerate() {
        let (x, y) = (i as u32 % a.width(), i as u32 / a.width());
        let d = pa.iter().zip(pb).map(|(p, q)| p.abs_diff(*q)).max().unwrap();
        if d > tolerance && (near(x) || near(y)) {
            out.push((x, y, d));
        }
    }
    out
}

#[test]
fn tiles_have_no_seams() {
    // Compares the page assembled from tiles with the page drawn in one pass, near the tile
    // borders. Odd scales on purpose: tile borders fall at fractional mm positions.
    //
    // Inside tiles a few isolated pixels may differ: the two renders use different whole-pixel
    // offsets, and f32 rounding of the transformed coordinates can flip single anti-aliasing
    // sub-samples (seen at the end caps of small strokes, up to 27/255). Those are not seams.
    let page = sample_page();
    for scale in [3.7, 4.0, 11.3] {
        let tiled = page_from_tiles(&page, scale);
        let whole = page_in_one_pass(&page, scale);
        // Seams show up as differences concentrated at tile borders. Isolated rounding
        // differences (see above) occur everywhere at about the same rate, so compare rates.
        // Measured at 11.3 px/mm: no padding 3e-3, 8 px padding 3.1e-4 at borders vs. 3.9e-5
        // overall; 16 px padding 1.5e-5 vs. 1.9e-5.
        let band = 3;
        let border_pixels = {
            let (w, h) = (tiled.width(), tiled.height());
            let lines = |len: u32| (len / TILE_PX + 1) * 2 * band;
            (lines(w) * h + lines(h) * w) as usize
        };
        let seams = border_differences(&tiled, &whole, band, 2);
        let (all, all_max) = diff(&tiled, &whole, 2);
        let total = (tiled.width() * tiled.height()) as usize;
        let border_rate = seams.len() as f64 / border_pixels as f64;
        let rate = all as f64 / total as f64;
        if std::env::var_os("BN_DEBUG_SEAMS").is_some() {
            eprintln!("scale {scale}: border {}/{border_pixels} = {border_rate:.2e}, all {all}/{total} = {rate:.2e} (max {all_max})", seams.len());
        }
        assert!(
            border_rate <= 3.0 * rate + 2.0 / border_pixels as f64,
            "scale {scale}: seams: {} of {border_pixels} border pixels differ ({border_rate:.2e}, overall {rate:.2e}): {:?}",
            seams.len(),
            &seams[..seams.len().min(10)]
        );
        assert!(all * 10_000 < total, "scale {scale}: {all} of {total} pixels differ");
    }
}

#[test]
fn transparent_strokes_have_no_overlap_spots() {
    // A semi-transparent constant-width polyline must have the same alpha at a joint as
    // in the middle of a segment (the Dart renderer drew segments separately).
    let page = PageGeometry {
        ink: Arc::new(vec![Arc::new(Stroke::new(1, 0x80000000, vec![
            Point::new(1.0, 4.0, 1.0),
            Point::new(4.0, 4.0, 1.0),
            Point::new(7.0, 4.0, 1.0),
        ]))]),
        ..PageGeometry::new(8.0, 8.0, 0)
    };
    let tile = render_tile(&page, Layer::Ink, 32.0, 0, 0);
    let alpha = |x: u32| tile.pixel(x, 128).unwrap().alpha();
    assert_eq!(alpha(128), alpha(80)); // joint at x = 4 mm vs. segment middle
}
