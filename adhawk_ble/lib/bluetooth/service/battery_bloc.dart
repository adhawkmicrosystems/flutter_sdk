/// This library is used to monitor the battery status of the glasses

import 'dart:typed_data';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/bluetooth_characteristics.dart';
import '../repository/bluetooth_repository.dart';

/// Events published to the [BatteryBloc]
sealed class BatteryEvent {}

/// Start/stop monitoring the battery levels
class BatteryMonitorToggled extends BatteryEvent {
  BatteryMonitorToggled({required this.on}) : super();
  final bool on;
}

enum BatteryStatus {
  unknown,
  critical,
  low,
  ok,
}

/// Encapsulates the current state of the battery
class BatteryState extends Equatable {
  const BatteryState({required this.status, required this.level});

  final BatteryStatus status;

  /// Battery level as a percentage
  final int level;

  const BatteryState.unknown() : this(status: BatteryStatus.unknown, level: 0);

  @override
  List<Object> get props => [status, level];
}

/// The [BatteryBloc] monitors and emits the [BatteryStatus] of the glasses
class BatteryBloc extends Bloc<BatteryEvent, BatteryState> {
  BatteryBloc({required BluetoothRepository deviceRepo})
      : _deviceRepo = deviceRepo,
        super(const BatteryState.unknown()) {
    on<BatteryMonitorToggled>(
      _startBatteryMonitoring,
      transformer: restartable(),
    );
  }

  final BluetoothRepository _deviceRepo;

  Future<void> _startBatteryMonitoring(
    BatteryMonitorToggled event,
    Emitter<BatteryState> emit,
  ) async {
    if (!event.on) {
      emit(const BatteryState.unknown());
      return;
    }

    // Get initial levels
    BatteryState initialState = _getBatteryState((await _deviceRepo
        .read(BatteryCharacteristics.batteryLevel.characteristic))[0]);
    emit(initialState);

    // Start monitoring levels
    var batteryStream = await _deviceRepo
        .startStream(BatteryCharacteristics.batteryLevel.characteristic);
    await emit.forEach(batteryStream, onData: (Uint8List data) {
      return _getBatteryState(data[0]);
    });
  }

  /// Get the [BatteryState] given a battery level
  BatteryState _getBatteryState(int level) {
    BatteryStatus status;
    if (level == 0) {
      status = BatteryStatus.unknown;
    } else if (level < 10) {
      status = BatteryStatus.critical;
    } else if (level < 20) {
      status = BatteryStatus.low;
    } else {
      status = BatteryStatus.ok;
    }
    return BatteryState(status: status, level: level);
  }
}
