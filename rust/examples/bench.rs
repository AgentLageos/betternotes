//! Renderer benchmark, independent of Flutter: `cargo run --release --example bench`.
//!
//! Prints rasterization time per tile and the time until a whole page is delivered by the
//! threaded renderer, for the sample page and a dense handwritten page.

#[path = "../tests/common/mod.rs"]
mod common;

use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use bn_renderer::engine::geometry::{Point, Rect, Stroke};
use bn_renderer::engine::page::{Layer, PageGeometry, PageKey};
use bn_renderer::engine::raster::{into_rgba, render_tile};
use bn_renderer::engine::renderer::{PageViewport, Renderer, RendererConfig};
use bn_renderer::engine::tiles::{grid_size, Scale};

/// A page full of handwriting: 40 lines × 25 words, each word a stroke of 60 points.
fn dense_ink() -> Vec<Stroke> {
    let mut strokes = Vec::new();
    let mut id = 0;
    for line in 0..40 {
        for word in 0..25 {
            id += 1;
            let x0 = 8.0 + word as f32 * 7.8;
            let y0 = 10.0 + line as f32 * 7.0;
            strokes.push(Stroke::new(id, 0xff202020, (0..60).map(|i| {
                let t = i as f32 / 59.0;
                let wiggle = (t * 40.0 + id as f32).sin();
                Point::new(x0 + t * 6.0 + wiggle * 0.4, y0 + (t * 17.0 + id as f32 * 0.7).sin() * 1.6, 0.3 + 0.15 * wiggle.abs())
            }).collect()));
        }
    }
    strokes
}

fn geometry(ink: &[Stroke]) -> PageGeometry {
    let mut page = PageGeometry::new(common::A4.0, common::A4.1, common::PAGE_COLOR);
    page.background = Arc::new(common::ruled_background().into_iter().map(Arc::new).collect());
    page.ink = Arc::new(ink.iter().cloned().map(Arc::new).collect());
    page
}

fn ms(d: Duration) -> f64 {
    d.as_secs_f64() * 1000.0
}

/// Single thread: average time to rasterize (and convert) one tile, over the whole page.
fn raster_per_tile(page: &PageGeometry, scale: f32, layer: Layer) -> (f64, u32) {
    let (cols, rows) = grid_size(page.width, page.height, Scale::new(scale));
    let start = Instant::now();
    for y in 0..rows {
        for x in 0..cols {
            let tile = render_tile(page, layer, scale, x, y);
            std::hint::black_box(into_rgba(tile));
        }
    }
    (ms(start.elapsed()) / (cols * rows) as f64, cols * rows)
}

/// Threaded renderer: time from opening a page and setting the viewport until all visible tiles
/// are delivered, then the time to deliver the update after adding one stroke.
fn renderer_whole_page(ink: &[Stroke], scale: f32, threads: usize) -> (f64, usize, f64) {
    let count = Arc::new(AtomicUsize::new(0));
    let sink_count = count.clone();
    let renderer = Renderer::new(
        RendererConfig { threads, cache_bytes: 256 << 20, prefetch_margin: 0 },
        Box::new(move |_| {
            sink_count.fetch_add(1, Ordering::Relaxed);
            true
        }),
    );
    let page = PageKey { doc: 1, page: 1 };
    let start = Instant::now();
    renderer.open_page(page, common::A4.0, common::A4.1, common::PAGE_COLOR);
    renderer.set_background(page, common::PAGE_COLOR, common::ruled_background());
    let _ = renderer.add_strokes(page, ink.to_vec());
    renderer.set_viewport(&[PageViewport { page, scale, visible: Rect::from_ltwh(0.0, 0.0, common::A4.0, common::A4.1) }]);
    renderer.wait_idle();
    let full = ms(start.elapsed());
    let tiles = count.load(Ordering::Relaxed);

    let start = Instant::now();
    let _ = renderer.add_strokes(page, vec![common::pen_wave(999_999, 30.0, 150.0, 0xff1a237e)]);
    renderer.wait_idle();
    (full, tiles, ms(start.elapsed()))
}

fn main() {
    let threads = RendererConfig::default().threads;
    println!("bn_renderer benchmark ({threads} worker threads by default)\n");

    for (name, ink) in [("sample page", common::sample_ink()), ("dense page (1000 strokes × 60 points)", dense_ink())] {
        println!("{name}");
        let page = geometry(&ink);
        for scale in [4.0, 8.0, 16.0] {
            let (bg, tiles) = raster_per_tile(&page, scale, Layer::Background);
            let (ink_ms, _) = raster_per_tile(&page, scale, Layer::Ink);
            println!("  {scale:>4} px/mm, {tiles:>3} tiles: background {bg:.2} ms/tile, ink {ink_ms:.2} ms/tile (1 thread)");
        }
        for scale in [4.0, 8.0] {
            for t in [1, threads] {
                let (full, tiles, update) = renderer_whole_page(&ink, scale, t);
                println!("  renderer {scale} px/mm, {t} threads: whole page ({tiles} tiles) {full:.1} ms, update after one stroke {update:.1} ms");
            }
        }
        println!();
    }
}
