# Renderer: findings, failed attempts, open points

**Status (2026-11-26): all points in section 4 are decided** (sections 4.1–4.13). Next come the
measurements those decisions require (outside the app), then the roadmap's Phase 5 is rewritten
to match. *(Before 2026-11-26: every point in section 4 had to be discussed in detail and decided
with the project owner before any renderer code was written, changed or committed.)* Sections 1–3 are findings, not decisions. The proposals that were tried (texture
mode, native canvas) are *not* the agreed design.

## 1. Session log 2026-11-24 (R1-06): what was done

Starting point: R1-06, "the Rust tile renderer is much slower than the Dart renderer on the
tablet". All work below is uncommitted on `update/rework`, behind developer switches.

| Step | What | Result |
|---|---|---|
| 1 | `[profile.dev] opt-level = 3` in `rust/Cargo.toml` | Fine; debug APKs no longer run unoptimized Rust. Worth keeping. |
| 2 | **Texture mode** (switch "Rust texture view"): Rust keeps the tiles and composes the visible area into one of two Flutter `SurfaceTexture`s; Dart swaps textures in paint; scale changes in levels during zoom, exact after 150 ms; per-area fallback from other scales. Files: `rust/src/engine/compositor.rs`, `rust/src/surface.rs`, `rust/src/texture_host.rs`, `rust/src/api/texture.rs`, `lib/features/editor/rendering/rust_texture_view.dart`, `MainActivity.kt` (`RustTexture`). | Zoom/scroll without dropped frames (compose 7–30 ms off the UI thread). **Drawing did not improve**: the active stroke was still Flutter and switched to the Rust rendering at pen-up (visible). |
| 3 | Fixes inside texture mode, one at a time after testing on the tablet: `SurfaceProducer` → `SurfaceTexture`; paint the hidden texture tiny so it latches; report frames only after `onFrameConsumed`; fallback per area with current tile versions first; Flutter paints the page under a transparent texture. | Each fixed one visible problem; the user still saw flicker. |
| 4 | Research on ink renderers (wet/dry ink, Android front-buffered rendering, androidx.ink). | Findings in section 2. |
| 5 | **Native canvas spike** (switch "Rust native canvas"): `SurfaceView` + `SurfaceControl` layers owned by Rust, native touch input, Rust owns zoom/scroll, wet layer for the active stroke, handoff at pen-up in one transaction, low-res overview layer. Files: `rust/src/engine/canvas.rs`, `rust/src/canvas_android.rs`, `rust/src/api/canvas.rs`, `lib/features/editor/rendering/native_canvas.dart`, `NativeCanvas.kt`, transparent Flutter surface in `MainActivity.kt`. | Pen worked, but: drawing over the toolbar, menus hidden, ink outside the page, handoff never completing, gaps when zooming out, view shifted to the right, flicker again, every other tool missing. Fixed some, user judged it "not a good base". |

### What not to do again (lessons)

- **Don't build before the design is agreed.** Both spikes went straight into the app after a
  short discussion; problems were then found by the user on the device and patched one by one.
  The roadmap's own ground rule ("discuss larger changes before implementing them") was not
  followed closely enough.
- **Don't stage a renderer so that live and finished strokes come from different code.** D7
  already required "Rust draws everything, including the stroke being drawn". Building finished
  content first (texture mode) produced exactly the visible pen-up switch D7 was meant to avoid.
- **Don't assume platform behaviour; verify it with a minimal test first.** Assumed and wrong:
  CPU writes into Flutter `SurfaceProducer` buffers (they are PRIVATE `ImageReader` buffers);
  a hidden `SurfaceTexture` latching new buffers (it only latches while painted); front-buffer
  support (this tablet has none, yet the wet layer kept writing into the displayed buffer).
- **Don't measure only part of the experience.** Scrolling and zooming were measured; drawing
  (latency, what changes per frame) was never measured, although it is what the user feels.
- **Don't patch symptoms of a design that needs many asynchronous handoffs.** Tiles → frame,
  fallback → exact, overview → sharp, buffer swaps, wet → dry: each handoff is a possible
  flicker. Adding fixes added handoffs. Look for designs with fewer of them.
- **Don't widen scope without saying so.** The native canvas silently dropped every tool except
  the pen and broke the toolbar menus; the user had to discover it.
- **Don't drive the device while the user tests it.** Synthesized input (`adb shell input`) during
  a user test mixed up both.

## 2. Findings worth keeping

### Measurements (Xiaomi Pad 6 / SM8250, 120 Hz, Android 16, Impeller Vulkan, profile build)

