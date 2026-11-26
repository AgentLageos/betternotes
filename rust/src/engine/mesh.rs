//! Stroke meshes (roadmap D15, R8-01): turns the input points of a stroke into triangles that
//! Flutter draws with `Canvas.drawVertices`.
//!
//! The same function builds the live stroke and the finished stroke, so a stroke looks exactly the
//! same before and after pen-up (design doc §4.6). The shape:
//! - **Smoothing** (freehand strokes): a centripetal Catmull-Rom curve through the input points,
//!   subdivided until the polyline stays within [`MeshParams::tolerance`] of the curve. Shapes and
//!   lines keep their straight segments (`smooth = false`).
//! - **Outline:** a triangle strip around the polyline with the width of each point. At gentle
//!   turns the strip bends (bisector normals, miter clamped at 2×); at sharp turns a round join
//!   (fan on the outer side) is inserted, so there are no spikes.
//! - **Caps:** round at both ends. Arc segment counts follow the tolerance as well.
//!
//! Detail levels (R8-03) are the same function with a coarser tolerance, see
//! [`MeshParams::for_tolerance`]. Units are millimetres like the rest of the engine.
use std::f32::consts::PI;

use super::geometry::Point;

/// Turns below this angle (radians) bend the strip; above it a round join is inserted.
const JOIN_ANGLE_FINE: f32 = 0.35;
/// Coarse levels round only very sharp turns (the difference is below a pixel there, R7-02).
const JOIN_ANGLE_COARSE: f32 = 1.2;
/// From this tolerance (mm) on, a level counts as coarse: input points are reduced and fewer joins
/// are rounded (R7-02).
const COARSE_FROM: f32 = 0.02;
/// Upper bound for segments per curve piece and per arc.
const MAX_SEGMENTS: usize = 32;

/// How finely a stroke is built.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MeshParams {
    /// Maximum distance (mm) between the drawn polyline/arcs and the ideal curve.
    pub tolerance: f32,
    /// Douglas-Peucker tolerance (mm) for reducing input points first; 0 = keep all points.
    pub point_tolerance: f32,
    /// Turn angle (radians) above which a round join is inserted.
    pub join_angle: f32,
}

impl MeshParams {
    /// Parameters for a detail level with the given tolerance (R7-02): fine levels keep every
    /// input point and round every sharp turn; coarse levels reduce points and round fewer joins.
    pub fn for_tolerance(tolerance: f32) -> Self {
        let coarse = tolerance >= COARSE_FROM;
        Self {
            tolerance,
            point_tolerance: if coarse { tolerance } else { 0.0 },
            join_angle: if coarse { JOIN_ANGLE_COARSE } else { JOIN_ANGLE_FINE },
        }
    }
}

/// Triangles of one stroke. `positions` holds x, y pairs (mm); `indices` refers to them, three per
/// triangle. Indices are `u32` here; chunk packing (R8-02) converts them for `Vertices`.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct StrokeMesh {
    pub positions: Vec<f32>,
    pub indices: Vec<u32>,
    /// The center line actually drawn (after smoothing), with the width at each point. Hit testing
    /// uses this, so what is erased is what is visible (design doc §4.12).
    pub outline: Vec<Point>,
}

impl StrokeMesh {
    pub fn vertex_count(&self) -> usize {
        self.positions.len() / 2
    }

    pub fn triangle_count(&self) -> usize {
        self.indices.len() / 3
    }

    fn vertex(&mut self, x: f32, y: f32) -> u32 {
        self.positions.push(x);
        self.positions.push(y);
        (self.positions.len() / 2 - 1) as u32
    }

    fn triangle(&mut self, a: u32, b: u32, c: u32) {
        self.indices.extend_from_slice(&[a, b, c]);
    }

    /// Fan around (cx, cy) with radius r, from angle `start` over `sweep` (may be negative).
    fn fan(&mut self, cx: f32, cy: f32, r: f32, start: f32, sweep: f32, segments: usize) {
        let center = self.vertex(cx, cy);
        let mut prev = self.vertex(cx + start.cos() * r, cy + start.sin() * r);
        for k in 1..=segments {
            let a = start + sweep * k as f32 / segments as f32;
            let v = self.vertex(cx + a.cos() * r, cy + a.sin() * r);
            self.triangle(center, prev, v);
            prev = v;
        }
    }
}

