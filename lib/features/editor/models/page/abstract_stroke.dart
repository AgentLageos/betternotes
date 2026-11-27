

//the type of stroke used by tile-widget. to be more memory efficient, it only references the actual strokes

class AbstractStroke {
  Set<int> pointIndexes;
  int strokeID;


  AbstractStroke({
    //required this.strokeIndex,
    required this.pointIndexes,
    required this.strokeID});



}



