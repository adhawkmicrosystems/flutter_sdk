/// This file provides the data structures streamed from the AdHawk eye tracker
///
/// Most of the structures refer to the AdHawk Coordinate System
/// In the AdHawk coordinate system X, Y and Z are coordinates relative to a particular origin where:
/// * X is oriented in the positive direction to the right (user’s point of view)
/// * Y is oriented in the positive direction going up
/// * Z is oriented in the positive direction when behind the user
///
/// The origin is specific to the stream or command. In general the origin is either:
/// * The midpoint of the scanners
/// * The center of the eye
///
/// | Stream                                             | Origin               |
/// |:---------------------------------------------------|:---------------------|
/// | [Gaze]                                             | Midpoint of scanners |
/// | [PupilPosition]                                    | Midpoint of scanners |
/// | [PerEyeGaze]                                       | Center of eye        |
library;

import 'dart:math' as math;

/// Enum referring to which Eye the data is coming from
enum Eye {
  right(0),
  left(1),
  ;

  const Eye(this.value);
  factory Eye.from(int value) {
    return values.firstWhere((element) => value == element.value);
  }
  final int value;
}

/// Generic 3D coordinates structure
class Coordinates {
  const Coordinates({
    this.x = 0,
    this.y = 0,
    this.z = 0,
  });
  final double x;
  final double y;
  final double z;

  bool isValid() => [x, y, z].every((element) => element.isFinite);

  @override
  String toString() {
    return '($x, $y, $z)';
  }
}

/// Mixin to allow adding Unix timestamps to eye tracking data points
mixin UnixTimestamp {
  set utctime(DateTime? utctime) => _utctime = utctime;
  String? get displayTime => _utctime?.toLocal().toString();
  DateTime? get localtime => _utctime?.toLocal();
  DateTime? get utctime => _utctime;
  DateTime? _utctime;
}

/// High resolution MCU timestamp since system start
mixin McuTimestampInt64 {
  int? timestamp;
}

/// Angle of the gaze vector
class GazeAngles with UnixTimestamp, McuTimestampInt64 {
  GazeAngles({required this.azRad, required this.elRad})
      : azDeg = _toDegrees(azRad),
        elDeg = _toDegrees(elRad);

  factory GazeAngles.fromGazeVector(Coordinates gaze) {
    return GazeAngles(
        azRad: math.atan2(
            gaze.x, math.sqrt(math.pow(gaze.y, 2) + math.pow(gaze.z, 2))),
        elRad: math.atan2(gaze.y, -gaze.z));
  }

  final double azRad;
  final double elRad;
  final double azDeg;
  final double elDeg;

  Coordinates toGazeVector() {
    return Coordinates(
        x: math.sin(azRad),
        y: math.cos(azRad) * math.sin(elRad),
        z: -math.cos(azRad) * math.cos(elRad));
  }

  static double _toDegrees(double radians) {
    return radians * 180 / math.pi;
  }
}

/// Coordinates of a users gaze unit vector relative to the midpoint of the scanners
class Gaze with UnixTimestamp, McuTimestampInt64 {
  Gaze({
    this.cyclopean = const Coordinates(z: -1),
    this.vergence = 0,
  });

  static Coordinates calculateLeftAngle(
      Coordinates cyclopeanGaze, double vergence) {
    final avgAngles = GazeAngles.fromGazeVector(cyclopeanGaze);
    return GazeAngles(
      azRad: avgAngles.azRad + vergence * 0.5,
      elRad: avgAngles.elRad,
    ).toGazeVector();
  }

  static Coordinates calculateRightAngle(
      Coordinates cyclopeanGaze, double vergence) {
    final avgAngles = GazeAngles.fromGazeVector(cyclopeanGaze);
    return GazeAngles(
      azRad: avgAngles.azRad - vergence * 0.5,
      elRad: avgAngles.elRad,
    ).toGazeVector();
  }

  Coordinates get right {
    _right ??= calculateRightAngle(cyclopean, vergence);
    return _right!;
  }

  Coordinates get left {
    _left ??= calculateLeftAngle(cyclopean, vergence);
    return _left!;
  }

  bool isValid() => [cyclopean].every((element) => element.isValid());

  /// Cyclopean gaze
  final Coordinates cyclopean;

  /// Angle between the left and right gaze vector
  final double vergence;

  /// Right eye gaze unit vector
  Coordinates? _right;

