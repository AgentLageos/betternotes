import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:betternotes/features/editor/models/page/page_model.dart';
import 'package:betternotes/features/editor/models/tools/eraser_tool.dart';
import 'package:betternotes/features/editor/models/tools/laser_tool.dart';
import 'package:betternotes/features/editor/models/tools/pen_tool.dart';
import 'package:betternotes/features/editor/models/tools/selection_tool.dart';
import 'package:betternotes/features/editor/models/tools/tool.dart';
import 'package:betternotes/features/editor/models/page/editor_setup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/global_providers.dart';
import '../models/tools/line_tool.dart';
import '../models/tools/shape_tool.dart';


class EditorSetupNotifier extends Notifier<List<EditorSetup>> {

  int currentEditorID = 0;

  //File file = File('/storage/emulated/0/betternotes/editor_setup.json');

  late final dir = ref.read(platformProvider).homeDirectory;
  late File file = File('$dir/config/editor_setup.json');

  bool loaded = false;


  @override
  List<EditorSetup> build() {
    _init();
    //print('editorseutp');
    return [EditorSetup()];
  }

  Future<void> _init() async {
    if (loaded) return;
    loaded = true;
    await loadSettings();
  }







  Future<void> setToolIndex(int editorIndex, int toolIndex) async {
    if (editorIndex < 0 || editorIndex >= state.length) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedTool', toolIndex);

    final newSetups = [...state];

    newSetups[editorIndex] = newSetups[editorIndex].copyWith(toolIndex: toolIndex);

    state = newSetups;
  }

  Future<void> setEraserWidth(int editorIndex, double width) async {
    if (editorIndex < 0 || editorIndex >= state.length) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('eraseWidth', width);


    final newSetups = [...state];

    newSetups[editorIndex] = newSetups[editorIndex].copyWith(eraserWidth: width);

    state = newSetups;
  }


  double getEraserWidth(int editorIndex) {
    final setups = [...state];
    final eraserWidth = setups[editorIndex].widths[setups[editorIndex].widthIndex];
    return eraserWidth;

  }


  Future<void> setColorIndex(int editorIndex, int index) async {
    if (editorIndex < 0 || editorIndex >= state.length) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedColorIndex', index);

    final newSetups = [...state];

    newSetups[editorIndex] = newSetups[editorIndex].copyWith(colorIndex: index);

    state = newSetups;
  }

  Future<void> setWidthIndex(int editorIndex, int index) async {
    if (editorIndex < 0 || editorIndex >= state.length) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedWidthIndex', index);

    final newSetups = [...state];

    newSetups[editorIndex] = newSetups[editorIndex].copyWith(widthIndex: index);

    state = newSetups;
  }

  Future<void> setSelectionShape(int editorIndex, int shape) async {
    if (editorIndex < 0 || editorIndex >= state.length) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectionShape', shape);

    final newSetups = [...state];

    newSetups[editorIndex] = newSetups[editorIndex].copyWith(selectionShape: shape);

    state = newSetups;
  }

  Future<void> setSelectionMode(int editorIndex, bool mode) async {
    if (editorIndex < 0 || editorIndex >= state.length) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('selectionMode', mode);
    final newSetups = [...state];
    newSetups[editorIndex] = newSetups[editorIndex].copyWith(selectionMode: mode);
    state = newSetups;
  }




  Future<void> setAmountOfColors(int editorIndex, int amount)async {
    if (editorIndex < 0 || editorIndex >= state.length) return;
    if (amount<1) {amount = 1;}
    List<Color> colors = state[editorIndex].colors;
    int colorIndex = state[editorIndex].colorIndex;
    //print(colors);
    if (amount>colors.length) {
      colors.addAll(List.filled(amount-colors.length, Colors.black));
      //print(colors);
    }
    else {
      colors.removeRange(amount, colors.length);
      if (state[editorIndex].colorIndex>amount-1){
        colorIndex = amount-1;
      }

    }
    state[editorIndex] = state[editorIndex].copyWith(colors: colors, colorIndex: colorIndex);

    //print(state[0].colorSelector);

    saveToJson();

  }

