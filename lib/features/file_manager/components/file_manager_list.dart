import 'dart:io';
import 'dart:ui' as ui;
import 'package:betternotes/features/editor/models/page/image_model.dart';
import 'package:betternotes/features/editor/providers/documents_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

//import 'package:betternotes/page_list_screen.dart';                  //no longer exists

import 'package:betternotes/features/editor/editor_screen.dart';

import '../../../core/providers/global_providers.dart';
import '../../editor/models/page/document_model.dart';
import '../../editor/models/page/page_model.dart';
import '../../../l10n/app_localizations.dart';

import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';

class FileManagerList extends ConsumerWidget implements PreferredSizeWidget {


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
        final text = AppLocalizations.of(context)!;
        final f = files[index];
        final isDir = FileSystemEntity.isDirectorySync(f.path);
        final isSelected = selectedFiles.contains(f);

        return ListTile(
          leading: Icon(
            isDir ? Icons.folder : Icons.insert_drive_file,
            //color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurface,
          ),
          title: Text(
            f.path.split('/').last,
            style: TextStyle(
              //color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurface,
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

              //print("file_manager_list: currentDir= ${ref.read(platformProvider).currentDirectory}");
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoadingPage()),);

              await ref.read(documentsProvider.notifier).loadDoc2(stringFile, 0);
              ref.read(documentsProvider.notifier).updateIsolatedPages(0);

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

              /*
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoadingPage(),
                ),
              );

               */

              await _importPdf(f.path, ref);

              /*
              try {
                await _importPdf(f.path, ref);
                //return;
                /*
                if (context.mounted) {
                  Navigator.pop(context);
                }


                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Editor(),
                    ),
                  );
                }

                 */
              } catch (e) {
                if (context.mounted) {
                Navigator.pop(context);
                await _showImportErrorDialog(context, e);
                }
              }

               */


            }

          },
        );
      },
    );
  }

  Future<bool> _showImportPdfDialog(BuildContext context) async {
    final text = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(

          title: const Text('PDF importieren?'),
          content: const Text(
            'Möchtest du diese PDF-Datei importieren?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importieren'),
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
          title: const Text('Import fehlgeschlagen'),
          content: Text(
            'Die PDF konnte nicht importiert werden.\n\n$error',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }




  Future<void> _importPdf(String path, WidgetRef ref) async {

    final newPath = path.replaceFirst('.pdf', '.bnf');

    final document = await PdfDocument.openFile(path);

    print('Anzahl Seiten: ${document.pagesCount}');

    if (document.pagesCount == 0) return;

    final file = File(newPath);
    final defaultPage = ref.read(editorSetupProvider)[editorIndex].defaultPage;
    DocumentModel newDoc = DocumentModel(pages: [], defaultPage: defaultPage, author: 'name', title: 'title', created: DateTime.now(), pageHeights: [], pageList: []);
    final bytes = await newDoc.toBytes();
    await file.writeAsBytes(bytes, flush: true,);

    List<PageModel> pages = [];
    List<double> pageHeights = [];
    List<int> pageIds = [];

    //final docIndex = ref.read(documentsProvider).length;

    final docIndex = 0;

    //print(ref.read(documentsProvider).);

    await ref.read(documentsProvider.notifier).loadDoc2(newPath, docIndex);

    for (int i = 1; i <= document.pagesCount; i++) {
      final page = await document.getPage(i);

      print('Seite $i');
      print('Breite: ${page.width}');
      print('Höhe: ${page.height}');

      final height = page.height/3;
      final width = page.width/3;

      PageModel newPage = PageModel(pageHeight: height, pageWidth: width);



      final image = await page.render(
        width: width*6,
        height: height*6,
      );
      if (image != null) {
        final Uint8List bytes = image.bytes;

        final ui.Image uiImage = await bytesToUiImage(bytes);

        final background = ImageModel(height: height, width: width, position: Offset(0,0), rotation: 0, image: uiImage);
        print("file_manager_list: importpdf: $uiImage");
        newPage = newPage.copyWith(backgroundImage: background);

        print("file_manager_list: importpdf: ${newDoc.pageHeights.length}");



        final document = ref.read(documentsProvider)[docIndex];
        await ref.read(documentsProvider.notifier).modifyPages(docIndex, [newPage], [document.pageList.length], []);
        await ref.read(documentsProvider.notifier).saveDoc2(docIndex, [newPage]);

        //await writeDoc(newPath, [newPage], newDoc);

      }
      await page.close();
    }

    await document.close();


    await ref.read(documentsProvider.notifier).compactDoc(docIndex);
    ref.read(documentsProvider.notifier).clearDoc(docIndex);





    return;

  }


  Future<ui.Image> bytesToUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    return frame.image;
  }









  @override
  Size get preferredSize => Size.fromHeight(height1); // Höhe frei wählbar
}


class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
