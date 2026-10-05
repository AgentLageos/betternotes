import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';


class FileManagerCopyBar extends StatelessWidget implements PreferredSizeWidget {

  final dynamic currentDir;
  final void Function(Directory) onLoadDir;
  //final VoidCallback? onCreateNewFolder;
  final VoidCallback onCancelSelection;
  final VoidCallback onCopyEntities;
  final height1 = 40.0;      //height of the upper container




  const FileManagerCopyBar({super.key,
    required this.currentDir,
    required this.onLoadDir,
    required this.onCopyEntities,
    required this.onCancelSelection,


    //this.onCreateNewFolder,


  });




  @override
  Widget build(BuildContext context) {

    final text = AppLocalizations.of(context)!;

    return Container(
      color: Colors.blue,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: SizedBox(

                height: height1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [

                    if (currentDir.path != '/')
                      IconButton(
                        icon: const Icon(Icons.drive_folder_upload),
                        onPressed: () {
                          final parent = currentDir.parent;
                          onLoadDir(parent);
                        },
                      ),

                    Text('${currentDir.path}'),

                    Spacer(),                                                    //move everything after this to the right

                    ElevatedButton(
                      child: Text(text.copy, style: TextStyle(fontSize: 10)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 30),

                      ),
                      onPressed: onCopyEntities,
                    ),

                    SizedBox(width: 10),

                    ElevatedButton(
                      child: Text(text.cancel, style: TextStyle(fontSize: 10)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 30),

                      ),
                      onPressed: onCancelSelection,
                    ),

                    SizedBox(width: 20), // kleiner Abstand zwischen Buttons




                  ],

                ),
              ),
            ),
          ],
        ),
      ),
    );
  }







  @override
  Size get preferredSize => Size.fromHeight(height1);
}