  Future<void> setAmountOfWidths(int editorIndex, int amount)async {
    if (editorIndex < 0 || editorIndex >= state.length) return;
    if (amount<1) {amount = 1;}
    List<double> widths = state[editorIndex].widths;
    //print(colors);
    int widthIndex = state[editorIndex].widthIndex;
    if (amount>widths.length) {
      widths.addAll(List.filled(amount-widths.length, 1.0));
      //print(colors);
    }
    else {
      widths.removeRange(amount, widths.length);
      if (state[editorIndex].widthIndex>amount-1){
        widthIndex = amount-1;
        //print(amount);
        //print("moving index...");

      }

    }
    state[editorIndex] = state[editorIndex].copyWith(widths: widths, widthIndex: widthIndex);

    //print(state[0].colorSelector);

    //print(state[editorIndex].widthIndex);
    saveToJson();
    //print('saved');

  }


  void setSpaces(int editorIndex, List<double> spaces){
    final newList = [...state];
    newList[editorIndex] = state[editorIndex].copyWith(spaces: spaces);
    state = newList;
    saveToJson();
    //print(state[editorIndex].spaces);
  }

  void setTools(int editorIndex, List<Tool> tools) {

    int toolIndex = state[editorIndex].toolIndex;
    if (toolIndex>tools.length-1){
      toolIndex = tools.length-1;
    }


    final newList = [...state]; // flache Kopie der Liste
    newList[editorIndex] = state[editorIndex].copyWith(tools: tools, toolIndex: toolIndex);
    state = newList; //new  reference
    saveToJson();
  }

  void setTool(int editorIndex, int toolIndex, Tool tool) {

    if (state[editorIndex].tools.length-1<toolIndex) return;

    List<Tool> newTools = state[editorIndex].tools;
    newTools[toolIndex] = tool;

    //int toolIndex = state[editorIndex].toolIndex;


    final newList = [...state]; // flat copy
    newList[editorIndex] = state[editorIndex].copyWith(tools: newTools);
    state = newList; // new reference
    saveToJson();
  }


  void setDefaultPage({required int editorIndex, Color? pageColor, double? pageWidth, double? pageHeight, double? verticalSpace, double? horizontalSpace, Color? backgroundStrokeColor, double? backgroundStrokeWidth}) {

    PageModel newDefaultPage = state[editorIndex].defaultPage;

    if (pageColor != null) newDefaultPage = newDefaultPage.copyWith(pageColor: pageColor);
    if (pageWidth != null) newDefaultPage = newDefaultPage.copyWith(pageWidth: pageWidth);
    if (pageHeight != null) newDefaultPage = newDefaultPage.copyWith(pageHeight: pageHeight);
    if (verticalSpace != null) newDefaultPage = newDefaultPage.copyWith(verticalSpaces: [verticalSpace]);
    if (horizontalSpace != null) newDefaultPage = newDefaultPage.copyWith(horizontalSpaces: [horizontalSpace]);

    horizontalSpace ??= newDefaultPage.horizontalSpaces.isNotEmpty ? newDefaultPage.horizontalSpaces.first : 0;
    verticalSpace ??= newDefaultPage.verticalSpaces.isNotEmpty ? newDefaultPage.verticalSpaces.first : 0;
    backgroundStrokeColor ??= newDefaultPage.backgroundStrokes.isNotEmpty ? newDefaultPage.backgroundStrokes.first.color : Colors.grey;
    backgroundStrokeWidth ??= newDefaultPage.backgroundStrokes.isNotEmpty ? newDefaultPage.backgroundStrokes.first.width : 0.4;


    newDefaultPage.setBackgroundStrokesBySpacing([horizontalSpace], [verticalSpace], backgroundStrokeColor, backgroundStrokeWidth);


    final newState = [...state];
    newState[editorIndex] = state[editorIndex].copyWith(defaultPage: newDefaultPage);

    state = newState;
    saveToJson();




  }





  Future<Map<String, dynamic>> loadConfig() async {
    await checkIfConfigFileExists();
    final String jsonString = await file.readAsString();
    return json.decode(jsonString);
  }

  Future<void> checkIfConfigFileExists() async {
    if (!await file.exists()) {
      print('toolbar.json nicht gefunden');
      await generateJson();
    }
  }


