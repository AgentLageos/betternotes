import 'dart:io';
import 'package:betternotes/features/file_manager/components/file_manager_list.dart';
import 'package:betternotes/core/providers/global_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as path;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:betternotes/features/file_manager/components/top_bar/file_manager_top_bar.dart';
import 'package:betternotes/features/file_manager/components/top_bar/file_manager_top_bar_edit.dart';
import 'package:betternotes/features/file_manager/components/top_bar/file_manager_move_bar.dart';
import 'package:betternotes/features/file_manager/components/top_bar/file_manager_copy_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';


class FileManager extends ConsumerStatefulWidget {
  const FileManager({super.key});

  @override
  ConsumerState<FileManager> createState() => _FileManagerState();
}


class _FileManagerState extends ConsumerState<FileManager> {
  Directory? currentDir;
  List<FileSystemEntity> files = [];
  bool permissionGranted = false;

  Set<FileSystemEntity> selectedFiles = {};                                     // the files highlighted when long pressed
  Set<FileSystemEntity> copyFiles = {};                                         //the set of files/folders that will be moved or copied to another dir
  int mode = 0;



  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }



  Future<void> _init() async {
    /*
    if (Platform.isAndroid) {
      permissionGranted = await _requestPermission();
      if (!permissionGranted) return;
    } else {
      // Linux, Windows, macOS no permissions needed
      permissionGranted = true;
      print("permission");
    }

     */

    Directory dir;
    final platformSettings = ref.read(platformProvider);
    

    if (platformSettings.currentDirectory.isEmpty) {
      debugPrint("FileManager: Pfad ist noch leer, warte...");
      return;
    }

    if (Platform.isAndroid) {
      final home = platformSettings.currentDirectory;
      dir = Directory(home);
    } else {
      final home = platformSettings.homeDirectory;
      dir = Directory('$home/betternotes');
    }

    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    _loadDir(dir);
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      } else {
        final status = await Permission.manageExternalStorage.request();
        if (status.isGranted) return true;
        if (status.isPermanentlyDenied) {
          openAppSettings();
          return false;
        }
      }
    }
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<void> _loadDir(Directory dir) async {


    try {


      final list = dir.listSync();
      setState(() {
        currentDir = dir;
        files = list;
        selectedFiles.clear();

        //mode = 0;
      });
      setPref(dir);
      ref.read(platformProvider.notifier).setCurrentDir(dir.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Access Denied: ${dir.path}')),
      );
    }
  }

  Future<void> setPref(Directory dir) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('currentDirectory', dir.path);
  }

  void _toggleSelection(FileSystemEntity file) {                                //adds the current file to the set of selected files
    setState(() {

      if (selectedFiles.contains(file)) {
        selectedFiles.remove(file);
        if (selectedFiles.isEmpty) mode = 0;
      } else {
        selectedFiles.add(file);
        mode = 1;
      }

    });

  }

  void _selectAll() {                                                            //selects all elements
    setState(() {
      if (!files.every((file) => selectedFiles.contains(file))) {
        for (int i = 0; i < files.length; i++) {                                //adds elements currently not selected
          if (!selectedFiles.contains(files[i])) {
            selectedFiles.add(files[i]);
          }
        }
        if (selectedFiles.isEmpty) mode = 1;
      } else {                                                                  //when everything is already selected, deselect all
        selectedFiles = {};
        mode = 0;
      }
    });
  }

  void _deleteSelected() {
    for (var f in selectedFiles) {
      f.deleteSync(recursive: true);
    }
    mode=0;
    _loadDir(currentDir!);
  }

  void _cancelSelection() {
    setState(() {
      selectedFiles.clear();
      mode = 0;
    });
  }

  void _setMode(int number) {
    setState(() {
      mode = number;
    });
  }

  void _moveSetup() {
    setState(() {
      copyFiles = Set<FileSystemEntity>.from(selectedFiles);                    //this cant just be copyFiles=selectedFiles, because this would only make copyFiles a reference to selectedFiles, meaning when selectedFiles are deleted in _cancelSelection, copyFiles is deleted as well
      _cancelSelection();
      mode= 2;

    });
  }


  Future<void> exportFilesWithPicker() async {
    try {
      final files = Set<FileSystemEntity>.from(selectedFiles);

      if (files.isEmpty) {
        debugPrint('No Files for Export found.');
        return;
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose Destination',
      );

      if (selectedDirectory == null) {
        debugPrint('Export canceled');
        return;
      }

      // Interne Hilfsfunktion für die Rekursion
      Future<void> copyRecursive(FileSystemEntity entity, String destinationPath) async {
        if (entity is File) {
          // Datei einfach kopieren
          await entity.copy(destinationPath);
        } else if (entity is Directory) {
          // Ziel-Ordner erstellen, falls er nicht existiert
          final newDir = Directory(destinationPath);
          if (!await newDir.exists()) {
            await newDir.create(recursive: true);
          }

          // Alle Inhalte des Ordners auflisten und rekursiv kopieren
          await for (final item in entity.list(recursive: false)) {
            final itemName = item.uri.pathSegments.last.isEmpty
                ? item.uri.pathSegments[item.uri.pathSegments.length - 2]
                : item.uri.pathSegments.last;

            await copyRecursive(item, '$destinationPath/$itemName');
          }
        }
      }

      for (var entity in files) {
        final entityName = entity.uri.pathSegments.last.isEmpty
            ? entity.uri.pathSegments[entity.uri.pathSegments.length - 2]
            : entity.uri.pathSegments.last;

        final targetPath = '$selectedDirectory/$entityName';
        await copyRecursive(entity, targetPath);
      }

      debugPrint('All files and folders exported to: $selectedDirectory');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All files exported to: $selectedDirectory')),
        );
      }
    } catch (e, stack) {
      debugPrint('Error trying to export: $e');
      if (mounted) {
        /*
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error trying to export: $e')),
        );

         */
      }
      debugPrint(stack.toString());
    }
  }

  double importProgress = 0.0;
  String importStatus = '';

  Future<void> importFilesWithPicker() async {
    try {
      //final internalDir = await getApplicationDocumentsDirectory();
      final internalDir = currentDir!;

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('Import aborted or no files selected.');
        return;
      }

      final totalFiles = result.files.length;
      int processedFiles = 0;

      setState(() {
        importProgress = 0.0;
        importStatus = 'Start Import...';
      });

      for (var pickedFile in result.files) {
        final path = pickedFile.path;

        if (path != null) {
          final file = File(path);

          String newPath = '${internalDir.path}/${pickedFile.name}';
          File newFile = File(newPath);

          // 🔁 prevent override --> find new name
          if (await newFile.exists()) {
            final baseName = pickedFile.name.split('.').first;
            final extension = pickedFile.name.contains('.')
                ? '.${pickedFile.name.split('.').last}'
                : '';

            int counter = 1;
            do {
              newPath =
              '${internalDir.path}/${baseName}_$counter$extension';
              newFile = File(newPath);
              counter++;
            } while (await newFile.exists());
          }

          final copiedFile = await file.copy(newPath);

          selectedFiles.add(copiedFile);
        }


        processedFiles++;
        setState(() {
          importProgress = processedFiles / totalFiles;
          importStatus =
          'Importing $processedFiles from $totalFiles';
        });
      }

      setState(() {
        importStatus = 'Import finished.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Files imported successfully.'),
        ),
      );

      _loadDir(currentDir!);

      debugPrint('Finished Import: ${internalDir.path}');
    } catch (e, stack) {
      setState(() {
        importStatus = 'Fehler beim Import';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error trying to Import: $e'),
        ),
      );

      debugPrint(stack.toString());
    }
  }


  @override
  Widget build(BuildContext context) {
    if (currentDir == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar                                                                   //depending on user long clicked on contents, display a normal top bar, or the topbar for editing/moving files
          :mode == 1 ? FileManagerTopBarEdit(onCancelSelection: _cancelSelection, numberOfSelectedFiles: selectedFiles.length, onDeleteSelected: _deleteSelected, onSelectAll: _selectAll, selectedFiles: selectedFiles, onSetMode: _setMode, onMoveSetup: _moveSetup, onCopySetup: _copySetup, currentDir: currentDir!, onLoadDir: _loadDir, onExportFiles: exportFilesWithPicker)
          :mode ==2 ? FileManagerMoveBar(onCancelSelection: _cancelSelection, currentDir: currentDir!, onLoadDir: _loadDir, onMoveEntities: _moveEntities,)
          :mode ==3 ? FileManagerCopyBar(onCancelSelection: _cancelSelection, currentDir: currentDir!, onLoadDir: _loadDir, onCopyEntities: _copyEntities,)
          :FileManagerTopBar(currentDir: currentDir!, onLoadDir: _loadDir, onImportFiles: importFilesWithPicker,),

      body: FileManagerList(onCancelSelection: _cancelSelection, onToggleSelection: _toggleSelection, files: files, mode: mode, selectedFiles: selectedFiles, onDeleteSelected: _deleteSelected, onLoadDir: _loadDir, currentDir: currentDir!),
    );
  }



  void _moveEntities() async {
    for (var entity in copyFiles) {

      String targetPath = await _checkAlreadyExists(entity);

      if (entity is File) {
        try {
          await entity.rename(targetPath);
          //print('Datei ${entity.path} verschoben nach $targetPath');
        } catch (e) {
          print('Error trying to move file: $e');
        }
      } else if (entity is Directory) {
        // Verzeichnis verschieben
        try {
          await entity.rename(targetPath);
          //print('Verzeichnis ${entity.path} verschoben nach $targetPath');
        } catch (e) {
          print('Error trying to move directory: $e');
        }
      }
    }
    mode = 0;
    _loadDir(currentDir!);
  }

  void _copySetup() {
    setState(() {
      copyFiles = Set<FileSystemEntity>.from(selectedFiles);                    //this cant just be copyFiles=selectedFiles, because this would only make copyFiles a reference to selectedFiles, meaning when selectedFiles are deleted in _cancelSelection, copyFiles is deleted as well
      _cancelSelection();
      mode= 3;

    });
  }


  void _copyEntities() async {
    for (var entity in copyFiles) {
      String targetPath = await _checkAlreadyExists(entity);

      if (entity is File) {

        try {
          await entity.copy(targetPath);
          //print('Datei ${entity.path} verschoben nach $targetPath');
        } catch (e) {
          //print('Fehler beim Verschieben der Datei: $e');
        }
      } else if (entity is Directory) {
        Directory targetDir = Directory(targetPath);

        try {
          // Erstelle das Zielverzeichnis, falls es nicht existiert
          await targetDir.create(recursive: true);

          // Rekursiv alle Dateien und Unterverzeichnisse kopieren
          await _copyDirectoryContents(entity, targetDir);
          //print('Verzeichnis ${entity.path} erfolgreich kopiert nach $targetPath');
        } catch (e) {
          print('Error trying to copy directory: $e');
        }
      }
    }
    mode = 0;
    _loadDir(currentDir!);
  }


  Future<String> _checkAlreadyExists(FileSystemEntity entity) async {
    String targetPath = '${currentDir!.path}/${entity.uri.pathSegments.last}';


    if (entity is File) {
      if (await File(targetPath).exists()) {
        final fileName = entity.uri.pathSegments.last;
        final extension = fileName.split('.').last;
        final baseName = fileName.substring(0, fileName.lastIndexOf('.'));

        int counter = 1;
        while (await File(targetPath).exists()) {
          targetPath = '${currentDir!.path}/$baseName($counter).$extension';
          counter++;
        }
      }
    } else if (entity is Directory) {
      if (await Directory(targetPath).exists()) {
        final dirName = path.basename(entity.path);
        print(dirName);
        int counter = 1;

        while (await Directory(targetPath).exists()) {
          targetPath = '${currentDir!.path}/$dirName($counter)';
          counter++;
        }
      }
    }

    return targetPath;
  }

  Future<void> _copyDirectoryContents(Directory sourceDir, Directory targetDir) async {
    await for (var subEntity in sourceDir.list(recursive: false)) {
      String newTargetPath = '${targetDir.path}${Platform.pathSeparator}${path.basename(subEntity.path)}';

      if (subEntity is File) {
        await subEntity.copy(newTargetPath);
      } else if (subEntity is Directory) {
        Directory newTargetSubDir = Directory(newTargetPath);
        await newTargetSubDir.create(recursive: true);
        //print('Created new Dir: $newTargetSubDir');
        await _copyDirectoryContents(subEntity, newTargetSubDir);
      }
    }
  }

}
