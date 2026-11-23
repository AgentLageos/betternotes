# BetterNotes Roadmap

This file is the single source of truth for planned changes. It is written for both humans and
AI assistants working on the repo in later sessions: read it before starting work, update item
status when work is done, and record new decisions in the "Decisions" section.

- Item status: `[ ]` open, `[~]` in progress, `[x]` done, `[-]` dropped (with reason)
- Item IDs (`P1-03`) are stable; reference them in commit messages.
- `file:line` references point to commit `bbefaa3` and will drift as the code changes.
- Priority tags: **(high)** = Android/Linux or data safety, **(low)** = other platforms / polish.

---

## Ground rules

- **Keep the `print` calls for now.** They are used for debugging. Do not remove or replace them
  unless this rule is changed here.
- **All comments in English.** German comments get translated (P2-04), new comments are English.
- **No backwards compatibility needed** for `.bnf` files. The format can change freely; no
  migration code. (Revisit before the first real release.)
- **Design for tabs.** Multiple open documents (tabs) are a planned feature. Never address a
  document by list index; always by a unique `docID`.
- **Platforms:** Android and Linux are high priority. Windows, macOS, iOS and web must keep
  working but get less attention.
- Discuss larger changes before implementing them.

---

## Decisions

| # | Decision | Reason |
|---|----------|--------|
| D1 | `DocumentModel`, `PageModel` and friends become immutable (final fields, changes only via `copyWith` producing new objects and new lists). Hand-written, no `freezed`. | In-place mutation is shared between current state, old Riverpod state and undo history; main cause of broken undo/redo. No build step wanted. |
| D2 | Per-document state keyed by `docID` (one notifier per open document). | Makes tabs a UI-only addition later. |
| D3 | Renderer is rewritten in Rust (`flutter_rust_bridge`). Tile-based concept stays. | Flutter's async image pipeline and isolates make the current tile renderer slow and workaround-heavy. |
| D4 | Dart owns the page data. Rust holds a render mirror updated via deltas (add/remove strokes etc.). | Keeps document logic and undo in one place (Dart), renderer stays replaceable. |
| D5 | Rust returns RGBA pixel buffers; Dart creates `ui.Image` via `decodeImageFromPixels`. No external textures for now. | Works on all platforms incl. web, no platform glue. With CPU rasterization the GPU upload is needed anyway, so textures would gain little. |
| D6 | Rasterizer: `tiny-skia` (CPU only). | GPU stacks are unreliable, especially on Linux. Tiles parallelize well on CPU. |
| D7 | Rust draws everything, including the stroke currently being drawn. | Same code for live and committed strokes, so no visible switch from vector to raster. Gated by a latency measurement (R2-04). |
| D8 | Imported PDFs are stored as original bytes inside the `.bnf` and rendered on demand by pdfium (`pdfium-render`) in Rust. | Text/vector information preserved, sharp at every zoom, instant import, small saves, lossless PDF export later. pdfium is BSD/Apache (compatible with MIT); MuPDF (AGPL) and Poppler (GPL) are not. |
| D9 | `.bnf` stays an append-only block store with an index, generalized to typed entries (page / pdf / image). | The existing lazy-loading design fits embedded blobs naturally. |
| D10 | Rust code documented at a medium level: the Dart/Rust API is explained, internals get normal comments. | |

---

## Architecture notes (current state, as of bbefaa3)

- Flutter app, Riverpod (`flutter_riverpod` 3) for state, GoRouter for two routes, plain
  `Navigator` elsewhere.
- `lib/features/editor/providers/documents_notifier.dart` (~2600 lines) contains document state,
  undo/redo, lazy page loading, the isolate pool, `.bnf` reading/writing and compaction.
- Lazy loading: only pages within `lazyLoadRange` (1) of the current page are loaded;
  others are `PageModel(isTemp: true)` placeholders. `DocumentModel.pageList` (all page IDs) and
  `pageHeights` describe the whole document; `pages` holds only the loaded window.
