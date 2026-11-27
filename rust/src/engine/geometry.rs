//! Basic geometry, in millimetres.

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
