import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:retry/retry.dart';

import '../../bluetooth/models/bluetooth_characteristics.dart';
import '../../bluetooth/repository/bluetooth_api.dart';
import '../../bluetooth/repository/bluetooth_repository.dart';
import '../../logging/logging.dart';
import '../../utilities/formatters.dart';
import '../models/api.dart';
import 'api_packet.dart';
import 'packet.dart';

class TrackerException implements Exception {
  TrackerException(this.message);

  @override
  String toString() => message;

  String message;
}

class RequestFailedException extends TrackerException {
  RequestFailedException(this.packet) : super(packet.ackCode.toString());

  @override
  String toString() {
    return packet.ackCode.toString();
  }

  final ResponsePacket packet;
}

class RequestTimeoutException extends TrackerException {
  RequestTimeoutException(super.message);
}

class CommsException implements Exception {
  CommsException(this.message);

  @override
  String toString() => message;

  String message;
}

class AdHawkApi {
  AdHawkApi({required this.deviceRepo});

  final BluetoothRepository deviceRepo;
  final _logger = getLogger((AdHawkApi).toString());
  final Map<int, ResponsePacket> _responseQueue = {};
  final _etController = StreamController<EyeTrackingData>.broadcast();
  final _eventController = StreamController<EventData>.broadcast();
  final _trackerStatusController = StreamController<AckCode>.broadcast();
  final _rawPktController = StreamController<StreamPacket>.broadcast();

  // Subscriptions to streams from the underlying service
  StreamSubscription<Uint8List>? _responseStreamSub;
  StreamSubscription<Uint8List>? _etStreamSub;
  StreamSubscription<Uint8List>? _eventStreamSub;
  StreamSubscription<Uint8List>? _trackerStatusSub;

  /// Initialize the API by enabling notifications on
  /// all applicable characteristics
  Future<void> start() async {
    _logger.info('Initializing adhawkapi');

    try {
      _responseStreamSub = await deviceRepo
          .startStream(AdhawkCharacteristics.command.characteristic)
          .then((stream) => stream.listen(_handleResponsePackets),
              onError: (error) => _logger.severe(error.toString()));

      _etStreamSub = await deviceRepo
          .startStream(AdhawkCharacteristics.eyetrackingStream.characteristic)
          .then((stream) => stream.listen(_handleEyetrackingStream),
              onError: (error) => _logger.warning(error.toString()));

      _eventStreamSub = await deviceRepo
          .startStream(AdhawkCharacteristics.eventStream.characteristic)
          .then((stream) => stream.listen(_handleEventStream),
              onError: (error) => _logger.warning(error.toString()));

      _trackerStatusSub = await deviceRepo
          .startStream(AdhawkCharacteristics.statusStream.characteristic)
          .then((stream) => stream.listen(_handleStatusStream),
              onError: (error) => _logger.warning(error.toString()));
    } on BluetoothCommsException catch (e) {
      throw CommsException(e.message);
    }
  }

  Stream<EyeTrackingData> get etData async* {
    yield* _etController.stream;
  }

  Stream<EventData> get eventData async* {
    yield* _eventController.stream;
  }

  Stream<AckCode> get trackerStatus async* {
    yield* _trackerStatusController.stream;
  }

  Stream<StreamPacket> get rawPacket async* {
    yield* _rawPktController.stream;
  }

  Future<void> stop() async {
    await _responseStreamSub?.cancel();
    await _etStreamSub?.cancel();
    await _eventStreamSub?.cancel();
    await _trackerStatusSub?.cancel();
  }

  Future<void> dispose() async {
    await _etController.close();
    await _eventController.close();
    await _trackerStatusController.close();
    await _rawPktController.close();
  }

  Future<ResponsePacket> setTracking({required bool track}) async {
    final request = RequestPacket(
      PacketType.systemControl,
      '<2B',
      [SystemControlTypes.tracking.value, track ? 1 : 0],
    );
    return _sendRequestPacket(request);
  }

  // Get tracker state
  Future<ResponsePacket> getTrackerState() async {
    final request = RequestPacket(PacketType.trackerState);
    return _sendRequestPacket(request);
  }

  // Get system information state
  Future<ResponsePacket> getSystemInformation(
      SystemInfoTypes systemInfoType) async {
    final request = RequestPacket(
      PacketType.systemInfo,
      '<B',
      [systemInfoType.value],
    );
    return _sendRequestPacket(request);
  }

  /// Enable eyetracking streams
  Future<ResponsePacket> setEyetrackingStreams({
    required Set<StreamTypes> streamTypes,
    required bool enable,
  }) async {
    final mask = StreamTypes.createMask(streamTypes);
    final request = RequestPacket(
      PacketType.propertySet,
      '<BLB',
      [PropertyTypes.eyetrackingStreams.value, mask, enable ? 1 : 0],
    );
    return _sendRequestPacket(request);
  }

  /// Set the eyetracking rate
  Future<ResponsePacket> setEyetrackingRate(double rate) async {
    final request = RequestPacket(
      PacketType.propertySet,
      '<Bf',
      [PropertyTypes.eyetrackingRate.value, rate],
    );
    return _sendRequestPacket(request);
  }

  /// Enable event streams
  Future<ResponsePacket> setEvents({
    required Set<EventControlBit> eventTypes,
    required bool enable,
  }) async {
    final mask = EventControlBit.createMask(eventTypes);
    final request = RequestPacket(
      PacketType.propertySet,
      '<BLB',
      [PropertyTypes.eventControl.value, mask, enable ? 1 : 0],
    );
    return _sendRequestPacket(request);
  }