- Rust tile rendering (release opt): whole A4 page at 8 px/mm in ~33 ms on 7 threads, one stroke
  update ~3 ms. Unoptimized (debug) ~3× slower.
- Composing a 3137×2249 frame from tiles on the CPU: 7–30 ms (fallback frames slower).
- Tile mode (one `ui.Image` per tile): ~530 tiles of 256 KB per A4 page at fit-width zoom; the
  per-tile copies and `decodeImageFromPixels` are the bottleneck, not rendering.
- Wet-ink draw of a small dirty rectangle: 0.4–1 ms per pen event.
- The tablet reports **no** `USAGE_FRONT_BUFFER` support.

### Platform facts (Android / Flutter 3.47)

- `SurfaceProducer` = `ImageReader` in PRIVATE format: `ANativeWindow_lock` fails
  (`createGraphicBuffer failed`). `SurfaceTexture` entries accept CPU-written RGBA buffers.
- A `SurfaceTexture` only latches new buffers when Flutter paints it; `setOnFrameConsumedListener`
  reports latching.
- A `SurfaceView` with `setZOrderOnTop(true)` covers all Flutter UI (menus, dialogs). Flutter can
  instead draw on a transparent surface above a native view (`RenderMode.surface` +
  `TransparencyMode.transparent`); then input routing between the two has to be managed.
- SurfaceControl children are not clipped to the parent view unless a crop is set.
- NDK `ASurfaceControl`/`AHardwareBuffer` functions need API 29–31; loading them with `dlsym`
  avoids raising the build API level.

### How good ink renderers work (research)

- Wet (in-progress) and dry (finished) ink are separate layers but come from **one** renderer
  with the same geometry; the handoff happens inside it in one frame (androidx.ink).
- Low latency on Android: front-buffered layer for the active stroke only, outside the app's
  frame pipeline, plus motion prediction (androidx.graphics low-latency). Not for pan/zoom.
- Many apps render strokes on the **GPU as meshes** (tessellated once, drawn every frame with the
  current transform): zoom is a matrix, always sharp, no tiles or levels of detail. CPU raster
  is what forces tiles, LOD, async frames and fallback.

Sources: androidx.graphics low-latency (`GLFrontBufferedRenderer`, `CanvasFrontBufferedRenderer`),
"Stylus low latency" (Android Developers blog), androidx.ink module docs, Android advanced stylus
codelab, Flutter platform-views docs.

## 3. Options raised, not decided

- **GPU meshes drawn by Flutter**: Rust builds stroke meshes, Flutter draws them with
  `Canvas.drawVertices` (Impeller). One pipeline for live and finished strokes, no platform glue,
  all platforms. Latency = Flutter's frame pipeline. Unknown: cost of many vertices per frame.
- **GPU meshes drawn by Rust** (e.g. wgpu) on a native surface: lowest latency, full control, but
  native glue per platform, input routing and Flutter-over-native layering (all seen in the spike).
- **CPU tiles** (current Rust engine): proven rendering speed, but the handoff complexity above.
- Proposed process: requirements first, then small throwaway benchmarks on the tablet (dense
  page during continuous zoom, pen latency) before choosing.

## 4. Open points: each must be discussed and decided before work continues

| # | Point | Decided so far | Learned |
|---|---|---|---|
| 1 | **Requirements** (decided, 4.1): pen latency target (reference app?), sharpness during zoom, strokes per page / pages per document, hard no-gos (flicker, pen-up switch, gaps, dropped frames), platform parity | nothing written down | without targets every fix was guesswork |
| 2 | **Rasterization**: CPU or GPU (meshes) | **decided: GPU meshes (4.5)**, replaces D6 | CPU forces tiles, LOD, async frames, fallback |
| 3 | **Where the canvas is drawn**: Flutter or a native surface | **decided: Flutter (4.3)**, D12 dropped | native surface brings glue, input routing, UI layering; no front buffer on the tablet |
| 4 | **Stroke geometry** (decided, 4.6): points → shape (smoothing, pressure, joins, caps); one implementation for live and finished | outline from `draw_strokes.dart`; R4-02 open | must be shared by live and finished strokes |
| 5 | **Input and live stroke** (decided, 4.7): event path, latency, prediction | D7, D13 | never measured |
| 6 | **Zoom and scroll** (decided, 4.8): who owns the transform, how content stays sharp | `InteractiveViewer` (Flutter); Rust in the spike | depends on 2 |
| 7 | **Data ownership** (decided, 4.9): Dart document vs. Rust mirror, change flow, undo | D4 | works; tool/undo interaction open |
| 8 | **Backgrounds** (decided, 4.10): line patterns, images, PDFs | D8, D9 | not started |
| 9 | **Tools on the canvas** (decided, 4.11): eraser, selection, shapes, laser, previews | Flutter | must use the same renderer |
| 10 | **Hit testing** (decided, 4.12): eraser, lasso | R4-01 | not started |
| 11 | **Platforms** (decided, 4.13): Android, Linux, others; what must be identical | Android + Linux high priority | glue multiplies per platform |
| 12 | **Process**: measurements and gates, which spike code to keep or delete | **decided (4.2)** | spikes went into the app too early, without numbers |

