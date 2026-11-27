import 'dart:io';
import 'dart:typed_data';

import 'package:betternotes/core/bnf/bnf_repository.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';

Uint8List bytes(int length, int seed) =>
    Uint8List.fromList([for (var i = 0; i < length; i++) (i * 31 + seed) & 0xFF]);

BnfPageRecord page(int id, {int length = 100, int seed = 0, List<int> images = const []}) =>
    BnfPageRecord(id: id, data: bytes(length, seed), imageIDs: images);

Map<String, dynamic> meta(List<int> pageList) => {'title': 't', 'pageList': pageList};

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bnf_test');
    path = p.join(dir.path, 'doc.bnf');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('create -> open round trip', () async {
    await BnfRepository.create(path,
        metadata: meta([1, 2]),
        pages: [page(1, seed: 1), page(2, seed: 2, images: [9])],
        images: {9: bytes(50, 9)});

    final repo = await BnfRepository.open(path);
    expect(repo.metadata['title'], 't');
    expect(repo.metadata['pageList'], [1, 2]);
    expect(repo.metadata['modified'], isA<String>());
    expect(repo.pageIDs, {1, 2});
    expect(repo.imageIDs, {9});

    final pages = await repo.readPages([1, 2, 3]);
    expect(pages.keys, unorderedEquals([1, 2]));
    expect(pages[1]!.data, bytes(100, 1));
    expect(pages[2]!.imageIDs, [9]);
    expect(await repo.readImage(9), bytes(50, 9));
    expect(await repo.readImage(10), isNull);
    expect(repo.garbageBytes, 0);
  });

  test('create refuses to overwrite unless asked', () async {
    await BnfRepository.create(path, metadata: meta([]));
    expect(() => BnfRepository.create(path, metadata: meta([])), throwsA(isA<FileSystemException>()));
    await BnfRepository.create(path, metadata: meta([5]), overwrite: true);
    expect((await BnfRepository.open(path)).metadata['pageList'], [5]);
  });

  test('append -> reopen sees new and changed pages', () async {
    final repo = await BnfRepository.create(path, metadata: meta([1]), pages: [page(1, seed: 1)]);
    final written = await repo.write(pages: [page(1, seed: 7), page(2, seed: 2)], metadata: meta([1, 2]));
    expect(written, isTrue);
    expect(repo.garbageBytes, greaterThan(0));

    final reopened = await BnfRepository.open(path);
    expect(reopened.metadata['pageList'], [1, 2]);
    expect((await reopened.readPage(1))!.data, bytes(100, 7));
    expect((await reopened.readPage(2))!.data, bytes(100, 2));
    expect(reopened.garbageBytes, repo.garbageBytes);
  });

  test('unchanged pages and metadata write nothing', () async {
    final repo = await BnfRepository.create(path, metadata: meta([1]), pages: [page(1)], images: {3: bytes(10, 3)});
    final length = repo.fileLength;
    expect(await repo.write(pages: [page(1)], images: {3: bytes(10, 3)}, metadata: meta([1])), isFalse);
    expect(await File(path).length(), length);
  });

  test('metadata-only change is written', () async {
    final repo = await BnfRepository.create(path, metadata: meta([1, 2]), pages: [page(1), page(2)]);
    expect(await repo.write(metadata: meta([2, 1])), isTrue);
    expect((await BnfRepository.open(path)).metadata['pageList'], [2, 1]);
  });

  test('concurrent writes are serialized', () async {
    final repo = await BnfRepository.create(path, metadata: meta([]));
    await Future.wait([
      for (var i = 1; i <= 20; i++) repo.write(pages: [page(i, seed: i)], metadata: meta([for (var j = 1; j <= i; j++) j])),
    ]);
    final reopened = await BnfRepository.open(path);
    expect(reopened.pageIDs, {for (var i = 1; i <= 20; i++) i});
    expect((await reopened.readPage(13))!.data, bytes(100, 13));
  });

  test('compaction keeps everything by default and removes garbage', () async {
    final repo = await BnfRepository.create(path, metadata: meta([1, 2]), pages: [page(1), page(2)]);
    for (var i = 0; i < 5; i++) {
      await repo.write(pages: [page(1, seed: i + 10, length: 5000)], metadata: meta([1, 2]));
    }
    await repo.write(metadata: meta([2]));
    expect(repo.garbageBytes, greaterThan(20000));

    await repo.compact();
    expect(repo.garbageBytes, 0);
    expect(await File(path).length(), repo.fileLength);
    expect(File('$path.compact.tmp').existsSync(), isFalse);

    final reopened = await BnfRepository.open(path);
    expect(reopened.garbageBytes, 0);
    expect(reopened.pageIDs, {1, 2});
    expect((await reopened.readPage(1))!.data, bytes(5000, 14));
    expect(reopened.metadata['pageList'], [2]);
  });

  test('compaction with keepPages drops pages and unused images', () async {
    final repo = await BnfRepository.create(path,
        metadata: meta([1, 2]),
        pages: [page(1, images: [7]), page(2, images: [7, 8])],
        images: {7: bytes(10, 7), 8: bytes(3000, 8)});
    await repo.write(metadata: meta([1]));
    await repo.compact(keepPages: {1});

    final reopened = await BnfRepository.open(path);
    expect(reopened.pageIDs, {1});
    expect(reopened.imageIDs, {7});
    expect(await reopened.readImage(7), bytes(10, 7));
  });

  test('large blocks are copied in chunks', () async {
    final big = bytes(3 * 1024 * 1024 + 17, 5);
    final repo = await BnfRepository.create(path, metadata: meta([1]), pages: [page(1)], images: {1: big});
    await repo.write(pages: [page(1, seed: 2)], metadata: meta([1]));
    await repo.compact();
    expect(await (await BnfRepository.open(path)).readImage(1), big);
  });

  test('shouldCompact needs both ratio and minimum size', () async {
    final repo = await BnfRepository.create(path, metadata: meta([1]), pages: [page(1)]);
    await repo.write(pages: [page(1, seed: 1)], metadata: meta([1]));
    expect(repo.garbageBytes, greaterThan(0));
    expect(repo.shouldCompact, isFalse); // tiny file

    final large = BnfRepository.compactMinBytes;
    await repo.write(pages: [page(1, seed: 2, length: large)], metadata: meta([1]));
    await repo.write(pages: [page(1, seed: 3, length: large)], metadata: meta([1]));
    await repo.write(pages: [page(1, seed: 4, length: large)], metadata: meta([1]));
    expect(repo.shouldCompact, isTrue);
  });

  test('reclaimableBytes counts garbage, dropped pages and their images', () async {
    final repo = await BnfRepository.create(path,
        metadata: meta([1, 2]),
        pages: [page(1, images: [7]), page(2, images: [8])],
        images: {7: bytes(10, 7), 8: bytes(3000, 8)});
    expect(await repo.reclaimableBytes({1, 2}), 0);
    final dropped = await repo.reclaimableBytes({1});
    expect(dropped, (8 + 4 + 8 + 100 + 25) + (8 + 3000 + 25));
    final before = repo.fileLength;
    await repo.compact(keepPages: {1});
    expect(before - repo.fileLength, dropped);
  });

  group('corrupted files', () {
    test('not a .bnf file', () async {
      await File(path).writeAsBytes(bytes(100, 1));
      expect(BnfRepository.open(path), throwsA(isA<BnfFormatException>()));
    });

    test('too small', () async {
      await File(path).writeAsBytes([0x42, 0x4E]);
      expect(BnfRepository.open(path), throwsA(isA<BnfFormatException>()));
    });

    test('wrong version', () async {
      await BnfRepository.create(path, metadata: meta([]));
      final raf = await File(path).open(mode: FileMode.append);
      await raf.setPosition(4);
      await raf.writeFrom([1, 0, 0, 0]);
      await raf.close();
      expect(BnfRepository.open(path), throwsA(isA<BnfFormatException>()));
    });

    test('truncated file', () async {
      await BnfRepository.create(path, metadata: meta([1]), pages: [page(1, length: 1000)]);
      final length = await File(path).length();
      final raf = await File(path).open(mode: FileMode.append);
      await raf.truncate(length - 10);
      await raf.close();
      expect(BnfRepository.open(path), throwsA(isA<BnfFormatException>()));
    });

    test('interrupted save leaves the previous version readable', () async {
      final repo = await BnfRepository.create(path, metadata: meta([1]), pages: [page(1, seed: 1)]);
      final before = await File(path).readAsBytes();
      await repo.write(pages: [page(1, seed: 2)], metadata: meta([1]));
      final after = await File(path).readAsBytes();

      // Simulate a crash after the new blocks were appended but before the header was updated:
      // new tail, old header.
      final crashed = Uint8List.fromList(after)..setRange(0, 16, before);
      await File(path).writeAsBytes(crashed);
      final reopened = await BnfRepository.open(path);
      expect((await reopened.readPage(1))!.data, bytes(100, 1));
      expect(reopened.garbageBytes, after.length - before.length);
    });

    test('corrupted block length is detected on read', () async {
      await BnfRepository.create(path, metadata: meta([1]), pages: [page(1)]);
      final data = await File(path).readAsBytes();
      data[16] ^= 0xFF; // length field of the first block (page 1)
      await File(path).writeAsBytes(data);
      final repo = await BnfRepository.open(path);
      expect(repo.readPage(1), throwsA(isA<BnfFormatException>()));
    });
  });

  test('closed repository rejects calls', () async {
    final repo = await BnfRepository.create(path, metadata: meta([]));
    await repo.close();
    expect(() => repo.readPage(1), throwsStateError);
  });
}
