/// Generates unique, increasing IDs (documents, pages, strokes, images, commands).
///
/// IDs are `milliseconds since epoch * 1000 + counter`, about 1.8e15 today. That stays below
/// 2^53 (9.0e15) until the year 2255, so IDs are exact integers on the web (JavaScript numbers)
/// too. More than 1000 IDs per millisecond simply run ahead of the clock; IDs never repeat or
/// decrease within a session.
class IdGenerator {
  static int _last = 0;

  static int next() {
    final candidate = DateTime.now().millisecondsSinceEpoch * 1000;
    _last = candidate > _last ? candidate : _last + 1;
    return _last;
  }
}
