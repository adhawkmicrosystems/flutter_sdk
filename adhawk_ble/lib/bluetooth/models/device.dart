import 'package:equatable/equatable.dart';

/// Generic device connectivity status
enum ConnectionStatus {
  /// Initial status on application start
  init,
  disconnected,
  connecting,
  connected,
  disconnecting
}

/// Bluetooth specific information
class BluetoothInformation extends Equatable {
  const BluetoothInformation({required this.id, required this.description});

  final String id;
  final String description;

  @override
  List<Object?> get props => [id];
}

/// Encapsulates information about a device
class Device extends Equatable {
  const Device({required this.name, required this.btInfo});

  final String name;
  final BluetoothInformation btInfo;

  /// Use this check when verifying it is the same physical device
  /// as sometimes the device name might not be populated by flutter_blue_plus
  bool isSameBluetoothId(Device other) => btInfo.id == other.btInfo.id;

  @override
  List<Object?> get props => [name, btInfo];
}

class ConnectionStatusEvent {
  ConnectionStatusEvent({required this.device, required this.status});
  final Device device;
  final ConnectionStatus status;
}
