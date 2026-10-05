import 'dart:io';
import 'package:betternotes/features/editor/models/page/document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/providers/global_providers.dart';

final editorIndex = 0;


class NewFileButton extends ConsumerWidget {
  final MaterialTapTargetSize size;
  final void Function(Directory) onLoadDir;
  final dynamic currentDir;


  const NewFileButton({
    super.key,
    required this.size,
    required this.currentDir,
    required this.onLoadDir
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final settings = ref.watch(settingsProvider);

    final text = AppLocalizations.of(context)!;
    return IconButton(
      color: Theme.of(context).colorScheme.onPrimary,
      onPressed: () async {

        final existingNames = await _getExistingDocumentNames();
        _showNewFileDialog(context, existingNames, ref);

      },
      /*
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 30),
        tapTargetSize: size,
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),

       */
      icon: Icon(Icons.note_add_outlined),
      //child: Text(text.new_document, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSecondary)),
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

  void _showNewFileDialog(BuildContext context, List<String> existingNames, WidgetRef ref) {
    final text = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(

          builder: (context, setState) => AlertDialog(
            title: Text(text.create_new_document, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: text.document_name,
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

                  if (name.isEmpty) {
                    setState(() => errorText = text.name_cannot_be_empty);
                  } else if (existingNames.contains("$name") || existingNames.contains("$name.bnf")) {
                    //print("$name already exists");
                    setState(() => errorText = '\"$name\" '+text.already_exists);
                  } else {
                    Navigator.of(context).pop();
                    //onCreate("test");
                    createBnfFile(name, currentDir, ref).then((_) {
                      onLoadDir(currentDir);
                    });

                  }
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



Future<void> createBnfFile(String name, dynamic currentDir, WidgetRef ref) async {

  final file = File('${currentDir.path}/$name.bnf');



  final defaultPage = ref.read(editorSetupProvider)[editorIndex].defaultPage;
  DocumentModel newDoc = DocumentModel(pages: [defaultPage], defaultPage: defaultPage, author: 'name', title: 'title', created: DateTime.now(), pageHeights: [defaultPage.pageHeight], pageList: [defaultPage.pageID]);
  final bytes = await newDoc.toBytes();


  await file.writeAsBytes(
    bytes,
    flush: true,
  );
}