/// Builds the mesh of a stroke. `smooth` selects the Catmull-Rom curve (freehand strokes);
/// without it the input points are connected by straight segments (shapes, lines).
pub fn stroke_mesh(points: &[Point], smooth: bool, params: &MeshParams) -> StrokeMesh {
    let mut mesh = StrokeMesh::default();
    let mut input = without_duplicates(points);
    if input.is_empty() {
        return mesh;
    }
    if params.point_tolerance > 0.0 && input.len() > 2 {
        let keep = douglas_peucker(&input, params.point_tolerance);
        input = input.into_iter().zip(keep).filter(|(_, k)| *k).map(|(p, _)| p).collect();
    }
    let line = if smooth { catmull_rom(&input, params.tolerance) } else { input };
    let line = without_duplicates(&line);
    build_outline(&mut mesh, &line, params);
    mesh.outline = line;
    mesh
}

/// Drops points that coincide with their predecessor (the line tool duplicates points).
fn without_duplicates(points: &[Point]) -> Vec<Point> {
    let mut out: Vec<Point> = Vec::with_capacity(points.len());
    for p in points {
        if !(p.x.is_finite() && p.y.is_finite() && p.width.is_finite()) {
            continue;
        }
        if let Some(last) = out.last() {
            let (dx, dy) = (p.x - last.x, p.y - last.y);
            if dx * dx + dy * dy < 1e-10 {
                continue;
            }
        }
        out.push(*p);
    }
    out
}

/// Centripetal Catmull-Rom through `points`, subdivided so the polyline stays within `tolerance`
/// of the curve. Passes through every input point; widths are interpolated linearly.
fn catmull_rom(points: &[Point], tolerance: f32) -> Vec<Point> {
    let n = points.len();
    if n < 2 {
        return points.to_vec();
    }
    let mut out = Vec::with_capacity(n * 2);
    for i in 0..n - 1 {
        let (p1, p2) = (points[i], points[i + 1]);
        // Phantom end points continue the first/last segment straight.
        let p0 = if i > 0 { points[i - 1] } else { Point::new(2.0 * p1.x - p2.x, 2.0 * p1.y - p2.y, p1.width) };
        let p3 = if i + 2 < n { points[i + 2] } else { Point::new(2.0 * p2.x - p1.x, 2.0 * p2.y - p1.y, p2.width) };

        // Subdivision from the turn across this piece and the radius it implies.
        let a1 = signed_angle(p1.x - p0.x, p1.y - p0.y, p2.x - p1.x, p2.y - p1.y).abs();
        let a2 = signed_angle(p2.x - p1.x, p2.y - p1.y, p3.x - p2.x, p3.y - p2.y).abs();
        let turn = (a1 + a2) / 2.0;
        let chord = dist(p1, p2);
        let mut segments = 1;
        if turn > 1e-3 {
            let max_theta = max_arc_step(chord / turn, tolerance);
            segments = ((turn / max_theta).ceil() as usize).clamp(1, MAX_SEGMENTS);
        }

        // Barry-Goldman evaluation with centripetal knots (no cusps or self-intersections).
        let t0 = 0.0f32;
        let t1 = t0 + dist(p0, p1).sqrt() + 1e-6;
        let t2 = t1 + chord.sqrt() + 1e-6;
        let t3 = t2 + dist(p2, p3).sqrt() + 1e-6;
        let lerp = |a: f32, b: f32, ta: f32, tb: f32, t: f32| (tb - t) / (tb - ta) * a + (t - ta) / (tb - ta) * b;
        out.push(p1);
        for k in 1..segments {
            let u = k as f32 / segments as f32;
            let t = t1 + u * (t2 - t1);
            let axis = |c0: f32, c1: f32, c2: f32, c3: f32| {
                let a1 = lerp(c0, c1, t0, t1, t);
                let a2 = lerp(c1, c2, t1, t2, t);
                let a3 = lerp(c2, c3, t2, t3, t);
                let b1 = lerp(a1, a2, t0, t2, t);
                let b2 = lerp(a2, a3, t1, t3, t);
                lerp(b1, b2, t1, t2, t)
            };
            out.push(Point::new(
                axis(p0.x, p1.x, p2.x, p3.x),
                axis(p0.y, p1.y, p2.y, p3.y),
                p1.width + (p2.width - p1.width) * u,
            ));
        }
    }
    out.push(points[n - 1]);
    out
}

