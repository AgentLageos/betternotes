//! Behaviour of the threaded renderer: delivery, versions, cancellation, cache, closing.

mod common;

use std::collections::HashMap;
use std::sync::mpsc;
use std::sync::{Arc, Mutex};

use bn_renderer::engine::geometry::{Point, Rect, Stroke};
use bn_renderer::engine::page::{Layer, PageKey};
use bn_renderer::engine::renderer::{PageViewport, Renderer, RendererConfig, TileEvent};
use bn_renderer::engine::tiles::{Scale, TileKey};

const PAGE: PageKey = PageKey { doc: 1, page: 10 };
const OTHER: PageKey = PageKey { doc: 1, page: 11 };

/// Renderer whose events are collected in a list.
fn collecting(config: RendererConfig) -> (Renderer, Arc<Mutex<Vec<TileEvent>>>) {
    let events = Arc::new(Mutex::new(Vec::new()));
    let sink = events.clone();
    let renderer = Renderer::new(config, Box::new(move |e| sink.lock().unwrap().push(e)));
    (renderer, events)
}

fn config(threads: usize, prefetch_margin: u32) -> RendererConfig {
    RendererConfig { threads, cache_bytes: 64 << 20, prefetch_margin }
}

/// Whole A4 page visible at 4 px/mm: 64 mm tiles, 4 × 5 grid.
fn whole_page(page: PageKey) -> PageViewport {
    PageViewport { page, scale: 4.0, visible: Rect::from_ltwh(0.0, 0.0, common::A4.0, common::A4.1) }
}

fn open(renderer: &Renderer, page: PageKey) {
    renderer.open_page(page, common::A4.0, common::A4.1, common::PAGE_COLOR);
}

fn dot(id: u64, x: f32, y: f32) -> Stroke {
    Stroke::new(id, 0xff000000, vec![Point::new(x, y, 1.0); 2])
}

fn take(events: &Mutex<Vec<TileEvent>>) -> Vec<TileEvent> {
    std::mem::take(&mut *events.lock().unwrap())
}

#[test]
fn delivers_every_visible_tile_once_with_current_version() {
    let (renderer, events) = collecting(config(4, 0));
    open(&renderer, PAGE);
    renderer.add_strokes(PAGE, common::sample_ink());
    renderer.set_viewport(&[whole_page(PAGE)]);
    renderer.wait_idle();

    let events = take(&events);
    assert_eq!(events.len(), 4 * 5 * 2, "20 tiles, 2 layers");
    let mut seen = HashMap::new();
    for e in &events {
        assert_eq!(e.pixels.len(), 256 * 256 * 4);
        assert_eq!(Some(e.version), renderer.tile_version(&e.key));
        assert!(seen.insert(e.key, e.version).is_none(), "delivered twice: {:?}", e.key);
    }
}

#[test]
fn a_change_redelivers_only_affected_ink_tiles() {
    let (renderer, events) = collecting(config(4, 0));
    open(&renderer, PAGE);
    renderer.set_viewport(&[whole_page(PAGE)]);
    renderer.wait_idle();
    take(&events);

    renderer.add_strokes(PAGE, vec![dot(1, 100.0, 100.0)]); // inside tile (1, 1)
    renderer.wait_idle();
    let changed = take(&events);
    assert_eq!(changed.len(), 1);
    assert_eq!((changed[0].key.layer, changed[0].key.x, changed[0].key.y), (Layer::Ink, 1, 1));

    renderer.remove_strokes(PAGE, &[1]);
    renderer.wait_idle();
    assert_eq!(take(&events).len(), 1);

    renderer.set_background(PAGE, 0xffffffff, common::ruled_background());
    renderer.wait_idle();
    let changed = take(&events);
    assert_eq!(changed.len(), 20);
    assert!(changed.iter().all(|e| e.key.layer == Layer::Background));
}

#[test]
fn prefetch_renders_neighbours_after_visible_tiles() {
    let (renderer, events) = collecting(config(1, 1)); // one thread: strict priority order
    open(&renderer, PAGE);
    renderer.set_viewport(&[PageViewport { page: PAGE, scale: 4.0, visible: Rect::from_ltwh(70.0, 70.0, 10.0, 10.0) }]);
    renderer.wait_idle();
    let events = take(&events);
    assert_eq!(events.len(), 9 * 2);
    assert!(events[..2].iter().all(|e| (e.key.x, e.key.y) == (1, 1)), "visible tile first");
}

