import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/page/page_model.dart';

///////////this widget mainly exists to avoid having to deal with offsets in pagewidget because of padding and margin, that shift the pen position if not corrected
///////////pagewidgetframe however solves this!!!


class PageWidgetFrame extends StatelessWidget {
  final Widget child;


  const PageWidgetFrame({super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(0),
      padding: const EdgeInsets.all(12),
      //color: Colors.amber,   //backgroundcolor, for debug only
      child: child,
    );
  }
}