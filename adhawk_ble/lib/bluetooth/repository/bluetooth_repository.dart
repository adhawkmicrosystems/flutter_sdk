import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show Platform;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:synchronized/synchronized.dart';

import '../../logging/logging.dart';
import '../models/device.dart';
import '../models/bluetooth_characteristics.dart';

class BluetoothRepository {
  BluetoothRepository() : _readLock = Lock() {
    FlutterBluePlus.setLogLevel(LogLevel.info);
  }
  final Lock _readLock;
  final _logger = getLogger((BluetoothRepository).toString());

  /// The currently paired device
  BluetoothDevice? _pairedDevice;

  /// Subscription that monitors the state of the currently paired device
  StreamSubscription<BluetoothConnectionState>? _btDeviceStateSub;

  /// Stream controller that broadcasts the state of the currently paired device
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();

  /// The MTU required to receive et packets
  static const mtu = 244;

  /// A map to lookup the BluetoothCharacteristic object
  /// of the connected device by the service uuid and characteristic uuid
  final Map<Characteristic, BluetoothCharacteristic> _characteristics = {};

  Future<void> dispose() async {
    await _btDeviceStateSub?.cancel();
    await _connectionStatusController.close();
  }

  /// Get the currently connected [Device]
  Future<Device?> getConnectedDevice() async {
    final connectedDevices = (await FlutterBluePlus.connectedSystemDevices)
        .where((e) => _validDevice(e));
    if (connectedDevices.isEmpty) {
      return null;
    }
    BluetoothDevice btDevice = connectedDevices.first;
    await _initializeConnectedDevice(btDevice);
    return _mapToDevice(btDevice);
  }

  /// Starts a bluetooth scan and generates a stream of [Device]s
  Stream<List<Device>> startScan() async* {
    if (!FlutterBluePlus.isScanningNow) {
      FlutterBluePlus.startScan(
        withServices: [
          Guid(AdhawkCharacteristics.serviceUuid),
        ],
      );
    }
    await for (List<ScanResult> results in FlutterBluePlus.scanResults) {
      final connectedDevices = (await FlutterBluePlus.connectedSystemDevices)
          .where((e) => _validDevice(e))
          .map((e) => _mapToDevice(e));
      // We can only be connected to a single valid device at a time
      final connectedDevice =
          connectedDevices.isEmpty ? null : connectedDevices.first;
      final scanResults = results.map((e) => _mapToDevice(e.device));
      // The scan results exhibit strange behavior in flutter_blue_plus:v1.14.11
      // When connecting to a device in the scan result, the connected device only
      // disappears from the results IF it was the only entry in the scan.
      // To cover all cases, we check if the connected device is in the scan result
      // if not, we add it to the list.
      yield [
        if (connectedDevice != null && !scanResults.contains(connectedDevice))
          connectedDevice,
        ...scanResults
      ];
    }
  }

  /// Stops the scan for devices
  void stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connect to a [Device]
  connect(Device device) async {
    if (_pairedDevice != null) {
      await disconnect(_mapToDevice(_pairedDevice!));
    }
    BluetoothDevice btDevice = _mapToBluetoothDevice(device);
    await btDevice.connect(
      timeout: const Duration(seconds: 15),
      autoConnect: true, // Does not work on iOS: TRSW-8273
    );
    _pairedDevice = btDevice;
    await _initializeConnectedDevice(btDevice);
  }

  /// Disconnect from the currently connected device
  disconnect(Device device) async {
    BluetoothDevice btDevice = _mapToBluetoothDevice(device);
    await btDevice.disconnect();

    // Only when the user explicitly disconnects from the device
    // stop listening and clear characteristics
    await _btDeviceStateSub?.cancel();
    _pairedDevice = null;
    _characteristics.clear();
  }

  /// Monitor the connection status of the currently connected device
  Stream<ConnectionStatus> get connectionStatus async* {
    yield* _connectionStatusController.stream;
  }

  Future<Uint8List> read(Characteristic characteristic) async {
    var ch = _getCharacteristicInstance(characteristic);
    if (!ch.properties.read) {
      throw UnsupportedError(
          'Read is not supported by this characteristic: $characteristic');
    }

    return await _readLock
        .synchronized(() async => Uint8List.fromList(await ch.read()));
  }

