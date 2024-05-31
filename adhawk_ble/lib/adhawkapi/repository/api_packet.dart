import 'dart:typed_data';

import '../../utilities/struct.dart';
import '../models/api.dart';

/// Ack Codes
enum AckCode {
  success(0, ''),
  failure(1, 'Internal failure'),
  invalidArgument(2, 'Invalid argument'),
  trackerNotReady(3, 'Trackers not ready'),
  eyesNotFound(4, 'No eyes detected'),
  rightEyeNotFound(5, 'Right eye not detected'),
  leftEyeNotFound(6, 'Left eye not detected'),
  notCalibrated(7, 'Not calibrated'),
  notSupported(8, 'Not supported'),
  sessionAlreadyRunning(9, 'Data logging session already exists'),
  noCurrentSession(10, 'No data logging session exists to stop'),
  requestTimeout(11, 'Request has timed out'),
  unexpectedResponse(12, 'Unexpected response'),
  hardwareFault(13, 'Hardware faulted'),
  cameraFault(14, 'Camera initialization failed'),
  busy(15, 'System is busy'),
  communicationError(16, 'Communication error'),
  deviceCalibrationRequired(17, 'Device calibration is outdated'),
  processIncomplete(18, 'Process was aborted or interrupted unexpectedly'),
  inactiveInterface(17, 'Packet received from an inactive interface'),
  ;

  const AckCode(this.value, this.message);

  factory AckCode.from(int value) {
    return values.firstWhere((element) => value == element.value,
        orElse: () => throw Exception('No matching ackcode: $value'));
  }

  final int value;
  final String message;

  @override
  String toString() {
    return message;
  }
}

/// Packet types
enum PacketType {
  // Streams
  eyetrackingStream(0x01),
  trackerReady(0x02),
  events(0x18),
  // Commands
  triggerAutotune(0x85),
  calibrationStart(0x81),
  calibrationComplete(0x82),
  calibrationAbort(0x83),
  calibrationRegistration(0x84),
  trackerState(0x90),
  blobSize(0x92),
  propertyGet(0x9a),
  propertySet(0x9b),
  systemControl(0x9c),
  systemInfo(0x99),
  ;

  const PacketType(this.value);
  factory PacketType.from(int value) {
    return values.firstWhere((element) => value == element.value,
        orElse: () => throw Exception('No matching packet type: $value'));
  }
  bool get isStream => value < 0x80;
  final int value;
}

/// Property types for [PacketType.propertyGet] and [PacketType.propertySet]
enum PropertyTypes {
  eventControl(5),
  eyetrackingRate(13),
  eyetrackingStreams(14),
  featureStreams(15),
  ;

  const PropertyTypes(this.value);
  factory PropertyTypes.from(int value) {
    return values.firstWhere((element) => value == element.value,
        orElse: () => throw Exception('No matching property type: $value'));
  }
  final int value;
}

/// SystemControl types for [PacketType.systemControl]
enum SystemControlTypes {
  tracking(1),
  ;

  const SystemControlTypes(this.value);
  factory SystemControlTypes.from(int value) {
    return values.firstWhere((element) => value == element.value,
        orElse: () =>
            throw Exception('No matching system control type: $value'));
  }
  final int value;
}

/// SystemInfo types for [PacketType.systemInfo]
enum SystemInfoTypes {
  deviceSerial(2),
  firmwareApi(3),
  firmwareVersion(4),
  ;

  const SystemInfoTypes(this.value);
  factory SystemInfoTypes.from(int value) {
    return values.firstWhere((element) => value == element.value,
        orElse: () => throw Exception('No matching system info type: $value'));
  }
  final int value;
}

/// Stream types
enum StreamTypes {
  /// Eyetracking Stream Types
  gaze(1),
  perEyeGaze(2),
  eyeCenter(3),
  pupilPosition(4),
  pupilDiameter(5),
  imuQuaternion(8),
  ;

  const StreamTypes(this.value);
  factory StreamTypes.from(int value) {
    return values.firstWhere((element) => value == element.value,
        orElse: () => throw Exception('No matching stream type: $value'));
  }
  static List<StreamTypes> fromMask(int mask) {
    final streamTypes = <StreamTypes>[];
    for (final stream in values) {
      if (mask & (1 << stream.value) != 0) {
        streamTypes.add(stream);
      }
    }
    return streamTypes;
  }

