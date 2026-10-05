import 'dart:io';
import 'package:flutter/material.dart';
import 'package:betternotes/features/file_manager/components/buttons/delete_button.dart';
import 'package:betternotes/features/file_manager/components/buttons/rename_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/providers/global_providers.dart';


class FileManagerTopBarEdit extends ConsumerWidget implements PreferredSizeWidget {


  //final VoidCallback? onCreateNewFolder;
  final VoidCallback onCancelSelection;
  final VoidCallback onDeleteSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onMoveSetup;
  final VoidCallback onCopySetup;
  final VoidCallback onExportFiles;
  final int numberOfSelectedFiles;
  final Set<FileSystemEntity> selectedFiles;



  final void Function(int) onSetMode;
  final Function(Directory) onLoadDir;
  final Directory currentDir;

  final height1 = 40.0;      //height of the upper container




  const FileManagerTopBarEdit({super.key,

    required this.onCancelSelection,
    required this.numberOfSelectedFiles,
    required this.onDeleteSelected,
    required this.onSelectAll,
    required this.onMoveSetup,
    required this.onCopySetup,
    required this.selectedFiles,
    required this.onSetMode,
    required this.currentDir,
    required this.onLoadDir,
    required this.onExportFiles,



    //this.onCreateNewFolder,


  });




  @override
  Widget build(BuildContext context, WidgetRef  ref) {

    final text = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);



    return Container(
      color : Theme.of(context).colorScheme.primary,
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

                    IconButton(
                      icon: Icon(Icons.close),
                      color: Theme.of(context).colorScheme.onPrimary,
                      onPressed: onCancelSelection,
                    ),

                    Text('${numberOfSelectedFiles} '+text.selected, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary,),),

                    Spacer(), //move everything after this to the right

                    Visibility(
                      visible: numberOfSelectedFiles == 1,
                      child: RenameButton(
                        currentDir: currentDir,
                        onLoadDir: onLoadDir,
                        onSetMode: onSetMode,
                        entity: selectedFiles.toList()[0],
                      ),
                    ),

                    IconButton(
                      icon: Icon(Icons.file_copy),
                      color: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () {
                        print(selectedFiles);
                        onCopySetup();

                      }
                    ),

                    IconButton(
                      icon: Icon(Icons.arrow_circle_left),
                        color: Theme.of(context).colorScheme.onPrimary,
                        onPressed: () {
                          onMoveSetup();

                        }
                    ),

                    IconButton(
                        icon: Icon(Icons.upload_file_outlined),
                        color: Theme.of(context).colorScheme.onPrimary,
                        onPressed: () {
                          onExportFiles();

                        }
                    ),



                    DeleteButton(onDeleteSelected: onDeleteSelected, selectedFiles: selectedFiles,),

                    IconButton(
                      icon: Icon(Icons.library_add_check),
                      color: Theme.of(context).colorScheme.onPrimary,
                      onPressed: onSelectAll,
                    ),

                    SizedBox(width: 20),




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
