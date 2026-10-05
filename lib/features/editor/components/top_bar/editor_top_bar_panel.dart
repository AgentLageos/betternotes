import 'package:flutter/material.dart';
import 'package:betternotes/features/editor/components/top_bar/buttons/color_selector_bar.dart';
import 'package:betternotes/features/editor/components/top_bar/buttons/width_selector_bar.dart';
import 'package:betternotes/features/editor/components/top_bar/buttons/tool_selector_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betternotes/core/providers/global_providers.dart';
import '../../models/page/editor_setup.dart';


final buttonColor = Colors.greenAccent;



class EditorTopBarPanel extends ConsumerWidget implements PreferredSizeWidget {



  EditorTopBarPanel({super.key,});

  final height3 = 30.0;      //height of the lower container

  final editorIndex = 0;




  @override
  Widget build(BuildContext context, WidgetRef ref) {

    int docIndex = ref.read(documentsProvider.notifier).currentDocIndex;

    final double spacing = (MediaQuery.of(context).size.width)/80;

    final editorSetup = ref.watch(
      editorSetupProvider.select((list) => list[editorIndex]),
    );
    return Container(
            height: height3,
            color: Theme.of(context).colorScheme.surface,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                SizedBox(width: spacing),

                ...List.generate(editorSetup.selectorPools.length * 2 - 1, (index) {
                  if (index.isOdd) {
                    // separator  between spaces
                    return Text('  |  ', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20), );
                  }

                  final poolIndex = index ~/ 2;
                  final poolType = editorSetup.selectorPools[poolIndex];

                  return Expanded(
                    flex: _flexForPool(poolType, editorSetup),
                    child: buildSelectorPool(
                      poolType: poolType,
                      setup: editorSetup,
                      height: height3,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      ref: ref,
                      docIndex: docIndex,
                    ),
                  );
                }).toList(),

                SizedBox(width: spacing),
              ],
            ),
          );
  }



  int _flexForPool(int poolType, EditorSetup setup) {

    switch (poolType) {
      case 0: return (setup.spaces[0]*1000).toInt();
      case 1: return (setup.spaces[1]*1000).toInt();
      case 2: return (setup.spaces[2]*1000).toInt();
      case 3: return (setup.spaces[3]*1000).toInt();
      default: return 1;
    }
  }

  Widget buildSelectorPool({
    required int poolType,
    required EditorSetup setup,
    required double height,
    required Color backgroundColor,
    required WidgetRef ref,
    required int docIndex,
  }) {
    switch (poolType) {
      case 0: // tools
        return ToolSelectorBar(
          height: height,
          backgroundColor: backgroundColor,
        );
      case 1: // widths
        return StrokeWidthSelectorBar(
          height: height,
          onStrokeWidthSelected: (width) {
            //print("StrokeWidth: $width");
          },
        );
      case 2: // colors
        return ColorSelectorBar(
          height: height,
          backgroundColor: backgroundColor,
          onColorSelected: (color) {
            //print("Farbe ausgewählt: $color");
          },
        );
      case 3: // undo/redo
        return ListView(

          scrollDirection: Axis.horizontal,
          //padding: const EdgeInse`ts.symmetric(horizontal: 10),
          children: [
            UndoButton(
              onPressed: () {ref.read(documentsProvider.notifier).undo(docIndex);},
          ),
          const SizedBox(width: 5),
          RedoButton(
            onPressed: () {
              ref.read(documentsProvider.notifier).redo(docIndex);
            },
          ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }


  @override
  Size get preferredSize => Size.fromHeight(height3);



}



































class ColoredCircleButton extends StatelessWidget {   //widget for displaying colored button for color picker
  final Color color;
  final VoidCallback? onPressed;
  final String snackBarText;

  const ColoredCircleButton({
    Key? key,
    required this.color,
    this.onPressed,
    this.snackBarText = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed ??
              () {
            if (snackBarText.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(snackBarText)),
              );
            }
          },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      child: Icon(
        Icons.circle,
        color: color,
      ),
    );
  }





}

class PenButton extends StatelessWidget {   //widget for displaying colored button for color picker

  final VoidCallback? onPressed;
  final String snackBarText;

  const PenButton({
    Key? key,
    this.onPressed,
    this.snackBarText = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed ??
              () {
            if (snackBarText.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(snackBarText)),
              );
            }
          },
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      child: Icon(
        Icons.edit,
        color: Colors.black,
      ),
    );
  }
}

class UndoButton extends StatelessWidget {   //widget for displaying colored button for color picker
  final VoidCallback? onPressed;
  final String snackBarText;



  const UndoButton({
    Key? key,
    this.onPressed,
    this.snackBarText = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return ElevatedButton(
      onPressed: onPressed ??
              () {
            if (snackBarText.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(snackBarText)),
              );
            }
          },
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      child: Icon(
        Icons.undo,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class RedoButton extends StatelessWidget {   //widget for displaying colored button for color picker
  final VoidCallback? onPressed;
  final String snackBarText;

  const RedoButton({
    Key? key,
    this.onPressed,
    this.snackBarText = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed ??
              () {
            if (snackBarText.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(snackBarText)),
              );
            }
          },
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      child: Icon(
        Icons.redo,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}