  int get mask => 1 << value;

  static int createMask(Set<StreamTypes> streams) {
    var mask = 0;
    for (final stream in streams) {
      mask |= stream.mask;
    }
    return mask;
  }

  final int value;
}

enum EventTypes {
  /// Eyetracking Stream Types
  blink(1),
  eyeClosed(2),
  eyeOpened(3),
  tracklossStart(4),
  tracklossEnd(5),
  saccade(6),
  saccadeStart(7),
  saccadeEnd(8),
  depth(14),
  ;

  const EventTypes(this.value);
  factory EventTypes.from(int value) {
    return values.firstWhere((element) => value == element.value,
        orElse: () => throw Exception('No matching event type: $value'));
  }
  final int value;
}

enum EventControlBit {
  blink(0),
  eyeCloseOpen(1),
  saccade(3),
  saccadeEnd(4),
  ;

  const EventControlBit(this.value);
  factory EventControlBit.from(int value) {
    return values.firstWhere((element) => value == element.value,
        orElse: () => throw Exception('No matching event control bit: $value'));
  }
  int get mask => 1 << value;
  static int createMask(Set<EventControlBit> controls) {
    var mask = 0;
    for (final control in controls) {
      mask |= control.mask;
    }
    return mask;
  }

  final int value;
}

enum BlobType {
  personalization(10),
  ;

  const BlobType(this.value);
  final int value;
}

class GazePacket {
  static int get size => _struct.size;

  static Gaze decode(Uint8List bytes) {
    final data = List<double>.from(_struct.unpackFrom(bytes));
    if (data.length != 4) {
      throw FormatException('Gaze requires 4 values. Got ${data.length}');
    }
    return Gaze(
      cyclopean: Coordinates(x: data[0], y: data[1], z: data[2]),
      vergence: data[3],
    );
  }

  static final _struct = Struct('<4f');
}

class PerEyeGazePacket {
  static int get size => _struct.size;

  static PerEyeGaze decode(Uint8List bytes) {
    final data = List<double>.from(_struct.unpackFrom(bytes));
    if (data.length != 6) {
      throw FormatException('PerEyeGaze requires 6 values. Got ${data.length}');
    }
    return PerEyeGaze(
      right: Coordinates(x: data[0], y: data[1], z: data[2]),
      left: Coordinates(x: data[3], y: data[4], z: data[5]),
    );
  }

  static final _struct = Struct('<6f');
}

class EyeCenterPacket {
  static int get size => _struct.size;

  static EyeCenter decode(Uint8List bytes) {
    final data = List<double>.from(_struct.unpackFrom(bytes));
    if (data.length != 6) {
      throw FormatException('EyeCenter requires 6 values. Got ${data.length}');
    }
    return EyeCenter(
      right: Coordinates(x: data[0], y: data[1], z: data[2]),
      left: Coordinates(x: data[3], y: data[4], z: data[5]),
    );
  }

  static final _struct = Struct('<6f');
}

class PupilPositionPacket {
  static int get size => _struct.size;

  static PupilPosition decode(Uint8List bytes) {
    final data = List<double>.from(_struct.unpackFrom(bytes));
    if (data.length != 6) {
      throw FormatException(
          'PupilPosition requires 6 values. Got ${data.length}');
    }
    return PupilPosition(
      right: Coordinates(x: data[0], y: data[1], z: data[2]),
      left: Coordinates(x: data[3], y: data[4], z: data[5]),
    );
  }

  static final _struct = Struct('<6f');
}

class PupilDiameterPacket {
  static int get size => _struct.size;

  static PupilDiameter decode(Uint8List bytes) {
    final data = List<double>.from(_struct.unpackFrom(bytes));
    if (data.length != 2) {
      throw FormatException(
          'PupilDiameter requires 2 values. Got ${data.length}');
    }
    return PupilDiameter(
      right: data[0],
      left: data[1],
    );
  }

  static final _struct = Struct('<2f');
}

