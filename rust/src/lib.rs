//! BetterNotes renderer (Phase 5).
//!
//! - [`engine`]: the renderer itself, independent of Flutter (page mirror, tiles, rasterization,
//!   scheduling). Tested and benchmarked with plain `cargo test` / `cargo run --example`.
//! - [`api`]: the functions exported to Dart by `flutter_rust_bridge_codegen generate`.
pub mod api;
pub mod engine;
mod frb_generated;
