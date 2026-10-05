import 'dart:math';

import 'package:betternotes/core/utils/build_color_tile.dart';
import 'package:betternotes/features/editor/models/page/document_model.dart';
import 'package:flutter/material.dart';
import 'package:betternotes/features/editor/models/page/page_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betternotes/core/providers/global_providers.dart';

import 'package:betternotes/l10n/app_localizations.dart';




final docID = 0;

class PageSetupMenu extends ConsumerStatefulWidget {
  final void Function(String) onSelected;

  PageSetupMenu({Key? key, required this.onSelected}) : super(key: key);

  @override
  ConsumerState<PageSetupMenu> createState() => _PageSetupMenuState();
}

class _PageSetupMenuState extends ConsumerState<PageSetupMenu> {
  late TextEditingController heightController;
  late TextEditingController widthController;
  late TextEditingController vertSpacingController;
  late TextEditingController horiSpacingController;
  late Color newColor;

  @override
  void initState() {
    super.initState();
    final doc = ref.read(documentsProvider)[0];
    final pageIndex = doc.currentPageIndex;

    heightController =
        TextEditingController(text: doc.pages[pageIndex].pageHeight.toString());
    widthController =
        TextEditingController(text: doc.pages[pageIndex].pageWidth.toString());
    vertSpacingController = TextEditingController();
    horiSpacingController = TextEditingController();
    newColor = doc.pages[pageIndex].pageColor;
  }

  @override
  void dispose() {
    heightController.dispose();
    widthController.dispose();
    vertSpacingController.dispose();
    horiSpacingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.read(documentsProvider)[0];
    final pageIndex = doc.currentPageIndex;
    final text = AppLocalizations.of(context)!;

    final mq = MediaQuery.of(context);
    final double dialogMaxHeight = mq.size.height * 0.9;
    final double dialogMaxWidth = mq.size.width * 0.6;

    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: dialogMaxHeight,
            maxWidth: dialogMaxWidth,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
                child: Text(text.page_setup, style: TextStyle(fontSize: 20)),
              ),
              Divider(height: 1),


              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(children: [Expanded(child: Text(text.page_size, style: TextStyle(fontSize: 16))),]),

                      Row(
                        children: [
                          Expanded(child: Text('    ' + text.height, style: TextStyle(fontSize: 16))),
                          SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: heightController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: doc.pages[pageIndex].pageHeight.toString(),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Expanded(child: Text('    ' + text.width, style: TextStyle(fontSize: 16))),
                          SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: widthController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: doc.pages[pageIndex].pageWidth.toString(),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),

                      ListTile(title: Text('')),
                      Row(children: [Expanded(child: Text(text.background, style: TextStyle(fontSize: 16))),]),

                      Row(
                        children: [
                          Expanded(child: Text('Vert. Lines Space', style: TextStyle(fontSize: 16))),
                          SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: vertSpacingController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '5',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Expanded(child: Text('Hori. Lines Space', style: TextStyle(fontSize: 16))),
                          SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: horiSpacingController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '5',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Color picker
                      /*
                      InlineColorPicker(
                        initialColor: newColor,
                        onChanged: (color) {
                          newColor = color;
                        },
                      ),

                       */

                      buildColorTile(context: context, label: "background color", color: newColor, onColorPicked: (color) { setState(() {
                       newColor = color;
                      });}),



                      ListTile(title: Text('Info 2')),
                    ],
                  ),
                ),
              ),

              Divider(height: 1),


              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await _applyToAll(doc, pageIndex);
                          },
                          child: Text(text.apply_to_all_pages),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(text.cancel),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _apply(doc, pageIndex);
                          },
                          child: Text(text.apply),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyToAll(DocumentModel doc, int pageIndex) async {
    final double? height = double.tryParse(heightController.text);
    final double? width = double.tryParse(widthController.text);
    double vert = double.tryParse(vertSpacingController.text) ?? 0;
    double hori = double.tryParse(horiSpacingController.text) ?? 0;

    //PageModel newPage = doc.pages[pageIndex];

    if (height != null && width != null) {
      //newPage = newPage.copyWith(pageWidth: width, pageHeight: height);
      await ref.read(documentsProvider.notifier).setAllHeights(0, height);
      await ref.read(documentsProvider.notifier).setAllWidths(0, width);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid Input')),);
      return;
    }

    print("hi");

    if (vert > 0 || hori > 0) {
      //print(newPage)
      //newPage.setBackgroundStrokesBySpacing([hori], [vert], Colors.grey, 0.4);
      await ref.read(documentsProvider.notifier).setAllBackgroundStrokesExecute(docID, [hori], [vert], Colors.grey, 0.4);
    }

    if (newColor != doc.pages[pageIndex].pageColor) {
      //newPage = newPage.copyWith(pageColor: newColor);
      ref.read(documentsProvider.notifier).setAllPageColors(docID, newColor);
    }


    //newPage.initializeTiles();

    //ref.read(documentsProvider.notifier).setAllPages(docID, newPage);
    Navigator.of(context).pop();
  }







  Future<void> _apply(DocumentModel doc, int pageIndex) async {
    final double? height = double.tryParse(heightController.text);
    final double? width = double.tryParse(widthController.text);
    double vert = double.tryParse(vertSpacingController.text) ?? 0;
    double hori = double.tryParse(horiSpacingController.text) ?? 0;

    PageModel newPage = doc.pages[pageIndex];


    if (height != null && width != null) {
      //newPage = newPage.copyWith(pageWidth: width, pageHeight: height);
      ref.read(documentsProvider.notifier).setPageWidth(docID, pageIndex, width);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid Input')),);
      return;
    }

    if (vert > 0 || hori > 0) {
      //newPage.setBackgroundStrokesBySpacing([hori], [vert], Colors.grey, 0.4);
      ref.read(documentsProvider.notifier).setBackgroundStrokesExecute(docID, doc.pages[pageIndex].pageID, [hori], [vert], Colors.grey, 0.4);
      //ref.read(documentsProvider.notifier).setBackgroundStrokesExecute(0, doc.pages[pageIndex].pageID, hori, vert, Colors.grey, 0.4);
    }

    if (newColor != doc.pages[pageIndex].pageColor) {
      //newPage = newPage.copyWith(pageColor: newColor);
      ref.read(documentsProvider.notifier).setPageColor(0, pageIndex, newColor);
    }


    //await newPage.initializeTiles();



    //ref.read(documentsProvider.notifier).setPage(docID, doc.pages[pageIndex].pageID, newPage);
    Navigator.of(context).pop();

  }
}


