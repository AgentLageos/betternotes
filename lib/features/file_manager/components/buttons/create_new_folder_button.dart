import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../../../l10n/app_localizations.dart';

class NewFolderButton extends StatelessWidget {
  final MaterialTapTargetSize size;
  final void Function(Directory) onLoadDir;
  final dynamic currentDir;


  const NewFolderButton({
    super.key,
    required this.size,
    required this.currentDir,
    required this.onLoadDir
  });

  @override
  Widget build(BuildContext context) {


    final text = AppLocalizations.of(context)!;


    return IconButton(
      color: Theme.of(context).colorScheme.onPrimary,
      onPressed: () async {

        final existingNames = await _getExistingFolderNames();
        print(existingNames);
        _showNewFolderDialog(context, existingNames);
      },

      icon: Icon(Icons.create_new_folder_outlined),
      //child: Text(text.new_directory, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSecondary),),
    );
  }


  Future<List<String>> _getExistingFolderNames() async {
    final dir = Directory(currentDir.path);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final entries = dir.listSync();

    final folders = entries
        .where((entry) => FileSystemEntity.isDirectorySync(entry.path))
        .map((entry) => p.basename(entry.path))
        .toList();
    return folders;
  }




  Future<void> createNewFolder(String name, Directory currentDir) async {

    //print("hi");

    if (name != null && name.isNotEmpty) {
      final newDir = Directory('${currentDir.path}/$name');
      if (!(await newDir.exists())) {
        await newDir.create();
      }
    }
  }



  void _showNewFolderDialog(BuildContext context, List<String> existingNames) {

    final text = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(text.create_new_directory),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: text.directory_name,
                errorText: errorText,
              ),
              autofocus: true,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(text.cancel),
              ),
              SizedBox(width: 20),
              TextButton(
                onPressed: () {
                  final name = controller.text.trim();
                  print(existingNames);
                  if (name.isEmpty) {
                    setState(() => errorText = text.name_cannot_be_empty);
                  } else if (existingNames.contains("$name")) {
                    setState(() => errorText = '\"$name\" '+text.already_exists);
                  } else {
                    Navigator.of(context).pop();
                    createNewFolder(name, currentDir).then((_) {
                      onLoadDir(currentDir); // Aktualisiert die Dateiansicht
                    }); // Aktualisiert die Dateiansicht
                    //onCreate("test");
                    /*
                    createBnfFile(name, currentDir).then((_) {

                    });

                     */

                  };


                },
                child: Text(text.create),
              ),
            ],
          ),
        );
      },
    );
  }
}