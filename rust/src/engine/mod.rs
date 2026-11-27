//! The mesh renderer's engine, independent of Flutter (roadmap D15).
//!
//! Data flow (D4): Dart owns the documents and sends changes per page (open/close, strokes
//! added/removed/hidden, background replaced) to [`mesh_page::MeshPages`], which keeps a mirror of
//! each open page. Meshes are built from it on request ([`mesh`] for the geometry of one stroke)
//! and handed to Flutter as triangle chunks for `Canvas.drawVertices`.
//!
//! Units: page coordinates are millimetres (like the Dart models).
pub mod geometry;
pub mod mesh;
pub mod mesh_page;
