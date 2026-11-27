# `.bnf` file format, version 2

A `.bnf` file holds one BetterNotes document. It is an **append-only block store**: saving
appends new blocks at the end and then switches a single pointer in the header to them. Old
blocks stay in the file as garbage until the file is compacted.

Code: `lib/core/bnf/bnf_repository.dart` (format), `lib/features/editor/data/document_file.dart`
(models ↔ records), `PageModel.encode/decode`, `ImageModel.encode/decode`.

There is no migration from version 1; version 1 files are rejected.

All integers are **little-endian**. `u8/u32/u64` are unsigned, `f64` is an IEEE 754 double.

## Layout

```
Header (16 bytes)
  0   u8[4]  magic "BNF\0" (42 4E 46 00)
  4   u32    version = 2
  8   u64    rootOffset           file offset of the current root

Blocks (anywhere after the header, never modified once written)
      u64    length               length of data
      u8[]   data

Root (32 bytes, written right after the index of the same save)
  0   u64    metadataOffset       offset of the metadata block (its length field)
  8   u64    metadataLength       length of the metadata data
  16  u64    indexOffset          offset of the index block (its length field)
  24  u64    indexLength          length of the index data
```

All offsets point at a block's `length` field, not at its data. Readers check that the stored
length equals the length given by the root or index.

### Metadata block

UTF-8 JSON object:

| key           | type            | meaning                                                  |
|---------------|-----------------|----------------------------------------------------------|
| `title`       | string          |                                                          |
| `author`      | string          |                                                          |
| `created`     | ISO 8601 string |                                                          |
| `modified`    | ISO 8601 string | set by the repository on every save                      |
| `defaultPage` | object          | `PageModel.toJson()` of the page template                |
| `pageList`    | int[]           | page IDs in document order                               |
| `pageHeights` | double[]        | page heights in mm, same order as `pageList`             |

Page units are millimetres (A4 = 210 × 297).

### Index block

```
u32 count
count × entry (25 bytes):
  0   u8   type        1 = page, 2 = pdf (reserved, R3-01), 3 = image
  1   u64  id          page ID, or content ID for images
  9   u64  offset      offset of the block
  17  u64  length      length of the block data
```

`(type, id)` is unique. The index may contain pages that are no longer in `pageList` (deleted
pages the undo history may still need); they are dropped when the document is closed.

### Page block

```
u32   imageCount
u64   imageIDs[imageCount]     image blocks this page uses (for compaction)
u8[]  page data                (PageModel.encode)
```

Page data:

```
u64  pageID
f64  pageWidth, pageHeight
u32  pageColor (ARGB)
u32  n,  f64[n] verticalSpaces
u32  n,  f64[n] horizontalSpaces
u32  n,  n × (u64 length, stroke)          strokes
u32  n,  n × (u64 length, stroke)          background strokes
u32  n,  n × image placement (56 bytes)    images
u8   hasBackgroundImage (0/1), then one image placement if 1
```

Stroke (`Stroke.toBytes`): see `stroke.dart`.

Image placement (56 bytes):

```
0   f64  width       mm
8   f64  height      mm
16  f64  x           mm
24  f64  y           mm
32  f64  rotation
40  u64  imageID     identity of this placement (for undo, selection)
48  u64  blockID     id of the image block with the picture
```

### Image block

The encoded image exactly as imported (PNG, JPEG, ...), or a PNG if the app encoded it.
The block ID is the 64-bit FNV-1a hash of these bytes, masked to 53 bits. The same picture is
therefore stored only once per file, and an image block is never rewritten once it exists.

## Saving

1. For each page to save, encode it. If the bytes equal the stored block, skip it.
   Image blocks whose ID already exists are skipped.
2. If no page, image or metadata changed, write nothing.
3. Append the new blocks, the metadata block, the index block and the root; flush.
4. Overwrite `rootOffset` in the header; flush.

A crash before step 4 leaves the old root in place: the file opens with its previous content,
and the appended bytes are garbage. Trailing bytes after the last root are allowed.

## Compaction

Writes a new file `<name>.bnf.compact.tmp` containing only the blocks the current root
references, flushes it and renames it over the original (atomic on the same file system). Blocks
are copied in 1 MiB chunks. Block offsets change.

- **While a document is open** (automatic, after a save): runs when garbage is at least 50% of
  the file and at least 256 KiB. All indexed pages are kept.
- **When a document is closed**: pages not in `pageList` and images no remaining page uses are
  dropped. Runs when this frees at least 10% of the file.

## Not yet supported

- `pdf` entries (R3-01): embedded original PDF bytes, rendered by pdfium.
- Web: `getUint64/setUint64` are not supported by dart2js.
