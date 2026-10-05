import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../components/color_picker.dart';

Widget buildColorTile({
  required BuildContext context,
  required String label,
  required Color color,
  required ValueChanged<Color> onColorPicked,
}) {
  return ListTile(
    title: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
    trailing: CircleAvatar(
      backgroundColor: color,
      radius: 16,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade500, width: 2),
        ),
      ),
    ),
    onTap: () async {
      final picked = await pickColor(context, color);
      if (picked != null) onColorPicked(picked);
    },
  );
}