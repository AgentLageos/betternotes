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
- **Renderer work follows `docs/renderer-design.md` §4** (all points decided 2026-11-26). Changing
  any of those decisions needs a discussion with the project owner first. Every gate is measured in
  a throwaway benchmark before the matching app code is written. Read that file's "What not to do
  again" first.

---

## Decisions

| # | Decision | Reason |
|---|----------|--------|
| D1 | `DocumentModel`, `PageModel` and friends become immutable (final fields, changes only via `copyWith` producing new objects and new lists). Hand-written, no `freezed`. | In-place mutation is shared between current state, old Riverpod state and undo history; main cause of broken undo/redo. No build step wanted. |
| D2 | Per-document state keyed by `docID` (one notifier per open document). | Makes tabs a UI-only addition later. |
| D3 | **(renderer: all of D3, D5–D8, D11–D14 are open again, see `docs/renderer-design.md` §4)** Renderer is rewritten in Rust (`flutter_rust_bridge`). Tile-based concept stays. | Flutter's async image pipeline and isolates make the current tile renderer slow and workaround-heavy. |
| D4 | Dart owns the page data. Rust holds a render mirror updated via deltas (add/remove strokes etc.). | Keeps document logic and undo in one place (Dart), renderer stays replaceable. |
| D5 | **(replaced 2026-11-26 by D15)** Rust returns RGBA pixel buffers; Dart creates `ui.Image` via `decodeImageFromPixels`. No external textures for now. | Works on all platforms incl. web, no platform glue. With CPU rasterization the GPU upload is needed anyway, so textures would gain little. |
| D6 | **(replaced 2026-11-26 by D15)** Rasterizer: `tiny-skia` (CPU only). | GPU stacks are unreliable, especially on Linux. Tiles parallelize well on CPU. |
| D7 | Rust draws everything, including the stroke currently being drawn. | Same code for live and committed strokes, so no visible switch from vector to raster. Gated by a latency measurement (R2-04). |
| D8 | Imported PDFs are stored as original bytes inside the `.bnf` and rendered on demand by pdfium (`pdfium-render`) in Rust. | Text/vector information preserved, sharp at every zoom, instant import, small saves, lossless PDF export later. pdfium is BSD/Apache (compatible with MIT); MuPDF (AGPL) and Poppler (GPL) are not. |
| D9 | `.bnf` stays an append-only block store with an index, generalized to typed entries (page / pdf / image). | The existing lazy-loading design fits embedded blobs naturally. |
| D10 | Rust code documented at a medium level: the Dart/Rust API is explained, internals get normal comments. | |
| D11 | **(suspended, to be rediscussed)** The whole editor canvas is drawn by Rust, including the stroke being drawn, selections, previews and images. Flutter only draws UI chrome (toolbars, menus, dialogs). Supersedes the staged R1/R2 split. | Wet and dry ink must come from one renderer, or the handoff at pen-up is visible (found in the R1-06 texture spike). See `docs/renderer-design.md`. |
| D12 | **(dropped 2026-11-26: canvas stays inside Flutter, `docs/renderer-design.md` 4.3)** On Android the canvas is a native surface: `SurfaceControl` layers (paper colour layers, dry buffer, front-buffered wet layer), not a Flutter texture. Replaces D5 for Android. | Low-latency ink needs a front buffer outside the app's frame pipeline; layer changes (pen-up handoff, buffer + geometry) are atomic in one transaction. |
| D13 | **(suspended, to be rediscussed)** Canvas input (pen and fingers) goes from the platform straight to Rust; Rust owns zoom/scroll and page layout and reports finished strokes and the current page to Dart. Dart still owns document data and undo (D4). | Pen latency; nothing drawn by Flutter can drift against the canvas. |
| D14 | **(obsolete 2026-11-26 with D12/D15)** Linux shows the Rust canvas through a Flutter texture (no front buffer). | Lower priority platform; latency matters less with mouse/desktop tablets. |
| D15 | Strokes are GPU triangle meshes drawn by Flutter (`Canvas.drawVertices`, current transform each frame); live and finished strokes share mesh code and draw call. Android first; antialiasing via Impeller MSAA. Linux antialiasing deferred. | Benchmark on the Pad 6 passed all gates (no lost frames during 1×↔8× zoom on a 3000-stroke page, smooth edges, no flicker after drawing). See `docs/renderer-design.md` 4.4–4.5. |
| D16 | Android first for the renderer; Linux must keep working but may lag behind (e.g. jagged edges). | Decided with the project owner 2026-11-26. |

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
- [x] **P4-03** Per-document state (D2): one notifier per open document keyed by `docID`
  (e.g. a Riverpod family), plus a small "open documents" provider. All APIs take `docID`.
  Goal: tabs become a UI-only change.
