import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:synchronized/synchronized.dart';

import '../models/bluetooth_characteristics.dart';
import '../models/device.dart';
import 'bluetooth_api.dart';

class BluetoothApiFBP implements BluetoothApi {
  BluetoothApiFBP() : _readLock = Lock() {
    FlutterBluePlus.setLogLevel(LogLevel.info);
  }
  final Lock _readLock;

  /// The MTU required to receive et packets
  static const _mtu = 244;

  /// A map to lookup the BluetoothCharacteristic object
  /// of the connected device by the service uuid and characteristic uuid
  final Map<Characteristic, BluetoothCharacteristic> _characteristics = {};

  @override
  Stream<List<Device>> startScan() async* {
    // Call this again as there is a bug in flutterBluePlus where the
    // logLevel gets overridden in its init and we end up getting spammed
    // on characteristic changes
    // https://github.com/boskokg/flutter_blue_plus/issues/557
    FlutterBluePlus.setLogLevel(LogLevel.info);
    if (!FlutterBluePlus.isScanningNow) {
      try {
        await FlutterBluePlus.startScan(
          withServices: [
            Guid(AdhawkCharacteristics.serviceUuid),
          ],
        );
      } on Exception catch (e) {
        throw BluetoothScanException(e.toString());
      }
    }
    // Always yield an initial empty list since scanResults doesn't stream
    // if there are no devices in the scan
    yield [];
    await for (final List<ScanResult> results in FlutterBluePlus.scanResults) {
      final scanResults = results.map((e) => _mapToDevice(e.device));
      yield scanResults.toList();
    }
  }

  @override
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } on Exception catch (e) {
      throw BluetoothScanException(e.toString());
    }
  }

  @override
  Stream<ConnectionStatusEvent> getConnectionStatus() {
    return FlutterBluePlus.events.onConnectionStateChanged
        .asyncMap((event) async {
      if (event.connectionState == BluetoothConnectionState.connected) {
        // Ensure we initialize first before emitting the connected status
        try {
          await _initializeDevice(event.device);
        } on Exception {
          return ConnectionStatusEvent(
            device: _mapToDevice(event.device),
            status: ConnectionStatus.disconnected,
          );
        }
      }
      return ConnectionStatusEvent(
          device: _mapToDevice(event.device),
          status: _mapToConnectionStatus(event.connectionState));
    });
  }

  @override
  Future<void> connect(Device device) async {
    // Call this again as there is a bug in flutterBluePlus where the
    // logLevel gets overridden in its init and we end up getting spammed
    // on characteristic changes
    // https://github.com/boskokg/flutter_blue_plus/issues/557
    FlutterBluePlus.setLogLevel(LogLevel.info);
    final btDevice = _mapToBluetoothDevice(device);
    try {
      await btDevice.connect(
        timeout: const Duration(seconds: 5),
      );
    } on Exception catch (e) {
      throw BluetoothConnectException(e.toString());
    }
  }

  @override
  Future<void> disconnect(Device device) async {
    final btDevice = _mapToBluetoothDevice(device);
    try {
      await btDevice.disconnect();
    } on Exception catch (e) {
      throw BluetoothDisconnectException(e.toString());
    } finally {
      _characteristics.clear();
    }
  }

  @override
  Future<Uint8List> read(Characteristic characteristic) async {
    final ch = _getCharacteristicInstance(characteristic);
    if (!ch.properties.read) {
      throw BluetoothCommsException(
          'Read is not supported by this characteristic: $characteristic');
    }
    try {
      return await _readLock
          .synchronized(() async => Uint8List.fromList(await ch.read()));
    } on Exception catch (e) {
      throw BluetoothCommsException(e.toString());
    }
  }

  @override
  Future<void> write(Characteristic characteristic, Uint8List bytes,
      {bool withoutResponse = true}) async {
    final ch = _getCharacteristicInstance(characteristic);
    if (!(withoutResponse
        ? ch.properties.writeWithoutResponse
        : ch.properties.write)) {
      throw BluetoothCommsException(
          'Write ${withoutResponse ? "without response " : ""}is not supported'
          ' by this characteristic: $characteristic');
    }
    try {
      await ch.write(bytes, withoutResponse: withoutResponse);
    } on Exception catch (e) {
      throw BluetoothCommsException(e.toString());
    }
  }

  @override
  Future<Stream<Uint8List>> startStream(Characteristic characteristic) async {
    final ch = _getNotifiableCharacteristic(characteristic);
    try {
      await _readLock.synchronized(() async => ch.setNotifyValue(true));
    } on Exception catch (e) {
      throw BluetoothCommsException(e.toString());
    }
    return ch.onValueReceived.map(Uint8List.fromList);
  }

  @override
  Future<void> stopStream(Characteristic characteristic) async {
    final ch = _getNotifiableCharacteristic(characteristic);
    try {
      await _readLock.synchronized(() async => ch.setNotifyValue(false));
    } on Exception catch (e) {
      throw BluetoothCommsException(e.toString());
    }
  }

  /// Initialize the device after connecting
  Future<void> _initializeDevice(BluetoothDevice btDevice) async {
    if (!Platform.isIOS) {
      await btDevice.requestMtu(_mtu);
    }
    final services = await btDevice.discoverServices();
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        final key = Characteristic(
            characteristic.uuid.toString(), service.uuid.toString());
        _characteristics[key] = characteristic;
      }
    }
  }

  /// Get the BluetoothCharacteristic object from the saved characteristic map
  BluetoothCharacteristic _getCharacteristicInstance(
      Characteristic characteristic) {
    final ch = _characteristics[characteristic];
    if (ch == null) {
      throw BluetoothCommsException(
          'This device does not support characteristic: $characteristic');
    }
    return ch;
  }

  /// Get the notifiable bluetooth characteristic instance
  BluetoothCharacteristic _getNotifiableCharacteristic(
      Characteristic characteristic) {
    final ch = _getCharacteristicInstance(characteristic);
    if (!ch.properties.notify) {
      throw BluetoothCommsException(
          'Notify is not supported by this characteristic: $characteristic');
    }
    return ch;
  }

  /// Populate the [Device] model with fields from the flutter_blue [BluetoothDevice]
  static Device _mapToDevice(BluetoothDevice btDevice) {
    return Device(
      name: btDevice.platformName.replaceFirst('ADHAWK ', ''),
      btInfo: BluetoothInformation(
        id: btDevice.remoteId.toString(),
        description: btDevice.remoteId.toString(),
      ),
    );
  }

  /// Create a [BluetoothDevice] instance from a [Device] object
  static BluetoothDevice _mapToBluetoothDevice(Device device) {
    return BluetoothDevice.fromId(device.btInfo.id);
  }

  /// Convert [BluetoothConnectionState] to [ConnectionStatus]
  static ConnectionStatus _mapToConnectionStatus(
      BluetoothConnectionState state) {
    // connecting and disconnecting are deprecated but still exist in the enum
    switch (state) {
      case BluetoothConnectionState.connected:
        return ConnectionStatus.connected;
      case BluetoothConnectionState.disconnected:
        return ConnectionStatus.disconnected;
      // ignore: deprecated_member_use
      case BluetoothConnectionState.connecting:
      // ignore: deprecated_member_use
      case BluetoothConnectionState.disconnecting:
        throw UnimplementedError('Unhandled bluetooth state: $state');
    }
  }
}
