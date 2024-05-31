import 'dart:async';
import 'dart:typed_data';

import '../../logging/logging.dart';
import '../models/bluetooth_characteristics.dart';
import '../models/device.dart';
import 'bluetooth_api.dart';

class BluetoothRepository {
  BluetoothRepository({
    required BluetoothApi api,
    required int minReconnectDurationSecs,
    required int maxReconnectDurationSecs,
  })  : _api = api,
        _minReconnectDurationSecs = Duration(seconds: minReconnectDurationSecs),
        _maxReconnectDurationSecs =
            Duration(seconds: maxReconnectDurationSecs) {
    _statusSub = _api.getConnectionStatus().listen(_monitorConnectionStatus);
  }
  final BluetoothApi _api;

  final Duration _minReconnectDurationSecs;

  final Duration _maxReconnectDurationSecs;

  final _logger = getLogger((BluetoothRepository).toString());

  /// The last connected device
  Device? _device;

  /// Current connection status
  ConnectionStatus _status = ConnectionStatus.disconnected;

  /// Listen for the status of devices
  StreamSubscription<ConnectionStatusEvent>? _statusSub;

  /// Stream controller that broadcasts the state of the currently paired device
  final _connectionStatusController =
      StreamController<ConnectionStatusEvent>.broadcast();

  /// A timer used to reconnect to the last connected device
  Timer? _reconnectTimer;

  /// Number of reconnect attempts made since the last disconnect
  int _reconnectAttempts = 0;

  // A function that finds what the reconnect duration should be based on an exponential backoff
  Duration get _reconnectDuration {
    final duration = _minReconnectDurationSecs * (1 << _reconnectAttempts);
    if (duration > _maxReconnectDurationSecs) {
      return _maxReconnectDurationSecs;
    }
    return duration;
  }

  Future<void> dispose() async {
    await _statusSub?.cancel();
    await _connectionStatusController.close();
  }

  /// Starts a bluetooth scan and generates a stream of [Device]s
  Stream<List<Device>> startScan() async* {
    await for (final scanResult in _api.startScan()) {
      yield {
        if (_device != null && _status == ConnectionStatus.connected) _device!,
        ...scanResult,
      }.toList();
    }
  }

  /// Stops the scan for devices
  Future<void> stopScan() async {
    await _api.stopScan();
  }

  /// Connect to a [Device]
  Future<void> connect(Device device) async {
    try {
      if (_device != null) {
        await _api.disconnect(_device!);
      }
    } finally {
      _device = device;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      await _api.connect(device);
    }
  }

  /// Disconnect from the currently connected device
  Future<void> disconnect(Device device) async {
    try {
      await _api.disconnect(device);
    } finally {
      // We should disable the reconnect timer
      // even if the disconnect fails
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _device = null;
    }
  }

  /// Monitor the connection status of the currently connected device
  Stream<ConnectionStatusEvent> get connectionStatus async* {
    yield* _connectionStatusController.stream;
  }

  Future<Uint8List> read(Characteristic characteristic) async {
    if (_device == null) {
      throw BluetoothCommsException('Not connected to any bluetooth devices');
    }
    return _api.read(characteristic);
  }

  Future<void> write(Characteristic characteristic, Uint8List bytes,
      {bool withoutResponse = true}) async {
    if (_device == null) {
      throw BluetoothCommsException('Not connected to any bluetooth devices');
    }
    return _api.write(characteristic, bytes, withoutResponse: withoutResponse);
  }

  Future<Stream<Uint8List>> startStream(Characteristic characteristic) async {
    if (_device == null) {
      throw BluetoothCommsException('Not connected to any bluetooth devices');
    }
    return _api.startStream(characteristic);
  }

  Future<void> stopStream(Characteristic characteristic) async {
    if (_device == null) {
      throw BluetoothCommsException('Not connected to any bluetooth devices');
    }
    await _api.stopStream(characteristic);
  }

  Future<void> _monitorConnectionStatus(ConnectionStatusEvent event) async {
    _connectionStatusController.add(event);
    final device = _device;
    if (device != null && event.device.isSameBluetoothId(device)) {
      _status = event.status;
      if (event.status == ConnectionStatus.disconnected) {
        _logger.info('$_device disconnected. Reconnect in $_reconnectDuration');
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(_reconnectDuration, onReconnectTimer);
      }
    }
  }

  Future<void> onReconnectTimer() async {
    if (_status != ConnectionStatus.connected && _device != null) {
      _reconnectAttempts++;
      try {
        await _api.connect(_device!);
        _reconnectAttempts = 0;
      } on BluetoothConnectException {
        // No need to do anything here. We should receive a disconnect event
        // which resets the timer
      }
    }
  }
}