  /// Left eye gaze unit vector
  Coordinates? _left;

  @override
  String toString() {
    return 'Gaze [R: $right, L: $left, Vergence: $vergence]';
  }
}

/// Coordinates of a users gaze unit vector relative to the center of each eye
class PerEyeGaze with UnixTimestamp, McuTimestampInt64 {
  PerEyeGaze({
    this.right = const Coordinates(z: -1),
    this.left = const Coordinates(z: -1),
  });

  bool isValid() => [right, left].every((element) => element.isValid());

  /// Right eye gaze unit vector
  final Coordinates right;

  /// Left eye gaze unit vector
  final Coordinates left;

  @override
  String toString() {
    return 'PerEyeGaze [R: $right, L: $left]';
  }
}

/// Coordinates of the center of each eye relative to the midpoint of the scanners
class EyeCenter with UnixTimestamp, McuTimestampInt64 {
  EyeCenter({
    this.right = const Coordinates(z: -1),
    this.left = const Coordinates(z: -1),
  });

  bool isValid() => [right, left].every((element) => element.isValid());

  /// Coordinates of the center of the right eye in millimeters
  final Coordinates right;

  /// Coordinates of the center of the right eye in millimeters
  final Coordinates left;

  @override
  String toString() {
    return 'EyeCenter [R: $right, L: $left]';
  }
}

/// Coordinates of the pupil relative to the midpoint of the scanners
class PupilPosition with UnixTimestamp, McuTimestampInt64 {
  PupilPosition({
    this.right = const Coordinates(z: -1),
    this.left = const Coordinates(z: -1),
  });

  bool isValid() => [right, left].every((element) => element.isValid());

  /// Coordinates of the right pupil in millimeters
  final Coordinates right;

  /// Coordinates of the left pupil in millimeters
  final Coordinates left;

  @override
  String toString() {
    return 'PupilPosition [R: $right, L: $left]';
  }
}

/// The diameter of each pupil in millimeters
class PupilDiameter with UnixTimestamp, McuTimestampInt64 {
  PupilDiameter({
    this.right = 0,
    this.left = 0,
  });

  // Adjusted measurements for display purposes
  double adjusted(double minSize, double maxSize) {
    final average = (right + left) / 2;
    final clamped = average.clamp(minSize, maxSize);
    return clamped;
  }

  /// The coordinates of the right pupil in millimeters
  final double right;

  /// The coordinates of the left pupil in millimeters
  final double left;

  /// Returns true if it is a valid position
  bool isValid() => [right, left].every((element) => element.isFinite);

  @override
  String toString() {
    return 'PupilDiameter [R: $right, L: $left]';
  }
}

/// The IMU data from the glasses in unit-norm quaternions
///
/// See https://en.wikipedia.org/wiki/Quaternions_and_spatial_rotation
class IMUQuaternion with UnixTimestamp, McuTimestampInt64 {
  IMUQuaternion({
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.w = 0,
  });

  final double x;
  final double y;
  final double z;
  final double w;

  bool isValid() => [x, y, z, w].every((element) => element.isFinite);

  @override
  String toString() {
    return 'IMUQuaternion [X: $x, Y: $y, Z: $z, W: $w]';
  }
}

/// Continuous eye tracking data streamed from the glasses
class EyeTrackingData {
  EyeTrackingData({
    Gaze? gaze,
    PerEyeGaze? perEyeGaze,
    EyeCenter? eyeCenter,
    PupilPosition? pupilPosition,
    PupilDiameter? pupilDiameter,
    IMUQuaternion? imuQuaternion,
  })  : gaze = gaze ?? Gaze(),
        perEyeGaze = perEyeGaze ?? PerEyeGaze(),
        eyeCenter = eyeCenter ?? EyeCenter(),
        pupilPosition = pupilPosition ?? PupilPosition(),
        pupilDiameter = pupilDiameter ?? PupilDiameter(),
        imuQuaternion = imuQuaternion ?? IMUQuaternion();

  Gaze gaze;
  PerEyeGaze perEyeGaze;
  EyeCenter eyeCenter;
  PupilPosition pupilPosition;
  PupilDiameter pupilDiameter;
  IMUQuaternion imuQuaternion;

  @override
  String toString() {
    return '$gaze $perEyeGaze $eyeCenter $pupilPosition $pupilDiameter $imuQuaternion';
  }
}