- Page units are millimetres (A4 = 210 × 297).
- Rendering: pages are split into 20×20 mm tiles (`tile2.dart`), each rasterized at a fixed scale
  of 20 (400×400 px). An isolate computes stroke outlines (`core/utils/isolates/initializeTiles.dart`),
  the main thread rasterizes (`renderAfterIsolate` → `picture.toImage`). The active stroke is drawn
  by `page_widget.dart` via `setState` on every pointer move.
- `.bnf` v1 layout: header (`u64 version`, `u64 rootOffset`), then append-only blocks
  (`u64 length` + data). Each save appends changed page records, a JSON metadata block, an index
  (`u32 count`, entries of `u64 pageID, u64 offset, u64 length`) and a root
  (metadata offset/length, index offset/length), then overwrites the root offset in the header.
  `compactDoc` rewrites the file without garbage.
- `lib/custom_widgets/custom_gesture_detector.dart` and `custom_interactive_viewer.dart` are
  forked copies of Flutter framework files.

---

## Phase 1: Data-safety fixes (high)

Small, urgent fixes for bugs that can lose or corrupt data.

- [x] **P1-01** PDF import can overwrite the source PDF or an existing note
  (`file_manager_list.dart:213`). The `.pdf` check is case-insensitive but
  `path.replaceFirst('.pdf', '.bnf')` is not, so `Scan.PDF` gets overwritten with `.bnf` data.
  An existing `name.bnf` is overwritten without asking. Fix: build the target path with
  `package:path` (`setExtension`), and pick a free name (`name (1).bnf`) or ask if it exists.
- [x] **P1-02** Give documents real unique IDs. `docID` defaults to `0`
  (`document_model.dart:72`), and `DocumentModel.copyWith` (`:80`) doesn't copy `docID` or
  `maxAmountCommands`, resetting them on every update. Use `IdGenerator.next()` and copy all fields.
- [x] **P1-03** Stop passing `docIndex` where a `docID` is expected
  (`file_manager_list.dart:271,272,283`, `_importPdf`; also `loadDoc2(path, 0)` and
  `updateIsolatedPages(0)` at `:88-89`). Only works today because every `docID` is 0.
  Audit all callers of `DocumentsNotifier`; long-term all APIs take `docID` (see P4-03).
- [x] **P1-04** The save queue loses the document ID (`documents_notifier.dart:1551`):
  pages queued during a running save are later saved under whatever `docID` the next call uses.
  Queue entries must carry their `docID`.
- [x] **P1-05** `setDefaultPage` never assigns `state` and does nothing (`documents_notifier.dart:222`).
- [x] **P1-06** `modifyPagesExecute` discards the result of `p.copyWith(pageID: IdGenerator.next())`
  (`documents_notifier.dart:310`), so duplicate page IDs (and the duplicate-key red screen)
  can still occur.
- [x] **P1-07** `modifyPagesExecute` removes several entries from `pageHeights` by index in a loop
  without accounting for the shift after each removal; an index of `-1` crashes it
  (`documents_notifier.dart:339`). Remove by ID or remove indices in descending order.
- [x] **P1-08** Add `mounted` / `context.mounted` checks wherever `BuildContext` is used after an
  `await` (e.g. `Navigator.pushReplacement` after `loadDoc2`, `file_manager_list.dart:91`).
- [x] **P1-09** PDF page size conversion is wrong: `page.height / 3` (`file_manager_list.dart:246`)
  gives roughly mm but A4 becomes 198×280. Use `points × 25.4 / 72`.

**Phase 1 notes (done):**
- P1-01: existing target names get a ` (n)` suffix (no dialog).
- P1-02/03: every `DocumentModel` gets `IdGenerator.next()`; `loadDoc2(path)` returns the new
  `docID` (a document gets a new ID on every load). All `DocumentsNotifier` methods that took a
  `docIndex` now take a `docID`; UI code uses `DocumentsNotifier.currentDocID` (single-document
  stand-in until P4-03). Removed the global `docID = 0` in `page_setup_menu.dart`.
- P1-04: pages queued for a document that is no longer open are dropped with a print instead of
  being written into another document's file. Still open: `saveAsBnf` returns before queued saves
  run, so the back button can compact/clear while a save is pending (look at this in P3-04/P3-07).
- PDF import now runs behind a loading page that can't be closed with back, and only one import
  can run at a time. Before, a second import started meanwhile replaced the first import's document
  (found on a tablet: first file left incomplete). Errors show the import error dialog.
