/// tracker_bloc is used to manage the state of the AdHawk Eye Tracker
///
/// The presentation layer issues [TrackerEvent]s to the [TrackerBloc]
/// The commands are passed to the glasses over Bluetooth.
/// The result of the commands are reflected in the [TrackerState]
/// The [TrackerState] also contains the current [EyeTrackingData]
library;

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logging/logging.dart';
import '../models/api.dart';
import '../repository/adhawkapi.dart';
import '../repository/api_packet.dart';

/// Events published to the [TrackerBloc]
sealed class TrackerEvent {}

/// Commands issued to the tracker
sealed class TrackerCommand implements TrackerEvent {}

/// Start communication with the eye tracker
///
/// This must be called before any other commands are issued to the tracker
final class StartComms implements TrackerCommand {}

/// Start the personalization process
final class PersonalizeTracker implements TrackerCommand {}

/// Calibrate the tracker for a particular user
final class UserCalibration implements TrackerCommand {}

/// Stop communication with the eye tracker
final class StopComms implements TrackerCommand {}

/// Streaming commands issued to the tracker
final class StreamStartStop implements TrackerEvent {
  StreamStartStop({required this.start});

  /// Whether to start or stop streams
  final bool start;
}

/// The currenct operating status of the tracker
enum TrackerStatus {
  /// Communication with the tracker has stopped
  unavailable,

  /// The tracker is active and tracking
  active,

  /// The tracker is being personalized
  personalizing,

  /// The tracker is currently being tuned
  tuning,

  /// The tacker is being calibrated for the user
  calibrating,

  /// Commands issued to the tracker have failed
  faulted,
}

/// Encapsulates the current state of the tracker
class TrackerState {
  TrackerState({
    required this.status,
    required this.streaming,
    this.statusMessage = '',
    this.serialNumber = '',
    this.firmwareVersion = '',
    this.etData,
    this.eventData,
  });

  TrackerState.unavailable()
      : this(
          status: TrackerStatus.unavailable,
          streaming: false,
        );

  /// The operating status of the tracker
  final TrackerStatus status;

  /// A relevant status message if the [TrackerStatus] is [TrackerStatus.faulted]
  final String statusMessage;

  /// The serial number of the glasses
  final String serialNumber;

  /// The version of the firmware on the glasses
  final String firmwareVersion;

  /// The current [EyeTrackingData]
  final EyeTrackingData? etData;

  /// Populated if an eyetracking event was detected
  final EventData? eventData;

  /// Whether we're streaming live data
  final bool streaming;

  TrackerState copyWith({
    TrackerStatus? status,
    bool? streaming,
    String? statusMessage,
    String? serialNumber,
    String? firmwareVersion,
    EyeTrackingData? etData,
    EventData? eventData,
  }) =>
      TrackerState(
        status: status ?? this.status,
        streaming: streaming ?? this.streaming,
        statusMessage: statusMessage ?? this.statusMessage,
        serialNumber: serialNumber ?? this.serialNumber,
        firmwareVersion: firmwareVersion ?? this.firmwareVersion,
        etData: etData ?? this.etData,
        eventData: eventData, // If an event is not provided, it is set to null
      );

  @override
  String toString() {
    return '$status (serialNumber: $serialNumber)';
  }
}

/// User facing error messages
enum ErrorMsg {
  apiStartFailures('Failed to start communication'),
  apiStopFailures('Failed to stop communication'),
  enableStreamFailure('Failed to start eyetracking streams'),
  disableStreamFailure('Failed to stop eyetracking streams'),
  personalizationFailure('Failed to personalize the glasses'),
  userCalibrationFailure('User calibration failed'),
  ;