  /// Trigger an autotune
  Future<void> autotune() async {
    final request = RequestPacket(PacketType.triggerAutotune);
    return waitForTrackerReady(() async => _sendRequestPacket(request));
  }

  Future<void> waitForTrackerReady(
    Future<void> Function() callback, {
    Duration duration = const Duration(seconds: 5),
  }) async {
    var trackerReady = false;
    final sub = _trackerStatusController.stream.listen(
      (event) => trackerReady = true,
    );
    try {
      await callback();
      await retry(
          () => {
                if (!trackerReady)
                  throw RequestTimeoutException('Tracker is not ready'),
              },
          retryIf: (e) => e is RequestTimeoutException,
          onRetry: (e) => _logger.finer('Waiting for tracker ready'),
          maxDelay: duration);
    } finally {
      await sub.cancel();
    }
  }

  /// Trigger a single point calibration
  Future<ResponsePacket> singlePointCalibration() async {
    var request = RequestPacket(PacketType.calibrationStart);
    await _sendRequestPacket(request);
    request = RequestPacket(
      PacketType.calibrationRegistration,
      '<3f',
      [0.0, 0.0, -1.0],
    );
    await _sendRequestPacket(request);
    request = RequestPacket(PacketType.calibrationComplete);
    return _sendRequestPacket(request);
  }

  /// Clear the blob
  Future<ResponsePacket> clearBlob(BlobType blobType) async {
    final request = RequestPacket(
      PacketType.blobSize,
      '<BH',
      [blobType.value, 0],
    );
    return _sendRequestPacket(request);
  }

  /// Send request packets to the command characteristic
  ///
  /// Throws [CommsException] if we're unable to communicate with the device
  /// Throws [TrackerException] if the reponse ack code is an error
  /// or the request times out
  Future<ResponsePacket> _sendRequestPacket(RequestPacket request) async {
    final bytes = request.encode();
    _logger.fine('[TX] $request (${bytes.toHexString()})');
    try {
      await deviceRepo.write(
        AdhawkCharacteristics.command.characteristic,
        bytes,
      );
    } on BluetoothCommsException catch (e) {
      throw CommsException(e.message);
    }

    final responsePacket = await _waitForResponse(request);
    if (responsePacket.ackCode != AckCode.success) {
      _logger.severe('[RX] $request ${responsePacket.ackCode}');
      throw RequestFailedException(responsePacket);
    }
    return responsePacket;
  }

  /// Handle response packets and put them on a queue
  void _handleResponsePackets(Uint8List bytes) {
    try {
      final response = ResponsePacket.fromBytes(bytes);
      _logger.fine('[RX] $response');
      _responseQueue[response.requestId] = response;
    } on Exception catch (e) {
      _logger.severe('$e ${bytes.toHexString()}');
    }
  }

  /// Check the response queue for responses that match the request ID
  /// Throws [RequestTimeoutException] if no response was received
  Future<ResponsePacket> _waitForResponse(RequestPacket request) async {
    return retry(
      () {
        final response = _responseQueue[request.requestId];
        if (response == null) {
          throw RequestTimeoutException('No response for $request');
        }
        _responseQueue.remove(request.requestId);
        _logger.finer('[AK] $response');
        return response;
      },
      // Total wait time is approximately
      // 50 + 100 + 200 + 400 + 800 + 1600 + 3200 + 6400 = 12,750ms
      delayFactor: const Duration(milliseconds: 50),
      maxAttempts: 8,
      retryIf: (e) => e is RequestTimeoutException,
      onRetry: (e) => _logger.finer('Waiting for $request'),
    );
  }

  /// Handle eyetracking stream packets
  void _handleEyetrackingStream(Uint8List bytes) {
    var offset = 0;
    while (offset < bytes.length) {
      try {
        final packet =
            StreamPacket.fromBytes(Uint8List.sublistView(bytes, offset));
        final etData = EyeTrackingPacket.decode(packet.payload);
        _rawPktController.add(packet);
        _etController.add(etData);
        offset += packet.length;
      } on Exception catch (e) {
        _logger.finest('$e ${bytes.toHexString()}');
        break;
      }
    }
  }

  /// Handle event stream packets
  void _handleEventStream(Uint8List bytes) {
    var offset = 0;
    while (offset < bytes.length) {
      try {
        final packet =
            StreamPacket.fromBytes(Uint8List.sublistView(bytes, offset));
        final event = EventPacket.decode(packet.payload);
        _rawPktController.add(packet);
        _eventController.add(event);
        offset += packet.length;
      } on Exception catch (e) {
        _logger.finest('$e ${bytes.toHexString()}');
        break;
      }
    }
  }

  /// Handle status stream packets
  void _handleStatusStream(Uint8List bytes) {
    var offset = 0;
    while (offset < bytes.length) {
      try {
        final packet =
            StreamPacket.fromBytes(Uint8List.sublistView(bytes, offset));
        if (packet.packetType == PacketType.trackerReady) {
          _logger.info('Tracker Ready');
          _trackerStatusController.add(AckCode.success);
          offset += 1;
        }
      } on Exception catch (e) {
        _logger.finest('$e ${bytes.toHexString()}');
        break;
      }
    }
  }
}
