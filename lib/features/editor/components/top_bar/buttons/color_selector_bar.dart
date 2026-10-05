import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betternotes/core/providers/global_providers.dart';

import 'package:betternotes/l10n/app_localizations.dart';

import '../../../../../core/components/color_picker.dart';

class ColorSelectorBar extends ConsumerStatefulWidget {
  final double height;
  final Color backgroundColor;
  final void Function(Color) onColorSelected;

  const ColorSelectorBar({
    super.key,
    required this.height,
    required this.backgroundColor,
    required this.onColorSelected,
  });

  @override
  ConsumerState<ColorSelectorBar> createState() => _ColorSelectorBarState();
}

class _ColorSelectorBarState extends ConsumerState<ColorSelectorBar> {
  List<Color> colors = [
    Colors.black,
  ];

  final int editorIndex = 0;

  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        selectedIndex =ref.read(editorSetupProvider.select((editors) => editors[editorIndex].colorIndex));
        colors = ref.read(editorSetupProvider.select((editors) => editors[editorIndex].colors));
        //selectedIndex = context.read<GlobalState>().selectedColorIndex;       //overwrite colors and currently selected with global_state
        //colors = context.read<GlobalState>().colors;

      });
    });
  }

  Future<void> _pickColor(int index) async {

    final text = AppLocalizations.of(context)!;

    Color? picked = await showDialog<Color>(
      context: context,
      builder: (context) {
        Color tempColor = colors[index];
        return AlertDialog(
          title: Text(text.select_color),
          content: SingleChildScrollView(
            child: ColorPicker(
              initialColor: tempColor,
              onColorChanged: (color) {
                tempColor = color;

              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(text.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, tempColor);

                //Provider.of<GlobalState>(context, listen: false).setDrawingColors(colors);        //globally set colors in the color selection bar
              },
              child: Text(text.apply),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      setState(() {
        colors[index] = picked;
      });
      if (index == selectedIndex) {
        widget.onColorSelected(picked);
        //Provider.of<GlobalState>(context, listen: false).setStrokeColor(picked);        //globally set current pen color
        //Provider.of<GlobalState>(context, listen: false).setSelectedColorIndex(index);        //globally set currently selected color button
      }
    }
  }

  void _onTap(int index) {
    setState(() {
      selectedIndex = index;
    });
    widget.onColorSelected(colors[index]);

    ref.read(editorSetupProvider.notifier).setColorIndex(editorIndex, index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      //color: widget.backgroundColor,
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: colors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final color = colors[index];
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: () => _onTap(index),
            //onLongPress: () => _pickColor(index),
            onLongPress: () async {
              final picked = await pickColor(context, color);
              if (picked != null) {
                setState(() {
                  colors[index] = picked;
                });
                if (index == selectedIndex) {
                  widget.onColorSelected(picked);
                }
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}



class ColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const ColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  double red = 0, green = 0, blue = 0;

  @override
  void initState() {
    super.initState();
    red = widget.initialColor.red.toDouble();
    green = widget.initialColor.green.toDouble();
    blue = widget.initialColor.blue.toDouble();
  }

  void _updateColor() {
    final color = Color.fromARGB(255, red.toInt(), green.toInt(), blue.toInt());
    widget.onColorChanged(color);

  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: red,
          max: 255,
          activeColor: Colors.red,
          label: "Red",
          onChanged: (v) {
            setState(() => red = v);
            _updateColor();
          },
        ),
        Slider(
          value: green,
          max: 255,
          activeColor: Colors.green,
          label: "Green",
          onChanged: (v) {
            setState(() => green = v);
            _updateColor();
          },
        ),
        Slider(
          value: blue,
          max: 255,
          activeColor: Colors.blue,
          label: "Blue",
          onChanged: (v) {
            setState(() => blue = v);
            _updateColor();
          },
        ),
        Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.fromARGB(255, red.toInt(), green.toInt(), blue.toInt()),
            border: Border.all(color: Colors.black),
          ),
        )
      ],
    );
  }
}