import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'package:betternotes/core/utils/color_channels.dart';

Future<Color?> pickColor(BuildContext context, Color current) async {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorPickerBaseDialog(initialColor: current),
  );
}

class _ColorPickerBaseDialog extends StatefulWidget {
  final Color initialColor;
  const _ColorPickerBaseDialog({required this.initialColor});

  @override
  State<_ColorPickerBaseDialog> createState() => _ColorPickerBaseDialogState();
}

class _ColorPickerBaseDialogState extends State<_ColorPickerBaseDialog>
    with SingleTickerProviderStateMixin {
  late Color selectedColor;
  late TabController tabController;
  int initialTab = 0;

  late final language = AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    selectedColor = widget.initialColor;
    tabController = TabController(length: 4, vsync: this, initialIndex: 0);
  }


  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color oldColor = widget.initialColor;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: FractionallySizedBox(
        widthFactor: 0.8,
        heightFactor: 0.8,
        child: Column(
          children: [
            TabBar(
              controller: tabController,
              tabs: [
                Tab(text: language.palette),
                Tab(text: language.rgba),
                Tab(text: language.wheel),
                Tab(text: language.hex_code),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _paletteTab(),
                  _rgbaTab(),
                  _colorWheelTab(),
                  Center(child: Text(language.coming_soon)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _colorPreview(language.old, oldColor),
                  _colorPreview(language.new_, selectedColor),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(language.cancel)),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(selectedColor),
                    child: Text(language.apply)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _colorPreview(String label, Color color) {
    return Column(
      children: [
        Text(label),
        const SizedBox(height: 4),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  // ---------------------- Fertige Word/Office-Palette ----------------------
  Widget _paletteTab() {


    int columns = 24;
    int rows = 12;

    List<Color> paletteColors = [];

    // The first 2 columns are reserved for a clean grayscale gradient.
    // The remaining 22 columns hold the full color spectrum.
    int grayScaleColumns = 2;
    int colorColumns = columns - grayScaleColumns;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        if (col < grayScaleColumns) {
          // --- GRAYSCALE AREA (left) ---
          // Smooth gradient from pure white (top left) to pure black (bottom left)
          double value = 1.0 - (row / (rows - 1));

          // With 2 gray columns, the second one is slightly darker for more nuances
          if (col == 1 && row < rows - 1) {
            value = (value - 0.05).clamp(0.0, 1.0);
          }

          paletteColors.add(Color.fromRGBO(
            (value * 255).round(),
            (value * 255).round(),
            (value * 255).round(),
            1.0,
          ));
        } else {
          // --- FARB-BEREICH (Rechts) ---
          int adjustedCol = col - grayScaleColumns;

          // 1. Hue: runs from 0 to 360 degrees across the remaining columns
          double hue = (adjustedCol / colorColumns) * 360;

          // 2. Saturation & value (brightness)
          double saturation;
          double value;

          // Upper half: from pastel/whitish to full color
          if (row < rows / 2) {
            saturation = row / (rows / 2 - 1); // 0.0 to 1.0
            value = 1.0; // Volle Helligkeit
          }
          // Lower half: from full color to black
          else {
            saturation = 1.0; // full saturation
            value = 1.0 - ((row - (rows / 2) + 1) / (rows / 2)); // 1.0 to 0.0
          }

          paletteColors.add(HSVColor.fromAHSV(1.0, hue, saturation, value).toColor());
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double tileWidth = constraints.maxWidth / columns;
        double tileHeight = constraints.maxHeight / rows;

        // Safe lookup of the selected color
        int selectedIndex = paletteColors.indexWhere((c) => c.toARGB32() == selectedColor.toARGB32());

        return GestureDetector(
          onTapDown: (details) => _updateColorFromGrid(details.localPosition, tileWidth, tileHeight, columns, rows, paletteColors),
          onPanUpdate: (details) => _updateColorFromGrid(details.localPosition, tileWidth, tileHeight, columns, rows, paletteColors),
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                // Gitter zeichnen
                for (int row = 0; row < rows; row++)
                  for (int col = 0; col < columns; col++)
                    Positioned(
                      left: col * tileWidth,
                      top: row * tileHeight,
                      width: tileWidth,
                      height: tileHeight,
                      child: Container(color: paletteColors[row * columns + col]),
                    ),

                // Auswahl-Rahmen
                if (selectedIndex != -1)
                  Positioned(
                    left: (selectedIndex % columns) * tileWidth,
                    top: (selectedIndex ~/ columns) * tileHeight,
                    width: tileWidth,
                    height: tileHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          // Dynamic border (white on dark colors, black on light ones)
                          color: ThemeData.estimateBrightnessForColor(paletteColors[selectedIndex]) == Brightness.light
                              ? Colors.black
                              : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _rgbaTab() {
    return Column(
      children: [
        // R-Slider
        Slider(
          value: selectedColor.red8.toDouble(),
          min: 0,
          max: 255,
          activeColor: Colors.red,
          inactiveColor: Colors.red.withValues(alpha: 0.3),
          onChanged: (v) {
            setState(() {
              selectedColor = selectedColor.withRed(v.toInt());
            });
          },
        ),
        // G-Slider
        Slider(
          value: selectedColor.green8.toDouble(),
          min: 0,
          max: 255,
          activeColor: Colors.green,
          inactiveColor: Colors.green.withValues(alpha: 0.3),
          onChanged: (v) {
            setState(() {
              selectedColor = selectedColor.withGreen(v.toInt());
            });
          },
        ),
        // B-Slider
        Slider(
          value: selectedColor.blue8.toDouble(),
          min: 0,
          max: 255,
          activeColor: Colors.blue,
          inactiveColor: Colors.blue.withValues(alpha: 0.3),
          onChanged: (v) {
            setState(() {
              selectedColor = selectedColor.withBlue(v.toInt());
            });
          },
        ),
        // A-Slider
        Slider(
          value: selectedColor.a,
          min: 0,
          max: 1,
          activeColor: Colors.grey,
          inactiveColor: Colors.grey.withValues(alpha: 0.3),
          onChanged: (v) {
            setState(() {
              selectedColor = selectedColor.withValues(alpha: v);
            });
          },
        ),
      ],
    );
  }


  void _updateColorFromGrid(Offset position, double tileWidth, double tileHeight, int columns, int rows, List<Color> paletteColors) {
    int col = (position.dx ~/ tileWidth).clamp(0, columns-1);
    int row = (position.dy ~/ tileHeight).clamp(0, rows-1);

    setState(() {
      selectedColor = paletteColors[row*columns + col];
    });
  }



  Widget _colorWheelTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = size.center(Offset.zero);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handleDown(d.localPosition, center, size),
          onPanUpdate: (d) => _handleMove(d.localPosition, center, size),
          onPanEnd: (_) => _mode = "none",
          child: CustomPaint(
            size: size,
            painter: _ColorWheelPainter(
              hue: _hue,
              saturation: _saturation,
              value: _value,
            ),
          ),
        );
      },
    );
  }

  late double _hue = HSVColor.fromColor(selectedColor).hue;
  late double _saturation = HSVColor.fromColor(selectedColor).saturation;
  late double _value = HSVColor.fromColor(selectedColor).value;


  String _mode = "none"; // "hue" | "sv"
  void _handleDown(Offset pos, Offset center, Size size) {
    _mode = _detectMode(pos, center, size);
    _handleMove(pos, center, size);
  }


  void _handleMove(Offset pos, Offset center, Size size) {
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;


    final radius = min(size.width, size.height) / 2;
    final ringWidth = radius * 0.18;
    final innerRadius = radius - ringWidth;

    final boxSize = innerRadius * 1.4;
    final boxLeft = center.dx - boxSize / 2;
    final boxTop = center.dy - boxSize / 2;

    // 🌈 HUE MODE
    if (_mode == "hue") {
      final angle = atan2(dy, dx);

      setState(() {
        _hue = (angle * 180 / pi + 360) % 360;
        selectedColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _value,).toColor();
      });
      return;
    }

    // 🎨 SV MODE
    if (_mode == "sv") {
      final x = (pos.dx - boxLeft) / boxSize;
      final y = (pos.dy - boxTop) / boxSize;

      setState(() {
        _saturation = x.clamp(0.0, 1.0);
        _value = (1 - y).clamp(0.0, 1.0);
        selectedColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _value,).toColor();
      });
    }
  }

  String _detectMode(Offset pos, Offset center, Size size) {
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;

    final distance = sqrt(dx * dx + dy * dy);

    final radius = min(size.width, size.height) / 2;
    final ringWidth = radius * 0.18;
    final innerRadius = radius - ringWidth;

    final boxSize = innerRadius * 1.4;
    final boxLeft = center.dx - boxSize / 2;
    final boxTop = center.dy - boxSize / 2;

    final inRing = distance >= innerRadius && distance <= radius;

    final inBox =
        pos.dx >= boxLeft &&
            pos.dx <= boxLeft + boxSize &&
            pos.dy >= boxTop &&
            pos.dy <= boxTop + boxSize;

    if (inRing) return "hue";
    if (inBox) return "sv";
    return _mode; // bleibt wie vorher
  }






}


class _ColorWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _ColorWheelPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2;

    final ringWidth = radius * 0.18;
    final innerRadius = radius - ringWidth;

    // 🌈 HUE RING
    final rect = Rect.fromCircle(center: center, radius: radius);

    final sweep = SweepGradient(
      colors: List.generate(
        360,
            (i) => HSVColor.fromAHSV(1, i.toDouble(), 1, 1).toColor(),
      ),
    );

    final ringPaint = Paint()
      ..shader = sweep.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth;

    canvas.drawCircle(center, radius - ringWidth / 2, ringPaint);

    // 🎨 INNER SV BOX
    final boxSize = innerRadius * 1.4;

    final boxRect = Rect.fromCenter(
      center: center,
      width: boxSize,
      height: boxSize,
    );

    // Saturation gradient (white → hue)
    final satShader = LinearGradient(
      colors: [
        Colors.white,
        HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
      ],
    ).createShader(boxRect);

    canvas.drawRect(boxRect, Paint()..shader = satShader);

    // Value gradient (transparent → black)
    final valShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.black,
      ],
    ).createShader(boxRect);

    canvas.drawRect(boxRect, Paint()..shader = valShader);

    // 🔘 HUE INDICATOR
    final hueAngle = (hue * pi / 180);
    final ringRadius = radius - ringWidth / 2;

    final huePos = Offset(
      center.dx + cos(hueAngle) * ringRadius,
      center.dy + sin(hueAngle) * ringRadius,
    );

    _drawIndicator(canvas, huePos);

    // 🎯 SV INDICATOR
    print(saturation);
    print(value);
    final svX = boxRect.left + saturation * boxRect.width;
    final svY = boxRect.top + (1 - value) * boxRect.height;

    print(svX);
    print(svY);

    final svPos = Offset(svX, svY);

    _drawIndicator(canvas, svPos);
  }

  void _drawIndicator(Canvas canvas, Offset pos) {
    final outer = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final inner = Paint()..color = Colors.black;

    canvas.drawCircle(pos, 6, outer);
    canvas.drawCircle(pos, 3, inner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}