- [x] **P4-04** Split `documents_notifier.dart`: document state, undo/redo service, lazy loading,
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
- P4-03/P4-04: `documents_notifier.dart` (single `List<DocumentModel>` state) replaced by:
  - `providers/document_notifier.dart`: `documentProvider(docID)` (`NotifierProvider.autoDispose.family`),
    one `DocumentNotifier` per open document: element/page changes, undo/redo, lazy-loading window,
    saving. Methods no longer take a docID; async methods check `ref.mounted` after awaits.
  - `providers/open_documents_notifier.dart`: `openDocumentsProvider` (open/close, keeps each document's
    provider alive while open) and `activeDocumentProvider` (document shown in the editor). Tabs only
    need UI on top of these. Both are re-exported from `global_providers.dart`.
  - `data/document_store.dart`: the file behind a document (page loading, chained saves, close with
    compaction).
  - `models/commands/undo_history.dart`: pure push/cap logic.
  - `rendering/tile_renderer.dart`: the isolate pool (one for all documents, returns finished grids).
    Tiles in `pageTilesProvider` are keyed by `(docID, pageID)`.
  Editor widgets get the docID passed down (`DocumentWidget`, `PageWidget`, `EditorTopBar`,
  `EditorTopBarPanel`, `PageSetupMenu`) instead of a hard-coded `docIndex = 0`.
- Bugs found on the way (window index vs. page list position): the lasso read `pages[pageIndex]`
  with a page-list position (wrong page or RangeError from the 2nd page on); the page setup menu and
  the editor's zoom read `pages[currentPageIndex]` the same way. Now looked up by ID
  (`DocumentModel.currentPage`, `loadedPage`). "Apply to this page" in page setup only applied the
  width; now width and height (`setPageSize`), and page heights stay in sync with `pageHeights`.
- Tested on the tablet: open, draw/lasso/move/undo on page 6, close + reopen, PDF import.
- Still open (not command-based): the page setup menu (`setAllPageColors`, `setAllBackgroundStrokesExecute`,
  `setAllHeights/Widths`) only changes loaded pages and isn't undoable.

---

## Phase 5: Renderer (GPU meshes)

> **Rewritten 2026-11-26** after all points in `docs/renderer-design.md` §4 were decided (D15, D16).
> The design, the benchmark results and the reasons are in that file; read it (and its "What not to
> do again") before working on this phase. The old tile plan (R1-05, R2-xx, R6-xx) is dropped; the
> texture and native-canvas spike code is archived on the local branch `spike/r1-06`.

Goal (unchanged): fix the old renderer's problems: slow page rendering, the visible switch from the
live stroke to the finished stroke, bad anti-aliasing, and correctness that depends on workarounds
around Flutter's async timing.

### Design (summary, details in `docs/renderer-design.md` §4)

- **Strokes are GPU triangle meshes** drawn by Flutter with `Canvas.drawVertices` and the current
  transform every frame (D15). Sharp at every zoom; no tiles, zoom levels or async frames for ink.
  Antialiasing on Android by Impeller's MSAA (plain meshes, no vertex colours, `srcOver`).
- **Canvas inside Flutter**, no native surface. Zoom and scroll stay with `CustomInteractiveViewer`
  (0.2–8); each page paints its meshes in its own widget.
- **Geometry in Rust:** Catmull-Rom smoothing, round joins and caps, dotted strokes, packed into
  chunks (≤ 65k vertices, possibly smaller for cheap eraser updates). Line patterns use the same
  code in a background layer.
- **Data (D4):** Dart owns document, undo and saving; Rust mirrors pages through the existing change
  API and returns meshes (only affected chunks after a change, new strokes in a "recent" chunk).
- **Live stroke:** Rust returns the live mesh per pen event; at pen-up it moves into the page
  unchanged, so pen-up can't change anything. Own motion prediction (about one frame ahead,
  setting to turn it off), never stored.