/// Discrete events that were detected by the glasses
sealed class EventData with UnixTimestamp {
  bool isValid() => true;
}

/// Blink events detected by the glasses
///
/// Combined-eye blink event when the user's blink is detected on both eyes.
/// More specifically, the blink event indicates the time window where both
/// left and right blink events overlap in time.
/// This event is triggered as soon as any of the closed eyes is opened.
class BlinkEvent extends EventData {
  BlinkEvent({required this.timestamp, required this.duration});

  /// Microcontroller timestamp since system start
  final double timestamp;

  /// Duration of the blink in milliseconds
  final double duration;

  @override
  String toString() {
    return 'Blink: $timestamp $duration ms';
  }
}

/// Event indicating that a specific eye just opened or closed.
class EyeClosedOpenedEvent extends EventData {
  EyeClosedOpenedEvent({required this.eye, required this.opened});
  final Eye eye;
  final bool opened;

  @override
  String toString() {
    return 'Eye: $eye ${opened ? "opened" : "closed"}';
  }
}

/// Saccade events detected by the glasses
///
/// Combined-eye saccade event when a saccade is detected on both eyes.
/// More specifically, the saccade event indicates the time window where both
/// left and right saccade events overlap in time. This event is triggered as
/// soon as the saccade in any of the eyes ends.
class SaccadeEvent extends EventData {
  SaccadeEvent({
    required this.timestamp,
    required this.duration,
    required this.amplitude,
    required this.angle,
    required this.peakAngularVelocity,
  });

  /// Timestamp since system start of the event
  final double timestamp;

  /// Duration of the saccade in ms
  final double duration;

  /// Amplitude in deg
  final double amplitude;

  /// Angle in deg
  final double angle;

  /// Peak angular velocity in deg/s
  final double peakAngularVelocity;

  @override
  bool isValid() => [duration, amplitude, angle, peakAngularVelocity]
      .every((element) => element.isFinite);

  @override
  String toString() {
    return 'Saccade: $timestamp $duration ms, $amplitude deg, $angle deg,'
        ' $peakAngularVelocity deg/s';
  }
}

/// Saccade start events detected by the glasses on either eye
class SaccadeStartEvent extends EventData {
  SaccadeStartEvent({
    required this.timestamp,
    required this.eye,
  });

  /// Timestamp since system start of the event
  final double timestamp;

  /// Eye index specifying the eye
  final Eye eye;

  @override
  String toString() {
    return 'Saccade start: $timestamp $eye';
  }
}

/// Saccade end events detected by the glasses on either eye
class SaccadeEndEvent extends EventData {
  SaccadeEndEvent({
    required this.timestamp,
    required this.eye,
    required this.duration,
    required this.amplitude,
    required this.angle,
    required this.peakAngularVelocity,
  });

  /// Timestamp since system start of the event
  final double timestamp;

  /// Eye index specifying the eye
  final Eye eye;

  /// Duration of the saccade in ms
  final double duration;

  /// Amplitude in deg
  final double amplitude;

  /// Angle in deg
  final double angle;

  /// Peak angular velocity in deg/s
  final double peakAngularVelocity;

  @override
  String toString() {
    return 'Saccade End: $timestamp $eye, $duration ms, $amplitude deg, '
        '$angle deg, $peakAngularVelocity deg/s';
  }
}

/// Trackloss start events detected by the glasses on either eye
class TracklossStartEvent extends EventData {
  TracklossStartEvent({
    required this.timestamp,
    required this.eye,
  });

  /// Timestamp since system start of the event
  final double timestamp;

  /// Eye index specifying the eye
  final Eye eye;

  @override
  String toString() {
    return 'Trackloss start: $timestamp $eye';
  }
}

/// Trackloss end events detected by the glasses on either eye
class TracklossEndEvent extends EventData {
  TracklossEndEvent({
    required this.timestamp,
    required this.eye,
  });

  /// Timestamp since system start of the event
  final double timestamp;

  /// Eye index specifying the eye
  final Eye eye;

  @override
  String toString() {
    return 'Trackloss end: $timestamp $eye';
  }
}

class DepthEvent extends EventData {
  DepthEvent({required this.timestamp, required this.depth});

  /// Microcontroller timestamp since system start
  final double timestamp;

  /// Depth in meters
  final double depth;

  @override
  String toString() {
    return 'Depth: $timestamp $depth m';
  }
}
