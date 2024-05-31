/// device_bloc is used to manage the bluetooth connectivity to a pair of glasses
///
/// The presentation layer issues [DeviceEvent]s to connect to or disconnect
/// from a tracker. The [DeviceState] streams the current connection status
/// and provides bluetooth information for the currently connected [Device]
library;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logging/logging.dart';
import '../../utilities/struct.dart';
import '../models/bluetooth_characteristics.dart';
import '../models/device.dart';
import '../repository/bluetooth_api.dart';
import '../repository/bluetooth_repository.dart';

/// Events published to the [DeviceBloc]
sealed class DeviceEvent {}

/// Event triggered to check if a device is connected
class DeviceCheckTriggered extends DeviceEvent {}

/// Start monitoring the connected device
class DeviceMonitor extends DeviceEvent {}

enum DeviceAction {
  connect,
  disconnect,
}

/// Connect to or disconnect from a device
class DeviceActionTriggered extends DeviceEvent {
  DeviceActionTriggered(this.device, this.action) : super();
  final Device device;
  final DeviceAction action;
}

/// Encapsulates the current connectivity state of the application to
/// a pair of glasses. Only one pair of glasses may be connected at a time
class DeviceState extends Equatable {
  const DeviceState({
    required this.status,
    required this.device,
    required this.hardwareRev,
    required this.firmwareVersion,
    this.connectFailed = false,
  }) : supportsRecording =
            hardwareRev != null && hardwareRev != 'lp' && hardwareRev != 'v2';

  const DeviceState.initial()
      : this(
          status: ConnectionStatus.disconnected,
          device: null,
          hardwareRev: null,
          firmwareVersion: null,
        );

  /// The current connection status
  final ConnectionStatus status;

  /// The connected device (or actively attempting connect/disconnect)
  final Device? device;

  /// The hardware revision
  final String? hardwareRev;

  /// The device firmware version
  final String? firmwareVersion;

  /// Last connection attempt failed
  final bool connectFailed;

  /// Whether the device supports recording
  final bool supportsRecording;

  DeviceState copyWith({
    required ConnectionStatus status,
    String? hardwareRev,
    String? firmwareVersion,
    bool connectFailed = false,
  }) =>
      DeviceState(
        status: status,
        device: device,
        hardwareRev: hardwareRev ?? this.hardwareRev,
        firmwareVersion: firmwareVersion ?? this.firmwareVersion,
        connectFailed: connectFailed,
      );

  @override
  List<Object?> get props => [
        status,
        device,
        hardwareRev,
        firmwareVersion,
        connectFailed,
      ];

  @override
  String toString() {
    return '$status (${device?.name ?? "None"}'
        '${hardwareRev != null ? ":$hardwareRev" : ""})';
  }
}

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  DeviceBloc({required BluetoothRepository deviceRepo})
      : _deviceRepo = deviceRepo,
        super(const DeviceState.initial()) {
    on<DeviceActionTriggered>(
      _handleDeviceAction,
      transformer: restartable(),
    );
    on<DeviceMonitor>(
      _handleDeviceMonitor,
      transformer: restartable(),
    );
  }
  final BluetoothRepository _deviceRepo;
  final _logger = getLogger((DeviceBloc).toString());

  Future<void> _handleDeviceAction(
      DeviceActionTriggered event, Emitter<DeviceState> emit) async {
    switch (event.action) {
      case DeviceAction.connect:
        // We're already connected, but to a different device
        // first disconnect from that device
        if (state.status == ConnectionStatus.connected &&
            event.device != state.device) {
          await _handleDeviceDisconnectTriggered(event, emit);
        }
        await _handleDeviceConnectTriggered(event, emit);
      case DeviceAction.disconnect:
        await _handleDeviceDisconnectTriggered(event, emit);
    }
  }

  Future<void> _handleDeviceConnectTriggered(
      DeviceActionTriggered event, Emitter<DeviceState> emit) async {
    try {
      emit(DeviceState(
        status: ConnectionStatus.connecting,
        device: event.device,
        hardwareRev: null,
        firmwareVersion: null,
      ));
      await _deviceRepo.connect(event.device);
    } on BluetoothConnectException catch (e) {
      _logger.severe('Failed to connect to ${event.device}: ${e.message}');
      emit(state.copyWith(
        status: ConnectionStatus.disconnected,
        connectFailed: true,
      ));
    }
  }

  Future<void> _handleDeviceDisconnectTriggered(
    DeviceActionTriggered event,
    Emitter<DeviceState> emit,
  ) async {
    try {
      emit(state.copyWith(status: ConnectionStatus.disconnecting));
      final connectedDevice = state.device;
      if (connectedDevice == null) {
        throw BluetoothDisconnectException('No connected device');
      }
      await _deviceRepo.disconnect(connectedDevice);
    } on BluetoothDisconnectException catch (e) {
      _logger.warning(
        'Error when disconnecting from ${event.device.name}: ${e.message}',
      );
      // Emit disconnected. The failure is usually that the device was out of range.
      // The underlying _deviceRepo will disable the reconnectTimer
      emit(state.copyWith(
        status: ConnectionStatus.disconnected,
      ));
    }
  }

  Future<void> _handleDeviceMonitor(
      DeviceMonitor event, Emitter<DeviceState> emit) async {
    await emit.onEach(_deviceRepo.connectionStatus, onData: (event) async {
      final device = state.device;
      if (device == null || !event.device.isSameBluetoothId(device)) {
        return;
      }
      if (state.status == event.status) {
        return;
      }

      String? hardwareRev;
      String? firmwareVersion;
      if (event.status == ConnectionStatus.connected) {
        // Get Hardware revision
        try {
          hardwareRev = String.fromCharCodes(await _deviceRepo.read(
              DeviceInformationCharacteristics
                  .hardwareRevision.characteristic));
        } on BluetoothCommsException catch (e) {
          _logger.severe('Failed to get hardware version: ${e.message}');
        }
        // Get NRF version
        try {
          firmwareVersion = String.fromCharCodes(await _deviceRepo.read(
              DeviceInformationCharacteristics
                  .firmwareRevision.characteristic));
        } on BluetoothCommsException catch (e) {
          _logger.severe('Failed to get NRF version: ${e.message}');
        }
        // Sync host time
        try {
          await _deviceRepo.write(TimeCharacteristics.setTime.characteristic,
              Struct('<Q').pack([DateTime.now().microsecondsSinceEpoch * 1000]),
              withoutResponse: false);
        } on BluetoothCommsException catch (e) {
          _logger.severe('Failed to sync time: ${e.message}');
        }
      }
      emit(state.copyWith(
        status: event.status,
        hardwareRev: hardwareRev,
        firmwareVersion: firmwareVersion,
      ));
    });
  }

  @override
  void onChange(Change<DeviceState> change) {
    super.onChange(change);
    _logger.info('${change.currentState} -> ${change.nextState}');
  }
}
