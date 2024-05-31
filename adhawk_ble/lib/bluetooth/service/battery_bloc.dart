/// battery_bloc is used to monitor the battery status of the glasses
library;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logging/logging.dart';
import '../models/bluetooth_characteristics.dart';
import '../repository/bluetooth_api.dart';
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
  BatteryState({
    required this.status,
    required this.level,
    DateTime? lastThresholdChange,
  }) : lastThresholdChange =
            lastThresholdChange ?? DateTime.fromMicrosecondsSinceEpoch(0);

  BatteryState.unknown() : this(status: BatteryStatus.unknown, level: 0);

  final BatteryStatus status;

  /// Battery level as a percentage
  final int level;

  /// The time of the last threshold change
  final DateTime? lastThresholdChange;

  @override
  List<Object?> get props => [status, level, lastThresholdChange];
}

/// The [BatteryBloc] monitors and emits the [BatteryStatus] of the glasses
class BatteryBloc extends Bloc<BatteryEvent, BatteryState> {
  BatteryBloc({required BluetoothRepository deviceRepo})
      : _deviceRepo = deviceRepo,
        super(BatteryState.unknown()) {
    on<BatteryMonitorToggled>(
      _startBatteryMonitoring,
      transformer: restartable(),
    );
  }

  final BluetoothRepository _deviceRepo;

  final _logger = getLogger((BatteryBloc).toString());

  Future<void> _startBatteryMonitoring(
    BatteryMonitorToggled event,
    Emitter<BatteryState> emit,
  ) async {
    if (!event.on) {
      emit(BatteryState.unknown());
      return;
    }

    try {
      // Get initial levels
      final batteryLevelResponse = await _deviceRepo
          .read(BatteryCharacteristics.batteryLevel.characteristic);

      if (batteryLevelResponse.isEmpty) {
        emit(BatteryState.unknown());
        _logger.warning('Battery level characteristic is empty');
      } else {
        final initialState = _getBatteryState(batteryLevelResponse[0]);
        emit(initialState);
      }

      // Start monitoring levels
      final batteryStream = await _deviceRepo
          .startStream(BatteryCharacteristics.batteryLevel.characteristic);
      await emit.onEach(batteryStream, onData: (data) {
        if (data.isNotEmpty) {
          emit(_getBatteryState(data[0]));
        }
      });
    } on BluetoothCommsException {
      emit(BatteryState.unknown());
    }
  }

  /// Get the [BatteryState] given a battery level
  BatteryState _getBatteryState(int level) {
    BatteryStatus status;
    if (level == 0) {
      status = BatteryStatus.unknown;
    } else if (level < 10) {
      status = BatteryStatus.critical;
    } else if (level < 30) {
      status = BatteryStatus.low;
    } else {
      status = BatteryStatus.ok;
    }
    final threstholdChange =
        state.status == status ? state.lastThresholdChange : DateTime.now();
    return BatteryState(
        status: status, level: level, lastThresholdChange: threstholdChange);
  }
}
