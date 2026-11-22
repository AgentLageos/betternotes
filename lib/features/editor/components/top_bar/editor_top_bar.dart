import 'dart:io';

import 'package:betternotes/features/editor/components/top_bar/editor_top_bar_panel.dart';
import 'package:betternotes/features/editor/models/page/document_model.dart';
import 'package:betternotes/features/editor/models/page/image_model.dart';
import 'package:betternotes/features/editor/models/page/page_model.dart';
import 'package:flutter/material.dart';
// for PointerDeviceKind
import 'package:betternotes/features/file_manager/file_manager_screen.dart';
import 'dart:ui' as ui;


import 'package:betternotes/features/editor/components/top_bar/drop_down_menu_button.dart';
import 'package:betternotes/features/editor/components/top_bar/page_setup_menu.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betternotes/core/providers/global_providers.dart';
import 'package:image_picker/image_picker.dart';



import 'package:betternotes/l10n/app_localizations.dart';



final buttonColor = Colors.greenAccent;



class EditorTopBar extends ConsumerWidget implements PreferredSizeWidget {



  EditorTopBar({super.key,});



  final height1 = 30.0;      //height of the upper container
  final height2 = 30.0;     //height of the middle container
  final height3 = 30.0;      //height of the lower container


  @override
  Widget build(BuildContext context, WidgetRef ref) {

    int docIndex = ref.read(documentsProvider.notifier).currentDocIndex;
    DocumentModel document = ref.read(documentsProvider.select((docs) => docs[docIndex]));




    return Container(
      color: Theme.of(context).colorScheme.secondary,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min, // only as tall as needed
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: height1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BetterNotes Alpha',//'DEMO',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),





            // 2nd bar
            Container(
              height: height2,
              color: Theme.of(context).colorScheme.primary,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const SizedBox(width: 8),

                  IconButton(
                    onPressed: () async {
                      final docID = ref.read(documentsProvider.notifier).currentDocID;
                      await ref.read(documentsProvider.notifier).saveAsBnf(docID);
                      await ref.read(documentsProvider.notifier).compactDoc(docID);
                      await ref.read(editorSetupProvider.notifier).saveToJson();
                      ref.read(documentsProvider.notifier).clearDoc(docID);
                      print("editor_top_bar: currnetDir= ${ref.read(platformProvider).currentDirectory}");
                      if (!context.mounted) return;
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FileManager()),);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                      });
                    },
                    icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary,),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  ),

                  IconButton(
                    onPressed: () {
                      ref.read(documentsProvider.notifier).saveAsBnf(ref.read(documentsProvider.notifier).currentDocID);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.saved)),
                      );
                    },
                    icon: Icon(Icons.save, color: Theme.of(context).colorScheme.onPrimary,),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  ),

                  Spacer(),
                  IconButton(
                    onPressed: () async {
                      document = ref.read(documentsProvider).firstWhere((d) => d.docID == ref.read(documentsProvider.notifier).currentDocID);
                      await ref.read(documentsProvider.notifier).modifyPages(document.docID, [PageModel(strokes: [], backgroundStrokes: document.defaultPage.backgroundStrokes, images: [], pageWidth: document.defaultPage.pageWidth, pageHeight: document.defaultPage.pageHeight, pageColor: document.defaultPage.pageColor)], [document.currentPageIndex+1], []);
                    },
                    icon: Icon(Icons.note_add, color: Theme.of(context).colorScheme.onPrimary,),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  ),
                  IconButton(
                    onPressed: () {
                      final docID = ref.read(documentsProvider.notifier).currentDocID;
                      document = ref.read(documentsProvider).firstWhere((d) => d.docID == docID);

                      // currentPageIndex is a position in pageList (the whole document); doc.pages only
                      // holds the loaded window around it, so look the current page up by ID.
                      if (document.currentPageIndex < 0 || document.currentPageIndex >= document.pageList.length) return;
                      final pageID = document.pageList[document.currentPageIndex];
                      final page = document.pages.where((p) => p.pageID == pageID).firstOrNull;
                      if (page == null || page.isTemp) {
                        print("editor_top_bar: delete page: current page $pageID is not loaded yet, not deleted");
                        return;     //undo needs the page content
                      }
                      ref.read(documentsProvider.notifier).modifyPages(document.docID, [], [], [pageID]);
                    },
                    icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.onPrimary,),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),

                  ),
                  DropDownMenuButton(
                    onItemSelected: (value) async {
                      if (value=='pageSetup') {_openPopupMenu(context, (selected) {});}
                      else if (value=='importImage'){await importImage(context, ref);}

                    },
                  )
                ],
              ),

            ),

            //bottom bar
            EditorTopBarPanel(),

          ],
        ),
      ),
    );
  }



  void _openPopupMenu(BuildContext context, void Function(String) onSelected) {

    showDialog(
      context: context,
      builder: (context) {

        return PageSetupMenu(onSelected: onSelected);
      },
    );
  }


  final ImagePicker _picker = ImagePicker();



  Future<void> importImage(BuildContext context, WidgetRef ref) async {

    final text = AppLocalizations.of(context)!;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text(text.gallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text(text.camera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = File(pickedFile.path).readAsBytesSync();

        {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          final imageDecoded = frame.image;

          // Insert into the current page. Look it up by ID after the awaits: `pages` only holds
          // the loaded window around the current page, so its positions say nothing about which
          // page is current, and the window may have changed while decoding.
          final docID = ref.read(documentsProvider.notifier).currentDocID;
          final doc = ref.read(documentsProvider).firstWhere((d) => d.docID == docID);
          if (doc.currentPageIndex < 0 || doc.currentPageIndex >= doc.pageList.length) return;
          final pageID = doc.pageList[doc.currentPageIndex];
          final pageIndex = doc.pages.indexWhere((p) => p.pageID == pageID && !p.isTemp);
          if (pageIndex == -1) {
            print("editor_top_bar: importImage: current page $pageID is not loaded, image not inserted");
            return;
          }
          final page = doc.pages[pageIndex];
          //imageDecoded.width.toDouble()/100
          await ref.read(documentsProvider.notifier).modifyElements(doc.docID, pageID, [], [ImageModel(height: imageDecoded.height/imageDecoded.width*page.pageWidth*0.8, width: page.pageWidth*0.8, position: Offset(page.pageWidth*0.1,page.pageHeight*0.1), image: frame.image, rotation: 0)], [], []);


        }

      } else {
        print("No Image Selected");
      }
    }
  }


  @override
  Size get preferredSize => Size.fromHeight(height1+height2+height3);



}



































