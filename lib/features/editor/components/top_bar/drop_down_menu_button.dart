import 'package:flutter/material.dart';
import 'package:betternotes/l10n/app_localizations.dart';

class DropDownMenuButton extends StatefulWidget {
  final void Function(String) onItemSelected;

  const DropDownMenuButton({
    Key? key,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  _DropDownMenuButtonState createState() => _DropDownMenuButtonState();
}

class _DropDownMenuButtonState extends State<DropDownMenuButton> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  void _toggleDropdown() {
    if (_overlayEntry == null) {
      _showDropdown();
    } else {
      _removeDropdown();
    }
  }

  void _showDropdown() {
    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;

    const dropdownMaxHeight = 300.0;
    final dropdownWidth = screenWidth * 0.3;


    double left = offset.dx;
    if (left + dropdownWidth > screenWidth) {
      left = screenWidth - dropdownWidth - 8;
    }
    left = left.clamp(0.0, screenWidth - dropdownWidth);

    final top = offset.dy + size.height;

    final text = AppLocalizations.of(context)!;


    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeDropdown,
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: dropdownWidth,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(

                  constraints: BoxConstraints(
                    maxHeight: dropdownMaxHeight,
                  ),
                  child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          //TODO REIMPLEMENT ME
                          //ListTile(leading: Icon(Icons.sticky_note_2_outlined), title: Text(text.page_setup), onTap: () {widget.onItemSelected('pageSetup');_removeDropdown();},),
                          //Divider(height: 1, color: Colors.grey[300]),
                          ListTile(leading: Icon(Icons.image_outlined), title: Text(text.import_image), onTap: () {widget.onItemSelected('importImage');_removeDropdown();},),
                          //Divider(height: 1, color: Colors.grey[300]),
                          //ListTile(leading: Icon(Icons.access_alarm),  title: Text('PLACEHOLDER 3'),onTap: () {widget.onItemSelected('PLACEHOLDER 3');_removeDropdown();},),
                        ],
                      )
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context)?.insert(_overlayEntry!);
  }

  void _removeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton(
        key: _buttonKey,
        onPressed: _toggleDropdown,
        icon: Icon(Icons.more_horiz, color: Theme.of(context).colorScheme.onPrimary,),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      )

    );
  }
}