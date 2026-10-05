import 'dart:io';
import 'package:flutter/material.dart';
import 'package:betternotes/l10n/app_localizations.dart';

class DeleteButton extends StatelessWidget {
  final VoidCallback onDeleteSelected;
  final Set<FileSystemEntity> selectedFiles;


  const DeleteButton({
    super.key,
    required this.onDeleteSelected,
    required this.selectedFiles,

  });



@override
  Widget build(BuildContext context) {

  final text = AppLocalizations.of(context)!;

  final String string;
  if (selectedFiles.length>1) {
    string=selectedFiles.length.toString()+' '+text.elements;
  }else {
    string = "\""+ selectedFiles.first.path.split('/').last+"\"";
  };
    return IconButton(
      color: Theme.of(context).colorScheme.onPrimary,
      onPressed: () async {
        _showDeleteDialog(context, string);
      },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 30),
      ),
      icon: Icon(Icons.delete),
    );
  }

  void _showDeleteDialog(BuildContext context, String string) {
    final text = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(text.delete+' $string?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(text.cancel),
              ),
              TextButton(
                onPressed: () {
                  onDeleteSelected();
                  Navigator.of(context).pop();
                },
                child: Text(text.ok),
              ),
            ],
          ),
        );
      },
    );
  }
}
