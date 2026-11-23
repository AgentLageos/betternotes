//! Basic geometry: points, rectangles and strokes, in millimetres.

/// One input point of a stroke: position and the stroke width at that point (Dart `PointModel`).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Point {
    pub x: f32,
    pub y: f32,
    pub width: f32,
}

impl Point {
    pub const fn new(x: f32, y: f32, width: f32) -> Self {
        Self { x, y, width }
    }
}

/// Axis-aligned rectangle given by its edges.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Rect {
    pub left: f32,
    pub top: f32,
    pub right: f32,
    pub bottom: f32,
}

impl Rect {
    pub const fn from_ltrb(left: f32, top: f32, right: f32, bottom: f32) -> Self {
        Self { left, top, right, bottom }
    }

    pub fn from_ltwh(left: f32, top: f32, width: f32, height: f32) -> Self {
        Self::from_ltrb(left, top, left + width, top + height)
    }

    pub fn width(&self) -> f32 {
        self.right - self.left
    }

    pub fn height(&self) -> f32 {
        self.bottom - self.top
    }

    pub fn is_empty(&self) -> bool {
        !(self.right > self.left && self.bottom > self.top)
    }

    /// True if the interiors intersect (same rule as Flutter's `Rect.overlaps`).
    pub fn overlaps(&self, other: &Rect) -> bool {
        self.left < other.right && other.left < self.right && self.top < other.bottom && other.top < self.bottom
    }

    pub fn inflate(&self, delta: f32) -> Rect {
        Rect::from_ltrb(self.left - delta, self.top - delta, self.right + delta, self.bottom + delta)
    }

    pub fn union(&self, other: &Rect) -> Rect {
        Rect::from_ltrb(
            self.left.min(other.left),
            self.top.min(other.top),
            self.right.max(other.right),
            self.bottom.max(other.bottom),
        )
    }

    pub fn intersect(&self, other: &Rect) -> Rect {
        Rect::from_ltrb(
            self.left.max(other.left),
            self.top.max(other.top),
            self.right.min(other.right),
            self.bottom.min(other.bottom),
        )
    }

    pub fn center(&self) -> (f32, f32) {
        ((self.left + self.right) / 2.0, (self.top + self.bottom) / 2.0)
    }
}

/// A stroke as drawn: colour and points. Only the point widths are used for drawing (the Dart
/// `Stroke.width` field isn't needed for rendering).
#[derive(Clone, Debug, PartialEq)]
pub struct Stroke {
    pub id: u64,
    /// Colour as 0xAARRGGBB (Dart `Color.toARGB32()`).
    pub color: u32,
    pub points: Vec<Point>,
    bounds: Rect,
}

impl Stroke {
    pub fn new(id: u64, color: u32, points: Vec<Point>) -> Self {
        let bounds = Self::compute_bounds(&points);
        Self { id, color, points, bounds }
    }

    /// Area the stroke can paint (each point inflated by half its width). Empty for no points.
    pub fn bounds(&self) -> Rect {
        self.bounds
    }

    fn compute_bounds(points: &[Point]) -> Rect {
        let mut iter = points.iter();
        let Some(first) = iter.next() else {
            return Rect::from_ltrb(0.0, 0.0, 0.0, 0.0);
        };
        let around = |p: &Point| {
            let r = p.width.abs() / 2.0;
            Rect::from_ltrb(p.x - r, p.y - r, p.x + r, p.y + r)
        };
        iter.fold(around(first), |acc, p| acc.union(&around(p)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bounds_include_half_width() {
        let s = Stroke::new(1, 0xff000000, vec![Point::new(10.0, 10.0, 2.0), Point::new(20.0, 5.0, 4.0)]);
        assert_eq!(s.bounds(), Rect::from_ltrb(9.0, 3.0, 22.0, 11.0));
    }

    #[test]
    fn overlaps_excludes_touching_edges() {
        let a = Rect::from_ltwh(0.0, 0.0, 10.0, 10.0);
        assert!(a.overlaps(&Rect::from_ltwh(9.0, 9.0, 5.0, 5.0)));
        assert!(!a.overlaps(&Rect::from_ltwh(10.0, 0.0, 5.0, 5.0)));
    }
}
