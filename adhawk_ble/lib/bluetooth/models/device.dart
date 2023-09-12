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

  @override
  List<Object?> get props => [name, btInfo];
}
