/// device_bloc is used to manage the bluetooth connectivity to a pair of glasses
///
/// The presentation layer issues [DeviceEvent]s to connect to or disconnect
/// from a tracker. The [DeviceState] streams the current connection status
/// and provides bluetooth information for the currently connected [Device]

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logging/logging.dart';
import '../models/device.dart';
import '../repository/bluetooth_repository.dart';

/// Events published to the [DeviceBloc]
sealed class DeviceEvent {}

/// Event triggered to check if a device is connected
class DeviceCheckTriggered extends DeviceEvent {}

/// Start monitoring the connected device
class _DeviceMonitor extends DeviceEvent {}

/// Connect to or disconnect from a device
class DeviceConnectDisconnect extends DeviceEvent {
  DeviceConnectDisconnect(this.device) : super();
  final Device device;
}

/// Encapsulates the current connectivity state of the application to
/// a pair of glasses. Only one pair of glasses may be connected at a time
class DeviceState extends Equatable {
  const DeviceState({
    required this.status,
    required this.device,
  });

  /// The current connection status
  final ConnectionStatus status;

  /// The connected device (or actively attempting connect/disconnect)
  final Device? device;

  const DeviceState.initial()
      : this(status: ConnectionStatus.init, device: null);

  DeviceState copyWith({
    required ConnectionStatus status,
  }) =>
      DeviceState(
        status: status,
        device: device,
      );

  @override
  List<Object?> get props => [status, device];

  @override
  String toString() {
    return '${status.toString()} (${device?.name ?? "None"})';
  }
}

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  DeviceBloc({required BluetoothRepository deviceRepo})
      : _deviceRepo = deviceRepo,
        super(const DeviceState.initial()) {
    on<DeviceCheckTriggered>(_handleDeviceCheckTriggered);
    on<DeviceConnectDisconnect>(
      _handleDeviceConnectDisconnect,
      transformer: restartable(),
    );
    on<_DeviceMonitor>(
      _handleDeviceMonitor,
      transformer: restartable(),
    );
  }
  final BluetoothRepository _deviceRepo;
  final _logger = getLogger((DeviceBloc).toString());

  void _handleDeviceCheckTriggered(event, emit) async {
    try {
      Device? connectedDevice = await _deviceRepo.getConnectedDevice();
      if (connectedDevice == null) {
        emit(const DeviceState(
          status: ConnectionStatus.disconnected,
          device: null,
        ));
      } else {
        emit(DeviceState(
          status: ConnectionStatus.connected,
          device: connectedDevice,
        ));
        // Start monitoring the device
        add(_DeviceMonitor());
      }
    } catch (error) {
      emit(
        const DeviceState(
          status: ConnectionStatus.disconnected,
          device: null,
        ),
      );
    }
  }

  Future<void> _handleDeviceConnectDisconnect(event, emit) async {
    if (state.status == ConnectionStatus.connected) {
      await _handleDeviceDisconnectTriggered(event, emit);
    } else if (state.status == ConnectionStatus.disconnected) {
      await _handleDeviceConnectTriggered(event, emit);
    } else {
      // do nothing on connecting/disconnecting states
    }
  }

  Future<void> _handleDeviceConnectTriggered(event, emit) async {
    // Ensure we disconnect if we're currently connected to another device
    Device? device = state.device;
    if (state.status == ConnectionStatus.connected && device != null) {
      try {
        emit(DeviceState(
          status: ConnectionStatus.disconnecting,
          device: device,
        ));
        await _deviceRepo.disconnect(device);
        emit(const DeviceState(
          status: ConnectionStatus.disconnected,
          device: null,
        ));
      } catch (error) {
        _logger.warning('Failed to disconnect from ${device.name}: $error');
        emit(DeviceState(
          status: ConnectionStatus.connected,
          device: device,
        ));
        return;
      }
    }

    // Connect to the new device provided in the event
    try {
      emit(DeviceState(
        status: ConnectionStatus.connecting,
        device: event.device,
      ));
      await _deviceRepo.connect(event.device);
      // Start monitoring the device
      add(_DeviceMonitor());
    } catch (error) {
      _logger.severe('Failed to connect to ${event.device}: $error');
      emit(const DeviceState(
        status: ConnectionStatus.disconnected,
        device: null,
      ));
    }
  }

  Future<void> _handleDeviceDisconnectTriggered(event, emit) async {
    try {
      emit(DeviceState(
        status: ConnectionStatus.disconnecting,
        device: event.device,
      ));
      _deviceRepo.disconnect(event.device);
    } catch (error) {
      _logger.warning('Failed to disconnect from ${event.device.name}: $error');
      return;
    }
  }

  Future<void> _handleDeviceMonitor(event, emit) async {
    await emit.onEach(_deviceRepo.connectionStatus, onData: (connectionStatus) {
      if (state.status != connectionStatus) {
        emit(state.copyWith(status: connectionStatus));
      }
    });
  }

  @override
  void onChange(Change<DeviceState> change) {
    super.onChange(change);
    _logger.info('${change.currentState} -> ${change.nextState}');
  }
}
