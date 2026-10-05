import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/providers/global_providers.dart';
import 'package:betternotes/l10n/app_localizations.dart';

class StrokeWidthSelectorBar extends ConsumerStatefulWidget {
  final double height;
  final void Function(double) onStrokeWidthSelected;

  const StrokeWidthSelectorBar({
    super.key,
    required this.height,
    required this.onStrokeWidthSelected,
  });

  @override
  ConsumerState<StrokeWidthSelectorBar> createState() => _StrokeWidthSelectorBarState();


}

class _StrokeWidthSelectorBarState extends ConsumerState<StrokeWidthSelectorBar> {
  List<double> strokeWidths = [0.4, 1.0, 2.0, 4.0, 8.0, 10.0];
  int selectedIndex = 0;
  final editorIndex = 0;

  @override
  void initState() {
    super.initState();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        //selectedIndex = context.read<GlobalState>().selectedStrokeWidthIndex;       //overwrite colors and currently selected with global_state
        //strokeWidths = context.read<GlobalState>().strokeWidths;
        selectedIndex =ref.read(editorSetupProvider.select((editors) => editors[editorIndex].widthIndex));
        strokeWidths = ref.read(editorSetupProvider.select((editors) => editors[editorIndex].widths));
      });
    });
  }

  Future<void> _pickStrokeWidth(int index) async {

    final text = AppLocalizations.of(context)!;

    double tempWidth = strokeWidths[index];


    double? picked = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(text.adjust_stroke_width),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: tempWidth,
                    min: 0.2,
                    max: 10.0,
                    divisions: 49,
                    label: '${tempWidth.toStringAsFixed(1)}',
                    onChanged: (v) {
                      setDialogState(() => tempWidth = v);
                    },
                  ),
                  Container(
                    height: 40,
                    width: 100,
                    alignment: Alignment.center,
                    child: CustomPaint(
                      painter: StrokeWidthPreviewPainter(tempWidth),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(text.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, tempWidth);
                //Provider.of<GlobalState>(context, listen: false).setStrokeWidths(strokeWidths);     //globally set strokeWidths
              },
              child: Text(text.apply),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      setState(() {
        strokeWidths[index] = picked;
      });
      if (index == selectedIndex) {
        widget.onStrokeWidthSelected(picked);
        //Provider.of<GlobalState>(context, listen: false).setStrokeWidth(strokeWidths[index]);     //globally set current strokeWidth
        //Provider.of<GlobalState>(context, listen: false).setSelectedStrokeWidthIndex(index);        //globally set currently selected strokewidth button
      }
    }
  }




  void _onTap(int index) {
    setState(() {
      selectedIndex = index;
    });
    widget.onStrokeWidthSelected(strokeWidths[index]);

    ref.read(editorSetupProvider.notifier).setWidthIndex(editorIndex, index);
    //Provider.of<GlobalState>(context, listen: false).setStrokeWidth(strokeWidths[index]);     //globally set current strokeWidth
    //Provider.of<GlobalState>(context, listen: false).setSelectedStrokeWidthIndex(index);        //globally set currently selected strokewidth button
  }

  @override
  Widget build(BuildContext context) {


    return Container(
      height: widget.height,
      //color: Theme.of(context).colorScheme.surface,
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: strokeWidths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          final strokeWidth = strokeWidths[index];
          final radius = 3+3*strokeWidth;
          return GestureDetector(
            onTap: () => _onTap(index),
            onLongPress: () => _pickStrokeWidth(index),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Container(
                width: radius,
                height: radius,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class StrokeWidthPreviewPainter extends CustomPainter {       //for previewing the width in the pop up window
  final double strokeWidth;

  StrokeWidthPreviewPainter(this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3+3*strokeWidth;
    canvas.drawLine(
      Offset(size.width / 2, size.height / 2),
      Offset(size.width / 2, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant StrokeWidthPreviewPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth;
}