- **Tools:** everything that is or becomes ink uses meshes; UI markers (eraser cursor, lasso outline,
  handles) may stay Flutter-drawn. Hit testing in Rust with a spatial index, swept eraser, one
  bridge call per eraser event.
- **PDFs (D8):** pdfium in Rust; a base image per page that is never removed, sharper tiles
  (about 1024 px) for zoomed-in areas on top. Ink stays independent.
- **Rollout:** behind a developer switch until every tool works; Android first (D16), Linux built and
  run at every step; old renderers deleted only when all platforms run the new one.

### Done before the rewrite (Rust tile renderer, removed in R12-02 on 2026-11-26)

- [x] **R0-01** Dispose old `ui.Image`s and `Picture`s in `Tile` (GPU memory leak stopgap).
- [x] **R1-01** `PageRenderer` interface in Dart; old renderer moved behind it.
- [x] **R1-02** Rust crate and `flutter_rust_bridge`, building for Android and Linux.
- [x] **R1-03** Rust page mirror, tile grid, versioning, scheduler, cache, tests.
- [x] **R1-04** Rust tile renderer in the app behind **Settings → Developer → Rust renderer**.
- [-] **R1-05** Exact re-render after zoom (dropped: meshes are always exact).
- [-] **R1-06** Rust tile renderer slow on the tablet (resolved by the redesign: tiles handed to
  Flutter as ~530 images per page were the bottleneck; two spikes failed; see the design doc).
- [-] **R2-01..R2-04** Live stroke overlay / handoff / latency (replaced by R9-03..R9-05).
- [-] **R6-01..R6-03** Native Rust canvas (dropped with D12).
- [-] **R4-01** merged into R10-02; **R4-02** merged into R8-01.

### M1: Measurements (throwaway benchmarks outside the app, gates fixed before running)

- [x] **R7-01** G5: pinch zoom 0.2×↔1× over a document of dense pages on the tablet. Gate: no lost
  frames. If it fails: simplified meshes for small zoom (switched below a pixel), no raster caches.
- [x] **R7-02** G1 again with denser meshes (smoothing + round joins). Gate: no lost frames.
- [x] **R7-03** Bridge cost per pen event (Dart → Rust → live mesh). Gate: fits comfortably in a
  frame at 240 events/s.
- [x] **R7-04** Page-load mesh building time, Dart vs. Rust (number to decide by).
- [x] **R7-05** Eraser call (hit test + hide + chunk re-send) on a dense page. Gate: < 1 ms on the tablet.

**M1 results (2026-11-26, details in `docs/renderer-design.md` §5):** all pass, with these
additions to the plan: R7-01 needs detail levels when zoomed out; R7-02 smoothed geometry plus
**detail levels by zoom** (six levels, 0.4 px tolerance each; switches not visible); R7-03 pen event
p99 0.14 ms in Rust; R7-04 Rust builds a page 4–8× faster than Dart, builds must run off the UI
thread; R7-05 passes with **~8k-vertex chunks**.

### M1.5: First version in the app (2026-11-26, project owner: "it should be in the app to test it")

- [x] **R12-01** Vertical slice behind a new developer switch "Mesh renderer" (old renderer stays the
  default): pages draw finished strokes and line patterns as Rust meshes (one detail level, simple
  chunks, pages outside the screen skipped); active strokes (pen, shapes, lines) drawn as Rust meshes
  with the same geometry; pen-up without a visible change; undo/redo/erase/other changes re-send the
  page's meshes. **Known gaps at first:** no detail levels (zooming out over many dense pages may
  stutter), no prediction, eraser/selection previews may not hide strokes while dragging, laser and
  images as today. The remaining M2–M4 items then improve this step by step.