- Isolate result handlers now tolerate a closed document (previously `state[-1]`, which would
  also have left the isolate slot marked busy).

---

## Phase 2: Cleanup and tooling

Mechanical work that makes the rest easier. **Prints stay** (see Ground rules).

- [x] **P2-01** Enable stricter lints in `analysis_options.yaml` (currently an empty `rules:`), e.g.
  `use_build_context_synchronously`, `depend_on_referenced_packages`, `unawaited_futures`,
  `prefer_final_fields`. Do **not** enable `avoid_print` yet. Fix what the analyzer reports.
- [x] **P2-02** Dependencies:
  - move `flutter_colorpicker` from `dev_dependencies` to `dependencies` (used in `lib/`)
  - remove `provider` (redundant with Riverpod; used in `file_manager_list.dart`, `color_selector_bar.dart`)
  - remove unused `file_manager` and `image`
  - pin `intl` instead of `any`
  - check `flutter pub outdated` and upgrade (`go_router` etc.)
  - replace deprecated `Color.value`
- [x] **P2-03** Delete commented-out code (~3000 lines) and dead fields/classes:
  `busy`, `requested`, `requestID`, `requestedDocIDs`, `requestedPageIDs`, `isolateRunning`,
  `didRedo`, `NavigatonStateNotifier` (never used), commented-out providers in `global_providers.dart`.
  Commented-out `print` lines may be deleted; active `print` calls stay.
- [x] **P2-04** Translate all German comments to English. Files with German text (comments
  and/or strings): `documents_notifier.dart`, `document_model.dart`, `page_model.dart`,
  `file_manager_list.dart`, `file_manager_screen.dart`, `file_manager_top_bar.dart`,
  `developer_settings.dart`, `design_settings.dart`, `color_picker.dart`, `selection_drawer.dart`,
  `editor_top_bar.dart`, `editor_top_bar_panel.dart`, `tool_selector_bar.dart`.
- [x] **P2-05** Rename versioned names once the old variants are gone: `isolatePageTiles5`,
  `setCurrentPageIndex3`, `_handleMessage2`, `loadPages2`, `loadDoc2`, `saveDoc2`,
  `drawStrokes2`, `tile2.dart`, `_isolateEntry1`.
- [x] **P2-06** Merge the duplicated startup logic in `main.dart`: `main()` and `RestartWidget`
  both resolve directories with different fallbacks (`currentDirectory` falls back to
  `homeDir/betternotes` in one place and `homeDir` in the other). `RestartWidget` ignores its
  `child`, so the `ProviderScope` in `main()` (`main.dart:49`) is dead. One init function, one scope.
- [x] **P2-07** Fix inconsistent SharedPreferences keys (`homeDirectory` vs `home_directory`,
  `platform_notifier.dart:53`).
- [x] **P2-08** Move hard-coded UI strings into l10n (~18, e.g. PDF import dialogs in
  `file_manager_list.dart`). Includes the TODO item "localization for pdf import".
- [x] **P2-09** Use `package:path` for all path handling instead of `'/'` and `split('/')`
  (Windows support). **(low)**
- [x] **P2-10** Remove the hard-coded Android default `pathToFile`
  (`/storage/emulated/0/...`, `document_model.dart:53`).
- [x] **P2-11** Make `IdGenerator` web-safe: it produces values around 1.7e18, beyond the 2^53
  exact-integer limit in JS. **(low)**

