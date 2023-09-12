/// scan_bloc is used to trigger bluetooth scans for AdHawk BLE enabled glasses
///
/// The [ScanState] reflects the current [ScanStatus] and provides a list of AdHawk
/// [Device]s in the vicinity

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logging/logging.dart';
import '../repository/bluetooth_repository.dart';
import '../models/device.dart';

///  Scan Events
abstract class ScanEvent {}

/// Event triggered when the user starts the scan
class ScanStarted extends ScanEvent {}

/// Event triggered when the user stops the scan
class ScanStopped extends ScanEvent {}

/// Scan Status
enum ScanStatus { stopped, success, failure, scanning }

/// Scan State
class ScanState {
  const ScanState({
    this.status = ScanStatus.stopped,
    this.devices = const <Device>[],
  });

  final ScanStatus status;
  final List<Device> devices;

  @override
  String toString() {
    return '${status.toString()} (devices: ${devices.length})';
  }
}

/// [ScanBloc] responds to events from the UI layer that start or stop
/// a bluetooth scan for devices.
class ScanBloc extends Bloc<ScanEvent, ScanState> {
  ScanBloc({required BluetoothRepository deviceRepo})
      : _deviceRepo = deviceRepo,
        super(const ScanState()) {
    on<ScanStarted>((event, emit) async {
      try {
        if (state.status == ScanStatus.scanning) {
          return;
        }
        Stream<List<Device>> deviceStream = _deviceRepo.startScan();
        emit(const ScanState(status: ScanStatus.scanning));
        await emit.forEach(deviceStream, onData: (devices) {
          return ScanState(status: ScanStatus.success, devices: devices);
        });
      } catch (error) {
        emit(const ScanState(status: ScanStatus.failure, devices: []));
      }
    });

    on<ScanStopped>((event, emit) {
      try {
        if (state.status == ScanStatus.stopped) {
          return;
        }
        _deviceRepo.stopScan();
        emit(const ScanState(status: ScanStatus.stopped, devices: []));
      } catch (error) {
        emit(const ScanState(status: ScanStatus.failure, devices: []));
      }
    });
  }

  @override
  Future<void> close() async {
    if (state.status != ScanStatus.stopped) {
      add(ScanStopped());
    }
    await super.close();
  }

  @override
  void onChange(Change<ScanState> change) {
    super.onChange(change);
    if (change.nextState.status == ScanStatus.failure) {
      _logger.severe('${change.currentState} -> ${change.nextState}');
    }
  }

  final BluetoothRepository _deviceRepo;
  final _logger = getLogger((ScanBloc).toString());
}