### 4.1 Point 1, requirements (discussed 2026-11-26)

- **Latency:** hardware latency can't be beaten by rendering tricks. The tool is **motion
  prediction** (extrapolate the pen position from speed and direction), not chasing the pen with
  faster render paths. No fixed latency number.
- **Zoom sharpness:** temporarily blurry while pinching is acceptable; sharp shortly after the
  gesture ends. Always-sharp zoom is nice to have, not expected now (past attempts).
- **Size:** a page can hold many strokes; pages are lazy-loaded, so the per-page cost matters, not
  the document size. No real benchmark file exists yet, so one has to be generated.
- **The flicker the user saw** was mainly a stroke shortly after it was drawn, when zooming right
  after drawing. Requirement: content that was just drawn stays visible and unchanged through any
  zoom or scroll that follows.
- **Hard no-gos** (any one fails a design): any visible change at pen-up; flicker of any kind;
  gaps or blank areas over already-seen pages while scrolling/zooming; dropped frames while
  drawing; canvas covering toolbar, menus or dialogs.
- **Platforms:** Android and Linux look and behave the same (same tools, same result). Latency
  work only on Android. **Amended 2026-11-26:** Android first. Linux keeps working but may have
  jagged stroke edges until Linux antialiasing is picked up again (options in 4.5).

### 4.2 Point 12, process (decided 2026-11-26)

- No renderer code goes into the app until points 2–6 are decided.
- Points 2 and 3 are decided by small throwaway benchmarks **outside the app**, run on the Pad 6
  (and Linux), each with a pass/fail gate written down before it runs.
- Spike code (texture mode, native canvas) is removed. Kept: `[profile.dev] opt-level = 3` and
  the measurements in this file.

### 4.3 Point 3, where the canvas is drawn (decided 2026-11-26)

- **Inside Flutter.** No native surface (D12 dropped). Reasons: latency is handled by prediction
  (4.1), the tablet has no front buffer, "canvas covering UI" is a hard no-go, and one Flutter path
  gives Android/Linux parity.

### 4.4 Point 2, benchmark B (GPU meshes) first, gates fixed before running (2026-11-26)

Candidate B: every stroke is turned into a triangle mesh once; Flutter draws all meshes each frame
with `Canvas.drawVertices` and the current zoom matrix. Live and finished strokes use the same mesh
code and draw call. Candidate A (current CPU tiles) is the fallback.

Benchmark: standalone Flutter project outside the app, profile build, generated A4 page with 3000
handwriting-like strokes with varying pressure (meshes built in Dart for the benchmark).

| Gate | Pass condition |
|---|---|
| G1 | Continuous pinch zoom 1×↔8× over the dense page on the Pad 6 at 120 Hz: no dropped frames (raster time < 8.3 ms per frame) |
| G2 | Screenshot at 8×: edges antialiased, no visible jaggies compared with antialiased path rendering of the same strokes |
| G3 | Write a stroke and zoom right after: no flicker, checked by the user on the device and frame by frame in a screen recording |
| G4 | Same build on Linux: screenshots match the tablet (G2 quality) |

Things to verify, not assume: whether `drawVertices` edges are antialiased on Impeller/Vulkan and
on Linux; per-frame cost of a dense page (direct vs. recorded `ui.Picture`); which renderer
Flutter uses on Linux.

#### Results, run 1 (2026-11-26; benchmark code: scratchpad `mesh_bench`, throwaway)

Page: 3000 strokes → 299,598 vertices, 281,598 triangles in 5 chunks (Uint16 index limit);
mesh build in Dart 90 ms on the tablet. Auto-zoom 1×↔8×, 12 s, 4 s period.