**Phase 2 notes (done):**
- P2-01: `avoid_print: false` is set explicitly (flutter_lints enables it by default). Added
  `unawaited_futures` and `prefer_final_fields`. Every unawaited future was either awaited or marked
  `unawaited(...)` on purpose (pen-up save, page loading/saving while scrolling, isolate scheduling).
  Found on the way: two theme color handlers restarted the app before the new color was saved;
  a debug overlay compared a `PageModel` with an `int`; `LineTool.copyWith` ignored the line type.
  Analyzer issues: 511 -> 65. Left on purpose: `Radio` -> `RadioGroup` and `Matrix4.translate/scale`
  deprecations (UI refactors), `FilePicker.getDirectoryPath` (its replacement `pickDirectory` returns
  a `content://` URI on Android that `dart:io` can't write to; revisit with P6-03), and everything in
  `lib/custom_widgets/` (P6-02).
- P2-02: upgraded go_router 18, file_picker 13, permission_handler 13, package_info_plus 10,
  cupertino_icons 2. file_picker 13 returns `content://` URIs on Android, so file import now streams
  `readAsByteStream()` instead of copying a path. Removed `image` (dimensions come from the decoded
  `ui.Image`). Added `vector_math` (imported directly). `pdfx` still applies the Kotlin Gradle Plugin;
  Flutter warns about built-in Kotlin until it is removed (R3-06).
- P2-03: removed ~930 lines of commented-out code (not ~3000; most comments were real documentation)
  and dead members: `NavigatonStateNotifier` + `NavigationState`, unused developer-settings path UI
  code, `_requestPermission`, `_pickColor`. The byte layout comments of the `.bnf` code were kept.
- P2-06: `loadStartupConfig()` in `main.dart` is used at startup and on restart; one ProviderScope.
- P2-07: shared keys are in `lib/core/utils/pref_keys.dart`; the unused `setPrefs` with the wrong key
  was removed.
- P2-08: ~25 strings moved to l10n (en/de). `ListTile(title: Text('Info 2'))` in
  `page_setup_menu.dart` is still a visible placeholder.
- P2-09: also fixed copying a file without extension (crashed) and the root check (`'/'`).
- P2-11: IDs are now `ms * 1000 + counter` (~1.8e15 < 2^53), strictly increasing.
  Note for web: `.bnf` uses `getUint64`, which dart2js doesn't support; web needs more work anyway.
- `tile2.dart` is now `tile.dart`, `initializeTiles.dart` is now `initialize_tiles.dart`
  (R5-03 updated).

---

## Phase 3: Tests, file format v2, repository layer

- [x] **P3-01** Replace the default counter test in `test/widget_test.dart` (it fails against this app).
- [x] **P3-02** Pure-Dart tests for `.bnf`: save → load round trip, append → load, compaction,
  corrupted/truncated files.
- [x] **P3-03** Tests for undo/redo, especially page add/delete followed by undo and redo
  (currently broken, see P4-02).
- [x] **P3-04** Extract all file I/O from `DocumentsNotifier` into a `BnfRepository`
  (open, read page, write pages, compact, close). The notifier only talks to the repository.
- [x] **P3-05** `.bnf` format v2 (no migration from v1 needed):
  ```
  Header:  magic "BNF\0" | u32 version = 2 | u64 rootOffset
  Blocks:  [u64 length | data] ...   append-only, never modified
  Index:   u32 count | entries of (u8 type | u64 id | u64 offset | u64 length)
           type = page | pdf | image
  Root:    u64 metadataOffset | u64 metadataLength | u64 indexOffset | u64 indexLength
  ```
  The magic marker allows rejecting non-`.bnf` files cleanly.
- [x] **P3-06** Range reads with `RandomAccessFile` instead of `readAsBytes()` on the whole file
  (`documents_notifier.dart:1055,1284,2053`). Required before PDFs are embedded (R3), otherwise
  every page load reads the whole PDF into memory.
- [x] **P3-07** Crash-safe save order: write new blocks → flush → update the root pointer → flush.
  Currently the root pointer is written before anything is flushed.
- [x] **P3-08** Compaction writes a new file and atomically renames it over the old one;
  copies large blocks in chunks; drops blocks no longer referenced by any page.
  Notify the renderer afterwards (block offsets change).
- [x] **P3-09** Automatic compaction when the garbage share exceeds a threshold (e.g. 50%) and
  when a document is closed. Today it only runs on the save button and after PDF import.
- [x] **P3-10** Store user-inserted images as separate `image` blocks (deduplicated by content
  hash) instead of PNG inside the page record. Today each save of a changed page re-encodes the
  PNG and appends a full copy.
- [x] **P3-11** Write `docs/bnf-format.md` describing format v2.

**Phase 3 notes (done):**
- `lib/core/bnf/bnf_repository.dart`: pure-Dart `BnfRepository` (one per open file) with
  `create/open/readPages/readImage/write/compact/reclaimableBytes/close`. It works on bytes only;
  `lib/features/editor/data/document_file.dart` converts models (`PageModel.encode/decode`,
  `ImageModel.encode/decode`). All operations on one file run one after another (internal lock).
  Format details in `docs/bnf-format.md`. v1 files show an "could not open note" dialog
  (`BnfFormatException`); old test notes on devices have to be re-created / re-imported.
- `DocumentsNotifier`: `_repositories[docID]`, `loadPages(docID, ids)`, `saveDoc` chains saves per
  document (replaces `_isSaving`/`_saveQueue`; `saveAsBnf` now returns after its write is done, so
  the P1-04 note about the back button is resolved). New `closeDoc(docID)` = save + compact if it
  frees ≥10% + close + clear; used by the back button and PDF import. `compactDoc` is gone.
  `DocumentModel.toBytes/fromBytes/fromBytesToJson` (v1) removed; `toMetadata()` added.
- Metadata-only changes (page order, deleted pages) are now saved; before, a save without a
  changed page wrote nothing.
- P3-08/P3-09: compaction while open (after a save, ≥50% and ≥256 KiB garbage) keeps every
  indexed page, because undo may still need deleted pages. Dropping unreferenced pages/images
  only happens in `closeDoc`. There is no renderer to notify yet; offsets stay inside the
  repository, so R1 must read blocks through it.
- P3-10: page blocks start with the list of image block IDs they use, so compaction finds unused
  images without decoding pages. Image block ID = 53-bit FNV-1a of the encoded bytes. `ImageModel`
  keeps the encoded bytes (original file bytes for inserted images and PDF pages, otherwise a PNG
  encoded once), so saving no longer re-encodes images.
- P3-01/02/03: `test/bnf_repository_test.dart` (18 tests incl. corrupted/truncated files and an
  interrupted save), `test/document_file_test.dart` (models through a real file),
  `test/undo_redo_test.dart` (page add/delete undo/redo, stroke undo/redo, save on close;
  "undo on an unloaded page" is a skipped test for P4-02). The counter test was deleted.
- Tested on the tablet: v1 note shows the error dialog; 369-page PDF import ~24 s, file
  32.0 MB -> 21.9 MB after the close compaction; open ~80 ms; stroke survives close/reopen;
  scrolling through pages without errors.
- Found, not fixed: a PDF import writes metadata + index once per page (quadratic garbage, cleaned
  up by the final compaction). Could batch pages (e.g. save every 20 pages) — moot after R3-04.
  PDF import also keeps every imported page in memory until it finishes (pre-existing).

---

## Phase 4: Immutable models, undo/redo, per-document state

- [x] **P4-01** Make `DocumentModel`, `PageModel`, `Stroke`, `PointModel`, `ImageModel` immutable
  (D1). All fields `final`, lists copied on change, `copyWith` copies every field. Remove all
  in-place mutation in `DocumentsNotifier` (`doc.pages = ...`, `doc.pageList.insert(...)`,
  `doc.commands.removeRange(...)`, `doc.placeholderHeight = ...`, `stroke.width = ...` in
  selection scaling, etc.). Render state (`tiles`, `erasedIDs`) moves out of `PageModel`.
- [x] **P4-02** Rework undo/redo. Known issue: "undo after deleting a page works, redo then breaks
  everything". Causes found:
  - `modifyPages` records `removePageIndexes` as positions in `doc.pages` (the loaded window of
    ~3 pages); undo uses them as positions in the full `pageList`/`pageHeights`
  - `modifyPagesExecute` compares insert positions with `doc.pages.length` instead of `pageList.length`
  - `addCommands` (`documents_notifier.dart:877`) never assigns `state`, works only via mutation
  - undo of a stroke on an unloaded page silently does nothing
  Commands must store page IDs and absolute positions in `pageList`, and work on unloaded pages.
  - [x] partly fixed during Phase 1 testing: the delete button deleted the wrong page (used
    `currentPageIndex` as an index into the loaded window `doc.pages`); `modifyPages` now records
    `pageList` positions; `modifyPagesExecute` inserts into `pageList`/`pageHeights` at the absolute
    position (before, any position beyond the loaded window appended at the end of the document,
    which also affected "add page"). `updateIsolatedPages` wrote a state snapshot back after
    awaiting page loads, reverting undo/redo done meanwhile (page didn't reappear on the second
    undo); it now applies loaded pages to the current state. Undo/redo can't overlap any more.
    Still open: `addCommands` mutation, undo on unloaded pages.
- [ ] **P4-03** Per-document state (D2): one notifier per open document keyed by `docID`
  (e.g. a Riverpod family), plus a small "open documents" provider. All APIs take `docID`.
  Goal: tabs become a UI-only change.
- [ ] **P4-04** Split `documents_notifier.dart`: document state, undo/redo service, lazy loading,
  repository (P3-04). Rendering moves out entirely (Phase 5).
- [x] **P4-05** Unify navigation: GoRouter everywhere or drop it (currently GoRouter for two
  routes, `Navigator.push` elsewhere; `RouteSaver` relies on route names GoRouter may not set).
- [x] **P4-06** Reload the file manager after importing files / PDFs (from TODO.txt).
  (Files import already reloaded; PDF import now does too and shows a progress bar.)

**Phase 4 notes (P4-01, P4-02 done):**
- P4-01: `PointModel`, `Stroke`, `ImageModel`, `PageModel`, `DocumentModel` have only final fields;
  page/document lists are unmodifiable. Strokes are `Stroke.frozen()` (unmodifiable point list)
  when they enter a page; the stroke being drawn keeps a growable list owned by `page_widget`.
  `frozen()` doubles single-point strokes (the tile code used to append to the stroke itself).
  Selection move/rotate/scale, recolor and the laser fade now build new strokes/images.
  `PageModel.setBackgroundStrokesBySpacing` -> `withBackgroundSpacing` (returns a new page).
- Tiles moved out of `PageModel` into `pageTilesProvider` (`lib/features/editor/rendering/page_tiles.dart`,
  keyed by pageID, with a version counter because grids are updated in place). Tiles are dropped
  when a page leaves the loaded window. `erasedIDs` and `PageModel.rect` removed.
- Bugs found on the way: moving/scaling a selected **image** changed the `ImageModel` in the page and
  the undo history in place; `Stroke.copy()/copyWithID()` dropped `strokeType` (dotted strokes became
  solid when selected); `editor_setup_notifier.setDefaultPage` changed the shared default page.
- Removed dead notifier methods: `setPageHeight`, `addPageExecute`, `addPagesWithID`, `setPage`,
  `setAllPages`, `setNewImage`; `EmptyCommand`.
- P4-02: `addCommands` is immutable (drops undone commands, caps at `maxAmountCommands`).
  `modifyElements`/`modifyElementsExecute` work on pages outside the loaded window (read from the
  file, changed, saved back; a page that is still loading is awaited first). The change is
  idempotent (remove by ID, added elements replace same IDs), so it is also applied to the window if
  the page got loaded meanwhile. Deleting a page that is not loaded reads it from the file so undo
  can restore it. Undo/redo no longer stop at "page not loaded".
- Tests: 30 (undo on an unloaded page, deleting an unloaded page, selection move + undo/redo keeps
  `strokeType`, history cap, model immutability, single-point strokes). Tested on the tablet:
  draw, dot, lasso + move + undo/redo, eraser, shape, line.
- P4-05: GoRouter removed; plain `Navigator` everywhere, `MaterialApp(home: FileManager())`.
  GoRouter only existed to reopen the Settings page after `RestartWidget.restartApp`, which the
  design settings called after every colour change. The restart was needed because
  `design_settings.dart` (and `document_settings.dart`) declared their **own** `settingsProvider`,
  shadowing the global one, so `MaterialApp` never saw the change until a restart reloaded
  `config.json`. Fixed: duplicates removed, colour setters also update the state, theme changes
  apply live. Removed `RestartWidget`, `RouteSaver`/`app_router.dart` and the `lastRoute` pref; the
  app always starts in the file manager. Side effect: open documents no longer get thrown away by a
  theme change.
- Still open (not command-based): the page setup menu (`setAllPageColors`, `setAllBackgroundStrokesExecute`,
  `setAllHeights/Widths`) only changes loaded pages and isn't undoable.

---

## Phase 5: Rust renderer

Goal: fix the current renderer's problems:
1. rendering a page via isolates is slow (isolate spawned per page, all strokes copied,
   rasterization still sequential on the UI thread)
2. the switch from the live (vector) stroke to the rasterized tile is visible
3. anti-aliasing is bad (fixed scale 20 resampled by the zoom transform, tiles not pixel-aligned,
   strokes drawn as overlapping segments)
4. correctness depends on workarounds around Flutter's async timing
   (`addPostFrameCallback` hacks, "is this page still there?" checks)

### Design

- **Data flow (D4):** Dart sends deltas to Rust: `open_page`, `close_page`, `add_strokes`,
  `remove_strokes`, `set_background`, `set_viewport(page, zoom, visible rect, devicePixelRatio)`.
  Rust keeps a per-page mirror of the geometry.
- **Rasterization (D6):** `tiny-skia` on a persistent `rayon` thread pool. No isolates in Dart.
- **Tiles:** fixed pixel size (e.g. 256 px), aligned to the device pixel grid, at power-of-two
  zoom levels. During a zoom gesture the nearest level is shown scaled; when the gesture ends the
  visible tiles are re-rendered at the exact zoom × devicePixelRatio.
- **Two layers per tile:** background (page color, PDF, line pattern) and ink (strokes, images).
  Editing strokes only re-renders ink. Background tiles are cached longer (PDF rendering is slow).
- **Versioned tile events:** every change bumps the version of the affected tiles. Rust emits
  `tile ready (page, layer, level, x, y, version, pixels)`. Dart shows a tile only if its version
  is current and drops stale results. Tile states: missing → placeholder (other zoom level) →
  sharp. An existing image stays until its replacement is ready (no empty frames).
- **Scheduling:** visible tiles first, then neighbours; jobs for tiles that left the viewport are
  cancelled.
- **Memory:** LRU cache with a budget on both sides; `ui.Image`s are disposed on eviction.
- **Pixel transfer (D5):** RGBA buffers → `decodeImageFromPixels`. One `TileLayer` widget per
  page consumes tile events; the rest of the UI is unaware of the async rendering.
- **Live stroke (D7):** drawn by Rust into a separate overlay layer; each pointer move re-renders
  only the dirty region around the newest segment. On pen-up the stroke goes into the ink layer
  and the overlay is cleared. Same code, so pixel-identical.
- **PDF backgrounds (D8):** pdfium via `pdfium-render`, reading the embedded PDF block straight
  from the `.bnf` through a seekable reader (only the needed bytes are read). pdfium is not
  thread-safe: all PDF calls go through one dedicated thread.

### Milestones

- [ ] **R1-01** Define a `PageRenderer` interface in Dart and move the current renderer behind
  it without behavior changes.
- [ ] **R1-02** Set up the Rust crate and `flutter_rust_bridge`; build for Android and Linux first
  (Rust toolchain, Android NDK targets, cargokit or equivalent).
- [ ] **R1-03** Rust: page geometry mirror, tile grid, zoom levels, versioning, scheduler,
  cancellation, LRU cache. Unit tests and benchmarks independent of Flutter
  (render tiles to PNG and compare against reference images).
- [ ] **R1-04** Integrate: `TileLayer` widget, tile events, image disposal.
  Developer-settings switch between old and new renderer.
- [ ] **R1-05** Exact re-render after zoom gestures end.

**Milestone 1 done when:** a finished page renders fast, sharp at every zoom, without visible
seams, and without the async workarounds.

- [ ] **R2-01** Live stroke overlay layer rendered by Rust with dirty-region updates.
- [ ] **R2-02** Pen-up handoff from overlay to ink layer without visible change.
- [ ] **R2-03** Replace `setState`-per-pointer-move in `page_widget.dart`.
- [ ] **R2-04** Measure pen-to-screen latency on an Android device and on Linux. If too high:
  (a) external texture for the overlay layer only, or (b) short stroke prediction from pen
  velocity. Record the result here.

- [ ] **R3-01** Embedded PDF blocks in `.bnf` v2 (`pdf` entry type). Import copies the PDF once;
  pages store a background reference `(pdfBlockId, pageNumber)`. Page background becomes one of:
  none / image / pdf page, plus optional line pattern.
- [ ] **R3-02** Page size from the PDF page's crop box in mm; handle `/Rotate` and crop box offset
  at render time.
- [ ] **R3-03** pdfium rendering into background tiles on a dedicated thread; ship prebuilt pdfium
  binaries per platform (~5-8 MB each).
- [ ] **R3-04** Import becomes instant (only page count and sizes are read). Resolves TODO items
  "import pdf without loading the entire file / progress screen" and "temp pages while loading
  are always A4".
- [ ] **R3-05** Password-protected PDFs (from TODO.txt). Open decision: ask for the password on
  every open, or store the PDF decrypted inside the `.bnf`.
- [ ] **R3-06** Remove `pdfx` (it doesn't support Linux anyway).

- [ ] **R4-01** Hit-testing in Rust for eraser and lasso selection, with a per-page spatial index
  (`rstar`).
- [ ] **R4-02** Improved stroke geometry: input smoothing, proper joins at sharp turns, round caps,
  one filled polygon per stroke (fixes seams with semi-transparent strokes). Lower priority;
  strokes already look acceptable.

- [ ] **R5-01** Build and test on Windows, macOS, iOS. **(low)**
- [ ] **R5-02** Web via WASM (threads need cross-origin isolation headers). **(low)**
- [ ] **R5-03** Delete the old Dart renderer (`tile.dart`, `initialize_tiles.dart`,
  isolate code in `documents_notifier.dart`, `draw_strokes.dart`) once the Rust renderer matches it.

### Stopgap before Phase 5

- [ ] **R0-01** Dispose old `ui.Image`s and `Picture`s in `Tile` (`tile2.dart:93` is commented
  out) to reduce the GPU memory leak. Do not rework the isolate pool; it gets replaced.

### Later / optional

- Lossless PDF export: copy the original PDF pages and draw strokes on top as vectors.
- Text search and selection in PDFs via pdfium's text API.
- Move `.bnf` reading/writing into Rust (Rust already holds page data). Decide after Milestone 1.
- GPU rendering (`vello`/`wgpu` into a Flutter texture), only if CPU rendering turns out too slow.

---

## Phase 6: Project and platform

- [ ] **P6-01** One settings store. Today settings are split between SharedPreferences and JSON
  under `homeDirectory/config/` (`settings_notifier.dart:24`); changing the home directory loses
  the settings. Store settings in the app support directory, independent of the notes folder.
  Avoid concurrent read-modify-write of the config file.
- [ ] **P6-02** Review the forked Flutter widgets (`custom_gesture_detector.dart`,
  `custom_interactive_viewer.dart`) against upstream; document what was changed and reduce to a
  small subclass/wrapper where possible. The gesture detector redefines `RawGestureDetector` and
  `GestureRecognizerFactory` with the same names as Flutter's.
- [ ] **P6-03** Android: `MANAGE_EXTERNAL_STORAGE` will likely be rejected by the Play Store;
  switch to scoped storage / SAF where possible. **(high)**
  - Export (`exportFilesWithPicker` in `file_manager_screen.dart`) copies with `dart:io` to the
    path from `FilePicker.getDirectoryPath` and fails with `PathAccessException: Operation not
    permitted` unless "All files access" is granted (found on Android 16). Write through the picked
    folder's `content://` tree URI (`FilePicker.pickDirectory`) instead; needs a SAF plugin to
    create files/folders in a tree URI. Removes the deprecated `getDirectoryPath` (see P2-01 notes).
  - Check file import and the notes folder (`homeDirectory`) for the same problem.
  - Until then: when export fails for lack of permission, explain it and offer to open the
    "All files access" settings page instead of showing the raw error.
- [ ] **P6-04** Android release signing (release builds currently use debug keys).
- [ ] **P6-05** CI (GitHub Actions): `flutter analyze`, `flutter test`, `cargo test`,
  Android + Linux builds.
- [ ] **P6-06** README: project status (early), tested platforms, build instructions incl. Rust.
