/// scan_bloc is used to trigger bluetooth scans for AdHawk BLE enabled glasses
///
/// The [ScanState] reflects the current [ScanStatus] and provides a list of AdHawk
/// [Device]s in the vicinity
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logging/logging.dart';
import '../models/device.dart';
import '../repository/bluetooth_api.dart';
import '../repository/bluetooth_repository.dart';

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
    return '$status (devices: ${devices.length})';
  }
}

/// [ScanBloc] responds to events from the UI layer that start or stop
/// a bluetooth scan for devices.
class ScanBloc extends Bloc<ScanEvent, ScanState> {
  ScanBloc({required BluetoothRepository deviceRepo})
      : _deviceRepo = deviceRepo,
        super(const ScanState()) {
    on<ScanStarted>(_onScanStarted);
    on<ScanStopped>(_onScanStopped);
  }

  final BluetoothRepository _deviceRepo;
  final _logger = getLogger((ScanBloc).toString());

  @override
  Future<void> close() async {
    if (state.status != ScanStatus.stopped) {
      await _deviceRepo.stopScan();
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

  Future<void> _onScanStarted(ScanEvent event, Emitter<ScanState> emit) async {
    try {
      if (state.status == ScanStatus.scanning) {
        return;
      }
      final deviceStream = _deviceRepo.startScan();
      emit(const ScanState(status: ScanStatus.scanning));
      await emit.forEach(deviceStream, onData: (devices) {
        return ScanState(status: ScanStatus.success, devices: devices);
      });
    } on BluetoothScanException {
      emit(const ScanState(status: ScanStatus.failure));
    }
  }

  Future<void> _onScanStopped(ScanEvent event, Emitter<ScanState> emit) async {
    try {
      if (state.status == ScanStatus.stopped) {
        return;
      }
      await _deviceRepo.stopScan();
      emit(const ScanState());
    } on BluetoothScanException catch (e) {
      _logger.warning(e);
    }
  }
}
