import 'dart:io';
import 'package:flutter/material.dart';
import 'package:betternotes/l10n/app_localizations.dart';

class RenameButton extends StatelessWidget {
  final Function(Directory) onLoadDir;
  final dynamic currentDir;
  final FileSystemEntity entity;
  final void Function(int) onSetMode;


  const RenameButton({
    super.key,
    required this.currentDir,
    required this.onLoadDir,
    required this.entity,
    required this.onSetMode,
  });



  @override
  Widget build(BuildContext context) {
    return IconButton(
      color: Theme.of(context).colorScheme.onPrimary,
      icon: Icon(Icons.drive_file_rename_outline),
      onPressed: () async {

        final existingNames = await _getExistingDocumentNames();
        _showRenameDialog(context, existingNames);

      },
    );
  }

  Future<List<String>> _getExistingDocumentNames() async {
    final docDir = Directory('${currentDir.path}');

    if (!await docDir.exists()) {
      await docDir.create(recursive: true);
    }

    final files = docDir.listSync();
    return files
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList();
  }





  void _showRenameDialog(BuildContext context, List<String> existingNames) {
    final controller = TextEditingController();
    String? errorText;

    final text = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(text.rename),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: text.new_name,
                errorText: errorText,
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final name = controller.text.trim();

                  if (name.isEmpty) {
                    setState(() => errorText = text.name_cannot_be_empty);
                  } else if (existingNames.contains("$name.bnf")) {
                    setState(() => errorText = '\"$name\" '+text.already_exists);
                  } else {
                    Navigator.of(context).pop();
                    renameFile(name).then((_) {
                      onSetMode(0);
                      onLoadDir(currentDir);
                    });
                  }
                },
                child: Text(text.ok),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> renameFile(String name) async {



    if (entity is File) {
      final file = entity as File;

      final newFilePath;
      if (file.toString().contains(".bnf")) {
        newFilePath = '${currentDir.path}/$name.bnf';                         //put together new file name
      } else {
        newFilePath = '${currentDir.path}/$name';
      }


      try {
        // Datei umbenennen
        await file.rename(newFilePath);
        //print('Datei erfolgreich umbenannt zu: $newFilePath');
        onLoadDir(currentDir);
      } catch (e) {
        print('Fehler beim Umbenennen der Datei: $e');
      }





    } else if (entity is Directory ){
      final dir = entity as Directory;

      final newFilePath = '${currentDir.path}/$name';                         //put together new dir name

      try {
        // Datei umbenennen
        await dir.rename(newFilePath);
        //print('Datei erfolgreich umbenannt zu: $newFilePath');
        onLoadDir(currentDir);
      } catch (e) {
        print('Fehler beim Umbenennen der Datei: $e');
      }
    }
    else {
      print('Die angegebene Entity ist unbekannt.');
    }
  }

}



