import 'dart:io';

import 'package:betternotes/features/editor/components/top_bar/editor_top_bar_panel.dart';
import 'package:betternotes/features/editor/models/page/document_model.dart';
import 'package:betternotes/features/editor/models/page/image_model.dart';
import 'package:betternotes/features/editor/models/page/page_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // Für PointerDeviceKind
import 'package:betternotes/features/file_manager/file_manager_screen.dart';
import 'dart:ui' as ui;


import 'package:betternotes/features/editor/components/top_bar/buttons/color_selector_bar.dart';
import 'package:betternotes/features/editor/components/top_bar/buttons/width_selector_bar.dart';
import 'package:betternotes/features/editor/components/top_bar/buttons/tool_selector_bar.dart';
import 'package:betternotes/features/editor/components/top_bar/drop_down_menu_button.dart';
import 'package:betternotes/features/editor/components/top_bar/page_setup_menu.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betternotes/core/providers/global_providers.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/page/editor_setup.dart';

import 'package:image/image.dart' as img;

import 'package:betternotes/l10n/app_localizations.dart';



final buttonColor = Colors.greenAccent;



class EditorTopBar extends ConsumerWidget implements PreferredSizeWidget {



  EditorTopBar({super.key,});



  final height1 = 30.0;      //height of the upper container
  final height2 = 30.0;     //height of the middle container
  final height3 = 30.0;      //height of the lower container

  //final color1 =Colors.lightBlueAccent;
  //final color2 =Colors.lightBlue;
  //final color3 =Colors.white;



  @override
  Widget build(BuildContext context, WidgetRef ref) {

    int docIndex = ref.read(documentsProvider.notifier).currentDocIndex;
    //int currentPageIndex = ref.watch(currentPagesProvider)[docIndex];
    DocumentModel document = ref.read(documentsProvider.select((docs) => docs[docIndex]));

    //int pageID = document.pages.where(test)



    final double spacing = (MediaQuery.of(context).size.width)/80;
    final editorSetup = ref.watch(editorSetupProvider.notifier).state[docIndex];

    final text = AppLocalizations.of(context)!;

    return Container(
      color: Theme.of(context).colorScheme.secondary,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min, // nur so hoch wie nötig
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
                      await ref.read(documentsProvider.notifier).saveAsBnf(docIndex);
                      await ref.read(documentsProvider.notifier).compactDoc(docID);
                      ref.read(editorSetupProvider.notifier).saveToJson();
                      //ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert')),);
                      ref.read(documentsProvider.notifier).clearDoc(0);
                      print("editor_top_bar: currnetDir= ${ref.read(platformProvider).currentDirectory}");
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FileManager()),);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                      });
                    },
                    icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary,),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  ),

                  IconButton(
                    onPressed: () {
                      //onSave();
                      ref.read(documentsProvider.notifier).saveAsBnf(docIndex);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saved')),
                      );
                    },
                    icon: Icon(Icons.save, color: Theme.of(context).colorScheme.onPrimary,),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  ),

                  Spacer(),
                  IconButton(
                    onPressed: () async {
                      //onAddPage();
                      //print(document.docBackgroundColor);
                      document = ref.read(documentsProvider)[0];
                      //print(document.defaultPage.pageColor);
                      //ref.read(documentsProvider.notifier).addPage(docIndex, document.defaultPage);
                      await ref.read(documentsProvider.notifier).modifyPages(document.docID, [PageModel(strokes: [], backgroundStrokes: document.defaultPage.backgroundStrokes, images: [], pageWidth: document.defaultPage.pageWidth, pageHeight: document.defaultPage.pageHeight, pageColor: document.defaultPage.pageColor)], [document.currentPageIndex+1], []);
                      //ref.read(documentsProvider.notifier).setCurrentPageIndex3(document.docID, document.currentPageIndex);
                      //ref.read(documentsProvider.notifier).updateIsolatedPages(document.docID);
                      //ref.read(documentsProvider.notifier).setBackgroundStrokesExecute(document.docID, document.pages[document.currentPageIndex].pageID, 5, 5, Colors.grey, 0.2);
                    },
                    icon: Icon(Icons.note_add, color: Theme.of(context).colorScheme.onPrimary,),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  ),
                  IconButton(
                    onPressed: () {
                      document = ref.read(documentsProvider)[docIndex];


                      int removeIndex = document.currentPageIndex;
                      if(removeIndex>document.pages.length-1) removeIndex = document.pages.length-1;
                      //ref.read(documentsProvider.notifier).removePages(docIndex, [document.pages[removeIndex].pageID]);
                      ref.read(documentsProvider.notifier).modifyPages(document.docID, [], [], [document.pages[removeIndex].pageID]);
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
  File? _image;



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
        _image = File(pickedFile.path);
        final bytes = _image?.readAsBytesSync();
        final imageDecoded = img.decodeImage(bytes!);
        //print("Gewähltes Bild: ${pickedFile.path}");

        if (imageDecoded != null) {
          //print("Breite: ${imageDecoded.width}, Höhe: ${imageDecoded.height}");
          final docs = ref.read(documentsProvider.notifier);
          final docIndex =docs.currentDocIndex;
          final doc = ref.read(documentsProvider.select((docs) => docs[docIndex]));
          int pageID = 0;
          int index = 0;
          if (doc.pages.length >= 1) {
            pageID = doc.pages[1].pageID;
            index = 1;

          } else if (doc.pages.length == 0) {
            pageID = doc.pages.first.pageID;
            index = 0;
          } else return;
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          //imageDecoded.width.toDouble()/100
          ref.read(documentsProvider.notifier).modifyElements(docIndex, pageID, [], [ImageModel(height: imageDecoded.height/imageDecoded.width*doc.pages[index].pageWidth*0.8, width: doc.pages[index].pageWidth*0.8, position: Offset(doc.pages[index].pageWidth*0.1,doc.pages[index].pageHeight*0.1), image: frame.image, rotation: 0)], [], []);
          //final editorIndex = ref.read(editorSetupProvider.notifier).currentEditorID;
          //ref.read(editorSetupProvider.notifier).setToolIndex(editorIndex, 3);


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
    Key? key,
    required this.color,
    this.onPressed,
    this.snackBarText = '',
  }) : super(key: key);

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
    Key? key,
    this.onPressed,
    this.snackBarText = '',
  }) : super(key: key);

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
    Key? key,
    this.onPressed,
    this.snackBarText = '',
  }) : super(key: key);

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
    Key? key,
    this.onPressed,
    this.snackBarText = '',
  }) : super(key: key);

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



