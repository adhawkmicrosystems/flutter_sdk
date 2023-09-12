import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:retry/retry.dart';

import '../../bluetooth/models/bluetooth_characteristics.dart';
import '../../bluetooth/repository/bluetooth_repository.dart';
import '../../logging/logging.dart';
import '../models/api.dart';
import 'api_packet.dart';
import 'packet.dart';
import 'struct.dart';

class AdhawkApiException implements Exception {
  AdhawkApiException(this.packet);

  @override
  String toString() {
    return packet.ackCode.toString();
  }

  final ResponsePacket packet;
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

  Future<ResponsePacket> setTracking(bool start) async {
    var request = RequestPacket(
      PacketType.systemControl,
      '<2B',
      [SystemControlTypes.tracking.value, start ? 1 : 0],
    );
    return await _sendRequestPacket(request);
  }

  // Get tracker state
  Future<ResponsePacket> getTrackerState() async {
    var request = RequestPacket(PacketType.trackerState);
    return await _sendRequestPacket(request);
  }

  // Get system information state
  Future<ResponsePacket> getSystemInformation(
      SystemInfoTypes systemInfoType) async {
    var request = RequestPacket(
      PacketType.systemInfo,
      '<B',
      [systemInfoType.value],
    );
    return await _sendRequestPacket(request);
  }

  /// Enable eyetracking streams
  Future<ResponsePacket> setEyetrackingStreams(
      Set<StreamTypes> streamTypes, bool enable) async {
    int mask = StreamTypes.createMask(streamTypes);
    var request = RequestPacket(
      PacketType.propertySet,
      '<BLB',
      [PropertyTypes.eyetrackingStreams.value, mask, enable ? 1 : 0],
    );
    return await _sendRequestPacket(request);
  }

  /// Set the eyetracking rate
  Future<ResponsePacket> setEyetrackingRate(double rate) async {
    var request = RequestPacket(
      PacketType.propertySet,
      '<Bf',
      [PropertyTypes.eyetrackingRate.value, rate],
    );
    return await _sendRequestPacket(request);
  }

  /// Enable event streams
  Future<ResponsePacket> setEvents(
      Set<EventControlBit> controlTypes, bool enable) async {
    int mask = EventControlBit.createMask(controlTypes);
    var request = RequestPacket(
      PacketType.propertySet,
      '<BLB',
      [PropertyTypes.eventControl.value, mask, enable ? 1 : 0],
    );
    return await _sendRequestPacket(request);
  }

  /// Trigger an autotune
  Future<ResponsePacket> autotune() async {
    var request = RequestPacket(PacketType.triggerAutotune);
    ResponsePacket response;
    bool trackerReady = false;
    final sub = _trackerStatusController.stream.listen(
      (event) => trackerReady = true,
    );
    try {
      response = await _sendRequestPacket(request);
      await retry(
          () => {
                if (!trackerReady)
                  throw TimeoutException('Tracker is not ready'),
              },
          retryIf: (e) => e is TimeoutException,
          onRetry: (e) => _logger.finer('Waiting for tracker ready'),
          maxDelay: const Duration(seconds: 5));
    } finally {
      sub.cancel();
    }
    return response;
  }

  /// Trigger a single point calibration
  Future<ResponsePacket> singlePointCalibration() async {
    var request = RequestPacket(PacketType.calibrationStart);
    await _sendRequestPacket(request);
    request = RequestPacket(
      PacketType.calibrationRegistration,
      '<3f',
      [0.0, 0.0, -1000.0],
    );
    await _sendRequestPacket(request);
    request = RequestPacket(PacketType.calibrationComplete);
    return await _sendRequestPacket(request);
  }

  /// Send request packets to the command characteristic
  Future<ResponsePacket> _sendRequestPacket(RequestPacket request) async {
    var bytes = request.encode();
    _logger.fine('[TX] $request (${Struct.toHexString(bytes)})');
    await deviceRepo.write(
      AdhawkCharacteristics.command.characteristic,
      bytes,
    );
    var responsePacket = await _waitForResponse(request);
    if (responsePacket.ackCode != AckCode.success) {
      throw AdhawkApiException(responsePacket);
    }
    return responsePacket;
  }

  /// Handle response packets and put them on a queue
  void _handleResponsePackets(Uint8List bytes) {
    var response = ResponsePacket.fromBytes(bytes);
    _logger.fine('[RX] $response');
    _responseQueue[response.requestId] = response;
  }

  /// Check the response queue for responses that match the request ID
  Future<ResponsePacket> _waitForResponse(RequestPacket request) async {
    return await retry(
      () {
        ResponsePacket? response = _responseQueue[request.requestId];
        if (response == null) {
          throw TimeoutException('No response for $request');
        }
        _responseQueue.remove(request.requestId);
        _logger.finer('[AK] $response');
        return response;
      },
      // Total wait time is approximately
      // 50 + 100 + 200 + 400 + 800 + 1600 + 3200 + 6400 = 12,750ms
      delayFactor: const Duration(milliseconds: 50),
      maxAttempts: 8,
      retryIf: (e) => e is TimeoutException,
      onRetry: (e) => _logger.finer('Waiting for $request'),
    );
  }

  /// Handle eyetracking stream packets
  void _handleEyetrackingStream(Uint8List bytes) {
    int offset = 0;
    while (offset < bytes.length) {
      var packet = StreamPacket.fromBytes(Uint8List.sublistView(bytes, offset));
      var etData = EyeTrackingPacket.decode(packet.payload);
      _rawPktController.add(packet);
      _etController.add(etData);
      offset += packet.length;
    }
  }

  /// Handle event stream packets
  void _handleEventStream(Uint8List bytes) {
    int offset = 0;
    while (offset < bytes.length) {
      var packet = StreamPacket.fromBytes(Uint8List.sublistView(bytes, offset));
      var event = EventPacket.decode(packet.payload);
      _rawPktController.add(packet);
      _eventController.add(event);
      offset += packet.length;
    }
  }

  /// Handle status stream packets
  void _handleStatusStream(Uint8List bytes) {
    int offset = 0;
    while (offset < bytes.length) {
      try {
        var packet =
            StreamPacket.fromBytes(Uint8List.sublistView(bytes, offset));
        if (packet.packetType == PacketType.trackerReady) {
          _logger.info('Tracker Ready');
          _trackerStatusController.add(AckCode.success);
          offset += 1;
        }
      } catch (e) {
        _logger.info('Unhandled packet: $e');
      }
    }
  }
}