/// Strip with bisector normals, round joins at sharp turns, round caps.
fn build_outline(mesh: &mut StrokeMesh, line: &[Point], params: &MeshParams) {
    let tol = params.tolerance;
    let m = line.len();
    if m == 1 {
        let p = line[0];
        let r = p.width / 2.0;
        mesh.fan(p.x, p.y, r, 0.0, 2.0 * PI, arc_segments(2.0 * PI, r, tol));
        return;
    }
    // Unit direction of each segment.
    let dirs: Vec<(f32, f32)> = line
        .windows(2)
        .map(|w| {
            let (dx, dy) = (w[1].x - w[0].x, w[1].y - w[0].y);
            let len = (dx * dx + dy * dy).sqrt();
            (dx / len, dy / len)
        })
        .collect();

    let p0 = line[0];
    let (dx0, dy0) = dirs[0];
    let h0 = p0.width / 2.0;
    let mut prev_l = mesh.vertex(p0.x - dy0 * h0, p0.y + dx0 * h0);
    let mut prev_r = mesh.vertex(p0.x + dy0 * h0, p0.y - dx0 * h0);
    for j in 1..m {
        let p = line[j];
        let h = p.width / 2.0;
        let (ix, iy) = dirs[j - 1];
        let turn = if j < m - 1 { signed_angle(ix, iy, dirs[j].0, dirs[j].1) } else { 0.0 };
        if j == m - 1 || turn.abs() < params.join_angle {
            // Bend the strip: bisector normal, widened so the edges stay parallel (clamped).
            let (mut nx, mut ny, mut scale) = (-iy, ix, 1.0f32);
            if j < m - 1 {
                let (ox, oy) = dirs[j];
                nx = -iy - oy;
                ny = ix + ox;
                let len = (nx * nx + ny * ny).sqrt();
                nx /= len;
                ny /= len;
                scale = (1.0 / (turn / 2.0).cos()).min(2.0);
            }
            let l = mesh.vertex(p.x + nx * h * scale, p.y + ny * h * scale);
            let r = mesh.vertex(p.x - nx * h * scale, p.y - ny * h * scale);
            mesh.triangle(prev_l, prev_r, l);
            mesh.triangle(prev_r, r, l);
            prev_l = l;
            prev_r = r;
        } else {
            // End the strip with the incoming normal, fan on the outer side, restart with the
            // outgoing normal.
            let (inx, iny) = (-iy, ix);
            let l = mesh.vertex(p.x + inx * h, p.y + iny * h);
            let r = mesh.vertex(p.x - inx * h, p.y - iny * h);
            mesh.triangle(prev_l, prev_r, l);
            mesh.triangle(prev_r, r, l);
            // turn > 0: the line turns towards +normal, so the outer side is -normal.
            let (sx, sy) = if turn > 0.0 { (-inx, -iny) } else { (inx, iny) };
            mesh.fan(p.x, p.y, h, sy.atan2(sx), turn, arc_segments(turn.abs(), h, tol));
            let (ox, oy) = (-dirs[j].1, dirs[j].0);
            prev_l = mesh.vertex(p.x + ox * h, p.y + oy * h);
            prev_r = mesh.vertex(p.x - ox * h, p.y - oy * h);
        }
    }
    // Start cap: from +normal through -direction; end cap: from -normal through +direction.
    let last = line[m - 1];
    let (dxl, dyl) = dirs[m - 2];
    let h1 = last.width / 2.0;
    mesh.fan(p0.x, p0.y, h0, dx0.atan2(-dy0), PI, arc_segments(PI, h0, tol));
    mesh.fan(last.x, last.y, h1, (-dxl).atan2(dyl), PI, arc_segments(PI, h1, tol));
}

/// Largest arc step (radians) on radius `r` whose chord stays within `tolerance` of the arc.
fn max_arc_step(r: f32, tolerance: f32) -> f32 {
    (8.0 * tolerance / r.max(1e-6)).sqrt()
}

fn arc_segments(sweep: f32, r: f32, tolerance: f32) -> usize {
    ((sweep / max_arc_step(r, tolerance)).ceil() as usize).clamp(2, MAX_SEGMENTS)
}

fn dist(a: Point, b: Point) -> f32 {
    ((b.x - a.x).powi(2) + (b.y - a.y).powi(2)).sqrt()
}

fn signed_angle(ax: f32, ay: f32, bx: f32, by: f32) -> f32 {
    (ax * by - ay * bx).atan2(ax * bx + ay * by)
}

