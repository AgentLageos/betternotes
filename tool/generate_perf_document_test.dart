// Generates a .bnf document with many handwriting-like strokes for performance tests (R12-01).
//
// Not part of the normal test run (lives in tool/). Run with:
//   flutter test tool/generate_perf_document_test.dart
// Environment variables (all optional):
//   BN_OUT      output path            (default: build/perf_test.bnf)
//   BN_PAGES    number of pages        (default: 5)
//   BN_STROKES  strokes per page       (default: 3000)
// The strokes follow the renderer benchmarks (docs/renderer-design.md §5): lines of small curvy
// strokes with pressure, 20-60 points each, deterministic. A few strokes are blue or red (separate
// draw calls) and some pages carry rectangles drawn as shapes (not smoothed).
import 'dart:io';
import 'dart:math';

import 'package:betternotes/features/editor/data/document_file.dart';
import 'package:betternotes/features/editor/models/page/document_model.dart';
import 'package:betternotes/features/editor/models/page/page_model.dart';
import 'package:betternotes/features/editor/models/page/point.dart';
import 'package:betternotes/features/editor/models/page/stroke.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const pageW = 210.0, pageH = 297.0;

List<Stroke> handwriting(int count, Random rnd) {
  final strokes = <Stroke>[];
  const left = 15.0, right = 195.0, top = 20.0, bottom = 285.0, lineGap = 8.0;
  double x = left, lineY = top, pass = 0;
  while (strokes.length < count) {
    final n = 20 + rnd.nextInt(41);
    final points = <PointModel>[];
    double px = x, py = lineY + pass + (rnd.nextDouble() - 0.5) * 2;
    double heading = rnd.nextDouble() * 2 * pi, turn = 0;
    final baseW = 0.35 + rnd.nextDouble() * 0.25;
    double minX = px, maxX = px;
    for (int i = 0; i < n; i++) {
      final t = i / (n - 1);
      final pressure = (0.35 + 0.65 * sqrt(sin(pi * t)) + (rnd.nextDouble() - 0.5) * 0.1).clamp(0.2, 1.1);
      points.add(PointModel(pos: Offset(px, py), width: baseW * pressure));
      turn = (turn + (rnd.nextDouble() - 0.5) * 0.35).clamp(-0.5, 0.5);
      heading += turn;
      final dy = py - (lineY + pass);
      if (dy.abs() > 2.5) heading = atan2(-dy, 0.4) + (rnd.nextDouble() - 0.5) * 0.5;
      final step = 0.25 + rnd.nextDouble() * 0.15;
      px += cos(heading) * step;
      py += sin(heading) * step;
      minX = min(minX, px);
      maxX = max(maxX, px);
    }
    final r = rnd.nextDouble();
    final color = r < 0.1 ? const Color(0xFF1565C0) : (r < 0.15 ? const Color(0xFFC62828) : const Color(0xFF000000));
    strokes.add(Stroke(color: color, width: -1, points: points));
    x += (maxX - minX) * 0.8 + 0.5 + rnd.nextDouble() * 1.5;
    if (rnd.nextDouble() < 0.12) x += 3; // word gap
    if (x > right) {
      x = left;
      lineY += lineGap;
      if (lineY > bottom) {
        lineY = top;
        pass += 2.7;
      }
    }
  }
  return strokes;
}

Stroke rectangle(double x, double y, double w, double h) {
  final c = [Offset(x, y), Offset(x + w, y), Offset(x + w, y + h), Offset(x, y + h), Offset(x, y)];
  return Stroke(
    color: const Color(0xFF2E7D32),
    width: -1,
    kind: StrokeKind.shape,
    points: [for (final o in c) PointModel(pos: o, width: 0.6)],
  );
}

void main() {
  test('generate performance test document', () async {
    final env = Platform.environment;
    final out = env['BN_OUT'] ?? 'build/perf_test.bnf';
    final pageCount = int.parse(env['BN_PAGES'] ?? '5');
    final perPage = int.parse(env['BN_STROKES'] ?? '3000');

    final pages = <PageModel>[];
    for (int i = 0; i < pageCount; i++) {
      final rnd = Random(1000 + i);
      final strokes = handwriting(perPage, rnd);
      if (i.isOdd) {
        strokes.addAll([for (int k = 0; k < 5; k++) rectangle(20 + k * 35, 250, 25, 15)]);
      }
      pages.add(PageModel(pageWidth: pageW, pageHeight: pageH, strokes: strokes)
          .withBackgroundSpacing([8], [], const Color(0xFFB0BEC5), 0.15));
    }
    final doc = DocumentModel(
      pages: pages,
      created: DateTime(2026, 11, 26),
      author: 'generator',
      title: 'Performance test',
      pageList: [for (final p in pages) p.pageID],
      pageHeights: [for (final p in pages) p.pageHeight],
    );
    final file = File(out);
    if (file.existsSync()) file.deleteSync();
    file.parent.createSync(recursive: true);
    await (await createDocumentFile(out, doc)).close();
    int points = 0;
    for (final p in pages) {
      for (final s in p.strokes) {
        points += s.points.length;
      }
    }
    print('wrote $out: $pageCount pages, ${pages.fold<int>(0, (a, p) => a + p.strokes.length)} strokes, '
        '$points points, ${file.lengthSync()} bytes');
  });
}
