
import 'package:betternotes/core/utils/build_color_tile.dart';
import 'package:betternotes/features/editor/models/page/page_model.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betternotes/core/providers/global_providers.dart';

import 'package:betternotes/l10n/app_localizations.dart';



class PageSetupMenu extends ConsumerStatefulWidget {
  final void Function(String) onSelected;

  const PageSetupMenu({super.key, required this.docID, required this.onSelected});

  final int docID;

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
    // currentPageIndex is a position in the page list; look the page up by ID.
    final doc = ref.read(documentProvider(widget.docID));
    final page = doc.currentPage ?? doc.defaultPage;

    heightController = TextEditingController(text: page.pageHeight.toString());
    widthController = TextEditingController(text: page.pageWidth.toString());
    vertSpacingController = TextEditingController();
    horiSpacingController = TextEditingController();
    newColor = page.pageColor;
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
    final doc = ref.read(documentProvider(widget.docID));
    final page = doc.currentPage ?? doc.defaultPage;
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
                          Expanded(child: Text('    ${text.height}', style: TextStyle(fontSize: 16))),
                          SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: heightController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: page.pageHeight.toString(),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Expanded(child: Text('    ${text.width}', style: TextStyle(fontSize: 16))),
                          SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: widthController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: page.pageWidth.toString(),
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
                          Expanded(child: Text(text.vertical_space, style: TextStyle(fontSize: 16))),
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
                          Expanded(child: Text(text.horizontal_space, style: TextStyle(fontSize: 16))),
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

                      buildColorTile(context: context, label: text.background_color, color: newColor, onColorPicked: (color) { setState(() {
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
                            await _applyToAll(page);
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
                            _apply(page);
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

  /// Applies the dialog values to all loaded pages. [page] is the current page.
  Future<void> _applyToAll(PageModel page) async {
    final notifier = ref.read(documentProvider(widget.docID).notifier);
    final double? height = double.tryParse(heightController.text);
    final double? width = double.tryParse(widthController.text);
    double vert = double.tryParse(vertSpacingController.text) ?? 0;
    double hori = double.tryParse(horiSpacingController.text) ?? 0;

    if (height == null || width == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.invalid_input)),);
      return;
    }
    await notifier.setAllPageSizes(width, height);

    if (vert > 0 || hori > 0) {
      await notifier.setAllBackgroundSpacing([hori], [vert], Colors.grey, 0.4);
    }

    if (newColor != page.pageColor) {
      notifier.setAllPageColors(newColor);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Applies the dialog values to the current page [page].
  Future<void> _apply(PageModel page) async {
    final notifier = ref.read(documentProvider(widget.docID).notifier);
    final double? height = double.tryParse(heightController.text);
    final double? width = double.tryParse(widthController.text);
    double vert = double.tryParse(vertSpacingController.text) ?? 0;
    double hori = double.tryParse(horiSpacingController.text) ?? 0;

    if (height == null || width == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.invalid_input)),);
      return;
    }
    await notifier.setPageSize(page.pageID, width, height);

    if (vert > 0 || hori > 0) {
      await notifier.setBackgroundSpacing(page.pageID, [hori], [vert], Colors.grey, 0.4);
    }

    if (newColor != page.pageColor) {
      notifier.setPageColor(page.pageID, newColor);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