| Variant (Pad 6, Impeller, 120 Hz) | Frames / expected | Raster p50 / p99 / max | Over 8.3 ms |
|---|---|---|---|
| Mesh, drawn directly each frame | 1444 / 1440 | 3.2 / 5.3 / 12.1 ms | 1 |
| Mesh, recorded once into a `ui.Picture` | 1444 / 1440 | 3.3 / 5.5 / 5.7 ms | 0 |
| Antialiased `drawPath` per stroke (reference) | 511 / 1440 | 5.9 / 79.7 / 90.3 ms | 188 |
| Mesh with 1 px feather ring (vertex colours) | 717 / 1440 | 16.0 / 19.0 / 21.5 ms | 717 |

- **G1: pass** for plain meshes (direct and picture). Feather meshes fail (vertex colours ~5× the
  raster cost).
- **G2 (Android): pass.** Plain meshes are antialiased by Impeller's MSAA on the tablet; at 1×
  they look like the path reference.
- **G4 (Linux): fail as is.** Linux runs Impeller OpenGLES ("OpenGLESSDF") with no MSAA on the
  window: plain meshes are jagged, and even the `drawPath` reference is barely antialiased. Feather
  meshes are antialiased but softer, and they need a rebuild for each zoom level (a handoff).
- **G3:** open, needs the user on the device.
- Pitfalls found: `drawVertices` without vertex colours plus `BlendMode.modulate` draws nothing on
  Impeller (a first run measured an empty page). Use `srcOver` with the paint colour. The
  benchmark's simple miter joins make spikes at sharp turns; that's a stroke geometry issue
  (point 4), not a renderer one.
- The tablet logs both "Impeller (Vulkan)" and "Impeller (OpenGLES)" at start; which one draws
  the frames is not verified.

#### Results, run 2 (2026-11-26): textured AA (option b), Linux, G3 recording

- **Option (b), textured AA:** the mesh is 1.5× wider than the stroke and carries texture
  coordinates into a 256² disc image (PNG-decoded, `ImageShader` with `FilterQuality.medium`).
  Impeller does sample mipmaps for this (verified on Linux: edges are antialiased at every zoom,
  without MSAA and without a rebuild).
