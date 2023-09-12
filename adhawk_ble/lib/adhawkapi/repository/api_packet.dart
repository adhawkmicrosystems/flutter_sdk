import 'dart:typed_data';

import '../models/api.dart';
import 'struct.dart';

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
    return values.firstWhere((element) => value == element.value);
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
  propertyGet(0x9a),
  propertySet(0x9b),
  systemControl(0x9c),
  systemInfo(0x99),
  ;

  const PacketType(this.value);
  factory PacketType.from(int value) {
    return values.firstWhere((element) => value == element.value);
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
    return values.firstWhere((element) => value == element.value);
  }
  final int value;
}

/// SystemControl types for [PacketType.systemControl]
enum SystemControlTypes {
  tracking(1),
  ;

  const SystemControlTypes(this.value);
  factory SystemControlTypes.from(int value) {
    return values.firstWhere((element) => value == element.value);
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
    return values.firstWhere((element) => value == element.value);
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
    return values.firstWhere((element) => value == element.value);
  }
  static List<StreamTypes> fromMask(int mask) {
    List<StreamTypes> streamTypes = [];
    for (final stream in values) {
      if (mask & (1 << stream.value) != 0) {
        streamTypes.add(stream);
      }
    }
    return streamTypes;
  }

  int get mask => 1 << value;

  static int createMask(Set<StreamTypes> streams) {
    int mask = 0;
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
  ;

  const EventTypes(this.value);
  factory EventTypes.from(int value) {
    return values.firstWhere((element) => value == element.value);
  }
  final int value;
}

enum EventControlBit {
  blink(0),
  eyeCloseOpen(1),
  ;

  const EventControlBit(this.value);
  factory EventControlBit.from(int value) {
    return values.firstWhere((element) => value == element.value);
  }
  int get mask => 1 << value;
  static int createMask(Set<EventControlBit> controls) {
    int mask = 0;
    for (final control in controls) {
      mask |= control.mask;
    }
    return mask;
  }

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
    var offset = _offsetStruct.size;
    var etData = EyeTrackingData();
    while (offset < bytes.length) {
      var unpacked = _streamTypeStruct.unpackFrom(bytes, offset);
      var streamType = StreamTypes.from(unpacked[0] as int);
      offset += 1;
      var sublist = Uint8List.sublistView(bytes, offset);
      switch (streamType) {
        case StreamTypes.gaze:
          etData.gaze = GazePacket.decode(sublist);
          offset += GazePacket.size;
          break;
        case StreamTypes.perEyeGaze:
          etData.perEyeGaze = PerEyeGazePacket.decode(sublist);
          offset += PerEyeGazePacket.size;
          break;
        case StreamTypes.eyeCenter:
          etData.eyeCenter = EyeCenterPacket.decode(sublist);
          offset += EyeCenterPacket.size;
          break;
        case StreamTypes.pupilPosition:
          etData.pupilPosition = PupilPositionPacket.decode(sublist);
          offset += PupilPositionPacket.size;
          break;
        case StreamTypes.pupilDiameter:
          etData.pupilDiameter = PupilDiameterPacket.decode(sublist);
          offset += PupilDiameterPacket.size;
          break;
        case StreamTypes.imuQuaternion:
          etData.imuQuaternion = IMUQuaternionPacket.decode(sublist);
          offset += IMUQuaternionPacket.size;
          break;
      }
    }
    return etData;
  }

  /// Format of the initial part of the packet (timestamp, mask)
  static final _offsetStruct = Struct('<QB');
  static final _streamTypeStruct = Struct('<B');
}

class BlinkPacket {
  static int get size => _struct.size;

  static BlinkEvent decode(Uint8List bytes) {
    var unpacked = _struct.unpackFrom(bytes);
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

  static EyeOpenedEvent decode(Uint8List bytes) {
    var unpacked = _struct.unpackFrom(bytes);
    return EyeOpenedEvent(
      eye: Eye.from(unpacked[1] as int),
    );
  }

  /// Format: Timestamp, eye index
  static final _struct = Struct('<fB');
}

class EyeClosedPacket {
  static int get size => _struct.size;

  static EyeClosedEvent decode(Uint8List bytes) {
    var unpacked = _struct.unpackFrom(bytes);
    return EyeClosedEvent(
      eye: Eye.from(unpacked[1] as int),
    );
  }

  /// Format: Timestamp, eye index
  static final _struct = Struct('<fB');
}

class EventPacket {
  static EventData decode(Uint8List bytes) {
    int offset = 0;
    var unpacked = _eventTypeStruct.unpackFrom(bytes, offset);
    var eventType = EventTypes.from(unpacked[0] as int);
    offset += _eventTypeStruct.size;
    var sublist = Uint8List.sublistView(bytes, offset);
    switch (eventType) {
      case EventTypes.blink:
        return BlinkPacket.decode(sublist);
      case EventTypes.eyeClosed:
        return EyeClosedPacket.decode(sublist);
      case EventTypes.eyeOpened:
        return EyeOpenedPacket.decode(sublist);
    }
  }

  static final _eventTypeStruct = Struct('<B');
}

class SystemInfoPacket {
  static String decode(Uint8List bytes) {
    int offset = 0;
    var unpacked = _infoTypeStruct.unpackFrom(bytes, offset);
    var infoType = SystemInfoTypes.from(unpacked[0] as int);
    offset += _infoTypeStruct.size;
    var end = bytes.indexOf(0, offset); // find the null terminator
    var sublist = Uint8List.sublistView(bytes, offset, end);
    switch (infoType) {
      case SystemInfoTypes.deviceSerial:
      case SystemInfoTypes.firmwareApi:
      case SystemInfoTypes.firmwareVersion:
        return String.fromCharCodes(sublist);
    }
  }

  static final _infoTypeStruct = Struct('<B');
}
