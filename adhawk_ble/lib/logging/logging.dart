import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Singleton hierarchical logger used by this package
class AdHawkLogger {
  AdHawkLogger._internal() : logger = Logger('adhawk') {
    hierarchicalLoggingEnabled = true;
    logger.level = Level.ALL;
    logger.onRecord.listen((record) {
      developer.log(
        record.message,
        name: record.loggerName,
        time: record.time,
        level: record.level.value,
        error: record.error,
        stackTrace: record.stackTrace,
        sequenceNumber: record.sequenceNumber,
      );
      if (kDebugMode) {
        if (record.level >= Level.FINER) {
          print('${record.time} [${record.level.value}] ${record.message}');
        }
      }
    });
  }

  factory AdHawkLogger() {
    return _instance;
  }

  static final AdHawkLogger _instance = AdHawkLogger._internal();
  final Logger logger;
}

/// Returns a logger that is the child of the adhawk logger
Logger getLogger(String name) {
  return Logger('${AdHawkLogger().logger.name}.$name');
}