  Future<void> generateJson() async {

    final preset = [EditorSetup()];

    List<Tool> tools = [PenTool(), EraserTool(), SelectionTool(), LineTool(), ShapeTool(), LaserTool()];

    final jsonData = {
      'setups': preset.map((setup) {
        return {

          'selectorPools': [0,1,2,3],
          'toolsOld': [0,1,2,3,4,8,8,8],
          'tools': tools.map((tool) => tool.toJson()).toList(),
          'toolIndex': 0,
          'widths': [0.4, 1.2, 4.0],
          'widthIndex': 0,
          'colors': [Colors.black.value, Colors.blue.value, Colors.red.value, Colors.green.value, Colors.yellow.value],
          'colorIndex' : 0,
          'eraserWidth' :4.0,
          'selectionShape' : 0,
          'selectionMode' : false,
          'selectionColor' :  Colors.blue.value,
          'spaces' : [0.325, 0.25, 0.3,0.125],
          'defaultPage' : PageModel(strokes: [], pageHeight: 297, pageWidth: 210, backgroundStrokes: [], images: [], pageColor: Colors.white, tiles: []).toJson(),
        };
      }).toList(),
    };
    try {
      final dir = file.parent;

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await file.writeAsString(
        jsonEncode(jsonData),
        flush: true,
      );

    } catch (e) {
      print("Error creating json: $e");
    }
  }




  Future<void> saveToJson() async {

    final jsonData = {
      //'currentDocIndex': currentDocIndex,

      'setups': state.map((setup) {
        return {
          'selectorPools': setup.selectorPools,
          //'toolsOld': setup.toolsOld,
          'tools': setup.tools.map((tool) => tool.toJson()).toList(),
          'toolIndex': setup.toolIndex,
          'widths': setup.widths,
          'widthIndex': setup.widthIndex,
          'colors': setup.colors.map((c) => c.value).toList(),
          'colorIndex' : setup.colorIndex,
          'eraserWidth' : setup.eraserWidth,
          'selectionShape' : setup.selectionShape,
          'selectionMode' : setup.selectionMode,
          'selectionColor' :  setup.selectionColor.value,
          'spaces' : setup.spaces,
          'defaultPage' : setup.defaultPage.toJson(),
        };
      }).toList(),
    };

    await file.writeAsString(
      jsonEncode(jsonData),
      flush: true,
    );
  }





  Future<void> loadSettings() async {
    Map<String, dynamic> json = await loadConfig();

    try {
      await setStateFromJson(json);
    } catch (e, stackTrace) {
      print('Error loading config!: $e');
      print(stackTrace);
      print('Reseting Config...');

      await generateJson();
      await setStateFromJson(json);

    }

  }



  Future<void> setStateFromJson(Map<String, dynamic> json) async {
    final setupsJson = json['setups'] as List;

    final loadedSetups = await Future.wait(
      setupsJson.map((setupJson) async {
        //print(setupJson['defaultPage']);
        return EditorSetup(
          selectorPools: List<int>.from(setupJson['selectorPools']),
          tools: toolsFromJson(setupJson['tools']),
          toolIndex: setupJson['toolIndex'],
          widths: List<double>.from(setupJson['widths']),
          widthIndex: setupJson['widthIndex'],
          colors: (setupJson['colors'] as List).map((v) => Color(v)).toList(),
          colorIndex: setupJson['colorIndex'],
          eraserWidth: setupJson['eraserWidth'],
          selectionShape: setupJson['selectionShape'],
          selectionMode: setupJson['selectionMode'],
          selectionColor: Color(setupJson['selectionColor']),
          spaces: (setupJson['spaces'] as List).map((s) => (s as num).toDouble()).toList(),
          defaultPage: await PageModel.fromJson(setupJson['defaultPage']),
        );
      }),
    );

    state = loadedSetups;
  }



  List<Tool> toolsFromJson(List jsonList) {
    return jsonList.map<Tool>((json) {
      switch (json['type']) {
        case 'PenTool':
          return PenTool.fromJson(json);
        case 'EraserTool':
          return EraserTool.fromJson(json);
        case 'SelectionTool':
          return SelectionTool.fromJson(json);
        case 'LineTool':
          return LineTool.fromJson(json);
        case 'ShapeTool':
          return ShapeTool.fromJson(json);
        case 'LaserTool':
          return LaserTool.fromJson(json);
        default:
          return PenTool.fromJson(json);
      }
    }).toList();
  }









  List<EditorSetup> copyWith(List<EditorSetup> editors) {
    return editors;
  }


}