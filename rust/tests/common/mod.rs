//! Shared test data: a sample page with the kinds of strokes the app produces.
#![allow(dead_code)]

use bn_renderer::engine::geometry::{Point, Stroke};

pub const A4: (f32, f32) = (210.0, 297.0);
pub const PAGE_COLOR: u32 = 0xfffffbf0;

/// Ruled lines every 8 mm, like `PageModel.withBackgroundSpacing`.
pub fn ruled_background() -> Vec<Stroke> {
    let mut id = 1_000_000;
    let mut lines = Vec::new();
    let mut y = 16.0;
    while y < A4.1 {
        id += 1;
        lines.push(Stroke::new(id, 0xffb0c4de, vec![Point::new(0.0, y, 0.2), Point::new(A4.0, y, 0.2)]));
        y += 8.0;
    }
    lines
}

/// Variable-width wave, as drawn with a pressure-sensitive pen.
pub fn pen_wave(id: u64, x0: f32, y0: f32, color: u32) -> Stroke {
    let points = (0..=120)
        .map(|i| {
            let t = i as f32 / 120.0;
            let x = x0 + t * 150.0;
            let y = y0 + (t * std::f32::consts::TAU * 2.0).sin() * 10.0;
            Point::new(x, y, 0.4 + 1.2 * (t * std::f32::consts::PI).sin())
        })
        .collect();
    Stroke::new(id, color, points)
}

/// The sample page used by the reference tests and the benchmark.
pub fn sample_ink() -> Vec<Stroke> {
    let mut strokes = vec![
        pen_wave(1, 20.0, 40.0, 0xff1a237e),
        // Constant width polyline (line tool, arrow).
        Stroke::new(2, 0xffc62828, vec![
            Point::new(20.0, 80.0, 0.8),
            Point::new(150.0, 80.0, 0.8),
            Point::new(144.0, 76.0, 0.8),
            Point::new(150.0, 80.0, 0.8),
            Point::new(144.0, 84.0, 0.8),
        ]),
        // Dot (single point doubled by Stroke.frozen()).
        Stroke::new(3, 0xff000000, vec![Point::new(175.0, 80.0, 2.0); 2]),
        // Semi-transparent highlighter across the wave.
        Stroke::new(4, 0x80ffeb3b, vec![Point::new(15.0, 42.0, 6.0), Point::new(60.0, 38.0, 6.0), Point::new(110.0, 44.0, 6.0)]),
        // Closed-ish shape crossing tile borders.
        Stroke::new(5, 0xff2e7d32, (0..=64).map(|i| {
            let a = i as f32 / 64.0 * std::f32::consts::TAU;
            Point::new(105.0 + a.cos() * 40.0, 170.0 + a.sin() * 40.0, 1.0)
        }).collect()),
    ];
    // Handwriting-like scribbles.
    for row in 0..6 {
        for col in 0..4 {
            let id = 100 + row * 4 + col;
            let x0 = 20.0 + col as f32 * 45.0;
            let y0 = 225.0 + row as f32 * 10.0;
            strokes.push(Stroke::new(id, 0xff212121, (0..30).map(|i| {
                let t = i as f32 / 29.0;
                Point::new(x0 + t * 35.0, y0 + (t * 23.0 + id as f32).sin() * 2.5, 0.35 + 0.2 * (t * 9.0).cos().abs())
            }).collect()));
        }
    }
    strokes
}
