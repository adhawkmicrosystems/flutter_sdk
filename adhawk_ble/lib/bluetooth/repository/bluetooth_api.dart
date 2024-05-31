import 'dart:typed_data';
import '../models/bluetooth_characteristics.dart';
import '../models/device.dart';

class BluetoothException implements Exception {
  BluetoothException(this.message);
  String message;

  @override
  String toString() => message;
}

class BluetoothConnectException extends BluetoothException {
  BluetoothConnectException(super.message);
}

class BluetoothDisconnectException extends BluetoothException {
  BluetoothDisconnectException(super.message);
}

class BluetoothCommsException extends BluetoothException {
  BluetoothCommsException(super.message);
}

class BluetoothScanException extends BluetoothException {
  BluetoothScanException(super.message);
}

abstract class BluetoothApi {
  /// Starts a bluetooth scan and generates a stream of [Device]s
  Stream<List<Device>> startScan();

  /// Stops the scan for devices
  Future<void> stopScan();

  /// Monitor the connection status of devices
  Stream<ConnectionStatusEvent> getConnectionStatus();

  /// Connect to a [Device]
  ///
  /// Throws [BluetoothConnectException]
  Future<void> connect(Device device);

  /// Disconnect from the currently connected device
  ///
  /// Throws [BluetoothDisconnectException]
  Future<void> disconnect(Device device);

  /// Read from a bluetooth [Characteristic]
  Future<Uint8List> read(Characteristic characteristic);

  /// Write to a bluetooth [Characteristic]
  ///
  /// Throws [BluetoothCommsException]
  Future<void> write(Characteristic characteristic, Uint8List bytes,
      {bool withoutResponse = true});

  /// Start receiving stream data from a bluetooth [Characteristic]
  ///
  /// Throws [BluetoothCommsException]
  Future<Stream<Uint8List>> startStream(Characteristic characteristic);

  /// Stop receiving stream data from a bluetooth [Characteristic]
  ///
  /// Throws [BluetoothCommsException]
  Future<void> stopStream(Characteristic characteristic);
}