/// Douglas-Peucker: which points to keep so the polyline stays within `tolerance`.
fn douglas_peucker(points: &[Point], tolerance: f32) -> Vec<bool> {
    let mut keep = vec![false; points.len()];
    let last = points.len() - 1;
    keep[0] = true;
    keep[last] = true;
    let tol2 = tolerance * tolerance;
    let mut stack = vec![(0, last)];
    while let Some((a, b)) = stack.pop() {
        if b <= a + 1 {
            continue;
        }
        let (pa, pb) = (points[a], points[b]);
        let (dx, dy) = (pb.x - pa.x, pb.y - pa.y);
        let len2 = dx * dx + dy * dy;
        let (mut best, mut index) = (-1.0f32, a);
        for (i, p) in points.iter().enumerate().take(b).skip(a + 1) {
            let d2 = if len2 < 1e-12 {
                (p.x - pa.x).powi(2) + (p.y - pa.y).powi(2)
            } else {
                let c = (p.x - pa.x) * dy - (p.y - pa.y) * dx;
                c * c / len2
            };
            if d2 > best {
                best = d2;
                index = i;
            }
        }
        if best > tol2 {
            keep[index] = true;
            stack.push((a, index));
            stack.push((index, b));
        }
    }
    keep
}

#[cfg(test)]
mod tests {
    use super::*;

    const FINE: f32 = 0.003;

    fn params() -> MeshParams {
        MeshParams::for_tolerance(FINE)
    }

    /// Sum of triangle areas (overlaps counted twice).
    fn area(m: &StrokeMesh) -> f32 {
        m.indices
            .chunks(3)
            .map(|t| {
                let p = |i: u32| (m.positions[2 * i as usize], m.positions[2 * i as usize + 1]);
                let (a, b, c) = (p(t[0]), p(t[1]), p(t[2]));
                ((b.0 - a.0) * (c.1 - a.1) - (c.0 - a.0) * (b.1 - a.1)).abs() / 2.0
            })
            .sum()
    }

    fn dist_to_segment(px: f32, py: f32, a: Point, b: Point) -> f32 {
        let (dx, dy) = (b.x - a.x, b.y - a.y);
        let l2 = dx * dx + dy * dy;
        let t = if l2 < 1e-12 { 0.0 } else { (((px - a.x) * dx + (py - a.y) * dy) / l2).clamp(0.0, 1.0) };
        ((a.x + t * dx - px).powi(2) + (a.y + t * dy - py).powi(2)).sqrt()
    }

    /// Largest distance of any vertex from the outline, relative to the local half width.
    fn max_overshoot(m: &StrokeMesh) -> f32 {
        let mut worst = 0.0f32;
        for v in m.positions.chunks(2) {
            let mut best = f32::MAX;
            for w in m.outline.windows(2) {
                let h = w[0].width.max(w[1].width) / 2.0;
                best = best.min(dist_to_segment(v[0], v[1], w[0], w[1]) / h);
            }
            if m.outline.len() == 1 {
                let p = m.outline[0];
                best = ((v[0] - p.x).powi(2) + (v[1] - p.y).powi(2)).sqrt() / (p.width / 2.0);
            }
            worst = worst.max(best);
        }
        worst
    }

    fn valid(m: &StrokeMesh) {
        assert_eq!(m.indices.len() % 3, 0);
        assert!(m.positions.iter().all(|v| v.is_finite()));
        assert!(m.indices.iter().all(|&i| (i as usize) < m.vertex_count()));
    }

    #[test]
    fn empty_stroke_has_no_mesh() {
        let m = stroke_mesh(&[], true, &params());
        assert_eq!(m.vertex_count(), 0);
        assert!(m.outline.is_empty());
    }

    #[test]
    fn single_point_is_a_disc() {
        let m = stroke_mesh(&[Point::new(5.0, 5.0, 2.0)], true, &params());
        valid(&m);
        let a = area(&m);
        assert!((a - PI).abs() / PI < 0.01, "disc area {a}");
        assert!(max_overshoot(&m) <= 1.0001);
    }

    #[test]
    fn duplicated_points_are_one_point() {
        // The line tool starts strokes with copies of the same point.
        let p = Point::new(1.0, 1.0, 1.0);
        let m = stroke_mesh(&[p, p, p, p], false, &params());
        valid(&m);
        assert_eq!(m.outline.len(), 1);
    }

    #[test]
    fn straight_line_area_is_rectangle_plus_caps() {
        let pts = [Point::new(0.0, 0.0, 1.0), Point::new(10.0, 0.0, 1.0)];
        for smooth in [false, true] {
            let m = stroke_mesh(&pts, smooth, &params());
            valid(&m);
            let expected = 10.0 * 1.0 + PI * 0.25;
            assert!((area(&m) - expected).abs() / expected < 0.005, "smooth={smooth}: {}", area(&m));
        }
    }

