import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'page_widget.dart';
import 'page_widget_frame.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:betternotes/core/providers/global_providers.dart';

class DocumentWidget extends ConsumerStatefulWidget {

  DocumentWidget({
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<DocumentWidget> createState() => DocumentWidgetState();
}

class DocumentWidgetState extends ConsumerState<DocumentWidget> {

  List<GlobalKey<PageWidgetState>> pageKeys = [];
  List<PageWidgetFrame> pages = [];
  List<int> pageIndexes = [];
  final int docIndex=0;


  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    final doc = ref.watch(documentsProvider.select((docs) => docs[docIndex]));
    final pages = ref.watch(documentsProvider.select((docs) => docs[docIndex].pages),);

    //print("documentwidget:  ${doc.placeholderHeight}");

    return Column(
        children: [
          SizedBox(height: doc.placeholderHeight, width: 100, child:
          ColoredBox(color: Colors.red,)
          ),

          for (int i = 0; i < pages.length; i++)
            PageWidgetFrame(
              key: ValueKey(pages[i].pageID),
              child: PageWidget(pageIndex: i, pageID: pages[i].pageID),
            ),
        ],
    );
  }

  @override
  void dispose() {
    pages.clear();
    pageKeys.clear();
    super.dispose();
  }


}