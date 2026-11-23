//! The renderer: page mirrors, viewport, scheduling on worker threads, caching and delivery.
//!
//! # How tiles get rendered
//!
//! Dart describes what is on screen with [`Renderer::set_viewport`]. That replaces the set of
//! *wanted* tiles: the visible tiles of every listed page (high priority) plus a ring of
//! neighbours (prefetch). Tiles that are no longer wanted are thereby cancelled: workers only ever
//! pick work from the current wanted set.
//!
//! A wanted tile needs work if Dart doesn't have its current version yet. The current version of
//! a tile comes from the page's [`VersionGrid`](super::page::VersionGrid); the renderer remembers
//! which version it delivered for each tile. Workers repeatedly take the most important tile that
//! needs work, serve it from the [`LruCache`] if possible or render it, and deliver a
//! [`TileEvent`]. A tile whose page changed during rendering is dropped and rendered again.
//!
//! # Contract for the receiver (Dart)
//!
//! - Versions only grow. Events can arrive out of order (several workers), so keep the event with
//!   the highest version per tile and ignore lower ones.
//! - Call [`Renderer::forget_tiles`] for tiles you dropped, so they are delivered again when needed.
//! - The sink is called on worker threads and must not call back into the renderer.

use std::collections::HashMap;
use std::sync::{Arc, Condvar, Mutex, MutexGuard};
use std::thread::JoinHandle;

use super::cache::LruCache;
use super::geometry::{Rect, Stroke};
use super::page::{Layer, PageGeometry, PageKey, PageMirror};
use super::raster::{render_tile, to_straight_rgba};
use super::tiles::{tiles_in, Scale, TileKey, TILE_PX};

/// Size of one tile's pixel data in bytes.
pub const TILE_BYTES: usize = (TILE_PX * TILE_PX * 4) as usize;

/// The visible part of one page.
#[derive(Clone, Copy, Debug)]
pub struct PageViewport {
    pub page: PageKey,
    /// Device pixels per mm.
    pub scale: f32,
    /// Visible area of the page in mm (may extend beyond the page).
    pub visible: Rect,
}

/// A finished tile.
#[derive(Clone, Debug)]
pub struct TileEvent {
    pub key: TileKey,
    pub version: u64,
    /// [`TILE_PX`]² pixels, RGBA with straight alpha (see [`to_straight_rgba`]).
    pub pixels: Arc<Vec<u8>>,
}

/// Receives finished tiles; called on worker threads.
pub type TileSink = Box<dyn Fn(TileEvent) + Send + Sync>;

#[derive(Clone, Copy, Debug)]
pub struct RendererConfig {
    /// Number of worker threads.
    pub threads: usize,
    /// Budget of the Rust-side tile cache in bytes.
    pub cache_bytes: usize,
    /// Rings of neighbour tiles around the visible area that are rendered ahead.
    pub prefetch_margin: u32,
}

impl Default for RendererConfig {
    fn default() -> Self {
        let cores = std::thread::available_parallelism().map(|n| n.get()).unwrap_or(2);
        Self {
            // Leave a core for the UI thread.
            threads: cores.saturating_sub(1).clamp(1, 8),
            cache_bytes: 64 << 20,
            prefetch_margin: 1,
        }
    }
}

/// Counters for tests and benchmarks.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Stats {
    /// Tiles rasterized.
    pub rendered: u64,
    /// Tiles delivered from the cache.
    pub cache_hits: u64,
    /// Finished renders dropped because the page changed or closed meanwhile.
    pub stale: u64,
    /// Events sent to the sink.
    pub delivered: u64,
}

/// Lower sorts first: visible before prefetch, then background before ink, then by distance
/// to the centre of the visible area (in tiles).
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
struct Priority {
    class: u8,
    layer: u8,
    distance: f32,
}

struct State {
    pages: HashMap<PageKey, PageMirror>,
    /// Last version handed out; every change gets a new one.
    version: u64,
    wanted: HashMap<TileKey, Priority>,
    /// Version of each tile the receiver has (as far as we know).
    delivered: HashMap<TileKey, u64>,
    /// Tiles being rendered, with the version being rendered.
    in_flight: HashMap<TileKey, u64>,
    cache: LruCache<TileKey, (u64, Arc<Vec<u8>>)>,
    prefetch_margin: u32,
    shutdown: bool,
    stats: Stats,
}

enum Job {
    Cached(TileEvent),
    Render { key: TileKey, version: u64, page: PageGeometry },
}

impl State {
    fn next_version(&mut self) -> u64 {
        self.version += 1;
        self.version
    }