#[test]
fn viewport_change_cancels_tiles_that_are_no_longer_wanted() {
    // The sink blocks on the first event, so the only worker is stuck while the viewport moves
    // to another page. Nothing of the first page may be delivered after that.
    let (gate_tx, gate_rx) = mpsc::channel::<()>();
    let (started_tx, started_rx) = mpsc::channel::<()>();
    let gate = Mutex::new(Some((gate_rx, started_tx)));
    let events = Arc::new(Mutex::new(Vec::new()));
    let sink_events = events.clone();
    let renderer = Renderer::new(config(1, 0), Box::new(move |e: TileEvent| {
        if let Some((rx, started)) = gate.lock().unwrap().take() {
            started.send(()).unwrap();
            rx.recv().unwrap();
        }
        sink_events.lock().unwrap().push(e);
    }));
    open(&renderer, PAGE);
    open(&renderer, OTHER);
    renderer.set_viewport(&[whole_page(PAGE)]);
    started_rx.recv().unwrap();
    renderer.set_viewport(&[whole_page(OTHER)]);
    gate_tx.send(()).unwrap();
    renderer.wait_idle();

    let events = take(&events);
    let first_page = events.iter().filter(|e| e.key.page == PAGE).count();
    assert_eq!(first_page, 1, "only the event that was already being delivered");
    assert_eq!(events.iter().filter(|e| e.key.page == OTHER).count(), 40);
}

#[test]
fn forgotten_tiles_come_from_the_cache() {
    let (renderer, events) = collecting(config(2, 0));
    open(&renderer, PAGE);
    renderer.set_viewport(&[whole_page(PAGE)]);
    renderer.wait_idle();
    let first = take(&events);

    let key = first[0].key;
    renderer.forget_tiles(&[key]);
    renderer.wait_idle();
    let again = take(&events);
    assert_eq!(again.len(), 1);
    assert_eq!(again[0].key, key);
    assert!(Arc::ptr_eq(&again[0].pixels, &first[0].pixels), "same cached buffer");
    let stats = renderer.stats();
    assert_eq!((stats.rendered, stats.cache_hits), (40, 1));
}

#[test]
fn zooming_back_uses_the_cache() {
    let (renderer, events) = collecting(config(2, 0));
    open(&renderer, PAGE);
    renderer.set_viewport(&[whole_page(PAGE)]);
    renderer.wait_idle();
    renderer.set_viewport(&[PageViewport { scale: 8.0, ..whole_page(PAGE) }]);
    renderer.wait_idle();
    let rendered = renderer.stats().rendered;
    // Dart dropped the 4 px/mm tiles while zoomed in.
    let old: Vec<TileKey> = take(&events).iter().filter(|e| e.key.scale == Scale::new(4.0)).map(|e| e.key).collect();
    renderer.forget_tiles(&old);
    renderer.set_viewport(&[whole_page(PAGE)]);
    renderer.wait_idle();
    assert_eq!(renderer.stats().rendered, rendered, "nothing rendered again");
    assert_eq!(take(&events).len(), 40);
}

#[test]
fn closed_pages_get_no_tiles_and_lose_their_state() {
    let (renderer, events) = collecting(config(2, 0));
    open(&renderer, PAGE);
    renderer.close_page(PAGE);
    renderer.set_viewport(&[whole_page(PAGE)]);
    renderer.add_strokes(PAGE, vec![dot(1, 10.0, 10.0)]); // ignored
    renderer.wait_idle();
    assert!(take(&events).is_empty());

    // Reopening starts over with new versions and an empty page.
    open(&renderer, PAGE);
    renderer.set_viewport(&[whole_page(PAGE)]);
    renderer.wait_idle();
    let events = take(&events);
    assert_eq!(events.len(), 40);
    assert!(events.iter().filter(|e| e.key.layer == Layer::Ink).all(|e| e.pixels.iter().all(|b| *b == 0)));

    renderer.close_document(PAGE.doc);
    assert_eq!(renderer.tile_version(&events[0].key), None);
}

#[test]
fn versions_only_grow() {
    let (renderer, events) = collecting(config(4, 0));
    open(&renderer, PAGE);
    renderer.set_viewport(&[whole_page(PAGE)]);
    let mut last: HashMap<TileKey, u64> = HashMap::new();
    for i in 0..20 {
        renderer.add_strokes(PAGE, vec![dot(i, 5.0 + i as f32 * 10.0, 100.0)]);
    }
    renderer.wait_idle();
    for e in take(&events) {
        let entry = last.entry(e.key).or_insert(0);
        // Out-of-order delivery is allowed, but the final state must be current.
        *entry = (*entry).max(e.version);
    }
    for (key, version) in last {
        assert_eq!(Some(version), renderer.tile_version(&key));
    }
}

#[test]
fn drop_stops_the_workers() {
    let (renderer, _events) = collecting(config(3, 0));
    open(&renderer, PAGE);
    renderer.set_viewport(&[whole_page(PAGE)]);
    drop(renderer); // must not hang
}
