import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import 'package:betternotes/features/file_manager/components/buttons/create_new_file_button.dart';
import 'package:betternotes/features/file_manager/components/buttons/create_new_folder_button.dart';



class FileManagerTopBar extends ConsumerWidget implements PreferredSizeWidget {

  final void Function(Directory) onLoadDir;
  final VoidCallback? onCreateNewFolder;
  final VoidCallback onImportFiles;
  //final VoidCallback onSave;

  final height1 = 40.0;      //height of the upper container
  final height2 = 0.0;     //height of the middle container
  final height3 = 30.0;      //height of the lower container

  final dynamic currentDir;      //path currently in and displayed at top



  const FileManagerTopBar({super.key,
    required this.currentDir,
    required this.onLoadDir,
    this.onCreateNewFolder,
    required this.onImportFiles,


  });




  @override
  Widget build(BuildContext context, WidgetRef ref) {

    //final settings = ref.watch(settingsProvider);

    return Container(
      color : Theme.of(context).colorScheme.primary,
      //color : settings.primary,
      //color: Colors.blue,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min, // nur so hoch wie nötig
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: SizedBox(
                height: height1,



                child: Row(
                  children: [
                    if (currentDir.path != '/')
                      IconButton(
                        icon: const Icon(Icons.drive_folder_upload),
                        color: Theme.of(context).colorScheme.onPrimary,
                        onPressed: () {
                          final parent = currentDir.parent;
                          onLoadDir(parent);
                        },
                      ),

                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            currentDir.path,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),

                      SizedBox(width: 8),

                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [

                                IconButton(
                                    icon: Icon(Icons.file_download_outlined),
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    onPressed: () {
                                      onImportFiles();

                                    }
                                ),
                              NewFileButton(
                                size: MaterialTapTargetSize.shrinkWrap,
                                onLoadDir: onLoadDir,
                                currentDir: currentDir,
                              ),

                              SizedBox(width: 6),

                              NewFolderButton(
                                size: MaterialTapTargetSize.shrinkWrap,
                                onLoadDir: onLoadDir,
                                currentDir: currentDir,
                              ),
                            ],
                            ),
                          ),
                        ),
                      ),

                    SizedBox(width: 6),

                    IconButton(
                      icon: const Icon(Icons.settings),
                      color: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () {
                        context.push('/settings');
                      },
                    ),
                  ],
                )
              ),
            ),

          ],
        ),
      ),
    );
  }







  @override
  Size get preferredSize => Size.fromHeight(height1+height2+height3);
}
