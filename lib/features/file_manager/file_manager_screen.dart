import 'dart:io';
import 'package:betternotes/features/file_manager/components/file_manager_list.dart';
import 'package:betternotes/core/providers/global_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as path;

import 'package:flutter/material.dart';
import 'package:betternotes/features/file_manager/components/top_bar/file_manager_top_bar.dart';
import 'package:betternotes/features/file_manager/components/top_bar/file_manager_top_bar_edit.dart';
import 'package:betternotes/features/file_manager/components/top_bar/file_manager_move_bar.dart';
import 'package:betternotes/features/file_manager/components/top_bar/file_manager_copy_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:betternotes/l10n/app_localizations.dart';
import 'package:betternotes/core/utils/pref_keys.dart';


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

    Directory dir;
    final platformSettings = ref.read(platformProvider);
    

    if (platformSettings.currentDirectory.isEmpty) {
      debugPrint("FileManager: path is still empty, waiting...");
      return;
    }

    if (Platform.isAndroid) {
      final home = platformSettings.currentDirectory;
      dir = Directory(home);
    } else {
      final home = platformSettings.homeDirectory;
      dir = Directory(path.join(home, 'betternotes'));
    }

    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    await _loadDir(dir);
  }

  Future<void> _loadDir(Directory dir) async {


    try {


      final list = dir.listSync();
      setState(() {
        currentDir = dir;
        files = list;
        selectedFiles.clear();

      });
      await setPref(dir);
      ref.read(platformProvider.notifier).setCurrentDir(dir.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.access_denied(dir.path))),
      );
    }
  }

  Future<void> setPref(Directory dir) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.currentDirectory, dir.path);
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
    final text = AppLocalizations.of(context)!;
    try {
      final files = Set<FileSystemEntity>.from(selectedFiles);

      if (files.isEmpty) {
        debugPrint('No Files for Export found.');
        return;
      }

      String? selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: text.choose_destination,
      );

      if (selectedDirectory == null) {
        debugPrint('Export canceled');
        return;
      }

      // internal helper for the recursion
      Future<void> copyRecursive(FileSystemEntity entity, String destinationPath) async {
        if (entity is File) {
          // copy the file
          await entity.copy(destinationPath);
        } else if (entity is Directory) {
          // create the target folder if it doesn't exist
          final newDir = Directory(destinationPath);
          if (!await newDir.exists()) {
            await newDir.create(recursive: true);
          }

          // list everything in the folder and copy it recursively
          await for (final item in entity.list(recursive: false)) {
            await copyRecursive(item, path.join(destinationPath, path.basename(item.path)));
          }
        }
      }

      for (var entity in files) {
        final targetPath = path.join(selectedDirectory, path.basename(entity.path));
        await copyRecursive(entity, targetPath);
      }

      debugPrint('All files and folders exported to: $selectedDirectory');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text.files_exported_to(selectedDirectory))),
        );
      }
    } catch (e, stack) {
      debugPrint('Error trying to export: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text.export_error(e.toString()))),
        );
      }
      debugPrint(stack.toString());
    }
  }

  double importProgress = 0.0;
  String importStatus = '';

  Future<void> importFilesWithPicker() async {
    final text = AppLocalizations.of(context)!;
    try {
      final internalDir = currentDir!;

      final pickedFiles = await FilePicker.pickFiles();

      if (pickedFiles.isEmpty) {
        debugPrint('Import aborted or no files selected.');
        return;
      }

      final totalFiles = pickedFiles.length;
      int processedFiles = 0;

      setState(() {
        importProgress = 0.0;
        importStatus = text.import_starting;
      });

      for (var pickedFile in pickedFiles) {
        {
          String newPath = path.join(internalDir.path, pickedFile.name);
          File newFile = File(newPath);

          // 🔁 prevent override --> find new name
          if (await newFile.exists()) {
            final baseName = path.basenameWithoutExtension(pickedFile.name);
            final extension = path.extension(pickedFile.name);

            int counter = 1;
            do {
              newPath = path.join(internalDir.path, '${baseName}_$counter$extension');
              newFile = File(newPath);
              counter++;
            } while (await newFile.exists());
          }

          // Stream the data: on Android the picked file is a content:// URI without a file path.
          final sink = newFile.openWrite();
          await sink.addStream(pickedFile.readAsByteStream());
          await sink.close();
          final copiedFile = newFile;

          selectedFiles.add(copiedFile);
        }


        processedFiles++;
        setState(() {
          importProgress = processedFiles / totalFiles;
          importStatus = text.importing_progress(processedFiles, totalFiles);
        });
      }

      if (!mounted) return;
      setState(() {
        importStatus = text.import_finished;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.files_imported),
        ),
      );

      await _loadDir(currentDir!);

      debugPrint('Finished Import: ${internalDir.path}');
    } catch (e, stack) {
      if (!mounted) return;
      setState(() {
        importStatus = text.import_failed;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.import_error(e.toString())),
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
        } catch (e) {
          print('Error trying to move file: $e');
        }
      } else if (entity is Directory) {
        // Verzeichnis verschieben
        try {
          await entity.rename(targetPath);
        } catch (e) {
          print('Error trying to move directory: $e');
        }
      }
    }
    mode = 0;
    await _loadDir(currentDir!);
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
        } catch (e) {
          print("file_manager_screen: copying $targetPath failed: $e");
        }
      } else if (entity is Directory) {
        Directory targetDir = Directory(targetPath);

        try {
          // create the target directory if it doesn't exist
          await targetDir.create(recursive: true);

          // copy all files and subdirectories recursively
          await _copyDirectoryContents(entity, targetDir);
        } catch (e) {
          print('Error trying to copy directory: $e');
        }
      }
    }
    mode = 0;
    await _loadDir(currentDir!);
  }


  Future<String> _checkAlreadyExists(FileSystemEntity entity) async {
    String targetPath = path.join(currentDir!.path, path.basename(entity.path));


    if (entity is File) {
      if (await File(targetPath).exists()) {
        final extension = path.extension(entity.path);
        final baseName = path.basenameWithoutExtension(entity.path);

        int counter = 1;
        while (await File(targetPath).exists()) {
          targetPath = path.join(currentDir!.path, '$baseName($counter)$extension');
          counter++;
        }
      }
    } else if (entity is Directory) {
      if (await Directory(targetPath).exists()) {
        final dirName = path.basename(entity.path);
        print(dirName);
        int counter = 1;

        while (await Directory(targetPath).exists()) {
          targetPath = path.join(currentDir!.path, '$dirName($counter)');
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
        await _copyDirectoryContents(subEntity, newTargetSubDir);
      }
    }
  }

}