> **State 2026-11-26: important baseline.** First test by the project owner on the tablet: "runs
> remarkably well". Keep this state working; every later change is measured against it.
> Code: `rust/src/engine/mesh_page.rs` (page mirror, chunks by colour, ≤ 8k vertices),
> `rust/src/api/mesh.rs` (bridge), `lib/features/editor/rendering/mesh_page_renderer.dart`,
> `DrawerWidget` paints the meshes; switch **Settings → Developer → Mesh renderer**.
> `.bnf` files from before commit `5f270c8` no longer open (stroke kind byte; intended, no migration).
> Test document: `flutter test tool/generate_perf_document_test.dart` writes `build/perf_test.bnf`
> (5 pages × 3000 strokes; `BN_PAGES`, `BN_STROKES`, `BN_OUT` change it); import it in the app's file
> manager (e.g. after `adb push build/perf_test.bnf /sdcard/Download/`).

- [ ] **R12-02** **Next: clean up, document, remove leftovers from the testing phase** before new
  features. Candidates (check each before deleting):
  - [x] Rust tile renderer removed (2026-11-26, decided by the project owner): `engine/{page,tiles,
    raster,cache,renderer}.rs`, `api/renderer.rs`, its tests and reference images,
    `examples/bench.rs`, and the Dart side (`rust_page_renderer.dart`, `rust_tile_store.dart`,
    `viewport_tracker.dart`, the "Rust renderer" switch). §4.13 still holds for the **Dart**
    renderer (fallback on the other platforms). `tiny-skia` is only a dev dependency now (for
    `examples/mesh_preview.rs`). The R0/R1 notes below describe the removed code (history).
  - `DrawerWidget`/`ActivePainter`: tile and erase-preview code paths that only the old renderers
    use; comments that still describe tiles.
  - Design doc and roadmap: mark what is history, describe the mesh renderer as it is now.

### M2: Rust geometry

- [x] **R8-01** Stroke geometry in Rust (`rust/src/engine/mesh.rs`, tests, preview
  `cargo run --release --example mesh_preview -- out.png`). Smoothing only for freehand strokes:
  `Stroke.kind` (`StrokeKind.freehand` / `shape`, saved in the `.bnf`; shape and line tools and
  line patterns set `shape`); it reaches Rust with the mesh API (R9-02). Dotted lines: the line
  tool's dotted branch is empty today, so there is nothing to render yet.
  Original scope: Catmull-Rom smoothing (fine enough for max zoom), round
  joins and caps, per-point width, dotted strokes; must not rule out a later highlighter technique.
- [ ] **R8-03** Detail levels by zoom (R7-02): per page and level, tolerance 0.4 device px at the
  level's smallest zoom; coarse levels with point reduction and fewer joins; built lazily off the UI
  thread (current zoom first); a missing level is covered by a finer one.
- [ ] **R8-02** Chunk packing per page (~8k vertices, R7-05), "recent" chunk, re-send only affected
  chunks; background layer for line patterns. Tests independent of Flutter.

### M3: Mesh renderer in the app (developer switch)