    #[test]
    fn caps_reach_past_the_end_points() {
        // Area alone can't tell (caps folded into the strip have the same area), so check extent.
        let pts = [Point::new(0.0, 0.0, 1.0), Point::new(10.0, 0.0, 1.0)];
        for smooth in [false, true] {
            let m = stroke_mesh(&pts, smooth, &params());
            let xs = m.positions.chunks(2).map(|v| v[0]);
            let (min, max) = xs.fold((f32::MAX, f32::MIN), |(a, b), x| (a.min(x), b.max(x)));
            // Arcs are polygons within the tolerance, so the extreme may fall between two vertices.
            assert!((min + 0.5).abs() <= FINE && (max - 10.5).abs() <= FINE, "x range {min}..{max}");
        }
    }

    #[test]
    fn smoothing_passes_through_input_points() {
        let pts: Vec<Point> = (0..20)
            .map(|i| {
                let a = i as f32 * 0.4;
                Point::new(a.cos() * 3.0, a.sin() * 3.0, 0.5)
            })
            .collect();
        let m = stroke_mesh(&pts, true, &params());
        valid(&m);
        for p in &pts {
            assert!(m.outline.iter().any(|q| (q.x - p.x).abs() < 1e-5 && (q.y - p.y).abs() < 1e-5));
        }
        assert!(m.outline.len() > pts.len(), "curve should be subdivided");
    }

    #[test]
    fn finer_tolerance_gives_more_detail() {
        let pts: Vec<Point> = (0..30)
            .map(|i| {
                let a = i as f32 * 0.5;
                Point::new(i as f32 * 0.3, a.sin(), 0.4)
            })
            .collect();
        let fine = stroke_mesh(&pts, true, &MeshParams::for_tolerance(0.003));
        let coarse = stroke_mesh(&pts, true, &MeshParams::for_tolerance(0.1));
        assert!(fine.vertex_count() > coarse.vertex_count());
    }

    #[test]
    fn sharp_corners_have_no_spikes() {
        // Arrow-like shape with a very sharp turn, not smoothed.
        let pts = [
            Point::new(0.0, 0.0, 1.0),
            Point::new(10.0, 0.0, 1.0),
            Point::new(0.5, 0.6, 1.0),
            Point::new(10.0, 1.2, 1.0),
        ];
        let m = stroke_mesh(&pts, false, &params());
        valid(&m);
        // Round joins: no vertex further than half the width (plus the small miter at gentle turns).
        assert!(max_overshoot(&m) < 1.02, "overshoot {}", max_overshoot(&m));
    }

    #[test]
    fn varying_width_follows_points() {
        let pts = [Point::new(0.0, 0.0, 0.2), Point::new(5.0, 0.0, 2.0)];
        let m = stroke_mesh(&pts, false, &params());
        let near_start = m.positions.chunks(2).filter(|v| v[0].abs() < 1e-4).map(|v| v[1].abs()).fold(0.0, f32::max);
        assert!((near_start - 0.1).abs() < 1e-4, "start half width {near_start}");
        assert!(max_overshoot(&m) < 1.02);
    }

    #[test]
    fn same_points_give_identical_mesh() {
        // Pen-up keeps the live mesh; rebuilding from the stored points must give the same mesh.
        let pts: Vec<Point> = (0..50).map(|i| Point::new(i as f32 * 0.1, (i as f32 * 0.3).sin(), 0.5)).collect();
        assert_eq!(stroke_mesh(&pts, true, &params()), stroke_mesh(&pts, true, &params()));
    }

    #[test]
    fn coarse_levels_reduce_points() {
        let pts: Vec<Point> = (0..200).map(|i| Point::new(i as f32 * 0.05, (i as f32 * 0.02).sin() * 0.01, 0.4)).collect();
        let coarse = stroke_mesh(&pts, true, &MeshParams::for_tolerance(0.1));
        assert!(coarse.outline.len() < 10, "{} outline points", coarse.outline.len());
        assert!(max_overshoot(&coarse) < 1.02);
    }

    #[test]
    fn non_finite_points_are_ignored() {
        let pts = [Point::new(0.0, 0.0, 1.0), Point::new(f32::NAN, 1.0, 1.0), Point::new(3.0, 0.0, 1.0)];
        let m = stroke_mesh(&pts, true, &params());
        valid(&m);
        assert_eq!(m.outline.len() > 1, true);
    }
}