    /// Current version of a tile; None if its page is closed.
    fn tile_version(&self, key: &TileKey) -> Option<u64> {
        self.pages.get(&key.page).map(|p| p.version_in(key.layer, &key.rect()))
    }

    /// The most important wanted tile that needs work, if any. Takes cached tiles directly.
    fn next_job(&mut self) -> Option<Job> {
        let mut best: Option<(Priority, TileKey, u64)> = None;
        for (key, priority) in &self.wanted {
            let Some(version) = self.tile_version(key) else { continue };
            if self.delivered.get(key) == Some(&version) || self.in_flight.get(key) == Some(&version) {
                continue;
            }
            if best.as_ref().is_none_or(|(p, _, _)| priority < p) {
                best = Some((*priority, *key, version));
            }
        }
        let (_, key, version) = best?;
        if let Some((cached_version, pixels)) = self.cache.get(&key) {
            if *cached_version == version {
                return Some(Job::Cached(TileEvent { key, version, pixels: pixels.clone() }));
            }
        }
        let page = self.pages[&key.page].geometry().clone();
        Some(Job::Render { key, version, page })
    }

    fn drop_page_state(&mut self, mut matches: impl FnMut(&PageKey) -> bool) {
        self.wanted.retain(|k, _| !matches(&k.page));
        self.delivered.retain(|k, _| !matches(&k.page));
        self.cache.remove_where(|k| matches(&k.page));
    }
}

struct Shared {
    state: Mutex<State>,
    /// Signalled when there may be new work (or on shutdown).
    work: Condvar,
    /// Signalled when a worker finished a job or found nothing to do.
    idle: Condvar,
    sink: TileSink,
}

impl Shared {
    fn lock(&self) -> MutexGuard<'_, State> {
        // A panic in the sink must not take the whole renderer down.
        self.state.lock().unwrap_or_else(|e| e.into_inner())
    }
}

/// Tile renderer with its own worker threads. Dropping it stops the workers.
pub struct Renderer {
    shared: Arc<Shared>,
    workers: Vec<JoinHandle<()>>,
}

impl Renderer {
    pub fn new(config: RendererConfig, sink: TileSink) -> Self {
        let shared = Arc::new(Shared {
            state: Mutex::new(State {
                pages: HashMap::new(),
                version: 0,
                wanted: HashMap::new(),
                delivered: HashMap::new(),
                in_flight: HashMap::new(),
                cache: LruCache::new(config.cache_bytes),
                prefetch_margin: config.prefetch_margin,
                shutdown: false,
                stats: Stats::default(),
            }),
            work: Condvar::new(),
            idle: Condvar::new(),
            sink,
        });
        let workers = (0..config.threads.max(1))
            .map(|i| {
                let shared = shared.clone();
                std::thread::Builder::new()
                    .name(format!("bn-render-{i}"))
                    .spawn(move || worker(&shared))
                    .expect("failed to start render thread")
            })
            .collect();
        Self { shared, workers }
    }

    fn change(&self, f: impl FnOnce(&mut State)) {
        f(&mut self.shared.lock());
        self.shared.work.notify_all();
    }

    // ----- page data (deltas from Dart) -----

    /// Opens (or replaces) a page with the given size (mm) and colour, without strokes.
    pub fn open_page(&self, page: PageKey, width: f32, height: f32, color: u32) {
        self.change(|s| {
            let version = s.next_version();
            s.pages.insert(page, PageMirror::new(width, height, color, version));
            s.cache.remove_where(|k| k.page == page);
        });
    }

    /// Closes a page: drops its mirror, wanted tiles and cached tiles.
    pub fn close_page(&self, page: PageKey) {
        self.change(|s| {
            s.pages.remove(&page);
            s.drop_page_state(|k| *k == page);
        });
    }

    /// Closes all pages of a document.
    pub fn close_document(&self, doc: u64) {
        self.change(|s| {
            s.pages.retain(|k, _| k.doc != doc);
            s.drop_page_state(|k| k.doc == doc);
        });
    }

    /// Adds strokes on top; strokes with an existing ID replace the old one. Ignored for pages
    /// that aren't open.
    pub fn add_strokes(&self, page: PageKey, strokes: Vec<Stroke>) {
        self.change(|s| {
            let version = s.next_version();
            if let Some(p) = s.pages.get_mut(&page) {
                p.add_strokes(strokes, version);
            }
        });
    }

    pub fn remove_strokes(&self, page: PageKey, ids: &[u64]) {
        self.change(|s| {
            let version = s.next_version();
            if let Some(p) = s.pages.get_mut(&page) {
                p.remove_strokes(ids, version);
            }
        });
    }