  Future<void> write(Characteristic characteristic, Uint8List bytes) async {
    var ch = _getCharacteristicInstance(characteristic);
    if (ch.properties.write) {
      throw UnsupportedError(
          'Write is not supported by this characteristic: $characteristic');
    }
    await ch.write(bytes, withoutResponse: true);
  }

  Stream<Uint8List> getStream(Characteristic characteristic) {
    var ch = _getNotifiableCharacteristic(characteristic);
    return ch.onValueReceived.map(Uint8List.fromList);
  }

  Future<Stream<Uint8List>> startStream(Characteristic characteristic) async {
    var ch = _getNotifiableCharacteristic(characteristic);
    await _readLock.synchronized(() async => await ch.setNotifyValue(true));
    return ch.onValueReceived.map(Uint8List.fromList);
  }

  Future<void> stopStream(Characteristic characteristic) async {
    var ch = _getNotifiableCharacteristic(characteristic);
    await _readLock.synchronized(() async => await ch.setNotifyValue(false));
  }

  Future<void> _initializeConnectedDevice(BluetoothDevice btDevice) async {
    _btDeviceStateSub = btDevice.connectionState
        .listen((state) => _monitorDeviceState(btDevice, state));
  }

  Future<void> _monitorDeviceState(
      BluetoothDevice btDevice, BluetoothConnectionState state) async {
    if (state == BluetoothConnectionState.connected) {
      _logger.info('Initializing connected device ${btDevice.localName}');
      if (!Platform.isIOS) {
        await btDevice.requestMtu(mtu);
      }
      List<BluetoothService> services = await btDevice.discoverServices();
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          Characteristic key = Characteristic(
              characteristic.uuid.toString(), service.uuid.toString());
          _characteristics[key] = characteristic;
          _logger.config(key.toString());
        }
      }
    }
    // Emit the status after initialization is complete
    _connectionStatusController.add(_mapToConnectionStatus(state));
  }

  /// Get the BluetoothCharacteristic object from the [_characteristic] map
  BluetoothCharacteristic _getCharacteristicInstance(
      Characteristic characteristic) {
    if (_pairedDevice == null) {
      throw StateError('Not connected to any bluetooth devices');
    }
    var ch = _characteristics[characteristic];
    if (ch == null) {
      throw UnsupportedError(
          'This device does not support characteristic: $characteristic');
    }
    return ch;
  }

  /// Get the notifiable bluetooth characteristic instance
  BluetoothCharacteristic _getNotifiableCharacteristic(
      Characteristic characteristic) {
    BluetoothCharacteristic ch = _getCharacteristicInstance(characteristic);
    if (!ch.properties.notify) {
      throw UnsupportedError(
          'Notify is not supported by this characteristic: $characteristic');
    }
    return ch;
  }

  /// Returns true if [BluetoothDevice] is an AdHawk device
  static bool _validDevice(BluetoothDevice device) {
    if (device.localName.contains(RegExp(r'AdHawk', caseSensitive: false))) {
      return true;
    }
    return false;
  }

  /// Populate the [Device] model with fields from the flutter_blue [BluetoothDevice]
  static Device _mapToDevice(BluetoothDevice btDevice) {
    return Device(
      name: btDevice.localName,
      btInfo: BluetoothInformation(
        id: btDevice.remoteId.toString(),
        description: btDevice.remoteId.toString(),
      ),
    );
  }

  /// Create a [BluetoothDevice] instance from a [Device] object
  static BluetoothDevice _mapToBluetoothDevice(Device device) {
    return BluetoothDevice.fromId(device.btInfo.id, localName: device.name);
  }

  /// Convert [BluetoothConnectionState] to [ConnectionStatus]
  static ConnectionStatus _mapToConnectionStatus(
      BluetoothConnectionState state) {
    // connecting and disconnecting are deprecated but still exist in the enum
    // ignore: missing_enum_constant_in_switch
    switch (state) {
      case BluetoothConnectionState.connected:
        return ConnectionStatus.connected;
      case BluetoothConnectionState.disconnected:
        return ConnectionStatus.disconnected;
      default:
        throw UnimplementedError('Unhandled bluetooth state: $state');
    }
  }
}