enum _ActiveZone {
  none,
  wheel,
  value,
}

class InlineColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onChanged;

  const InlineColorPicker({
    super.key,
    required this.initialColor,
    required this.onChanged,
  });

  @override
  State<InlineColorPicker> createState() => _InlineColorPickerState();
}

class _InlineColorPickerState extends State<InlineColorPicker> {
  late HSVColor _hsv;
  _ActiveZone _activeZone = _ActiveZone.none;

  final GlobalKey _wheelKey = GlobalKey();
  final GlobalKey _valueKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  void _notify() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();

    final text = AppLocalizations.of(context)!;

    return ExpansionTile(
      leading: const Icon(Icons.palette),
      title: Text(text.background_color),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: GestureDetector(
                  key: _wheelKey,
                  behavior: HitTestBehavior.opaque,
                  onPanDown: _onWheelDown,
                  onPanUpdate: _onWheelUpdate,
                  onPanEnd: (_) => _activeZone = _ActiveZone.none,
                  child: CustomPaint(
                    painter: _ColorWheelPainter(_hsv),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            GestureDetector(
              key: _valueKey,
              behavior: HitTestBehavior.opaque,
              onPanDown: _onValueDown,
              onPanUpdate: _onValueUpdate,
              onPanEnd: (_) => _activeZone = _ActiveZone.none,
              child: _ValueBar(hsv: _hsv),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),

        const SizedBox(height: 16),


        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(text.old),
                  const SizedBox(height: 4),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.initialColor,
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                children: [
                  Text(text.new_),
                  const SizedBox(height: 4),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () {
              widget.onChanged(color);
            },
            child: Text(text.set_new_color),
          ),
        ),
      ],
    );
  }


  void _onWheelDown(DragDownDetails d) {
    final box = _wheelKey.currentContext!.findRenderObject() as RenderBox;
    final pos = box.globalToLocal(d.globalPosition);

    if (_isInsideWheel(pos, box.size)) {
      _activeZone = _ActiveZone.wheel;
      _updateWheel(pos, box.size);
    } else {
      _activeZone = _ActiveZone.none;
    }
  }

  void _onWheelUpdate(DragUpdateDetails d) {
    if (_activeZone != _ActiveZone.wheel) return;

    final box = _wheelKey.currentContext!.findRenderObject() as RenderBox;
    final pos = box.globalToLocal(d.globalPosition);
    _updateWheel(pos, box.size);
  }

  bool _isInsideWheel(Offset pos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    return (pos - center).distance <= size.width / 2;
  }

  void _updateWheel(Offset pos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final delta = pos - center;

    final angle = (atan2(delta.dy, delta.dx) * 180 / pi + 360) % 360;
    final saturation =
    (delta.distance / (size.width / 2)).clamp(0.0, 1.0);

    _hsv = _hsv.withHue(angle).withSaturation(saturation);
    _notify();
  }


  void _onValueDown(DragDownDetails d) {
    _activeZone = _ActiveZone.value;
    _updateValue(d.globalPosition);
  }

  void _onValueUpdate(DragUpdateDetails d) {
    if (_activeZone != _ActiveZone.value) return;
    _updateValue(d.globalPosition);
  }

  void _updateValue(Offset d) {
    final box = _valueKey.currentContext!.findRenderObject() as RenderBox;
    final pos = box.globalToLocal(d);

    final v = 1 - (pos.dy / box.size.height).clamp(0.0, 1.0);
    _hsv = _hsv.withValue(v);
    _notify();
  }
}



class _ColorWheelPainter extends CustomPainter {
  final HSVColor hsv;

  _ColorWheelPainter(this.hsv);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Colors.red,
          Colors.yellow,
          Colors.green,
          Colors.cyan,
          Colors.blue,
          Colors.purple,
          Colors.red,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final angle = hsv.hue * pi / 180;
    final r = hsv.saturation * radius;

    final marker = Offset(
      center.dx + cos(angle) * r,
      center.dy + sin(angle) * r,
    );

    canvas.drawCircle(marker, 6, Paint()..color = Colors.white);
    canvas.drawCircle(
      marker,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_) => true;
}




class _ValueBar extends StatelessWidget {
  final HSVColor hsv;

  const _ValueBar({required this.hsv});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 180,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    HSVColor.fromAHSV(
                      1,
                      hsv.hue,
                      hsv.saturation,
                      1,
                    ).toColor(),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: (1 - hsv.value) * 180 - 2,
            left: -4,
            right: -4,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