- **Linux, 1× monitor, 5.9 px/mm (fit width in a 1280 px window):** plain mesh and the `drawPath`
  reference are both jagged (no MSAA). Textured mesh is antialiased; at 8× its edges look clean,
  but at 1× thin strokes come out soft and greyish (mip blur of ~1.5–2 px on 2–3 px strokes).
  Tuning still to try (mip bias isn't exposed in Flutter).
- **Linux on a 1.5× scaled monitor:** Flutter renders at 2× and KWin scales the picture down,
  which blurs everything. Screenshots from that monitor can't be used to judge AA.
- **G1 Linux** (RTX 2080 SUPER, HDMI monitor at 60 Hz; Flutter reports 120 Hz there, which is
  wrong): every variant gets 724 of 720 frames. Raster p50/max: plain 1.1/3.5 ms, textured
  3.2/6.6 ms, feather 5.5/9.1 ms, paths 4.2/23.3 ms.
- **G3 recording** (116 fps, 120 s): an automatic one-frame dip check flagged 84 frames. The
  strongest were checked by eye: H.264 smearing in the grey area during fast zoom-out, and pinch
  jitter. No vanishing or changing stroke was found in the frames checked. The user's own
  observation is still pending. "feather AA" was on for part of the test.
- **G3: pass.** The user saw no flicker when zooming right after drawing (plain mesh).
- **Textured AA on the tablet:** looks the same as the plain mesh at 8× and slightly softer at 1×,
  but **fails G1**. 1008 of 1440 frames, raster p50 11.9 ms (plain mesh: 3.3 ms). Likely fill cost:
  1.5× wider geometry with texture sampling on top of MSAA. Not verified.
- **Open:** how to antialias on Linux (see the discussion after run 2).

### 4.5 Point 2, rasterization (decided 2026-11-26)

- **GPU meshes (candidate B).** Every stroke becomes a triangle mesh once; Flutter draws all
  meshes each frame with `Canvas.drawVertices` and the current transform. Live and finished
  strokes use the same mesh code and the same draw call. Replaces D5 (RGBA buffers into
  `ui.Image`) and D6 (CPU rasterization with tiny-skia); the CPU tile engine is no longer planned.
- Draw meshes directly each frame. Recording into a `ui.Picture` measured the same, so it isn't
  worth the extra step.
- Antialiasing on Android: Impeller's MSAA on plain meshes (no vertex colours, `srcOver`).
- Passed on the Pad 6: G1 (no lost frames, raster 3.3 ms p50), G2, G3.
- **Linux antialiasing deferred** (Android first). Options for later: (1) textured AA only on
  Linux (works, 3.2 ms raster, soft at low zoom; too slow on the tablet); (2) a cheaper textured
  AA; (3) enabling MSAA in Flutter's Linux embedder (not researched).

### 4.6 Point 4, stroke geometry (decided 2026-11-26)

- **Stored:** input points only (position + width, as now). The mesh is always computed from
  them, by the same function for live and finished strokes, so pen-up can't change the shape as
  long as the stroke end is handled the same way in both.
- **Smoothing:** a Catmull-Rom curve through the input points, subdivided finely enough to look
  smooth at maximum zoom (meshes are not rebuilt per zoom level). G1 has to be re-checked with the
  denser meshes.
- **Joins:** round at sharp turns (no miter spikes). **Caps:** round.
- **Pressure → width:** today's formula for now; tuning is separate.
- **Dotted strokes:** one mesh per dash along the same smoothed path.
- **Highlighter is planned later.** Overlapping triangles inside one semi-transparent stroke
  darken it, so the technique (separate layer per transparent stroke, or meshes that don't
  overlap) has to be chosen and measured before the highlighter is built. The geometry code must
  not rule either one out.
- **Geometry lives in Rust.** Before building on it, measure the bridge cost per pen event (live
  stroke) and page-load mesh time, Dart vs. Rust (process rule 4.2).

### 4.7 Point 5, input and live stroke (decided 2026-11-26)

- **Event path:** pen events through Flutter pointer events (`Listener`); each event goes to Rust,
  which returns the updated live-stroke mesh; only the canvas repaints (covers R2-03).
- **Sample rate:** the Pad 6 delivers 240 pen points per second to Flutter (user's observation).
  Nothing may depend on this device: rates and timestamps are read from the events, any rate
  must work.
- **Prediction:** own extrapolation from the last points (speed and direction, about one frame
  ahead), drawn on top of the live stroke, never stored. **A setting turns it off.** With it on,
  the predicted piece disappearing at pen-up is accepted.
- **Latency:** current latency is acceptable. No camera measurement. The in-app pen-event-to-frame
  time is kept as a regression check: the live stroke must not get slower than today's Dart
  renderer.
- Still to measure before building: bridge cost per pen event (see 4.6).

### 4.8 Point 6, zoom and scroll (decided 2026-11-26)

- **Zoom stays with `CustomInteractiveViewer`** (option A); each page paints its meshes in its own
  widget. Switch to one document canvas only if A shows concrete problems.
- **Zoom range 0.2–8** stays.
- **Gate G5 (to measure in the benchmark before building):** pinch zoom 0.2×↔1× over a document
  of dense pages, no lost frames. If it fails: simplified meshes for small zoom, switched where
  the difference is below a pixel. No cached raster images (they bring back async handoffs).
- **Unloaded pages:** a short blank on a page never seen before is acceptable. Meshes of recently
  seen pages stay in memory (with a memory limit), so already-seen pages never show gaps.

### 4.9 Point 7, data ownership (decided 2026-11-26)

- **D4 stays:** Dart owns document, undo and saving; Rust mirrors pages through the existing
  change API (open/close page, add/remove/hide strokes, background, resize) and returns
  **meshes** instead of tiles.
- **Mesh flow:** one mesh per stroke in Rust, packed into chunks (≤ 65k vertices); Dart fetches
  chunks as arrays (positions, indices) and makes `ui.Vertices`; after a change only affected
  chunks are re-sent; new strokes go into a "recent" chunk.
- **Live stroke:** live begin / add points (returns live mesh) / live end. At pen-up Rust moves
  the live mesh into the page unchanged (no rebuild); Dart adds the stroke with the same points to
  document and undo. The prediction mesh is separate and dropped.
- **Undo/redo:** unchanged in Dart; for Rust it's ordinary add/remove changes.
- **Old code:** the tile parts of the API are replaced. The committed tile renderer stays behind
  the developer switch until the mesh renderer works, then goes with R5-03. The uncommitted spike
  code is removed now (file-by-file review with the user first).

### 4.10 Point 8, backgrounds (decided 2026-11-26)

- **Page colour:** a rectangle drawn by Flutter. **Line patterns** (`backgroundStrokes`): meshes
  through the same geometry code, in a background layer under the ink; the eraser never touches it.
- **Inserted images:** drawn by Flutter with the current transform and smooth downscaling (mipmaps),
  in the same layer order as the meshes.
- **PDFs:** D8 stays (original bytes in the `.bnf`, pdfium in Rust). Per PDF page there's always a
  base image at about fit-width resolution that is never removed. When zoomed in, Rust renders
  sharper tiles (about 1024 px) for the visible area in the background; they're drawn over the base
  image when ready. Ink stays independent (meshes), so tiles can't affect it.
- **PDF gate (measured with a real PDF on the tablet before building):** no blank PDF areas over
  already-seen pages, sharp shortly after zooming stops, no lost frames while pinching.
- **Priority:** PDFs are important. R3 comes right after the stroke renderer is in the app. Until
  then PDF import keeps working as today (pages converted to images).

### 4.11 Point 9, tools on the canvas (decided 2026-11-26)

- **Rule:** everything that is or becomes ink uses the mesh pipeline. UI markers that never become
  ink (eraser cursor, lasso outline, selection handles) may stay drawn by Flutter.
- **Shapes and lines:** like the pen (live mesh while dragging, moved in unchanged at release).
- **Eraser:** hit strokes are hidden at once in Rust and the affected chunk is re-sent. Smaller
  chunks (e.g. ~8k vertices) make that cheaper; measure contact-to-disappearance on a dense page.
- **Selection while moving:** selected strokes hidden in their chunks, drawn as their own group
  with an extra transform (no rebuild while dragging). On drop the points are transformed and the
  meshes rebuilt: identical for moves; for scaling sub-pixel differences are possible, and if
  visible the transformed mesh is kept instead.
- **Selection highlight:** a slightly wider mesh of the selected strokes in the selection colour,
  under them.
- **Laser:** meshes with fading opacity; overlap darkening accepted for this temporary tool
  (check visually).
- **Rollout:** the mesh renderer stays behind a developer switch until every tool works with it;
  one roadmap item per tool; the switch becomes the default only when all are done.

### 4.12 Point 10, hit testing (decided 2026-11-26)

- **In Rust** (R4-01), with a **spatial index per page** (R-tree via `rstar`, or a grid) over stroke
  bounding boxes.
- **Tests use the drawn geometry** (smoothed, with per-point width), not raw points.
- **Eraser is a swept area:** the capsule (or swept rectangle) between previous and current eraser
  position, so fast moves can't skip strokes.
- **One bridge call per eraser event:** hit test + hide (+ chunk re-send) + return IDs for Dart's
  undo. Gate: under 1 ms on a dense page on the tablet.
- **Lasso:** Rust tests strokes against the polygon with both rules ("touches" / "fully inside");
  polygon sent when the lasso closes, or per move if a live preview is wanted.
- **Partial eraser** (cutting strokes) is wanted later. The hit test should be able to report
  where on a stroke it was hit, not only whether, so this can be added without a redesign.

### 4.13 Point 11, platforms (decided 2026-11-26)

- **Android first** (D16).
- **Linux:** the mesh renderer and all tools must work there too (edges may be jagged for now).
  Every renderer step is built and run on Linux as well. Linux edge smoothing (options in 4.5) is
  its own later item.
- **Windows, macOS, iOS:** expected to work (`drawVertices` and the bridge exist there); whether
  mesh edges are smoothed is checked in R5-01. The old Dart renderer stays the default there
  until then.
- **Web:** needs the Rust code as WebAssembly with threads and cross-origin isolation (R5-02); low
  priority.
- **The old Dart renderer is not deleted** (changed 2026-11-27, D21): it is cleaned up and stays
  as a fallback the user can select in the settings. It guarantees that documents open, display
  and edit correctly with the existing tools; new visual features may be mesh-only. The Rust tile
  renderer is gone (R12-02).

## 5. M1 measurement results

### R7-01, G5: zoom-out over many dense pages (2026-11-26, Pad 6, 120 Hz)

12 pages × 3000 strokes in a column, pinch 1×↔0.2× (relative to fit width), pages outside the
screen are not drawn (the app's `Column` currently paints every loaded page; R9-01 must cull).

| Variant | Pages visible | Vertices drawn (max) | Frames / expected | Raster p50 / p95 / max |
|---|---|---|---|---|
| Landscape, full meshes | 3 | 0.90 M | 1444 / 1440 | 8.2 / 8.8 / 12.1 ms |
| **Portrait, full meshes** | 6 | 1.80 M | **1368 / 1440 (fail)** | 8.2 / 11.0 / 13.4 ms |
| Portrait, simplified below 0.4× | 6 | 1.08 M | 1444 / 1440 | 4.3 / 5.3 / 9.8 ms |

- Full meshes fail G5 in portrait (landscape passes by the count but has no headroom).
- **Simplified meshes** below 0.4× (Douglas-Peucker with 0.05 mm tolerance, 3 cap segments
  instead of 8; 40% fewer vertices per page) pass.
- The switch: screenshots of the same view at 0.39×, full vs. simplified, differ only in scattered
  single edge pixels (MSAA coverage), no visible change of shape. The switch only happens while
  the zoom crosses 0.4×, i.e. during motion. **User check on the device: no visible switch.**
- **R7-01: pass with simplified meshes below 0.4×.** These go into the plan (R8-01).
- Android 16 ignores app orientation requests on tablets (`setPreferredOrientations` had no
  effect); the portrait run needed the tablet rotated by hand. Relevant for the app too.

### R7-02: smoothed geometry with round joins (2026-11-26, Pad 6 portrait)

Geometry candidate (benchmark `lib/smooth.dart`, Dart): centripetal Catmull-Rom through the input
points, subdivided until within a tolerance of the curve; strip with bisector normals (miter
clamped at 2×) at turns below 0.35 rad, round joins above; round caps; arc segment counts follow the
tolerance. At 8× strokes look smooth, no spikes.

| Run | Vertices | Frames / expected | Raster p50 / p95 / max |
|---|---|---|---|
| G1, one page 1×↔8×, tolerance 0.003 mm | 671k per page (2.2× the plain strip) | 1444 / 1440 | 3.8 / 4.9 / 11.1 ms |
| G5, smoothed full + one simplified level below 0.4× (plain strip) | 2.0 M on screen | 1386 / 1440 (fail) | 5.2 / 10.9 / 20.7 ms |
| G5, smoothed full + one simplified level below 0.4× (smoothed, few joins) | 2.0 M on screen | 1388 / 1440 (fail) | 8.3 / 10.9 / 20.0 ms |
| **G5, detail levels** (below) | 0.93 M on screen | **1443 / 1440 (pass)** | 3.9 / 4.8 / 7.7 ms |

- With one switch point, the drops happen between 0.4× and 1× (3–4 pages of full meshes).
- **Detail levels by zoom** (like mipmaps): level k is used from zoom z_k up (z = 4, 2, 1, 0.5,
  0.25, below); its tolerance is 0.4 device px at z_k (Pad 6 portrait: 8.4 px/mm at 1×, so
  0.012 / 0.024 / 0.048 / 0.095 / 0.19 / 0.38 mm). Coarse levels (tolerance ≥ 0.02 mm) also reduce
  input points (Douglas-Peucker) and use round joins only above 1.2 rad. Vertices per page:
  418k / 270k / 221k / 164k / 147k / 155k (round caps and joins put a floor under it).
- Switch check, same view just below each boundary, finer vs. coarser level: differences are
  edge shifts below a pixel (thin outlines in the diff, no change of shape); mean |diff| 2.5–3.6.
  **User check on the device: no visible switch.** R7-02 passes with detail levels.
- For the app: a level that isn't built yet is replaced by the next finer one (always correct,
  only slower), so missing levels can't cause flicker.
- Mesh building in Dart: 270 ms per page for the full level, 7.1 s for 6 levels × 12 pages.
  Building is R7-04's topic (Rust, background, lazily per level).

### R7-03 / R7-04: gates fixed before running (2026-11-26)

Benchmark: separate Flutter project with its own Rust crate (`flutter_rust_bridge` 2.13, same setup
as the app), Rust port of the R7-02 geometry, profile build on the Pad 6.

- **R7-03 gate:** one pen event = sync bridge call that adds a point and returns the live-stroke
  mesh, plus creating the `ui.Vertices` in Dart. p99 ≤ 1 ms for live strokes up to 1000 input
  points (a long stroke: ~4 s at 240 Hz). Measured per call with a `Stopwatch` over stroke lengths
  10…2000.
- **R7-04 (no gate, numbers to decide by):** one dense page (3000 strokes), full level and all six
  levels: Rust build time, transfer to Dart, `ui.Vertices` creation; compared with Dart (270 ms
  for the full level).

#### Results (2026-11-26, Pad 6, profile build, Rust with opt-level 3)

**R7-03, per pen event** (sync call adds a point, Rust rebuilds the whole live mesh from all
points and returns it, Dart creates `ui.Vertices`; ms, 3 runs over a 2000-point stroke):

| Live stroke length | Rust p50 / p99 / max | Dart (same geometry, no bridge) p50 / p99 / max |
|---|---|---|
| 1–100 points | 0.01 / 0.03 / 0.07 | 0.03 / 0.05 / 0.06 |
| 101–500 | 0.05 / 0.08 / 0.95 | 0.14 / 0.21 / 0.95 |
| 501–1000 | 0.10 / 0.14 / 2.90 | 0.33 / 0.84 / 1.15 |
| 1001–2000 | 0.19 / 0.26 / 1.81 | 0.66 / 1.23 / 2.77 |

- **R7-03: pass** (p99 0.14 ms up to 1000 points, gate 1 ms). Single outliers up to 3 ms (not
  analysed; likely scheduling or GC). Rebuilding the whole live stroke per event is affordable;
  incremental building isn't needed for now.

**R7-04, one dense page** (3000 strokes, 120k points; median of 5):

| | Dart | Rust: whole call | of which building in Rust | `ui.Vertices` |
|---|---|---|---|---|
| Full level (670k vertices) | 235 ms | 57 ms | 28 ms | 3.3 ms |
| All 6 levels (1.38 M vertices) | 555 ms | 146 ms | 99 ms | 9.8 ms |

- Rust builds 4–8× faster than Dart. About half of the Rust call time is the bridge: sending
  120k points in and the vertices back (FRB copies `Vec<f32>`). In the app the points are already
  in the Rust mirror (sent once at page open), so building a further level only costs the return
  trip; zero-copy return buffers are worth trying.
- Page builds must not run on the UI thread: async call (or a Rust worker) per page and level,
  the level for the current zoom first. A missing coarser level is covered by a finer one (always
  correct). A missing **finer** level (zooming in faster than building) would have to be covered by
  a coarser one, which looks slightly angular until the finer one arrives: a visible change, within
  what 4.1 accepts for zooming ("blurry while pinching, sharp shortly after"). To be settled in M2/M3
  (e.g. build the next finer level ahead).
- Decision 4.6 (geometry in Rust) is confirmed by the numbers.

### R7-05: eraser call and chunk size (2026-11-26, Pad 6)

Rust page mirror with per-stroke meshes (full level, 670k vertices) packed into chunks, 5 mm grid
index, swept capsule hit test on the smoothed polyline, hit strokes hidden, changed chunks rebuilt
and returned; Dart creates `ui.Vertices` for them. Zigzag eraser path over the page, 0.5 mm per
event (6819 events); numbers are for events that hit something.

| Chunk size | Chunks/page | r = 1.5 mm: p50 / p99 / max | r = 5 mm: p50 / p99 / max | Rust part p99 |
|---|---|---|---|---|
| 65k vertices | 11 | 1.51 / 6.16 / 23.3 ms | 0.99 / 5.73 / 26.6 ms | 0.91 ms |
| 16k | 43 | 0.26 / 3.14 / 4.5 ms | 0.19 / 2.03 / 5.1 ms | 0.29 ms |
| 8k | 86 | 0.12 / 0.85 / 5.7 ms | 0.08 / 0.70 / 4.0 ms | 0.18 ms |
| 4k | 174 | 0.05 / 0.32 / 1.5 ms | 0.04 / 0.23 / 1.7 ms | 0.07 ms |

- Hit test with the grid stays well under 0.1 ms; the cost is copying the rebuilt chunk back.
- **Draw-call check** (G1 landscape, smoothed meshes, 3 runs each): 8k and 4k chunks deliver all
  frames in every run (1442–1443 / 1440). Raster p50 jumps between ~3.1 ms and ~8.3 ms from run to
  run for the *same* build (also seen with 65k), so raster time isn't a reliable cost measure on
  this device; likely the GPU clock adapts to just fit the frame (not verified). Frames delivered is
  the gate metric. One earlier 4k run lost 116 frames; its conditions are unknown (it was not
  repeatable). G5 with 8k chunks (portrait, levels): 1444 / 1440.
- **R7-05: pass with 8k chunks** (p99 0.85 / 0.70 ms). 4k has more margin for the eraser but twice
  the draw calls; 8k is the proposal. Zero-copy return buffers (R7-04 note) would widen the margin.

### M1 summary

All five measurements are done; the decisions in section 4 hold with these additions: detail
levels by zoom (R7-02), geometry and page builds in Rust off the UI thread (R7-04), chunks of about
8k vertices (R7-05), pages outside the screen are not drawn (R7-01).
