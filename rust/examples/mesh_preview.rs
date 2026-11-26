//! Renders sample stroke meshes (R8-01) to a PNG for a visual check:
//! `cargo run --release --example mesh_preview -- out.png`
//! Triangles are filled with tiny-skia (no anti-aliasing, to show the exact geometry).
use bn_renderer::engine::geometry::Point;
use bn_renderer::engine::mesh::{stroke_mesh, MeshParams};
use tiny_skia::{FillRule, Paint, PathBuilder, Pixmap, Transform};

fn main() {
    let out = std::env::args().nth(1).unwrap_or_else(|| "mesh_preview.png".into());
    let scale = 40.0; // px per mm
    let mut pixmap = Pixmap::new(1600, 900).unwrap();
    pixmap.fill(tiny_skia::Color::WHITE);

    // Freehand-like squiggle with pressure, smoothed.
    let squiggle: Vec<Point> = (0..40)
        .map(|i| {
            let t = i as f32 * 0.35;
            Point::new(2.0 + i as f32 * 0.25, 5.0 + t.sin() * 2.0 + (t * 2.7).cos() * 0.6, 0.3 + 0.5 * (t * 0.5).sin().abs())
        })
        .collect();
    // Arrow like the line tool builds it (with a duplicated start point), not smoothed.
    let arrow = vec![
        Point::new(16.0, 12.0, 0.5),
        Point::new(16.0, 12.0, 0.5),
        Point::new(30.0, 4.0, 0.5),
        Point::new(27.0, 3.6, 0.5),
        Point::new(30.0, 4.0, 0.5),
        Point::new(28.4, 6.6, 0.5),
    ];
    // Rectangle, not smoothed.
    let rect = vec![
        Point::new(33.0, 3.0, 0.6),
        Point::new(38.0, 3.0, 0.6),
        Point::new(38.0, 9.0, 0.6),
        Point::new(33.0, 9.0, 0.6),
        Point::new(33.0, 3.0, 0.6),
    ];
    // Tight zigzag, smoothed (sharp turns after smoothing).
    let zigzag: Vec<Point> = (0..12).map(|i| Point::new(4.0 + i as f32 * 0.8, if i % 2 == 0 { 14.0 } else { 18.0 }, 0.4)).collect();
    // Single dot.
    let dot = vec![Point::new(30.0, 16.0, 1.2)];

    let params = MeshParams::for_tolerance(0.003);
    let coarse = MeshParams::for_tolerance(0.1);
    let mut paint = Paint::default();
    paint.anti_alias = false;
    for (pts, smooth, p, color) in [
        (&squiggle, true, params, (0, 0, 0)),
        (&arrow, false, params, (0, 0, 160)),
        (&rect, false, params, (0, 120, 0)),
        (&zigzag, true, params, (0, 0, 0)),
        (&dot, true, params, (160, 0, 0)),
        (&zigzag, true, coarse, (220, 120, 0)),
    ] {
        let mut pts = pts.clone();
        if p == coarse {
            for q in &mut pts {
                q.y += 4.0; // draw the coarse version below
            }
        }
        let m = stroke_mesh(&pts, smooth, &p);
        paint.set_color_rgba8(color.0, color.1, color.2, 255);
        for t in m.indices.chunks(3) {
            let v = |i: u32| (m.positions[2 * i as usize] * scale, m.positions[2 * i as usize + 1] * scale);
            let (a, b, c) = (v(t[0]), v(t[1]), v(t[2]));
            let mut pb = PathBuilder::new();
            pb.move_to(a.0, a.1);
            pb.line_to(b.0, b.1);
            pb.line_to(c.0, c.1);
            pb.close();
            if let Some(path) = pb.finish() {
                pixmap.fill_path(&path, &paint, FillRule::Winding, Transform::identity(), None);
            }
        }
        println!("{} points -> {} vertices, {} triangles", pts.len(), m.vertex_count(), m.triangle_count());
    }
    pixmap.save_png(&out).unwrap();
    println!("wrote {out}");
}
