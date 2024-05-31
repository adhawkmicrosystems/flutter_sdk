import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../logging/logging.dart';

/// Method names used for communicating between [KeepAliveApp] and
/// the KeepAliveService
enum KeepAliveServiceMethod {
  startService,
  stopService,
}

/// This class is used to ensure that the application remains open
/// by starting a foreground service
///
/// When notifications have been initialized, the service is started
/// When the user quits the app, the service is stopped
/// Note: We don't stop the service on glasses disconnect because we need to
/// try to reconnect in the background
class KeepAliveApp {
  factory KeepAliveApp() {
    return _instance;
  }

  /// Internal  constructor
  KeepAliveApp._internal();

  /// Start the service
  Future<void> start() async {
    if (!Platform.isAndroid) {
      return;
    }
    _logger.info('Start keepalive service');
    try {
      await service.invokeMethod(KeepAliveServiceMethod.startService.name);
    } on PlatformException catch (e) {
      _logger.severe(e);
    }
  }

  /// Stop the service
  Future<void> stop() async {
    if (!Platform.isAndroid) {
      return;
    }
    _logger.info('Stop keepalive service');
    try {
      await service.invokeMethod(KeepAliveServiceMethod.stopService.name);
    } on PlatformException catch (e) {
      _logger.severe(e);
    }
  }

  final _logger = getLogger((KeepAliveApp).toString());
  static const service = MethodChannel('KeepAliveService');
  static final KeepAliveApp _instance = KeepAliveApp._internal();
}
