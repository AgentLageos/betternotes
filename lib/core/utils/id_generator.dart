class IdGenerator {
  static int _lastTimestamp = 0;
  static int _counter = 0;

  static int next() {
    final now = DateTime.now().microsecondsSinceEpoch;

    if (now == _lastTimestamp) {
      _counter++;
    } else {
      _lastTimestamp = now;
      _counter = 0;
    }

    return now * 1000 + _counter;
  }
}