class ColoredCircleButton extends StatelessWidget {   //widget for displaying colored button for color picker
  final Color color;
  final VoidCallback? onPressed;
  final String snackBarText;

  const ColoredCircleButton({
    super.key,
    required this.color,
    this.onPressed,
    this.snackBarText = '',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed ??
              () {
            if (snackBarText.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(snackBarText)),
              );
            }
          },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      child: Icon(
        Icons.circle,
        color: color,
      ),
    );
  }





}

class PenButton extends StatelessWidget {   //widget for displaying colored button for color picker

  final VoidCallback? onPressed;
  final String snackBarText;

  const PenButton({
    super.key,
    this.onPressed,
    this.snackBarText = '',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed ??
              () {
            if (snackBarText.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(snackBarText)),
              );
            }
          },
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      child: Icon(
        Icons.edit,
        color: Colors.black,
      ),
    );
  }
}

class UndoButton extends StatelessWidget {   //widget for displaying colored button for color picker
  final VoidCallback? onPressed;
  final String snackBarText;

  const UndoButton({
    super.key,
    this.onPressed,
    this.snackBarText = '',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed ??
              () {
            if (snackBarText.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(snackBarText)),
              );
            }
          },
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      child: Icon(
        Icons.undo,
        color: Colors.black,
      ),
    );
  }
}

class RedoButton extends StatelessWidget {   //widget for displaying colored button for color picker
  final VoidCallback? onPressed;
  final String snackBarText;

  const RedoButton({
    super.key,
    this.onPressed,
    this.snackBarText = '',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed ??
              () {
            if (snackBarText.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(snackBarText)),
              );
            }
          },
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      child: Icon(
        Icons.redo,
        color: Colors.black,
      ),
    );
  }
}