    pub fn set_background(&self, page: PageKey, color: u32, strokes: Vec<Stroke>) {
        self.change(|s| {
            let version = s.next_version();
            if let Some(p) = s.pages.get_mut(&page) {
                p.set_background(color, strokes, version);
            }
        });
    }

    pub fn resize_page(&self, page: PageKey, width: f32, height: f32) {
        self.change(|s| {
            let version = s.next_version();
            if let Some(p) = s.pages.get_mut(&page) {
                p.resize(width, height, version);
            }
        });
    }

    // ----- viewport and delivery -----

    /// Sets what is on screen; replaces the previous viewport. Pages not listed get no tiles.
    pub fn set_viewport(&self, viewports: &[PageViewport]) {
        self.change(|s| {
            let mut wanted = HashMap::new();
            for vp in viewports {
                let Some(page) = s.pages.get(&vp.page) else { continue };
                let (w, h) = (page.geometry().width, page.geometry().height);
                let scale = Scale::new(vp.scale);
                let tile_mm = scale.tile_mm();
                let (cx, cy) = vp.visible.center();
                let visible = tiles_in(w, h, scale, &vp.visible, 0);
                for (x, y) in tiles_in(w, h, scale, &vp.visible, s.prefetch_margin) {
                    let class = if visible.contains(&(x, y)) { 0 } else { 1 };
                    let dx = (x as f32 + 0.5) * tile_mm - cx;
                    let dy = (y as f32 + 0.5) * tile_mm - cy;
                    let distance = (dx * dx + dy * dy).sqrt() / tile_mm;
                    for layer in Layer::ALL {
                        let key = TileKey { page: vp.page, layer, scale, x, y };
                        wanted.insert(key, Priority { class, layer: layer as u8, distance });
                    }
                }
            }
            s.wanted = wanted;
        });
    }

    /// The receiver dropped these tiles; deliver them again when they are wanted.
    pub fn forget_tiles(&self, keys: &[TileKey]) {
        self.change(|s| {
            for key in keys {
                s.delivered.remove(key);
            }
        });
    }

    /// Current version of a tile (None if its page isn't open).
    pub fn tile_version(&self, key: &TileKey) -> Option<u64> {
        self.shared.lock().tile_version(key)
    }

    pub fn stats(&self) -> Stats {
        self.shared.lock().stats
    }

    /// Blocks until every wanted tile has been delivered in its current version.
    pub fn wait_idle(&self) {
        let mut state = self.shared.lock();
        loop {
            let busy = !state.in_flight.is_empty() || state.wanted.iter().any(|(key, _)| {
                state.tile_version(key).is_some_and(|v| state.delivered.get(key) != Some(&v))
            });
            if !busy {
                return;
            }
            state = self.shared.idle.wait(state).unwrap_or_else(|e| e.into_inner());
        }
    }
}

impl Drop for Renderer {
    fn drop(&mut self) {
        self.shared.lock().shutdown = true;
        self.shared.work.notify_all();
        for worker in self.workers.drain(..) {
            let _ = worker.join();
        }
    }
}

fn worker(shared: &Shared) {
    let mut state = shared.lock();
    loop {
        if state.shutdown {
            return;
        }
        match state.next_job() {
            None => {
                shared.idle.notify_all();
                state = shared.work.wait(state).unwrap_or_else(|e| e.into_inner());
            }
            Some(Job::Cached(event)) => {
                state.delivered.insert(event.key, event.version);
                state.stats.cache_hits += 1;
                state.stats.delivered += 1;
                drop(state);
                (shared.sink)(event);
                state = shared.lock();
            }
            Some(Job::Render { key, version, page }) => {
                state.in_flight.insert(key, version);
                drop(state);

                let pixmap = render_tile(&page, key.layer, key.scale.get(), key.x, key.y);
                let pixels = Arc::new(to_straight_rgba(&pixmap));

                state = shared.lock();
                if state.in_flight.get(&key) == Some(&version) {
                    state.in_flight.remove(&key);
                }
                if state.tile_version(&key) != Some(version) {
                    state.stats.stale += 1;
                } else {
                    state.stats.rendered += 1;
                    state.cache.insert(key, (version, pixels.clone()), TILE_BYTES);
                    if state.wanted.contains_key(&key) && state.delivered.get(&key).is_none_or(|v| *v < version) {
                        state.delivered.insert(key, version);
                        state.stats.delivered += 1;
                        drop(state);
                        (shared.sink)(TileEvent { key, version, pixels });
                        state = shared.lock();
                    }
                }
                shared.idle.notify_all();
            }
        }
    }
}
