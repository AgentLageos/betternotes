//! The tile renderer, independent of Flutter.
//!
//! Data flow (roadmap D4): Dart owns the documents and sends changes (open/close page, add/remove
//! strokes, set background) to a [`renderer::Renderer`], which keeps a geometry mirror per page
//! ([`page::PageMirror`]). Dart also sets the viewport: which part of which page is visible at
//! which scale. The renderer then rasterizes the needed tiles ([`tiles::TileKey`]) on worker threads
//! with tiny-skia ([`raster`]) and reports finished tiles through a callback, each with a version so
//! Dart can drop stale results.
//!
//! Units: page coordinates are millimetres (like the Dart models), scales are device pixels per mm.
pub mod cache;
pub mod geometry;
pub mod mesh;
pub mod page;
pub mod raster;
pub mod renderer;
pub mod tiles;