class IMUQuaternionPacket {
  static int get size => _struct.size;

  static IMUQuaternion decode(Uint8List bytes) {
    final data = List<double>.from(_struct.unpackFrom(bytes));
    if (data.length != 4) {
      throw FormatException(
          'IMUQuaternion requires 4 values. Got ${data.length}');
    }
    return IMUQuaternion(
      x: data[0],
      y: data[1],
      z: data[2],
      w: data[3],
    );
  }

  static final _struct = Struct('<4f');
}

class EyeTrackingPacket {
  static EyeTrackingData decode(Uint8List bytes) {
    var offset = _timestampStruct.size;
    final timestamp = _timestampStruct.unpackFrom(bytes)[0] as int;
    final mask = _maskStruct.unpackFrom(bytes, offset)[0] as int;
    if (mask < 3) {
      throw const FormatException('Eye tracking packet is in monocular format');
    }
    offset += 1;
    final etData = EyeTrackingData();
    while (offset < bytes.length) {
      final unpacked = _streamTypeStruct.unpackFrom(bytes, offset);
      final streamType = StreamTypes.from(unpacked[0] as int);
      offset += 1;
      final sublist = Uint8List.sublistView(bytes, offset);
      switch (streamType) {
        case StreamTypes.gaze:
          etData.gaze = GazePacket.decode(sublist)..timestamp = timestamp;
          offset += GazePacket.size;
        case StreamTypes.perEyeGaze:
          etData.perEyeGaze = PerEyeGazePacket.decode(sublist)
            ..timestamp = timestamp;
          offset += PerEyeGazePacket.size;
        case StreamTypes.eyeCenter:
          etData.eyeCenter = EyeCenterPacket.decode(sublist)
            ..timestamp = timestamp;
          offset += EyeCenterPacket.size;
        case StreamTypes.pupilPosition:
          etData.pupilPosition = PupilPositionPacket.decode(sublist)
            ..timestamp = timestamp;
          offset += PupilPositionPacket.size;
        case StreamTypes.pupilDiameter:
          etData.pupilDiameter = PupilDiameterPacket.decode(sublist)
            ..timestamp = timestamp;
          offset += PupilDiameterPacket.size;
        case StreamTypes.imuQuaternion:
          etData.imuQuaternion = IMUQuaternionPacket.decode(sublist)
            ..timestamp = timestamp;
          offset += IMUQuaternionPacket.size;
      }
    }
    return etData;
  }

  /// Format of the initial part of the packet (timestamp, mask)
  static final _timestampStruct = Struct('<Q');
  static final _maskStruct = Struct('<B');
  static final _streamTypeStruct = Struct('<B');
}

class BlinkPacket {
  static int get size => _struct.size;

  static BlinkEvent decode(Uint8List bytes) {
    final unpacked = _struct.unpackFrom(bytes);
    return BlinkEvent(
      timestamp: unpacked[0] as double,
      duration: unpacked[1] as double,
    );
  }

  /// Format: Timestamp, duration in seconds
  static final _struct = Struct('<2f');
}

class EyeOpenedPacket {
  static int get size => _struct.size;

  static EyeClosedOpenedEvent decode(Uint8List bytes) {
    final unpacked = _struct.unpackFrom(bytes);
    return EyeClosedOpenedEvent(
      eye: Eye.from(unpacked[1] as int),
      opened: true,
    );
  }

  /// Format: Timestamp, eye index
  static final _struct = Struct('<fB');
}

class EyeClosedPacket {
  static int get size => _struct.size;

  static EyeClosedOpenedEvent decode(Uint8List bytes) {
    final unpacked = _struct.unpackFrom(bytes);
    return EyeClosedOpenedEvent(
      eye: Eye.from(unpacked[1] as int),
      opened: false,
    );
  }

  /// Format: Timestamp, eye index
  static final _struct = Struct('<fB');
}

class SaccadePacket {
  static int get size => _struct.size;

  static SaccadeEvent decode(Uint8List bytes) {
    final unpacked = _struct.unpackFrom(bytes);
    return SaccadeEvent(
      timestamp: unpacked[0] as double,
      duration: unpacked[1] as double,
      amplitude: unpacked[2] as double,
      angle: unpacked[3] as double,
      peakAngularVelocity: unpacked[4] as double,
    );
  }

