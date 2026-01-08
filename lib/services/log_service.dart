import 'dart:async';

class LogService {
  static final LogService _instance = LogService._internal();
  static LogService get instance => _instance;

  final _logController = StreamController<List<String>>.broadcast();
  final List<String> _logs = [];

  LogService._internal();

  Stream<List<String>> get logStream => _logController.stream;
  List<String> get logs => List.unmodifiable(_logs);

  void log(String message) {
    final timestamp = DateTime.now()
        .toIso8601String()
        .split('T')
        .last
        .split('.')
        .first;
    final logEntry = '[$timestamp] $message';
    _logs.add(logEntry);
    // Keep only the last 1000 logs to avoid memory issues
    if (_logs.length > 1000) {
      _logs.removeAt(0);
    }
    _logController.add(List.unmodifiable(_logs));

    // Also print to console for development
    print(logEntry);
  }

  void clear() {
    _logs.clear();
    _logController.add([]);
  }

  void dispose() {
    _logController.close();
  }
}