- [ ] **R9-01** Mesh renderer behind a new developer switch: pages draw page colour, background
  meshes, images and ink meshes in their own widgets under `CustomInteractiveViewer`.
  Pages outside the screen must not draw (today's `Column` paints every loaded page; R7-01).
- [ ] **R9-02** API: tile parts replaced by mesh calls (open/close/change pages return chunks).
- [ ] **R9-03** Live stroke: begin / add points / end; only the canvas repaints (no `setState` per
  pointer move).
- [ ] **R9-04** Pen-up: live mesh moved into the page unchanged; Dart stores the same points. Check
  with a recording that nothing changes.
- [ ] **R9-05** Motion prediction (own, about one frame ahead) with a setting to turn it off.
  In-app pen-event-to-frame timing as regression check against the Dart renderer.
- [ ] **R9-06** Undo/redo through the change API; recently seen pages keep their meshes (memory limit).

### M4: Tools on the mesh renderer (one item each; the switch can't become default before all are done)

- [ ] **R10-01** Shapes and lines (live mesh while dragging, moved in at release).
- [ ] **R10-02** Eraser: spatial index per page, swept hit test on the drawn geometry, one bridge
  call per event (hit + hide + chunk re-send + IDs for undo). Report hit positions too (partial
  eraser later).
- [ ] **R10-03** Lasso/rect selection in Rust (both rules), selected group drawn with an extra
  transform while moving, rebuilt on drop; selection highlight mesh.
- [ ] **R10-04** Laser (meshes with fading opacity; check overlap darkening visually).
- [ ] **R10-05** Images in the right layer order; eraser cursor and lasso outline as Flutter UI.

### M5: Default on Android and Linux

- [ ] **R11-01** Full check on the tablet and on Linux (all tools, no-go list from the design doc
  §4.1), then the mesh renderer becomes the default there. Old renderers stay for other platforms.

### M6: PDFs (right after the stroke renderer)

- [ ] **R3-01** Embedded PDF blocks in `.bnf` v2 (`pdf` entry type). Import copies the PDF once;
  pages store a background reference `(pdfBlockId, pageNumber)`. Page background becomes one of:
  none / image / pdf page, plus optional line pattern.
- [ ] **R3-02** Page size from the PDF page's crop box in mm; handle `/Rotate` and crop box offset.
- [ ] **R3-03** pdfium in Rust on a dedicated thread: base image per page (never removed) plus
  sharper tiles (~1024 px) for zoomed-in areas. Ship prebuilt pdfium binaries per platform.
  Gate first (real PDF on the tablet): no blank areas over seen pages, sharp shortly after zoom
  ends, no lost frames while pinching.
- [ ] **R3-04** Import becomes instant (only page count and sizes are read). Resolves TODO items
  "import pdf without loading the entire file / progress screen" and "temp pages while loading
  are always A4".
- [ ] **R3-05** Password-protected PDFs (from TODO.txt). Open decision: ask for the password on
  every open, or store the PDF decrypted inside the `.bnf`.
- [ ] **R3-06** Remove `pdfx` (it doesn't support Linux anyway).

### M7: Other platforms, then remove the old renderers

- [ ] **R5-01** Build and test on Windows, macOS, iOS, incl. whether mesh edges are smoothed. **(low)**
- [ ] **R5-02** Web via WASM (threads need cross-origin isolation headers). **(low)**
- [ ] **R5-03** Delete the old Dart renderer (`tile.dart`, `initialize_tiles.dart`,
  `rendering/tile_renderer.dart`, `rendering/page_tiles.dart`, `draw_strokes.dart`), **only when
  every platform runs the mesh renderer** (the Rust tile renderer is already gone, R12-02).

### Later / optional

- Linux edge smoothing (options in `docs/renderer-design.md` §4.5: textured AA on Linux only, a
  cheaper textured AA, or MSAA in Flutter's Linux embedder).
- Highlighter (choose and measure the transparency technique first, design doc §4.6).
- Partial eraser (cut strokes where the eraser passes).
- Lossless PDF export: copy the original PDF pages and draw strokes on top as vectors.
- Text search and selection in PDFs via pdfium's text API.
- Move `.bnf` reading/writing into Rust (Rust already holds page data).

### Notes on the done items (tile renderer, R0/R1)

- R0-01: `Tile` disposes the image it replaces and every `Picture` after `toImage`.
  `PageTilesNotifier.set/remove` dispose the images of replaced/dropped grids (`disposeTileGrid`);
  grids finished for pages that were hidden meanwhile are disposed too. Safe because the state
  change rebuilds the painters before the next frame, and recorded pictures keep their own reference.
- R1-01: `rendering/page_renderer.dart` defines `PageRenderer` (`showPage`, `hidePages`,
  `closeDocument`, `updateStrokes`, `updateBackground`, `resizePage`) and `pageRendererProvider`.
  Every call passes the page after the change; the renderer keeps the latest version per page and
  re-renders if it changed during a render (this replaced the `identical(current, page)` check
  against the notifier state). `rendering/dart_page_renderer.dart` wraps the old code
  (`TileRenderer` pool, `pageTilesProvider`). `DocumentNotifier` and `OpenDocumentsNotifier` no
  longer know about tiles. Still reading `pageTilesProvider` directly: `DrawerWidget` (paints the
  tiles, eraser preview uses `Tile.aStrokes`) and `PageWidget` (placeholder until rendered); both
  go behind the `TileLayer` widget in R1-04.
- R1-02: Rust crate `bn_renderer` in `rust/` (API in `rust/src/api/`), cargokit glue in
  `rust_builder/` (a local Flutter plugin, path dependency in `pubspec.yaml`), generated Dart
  bindings in `lib/src/rust/` (`flutter_rust_bridge.yaml`). `main()` calls `RustLib.init()` and prints
  the crate version. For now the API only has `renderer_version()`.
  - Toolchain: rustup in `~/.cargo` (stable), Android targets aarch64/armv7/x86_64/i686,
    `flutter_rust_bridge_codegen` 2.13.0 (must match the `flutter_rust_bridge` versions in
    `pubspec.yaml` and `rust/Cargo.toml`). `cargo` must be on PATH for `flutter build`/`run`
    (also when started from Android Studio). cargokit builds the crate during the normal Flutter build.
  - After changing `rust/src/api/`: `flutter_rust_bridge_codegen generate`. Rust tests: `cd rust && cargo test`.
  - Set up with `flutter_rust_bridge_codegen integrate --no-dart-fix --no-dart-format
    --no-integration-test --rust-crate-name bn_renderer --rust-crate-dir rust`. Without the
    `--no-dart-*` flags it reformats the whole codebase; it also replaces `main.dart` with a demo
    (restored by hand).
  - Verified: Linux debug build runs, Android debug APK (arm64, armv7, x86_64 libs) runs on the tablet.
    Not tried: release builds.
- R1-03: `rust/src/engine/` (no Flutter dependency, not exported to Dart yet):
  - `page.rs`: `PageMirror` per `PageKey (doc, page)`, layers `Background` (page colour + line
    pattern) and `Ink`. Changes are deltas (`add_strokes` replaces same IDs like
    `modifyElementsExecute`, `remove_strokes`, `set_background`, `resize`). Versions: one global
    counter; each change bumps the cells of an 8 mm `VersionGrid` that its area touches. A tile's
    version = max of its cells, so versions are zoom-independent.
  - `tiles.rs`: 256 px tiles; `Scale` = device px per mm (exact f32 as key); levels 2^n px/mm.
  - `raster.rs`: tiny-skia, same stroke look as `draw_strokes.dart` with two fixes: constant-width
    strokes are one path (no darker spots with transparency), and the varying-width outline reaches
    the end points (the Dart outline stopped mid-segment, a visible gap before the end cap).
    Tiles are rendered with **16 px padding** and cropped: tiny-skia anti-aliases clipped paths
    differently, which gave seams (up to 55/255) at tile borders. Output: straight-alpha RGBA.
  - `renderer.rs`: own worker threads (not rayon: the scheduler needs "pick the most important
    wanted tile" with cancellation, simpler with a mutex + condvar). `set_viewport` replaces the
    set of wanted tiles (visible, then a prefetch ring); dropping a tile from it is the
    cancellation. Renders whose page changed meanwhile are dropped and redone. Delivered versions
    are tracked; Dart calls `forget_tiles` when it evicts. Rust-side `LruCache` (64 MB default).
    Events may arrive out of order: the receiver keeps the highest version.
  - Tests (`cd rust && cargo test`): 29 (unit, renderer behaviour incl. cancellation with a
    blocked sink, reference PNGs in `rust/tests/reference/`, seam test tiled vs. one pass).
    Update references with `BN_UPDATE_REFERENCE=1 cargo test --test reference_images`, then look
    at them.
  - Benchmark: `cargo run --release --example bench`; on the tablet:
    `cargo ndk -t arm64-v8a build --release --example bench`, push to `/data/local/tmp`.
    Whole A4 page delivered / update after one new stroke:

    | page, 8 px/mm (140 tiles) | Ryzen 5600X, 8 threads | Tablet (SM8250), 7 threads |
    |---|---|---|
    | sample page | 9.8 ms / 1.1 ms | 32.8 ms / 3.3 ms |
    | dense (1000 strokes × 60 points) | 18.9 ms / 3.3 ms | 60.9 ms / 9.6 ms |

    Single thread on the tablet: 0.35 ms per background tile, 0.6–4 ms per ink tile.
  - Strokes are culled per tile by bounding box only (linear scan); a spatial index comes with R4-01.
  - Not in the renderer yet: images (`ImageModel`, still painted by Flutter), eraser preview, laser.
- R1-04: Rust renderer usable in the app behind **Settings → Developer → Rust renderer**
  (`Settings.rustRenderer`, mirrored into `rustRendererEnabledProvider`; read when a document is
  opened, so switching needs a reopen). Default off.
  - API `rust/src/api/renderer.rs`: one renderer per process; all change calls are `sync` (keeps
    them ordered; async calls run on a thread pool). Tiles come through one stream
    (`rendererTileStream`). `rendererReset()` runs first (hot restart); the stream call is async,
    so tiles finished before it are kept and resent (`forget_all`).
  - **Pixels are premultiplied** (`PixelFormat.rgba8888` is documented as premultiplied); the
    straight-alpha conversion from R1-03 was wrong and is gone (tiny-skia's data is sent as is).
  - `rendering/rust_tile_store.dart`: decodes tiles (`decodeImageFromPixels`), keeps the newest
    version, disposes replaced images, LRU budget 96 MB (tiles painted in the last second are
    kept), evicted tiles reported with `rendererForgetTiles`. `waitFor(pending)` completes when
    given tile versions are shown (500 ms timeout).
  - `rendering/viewport_tracker.dart`: after every frame reads each page's real on-screen
    transform (`getTransformTo(null)`), sends visible rect + scale per page. Scale = next power of
    two ≥ zoom × devicePixelRatio (tiles drawn slightly scaled down; exact scale is R1-05).
  - Painting: no separate `TileLayer` widget; `ActivePainter` (`drawer_widget.dart`) paints the Rust
    background layer, then images, then the ink layer, then live strokes (same order as before).
    Missing tiles are filled with the nearest other scale, clipped per tile (never two scales on
    top of each other). The Rust background layer is transparent; `PageWidget` paints the colour.
  - Hidden strokes: strokes being erased or selected (`erasedStrokes` in `page_widget.dart`) are
    hidden in the Rust ink layer (`rendererSetHidden`), Flutter draws the preview.
  - Pen-up handoff (both renderers): `PageRenderer.updateStrokes` completes when the change is
    visible (Rust: the change calls return the visible ink tiles to wait for). `PageWidget` keeps
    committed strokes in `pendingStrokes` (drawn like active strokes) until then. Replaces the
    one-extra-build workaround in `DrawerWidget`.
  - Fixed on the way: committing a selection didn't rebuild `PageWidget`, so `DrawerWidget` kept
    the old `erasedStrokes` (invisible with the Dart renderer, strokes stayed hidden with Rust).
  - Tested on Linux (Xephyr + xdotool, generated sample document): open, zoom in/out, pen
    stroke (no gap at pen-up in burst screenshots; small anti-aliasing difference between the
    vector preview and the tile, R2-02), eraser with preview, undo, lasso select + commit (5/5
    correct; one earlier run left the selected word hidden and could not be reproduced).
    Moving a selection could not be tested with a mouse (needs stylus). Tablet: see R1-06.
  - Seen with the Dart renderer: after selection commits, a word was drawn as large blobs cut at
    tile borders (the Rust renderer draws the same data correctly). Looks like a bug in the old
    tile code; not investigated (R5-03 removes it).

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