  static final _struct = Struct('<5f');
}

class SaccadeStartPacket {
  static int get size => _struct.size;

  static SaccadeStartEvent decode(Uint8List bytes) {
    final unpacked = _struct.unpackFrom(bytes);
    return SaccadeStartEvent(
      timestamp: unpacked[0] as double,
      eye: Eye.from(unpacked[1] as int),
    );
  }

  static final _struct = Struct('<fB');
}

class SaccadeEndPacket {
  static int get size => _struct.size;

  static SaccadeEndEvent decode(Uint8List bytes) {
    final unpacked = _struct.unpackFrom(bytes);
    return SaccadeEndEvent(
      timestamp: unpacked[0] as double,
      eye: Eye.from(unpacked[1] as int),
      duration: unpacked[2] as double,
      amplitude: unpacked[3] as double,
      angle: unpacked[4] as double,
      peakAngularVelocity: unpacked[5] as double,
    );
  }

  static final _struct = Struct('<fB4f');
}

class TracklossStartPacket {
  static int get size => _struct.size;

  static TracklossStartEvent decode(Uint8List bytes) {
    final unpacked = _struct.unpackFrom(bytes);
    return TracklossStartEvent(
      timestamp: unpacked[0] as double,
      eye: Eye.from(unpacked[1] as int),
    );
  }

  static final _struct = Struct('<fB');
}

class TracklossEndPacket {
  static int get size => _struct.size;

  static TracklossEndEvent decode(Uint8List bytes) {
    final unpacked = _struct.unpackFrom(bytes);
    return TracklossEndEvent(
      timestamp: unpacked[0] as double,
      eye: Eye.from(unpacked[1] as int),
    );
  }

  static final _struct = Struct('<fB');
}

class DepthPacket {
  static int get size => _struct.size;

  static DepthEvent decode(Uint8List bytes) {
    final unpacked = _struct.unpackFrom(bytes);
    return DepthEvent(
      timestamp: unpacked[0] as double,
      depth: unpacked[1] as double,
    );
  }

  static final _struct = Struct('<2f');
}

class EventPacket {
  static EventData decode(Uint8List bytes) {
    var offset = 0;
    final unpacked = _eventTypeStruct.unpackFrom(bytes, offset);
    final eventType = EventTypes.from(unpacked[0] as int);
    offset += _eventTypeStruct.size;
    final sublist = Uint8List.sublistView(bytes, offset);
    switch (eventType) {
      case EventTypes.blink:
        return BlinkPacket.decode(sublist);
      case EventTypes.eyeClosed:
        return EyeClosedPacket.decode(sublist);
      case EventTypes.eyeOpened:
        return EyeOpenedPacket.decode(sublist);
      case EventTypes.saccade:
        return SaccadePacket.decode(sublist);
      case EventTypes.saccadeStart:
        return SaccadeStartPacket.decode(sublist);
      case EventTypes.saccadeEnd:
        return SaccadeEndPacket.decode(sublist);
      case EventTypes.tracklossStart:
        return TracklossStartPacket.decode(sublist);
      case EventTypes.tracklossEnd:
        return TracklossEndPacket.decode(sublist);
      case EventTypes.depth:
        return DepthPacket.decode(sublist);
    }
  }

  static final _eventTypeStruct = Struct('<B');
}

class SystemInfoPacket {
  static String decode(Uint8List bytes) {
    var offset = 0;
    final unpacked = _infoTypeStruct.unpackFrom(bytes, offset);
    final infoType = SystemInfoTypes.from(unpacked[0] as int);
    offset += _infoTypeStruct.size;
    final end = bytes.indexOf(0, offset); // find the null terminator
    final sublist = Uint8List.sublistView(bytes, offset, end);
    switch (infoType) {
      case SystemInfoTypes.deviceSerial:
      case SystemInfoTypes.firmwareApi:
      case SystemInfoTypes.firmwareVersion:
        return String.fromCharCodes(sublist);
    }
  }

  static final _infoTypeStruct = Struct('<B');
}