  const ErrorMsg(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

/// The [TrackerBloc] responds to [TrackerEvent]s and is the interface to the
/// eye tracker on the glasses
class TrackerBloc extends Bloc<TrackerEvent, TrackerState> {
  TrackerBloc({required api})
      : _api = api,
        super(TrackerState.unavailable()) {
    on<TrackerCommand>(_handleTrackerCommandEvents, transformer: restartable());
    on<StreamStartStop>(_handleTrackerStreamEvents, transformer: restartable());
  }

  final AdHawkApi _api;
  final _logger = getLogger((TrackerBloc).toString());
  static const Set<StreamTypes> _enabledStreams = {
    StreamTypes.gaze,
    StreamTypes.eyeCenter,
    StreamTypes.pupilDiameter,
    StreamTypes.imuQuaternion,
  };
  static const Set<EventControlBit> _enabledEvents = {
    EventControlBit.blink,
    EventControlBit.saccade,
  };

  @override
  void onChange(Change<TrackerState> change) {
    super.onChange(change);
    if (change.currentState.status != change.nextState.status) {
      final logFn = change.nextState.status == TrackerStatus.faulted
          ? _logger.severe
          : _logger.info;

      logFn('${change.currentState} -> ${change.nextState}');
    }
  }

  Future<void> _handleTrackerCommandEvents(
      TrackerCommand event, Emitter<TrackerState> emit) async {
    switch (event) {
      case StartComms():
        await _handleStartComms(event, emit);
      case PersonalizeTracker():
        await _handlePersonalization(event, emit);
      case UserCalibration():
        await _handleUserCalibration(event, emit);
      case StopComms():
        await _handleStopComms(event, emit);
    }
  }

  Future<void> _handleTrackerStreamEvents(
      StreamStartStop event, Emitter<TrackerState> emit) async {
    if (event.start) {
      await _handleStartStreams(event, emit);
    } else {
      await _handleStopStreams(event, emit);
    }
  }

  Future<void> _handleStartComms(event, Emitter<TrackerState> emit) async {
    _logger.info('Start tracker communication');
    try {
      await _api.start();
      final serialNumber = await _getSerialNumber();
      var firmwareVersion = '';
      try {
        firmwareVersion = await _getFirmwareVersion();
      } on Exception {
        // We don't strictly need the firmware version for operation
        // This is a workaround for TRSW-8107
      }
      await _api.setEvents(eventTypes: _enabledEvents, enable: true);
      emit(TrackerState(
        status: TrackerStatus.active,
        serialNumber: serialNumber,
        firmwareVersion: firmwareVersion,
        streaming: false,
      ));
    } on CommsException catch (e) {
      emit(_handleDeviceDisconnected(e));
    } on TrackerException catch (e) {
      emit(_handleError(ErrorMsg.apiStartFailures, e));
    }
  }

  Future<String> _getFirmwareVersion() async {
    final res =
        await _api.getSystemInformation(SystemInfoTypes.firmwareVersion);
    return SystemInfoPacket.decode(res.payload);
  }

  Future<String> _getSerialNumber() async {
    final res = await _api.getSystemInformation(SystemInfoTypes.deviceSerial);
    return SystemInfoPacket.decode(res.payload);
  }

  Future<void> _handleStopComms(event, Emitter<TrackerState> emit) async {
    _logger.info('Stop tracker communication');
    try {
      await _api.stop();
      emit(TrackerState.unavailable());
    } on Exception catch (e) {
      emit(_handleError(ErrorMsg.apiStopFailures, e));
    }
  }

  Future<void> _handleStartStreams(event, Emitter<TrackerState> emit) async {
    _logger.info('Start eyetracking streams');
    try {
      await _api.setEyetrackingStreams(
        streamTypes: _enabledStreams,
        enable: true,
      );
    } on CommsException catch (e) {
      emit(_handleDeviceDisconnected(e));
      return;
    } on TrackerException catch (e) {
      emit(_handleError(ErrorMsg.enableStreamFailure, e));
      return;
    }
    emit(state.copyWith(streaming: true));
    // Setup the emitters
    await Future.wait([
      emit.onEach(_api.etData, onData: (etData) {
        if (etData.perEyeGaze.isValid() && etData.pupilDiameter.isValid()) {
          final utcTime = DateTime.now();
          etData
            ..gaze.utctime = utcTime
            ..perEyeGaze.utctime = utcTime
            ..eyeCenter.utctime = utcTime
            ..pupilPosition.utctime = utcTime
            ..pupilDiameter.utctime = utcTime;
          emit(state.copyWith(etData: etData));
        }
      }),
      emit.onEach(_api.eventData, onData: (event) {
        final utcTime = DateTime.now();
        event.utctime = utcTime;
        if (event.isValid()) {
          emit(state.copyWith(eventData: event));
        }
      }),
    ]);
  }

  Future<void> _handleStopStreams(event, Emitter<TrackerState> emit) async {
    _logger.info('Stop eyetracking streams');
    try {
      await _api.setEyetrackingStreams(
        streamTypes: _enabledStreams,
        enable: false,
      );
      emit(state.copyWith(streaming: false));
      // Don't disable any events. They still need to be recorded by NRF.
    } on CommsException catch (e) {
      emit(_handleDeviceDisconnected(e));
      return;
    } on TrackerException catch (e) {
      emit(_handleError(ErrorMsg.disableStreamFailure, e));
      return;
    }
  }

  Future<void> _handlePersonalization(event, Emitter<TrackerState> emit) async {
    try {
      emit(state.copyWith(status: TrackerStatus.personalizing));
      await _api.waitForTrackerReady(() async {
        await _api.clearBlob(BlobType.personalization);
      });
      emit(state.copyWith(status: TrackerStatus.active));
    } on CommsException catch (e) {
      emit(_handleDeviceDisconnected(e));
    } on TrackerException catch (e) {
      if (e is RequestFailedException &&
          e.packet.ackCode == AckCode.invalidArgument) {
        // older firmware might not support the personalization blob
        emit(state.copyWith(status: TrackerStatus.active));
      } else {
        emit(_handleError(ErrorMsg.personalizationFailure, e));
      }
    }
  }

  Future<void> _handleUserCalibration(event, Emitter<TrackerState> emit) async {
    try {
      emit(state.copyWith(status: TrackerStatus.tuning));
      await _api.autotune();
      emit(state.copyWith(status: TrackerStatus.calibrating));
      await _api.singlePointCalibration();
      emit(state.copyWith(status: TrackerStatus.active));
    } on CommsException catch (e) {
      emit(_handleDeviceDisconnected(e));
    } on TrackerException catch (e) {
      emit(_handleError(ErrorMsg.userCalibrationFailure, e));
    }
  }

  TrackerState _handleDeviceDisconnected(Exception e) {
    _logger.warning('$e');
    return state.copyWith(
        status: TrackerStatus.unavailable,
        statusMessage: 'Device disconnected');
  }

  TrackerState _handleError(ErrorMsg msg, Exception e) {
    _logger.severe('$msg. $e');
    return state.copyWith(
      status: TrackerStatus.faulted,
      statusMessage: msg.toString(),
    );
  }
}
