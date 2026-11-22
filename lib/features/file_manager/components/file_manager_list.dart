import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:betternotes/features/editor/models/page/image_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;


import 'package:betternotes/features/editor/editor_screen.dart';

import '../../../core/providers/global_providers.dart';
import '../../editor/models/page/document_model.dart';
import '../../editor/models/page/page_model.dart';
import '../../../l10n/app_localizations.dart';

import 'package:pdfx/pdfx.dart';

class FileManagerList extends ConsumerWidget implements PreferredSizeWidget {

  /// True while a PDF import is running (see the PDF branch in build).
  static bool _importRunning = false;


  final VoidCallback onCancelSelection;
  final VoidCallback onDeleteSelected;
  final Function(Directory)? onLoadDir;
  final Function(FileSystemEntity)? onToggleSelection;

  final int mode;
  final List<FileSystemEntity> files;
  final Set<FileSystemEntity> selectedFiles;

  final Directory currentDir;

  final height1 = 40.0;      //height of the upper container

  const FileManagerList({super.key,
    required this.onCancelSelection,
    required this.onToggleSelection,
    required this.files,
    required this.mode,
    required this.selectedFiles,
    required this.onDeleteSelected,
    required this.onLoadDir,
    required this.currentDir,

  });


  @override
  Widget build(BuildContext context, WidgetRef ref) {    return ListView.builder(

      itemCount: files.length,
      itemBuilder: (context, index) {
        final f = files[index];
        final isDir = FileSystemEntity.isDirectorySync(f.path);
        final isSelected = selectedFiles.contains(f);

        return ListTile(
          leading: Icon(
            isDir ? Icons.folder : Icons.insert_drive_file,
          ),
          title: Text(
            p.basename(f.path),
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          tileColor: isSelected ? Theme.of(context).colorScheme.primaryContainer.withAlpha(128) : null,

          onLongPress: () {                                                     //when user long presses on content, the selection mode is enabled
            if (files.isNotEmpty) {onToggleSelection?.call(f);}                 //has to be in if to make sure its not null
          },
          onTap: () async {
            if (mode==1) {
              if (files.isNotEmpty) {onToggleSelection?.call(f);}                 //has to be in if to make sure its not null
            } else if (isDir) {
              onLoadDir?.call(Directory(f.path));
            } else if (f.path.endsWith('.bnf') || f.path.endsWith('.bnf2')) {
              final stringFile = f.path;

              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoadingPage()),);

              final docID = await ref.read(documentsProvider.notifier).loadDoc(stringFile);
              if (docID != null) {
                unawaited(ref.read(documentsProvider.notifier).updateIsolatedPages(docID));    //pages load while the editor opens
              }

              if (!context.mounted) return;
              if (docID == null) {
                Navigator.pop(context);         //close the loading page, the file is gone
                return;
              }
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => Editor()),
              );

            } else if (f.path.toLowerCase().endsWith('.pdf')) {

              final shouldImport = await _showImportPdfDialog(context);

              if (!shouldImport) {
                return;
              }

              print("HIIII");

              // Only one import at a time: the import uses the editor's document slot, so a second
              // import (or opening a note) while one is running would replace its document.
              if (_importRunning || !context.mounted) return;
              _importRunning = true;

              // (pages done, total pages); null until the PDF is opened
              final progress = ValueNotifier<(int, int)?>(null);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LoadingPage(blockBack: true, progress: progress)),
              );

              try {
                await _importPdf(f.path, ref, progress);
                if (context.mounted) Navigator.pop(context);      //close the loading page
                onLoadDir?.call(currentDir);                       //show the new note
              } catch (e) {
                print("file_manager_list: importPdf failed: $e");
                if (context.mounted) {
                  Navigator.pop(context);
                  await _showImportErrorDialog(context, e);
                }
              } finally {
                _importRunning = false;
                progress.dispose();
              }


            }

          },
        );
      },
    );
  }

  Future<bool> _showImportPdfDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(

          title: Text(AppLocalizations.of(context)!.import_pdf_title),
          content: Text(AppLocalizations.of(context)!.import_pdf_question),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.import_action),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }


  Future<void> _showImportErrorDialog(
      BuildContext context,
      Object error,
      ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.import_failed),
          content: Text(AppLocalizations.of(context)!.import_pdf_failed(error.toString())),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.ok),
            ),
          ],
        );
      },
    );
  }




  Future<void> _importPdf(String path, WidgetRef ref, ValueNotifier<(int, int)?> progress) async {

    final newPath = await _freeBnfPath(path);

    final document = await PdfDocument.openFile(path);

    print('Page count: ${document.pagesCount}');

    if (document.pagesCount == 0) return;

    final file = File(newPath);
    final defaultPage = ref.read(editorSetupProvider)[editorIndex].defaultPage;
    DocumentModel newDoc = DocumentModel(pages: [], defaultPage: defaultPage, author: 'name', title: 'title', created: DateTime.now(), pageHeights: [], pageList: []);
    final bytes = await newDoc.toBytes();
    await file.writeAsBytes(bytes, flush: true,);


    final docID = await ref.read(documentsProvider.notifier).loadDoc(newPath);
    if (docID == null) {
      await document.close();
      return;
    }

    progress.value = (0, document.pagesCount);

    for (int i = 1; i <= document.pagesCount; i++) {
      final page = await document.getPage(i);

      print('Page $i');
      print('Width: ${page.width}');
      print('Height: ${page.height}');

      // PDF page sizes are in points (1/72 inch); page units are millimetres.
      final height = page.height * 25.4 / 72;
      final width = page.width * 25.4 / 72;

      PageModel newPage = PageModel(pageHeight: height, pageWidth: width);



      final image = await page.render(
        width: page.width*2,          //2 px per point (same resolution as before)
        height: page.height*2,
      );
      if (image != null) {
        final Uint8List bytes = image.bytes;

        final ui.Image uiImage = await bytesToUiImage(bytes);

        final background = ImageModel(height: height, width: width, position: Offset(0,0), rotation: 0, image: uiImage);
        print("file_manager_list: importpdf: $uiImage");
        newPage = newPage.copyWith(backgroundImage: background);

        print("file_manager_list: importpdf: ${newDoc.pageHeights.length}");



        final document = ref.read(documentsProvider).where((d) => d.docID == docID).firstOrNull;
        if (document == null) {
          throw StateError('The document was closed during the import, $newPath is incomplete.');
        }
        await ref.read(documentsProvider.notifier).modifyPages(docID, [newPage], [document.pageList.length], []);
        await ref.read(documentsProvider.notifier).saveDoc(docID, [newPage]);


      }
      await page.close();
      progress.value = (i, document.pagesCount);
    }

    await document.close();


    await ref.read(documentsProvider.notifier).compactDoc(docID);
    ref.read(documentsProvider.notifier).clearDoc(docID);





    return;

  }


  /// Path for the note created from the PDF at [pdfPath]: same folder and name with a `.bnf`
  /// extension. If that file exists, `name (1).bnf`, `name (2).bnf`, ... is used, so neither the
  /// PDF nor an existing note is overwritten.
  Future<String> _freeBnfPath(String pdfPath) async {
    final dir = p.dirname(pdfPath);
    final name = p.basenameWithoutExtension(pdfPath);
    String candidate = p.join(dir, '$name.bnf');
    for (int i = 1; await FileSystemEntity.type(candidate) != FileSystemEntityType.notFound; i++) {
      candidate = p.join(dir, '$name ($i).bnf');
    }
    return candidate;
  }


  Future<ui.Image> bytesToUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    return frame.image;
  }









  @override
  Size get preferredSize => Size.fromHeight(height1); // any height
}


class LoadingPage extends StatelessWidget {
  /// If true, the back button/gesture can't close the page (used while an import runs).
  final bool blockBack;

  /// Optional progress as (done, total). Shows a progress bar and "done / total" when set,
  /// otherwise a spinner.
  final ValueListenable<(int, int)?>? progress;

  const LoadingPage({super.key, this.blockBack = false, this.progress});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !blockBack,
      child: Scaffold(
        body: Center(
          child: progress == null
              ? const CircularProgressIndicator()
              : ValueListenableBuilder<(int, int)?>(
                  valueListenable: progress!,
                  builder: (context, value, _) {
                    if (value == null) return const CircularProgressIndicator();
                    final (done, total) = value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LinearProgressIndicator(value: total == 0 ? null : done / total),
                          const SizedBox(height: 12),
                          Text('$done / $total'),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
