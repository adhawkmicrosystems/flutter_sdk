/// This library provides the data structures streamed from the AdHawk eye tracker

/// Most of the structures in this library refer to the AdHawk Coordinate System
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

import 'dart:math' as math;
import 'defaults.dart';

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
  toString() {
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

/// Angle of the gaze vector
class GazeAngles with UnixTimestamp {
  final double yaw;
  final double pitch;

  GazeAngles({required this.yaw, required this.pitch});

  factory GazeAngles.fromGazeVector(Coordinates gaze) {
    return GazeAngles(
        yaw: math.atan2(
            gaze.x, math.sqrt(math.pow(gaze.y, 2) + math.pow(gaze.z, 2))),
        pitch: math.atan2(gaze.y, -gaze.z));
  }

  Coordinates toGazeVector() {
    return Coordinates(
        x: math.sin(yaw),
        y: math.cos(yaw) * math.sin(pitch),
        z: -math.cos(yaw) * math.cos(pitch));
  }
}

/// Coordinates of a users gaze unit vector relative to the midpoint of the scanners
class Gaze with UnixTimestamp {
  Gaze({
    this.cyclopean = const Coordinates(z: -1),
    this.vergence = 0,
  });

  static Coordinates calculateLeftAngle(
      Coordinates cyclopeanGaze, double vergence) {
    GazeAngles avgAngles = GazeAngles.fromGazeVector(cyclopeanGaze);
    return GazeAngles(
      yaw: avgAngles.yaw + vergence * 0.5,
      pitch: avgAngles.pitch,
    ).toGazeVector();
  }

  static Coordinates calculateRightAngle(
      Coordinates cyclopeanGaze, double vergence) {
    GazeAngles avgAngles = GazeAngles.fromGazeVector(cyclopeanGaze);
    return GazeAngles(
      yaw: avgAngles.yaw - vergence * 0.5,
      pitch: avgAngles.pitch,
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
  toString() {
    return 'Gaze [R: $right, L: $left, Vergence: $vergence]';
  }
}

/// Coordinates of a users gaze unit vector relative to the center of each eye
class PerEyeGaze with UnixTimestamp {
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
  toString() {
    return 'PerEyeGaze [R: $right, L: $left]';
  }
}

/// Coordinates of the center of each eye relative to the midpoint of the scanners
class EyeCenter with UnixTimestamp {
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
  toString() {
    return 'EyeCenter [R: $right, L: $left]';
  }
}

/// Coordinates of the pupil relative to the midpoint of the scanners
class PupilPosition with UnixTimestamp {
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
  toString() {
    return 'PupilPosition [R: $right, L: $left]';
  }
}

/// The diameter of each pupil in millimeters
class PupilDiameter with UnixTimestamp {
  PupilDiameter({
    this.right = Defaults.averagePupilSize,
    this.left = Defaults.averagePupilSize,
  });

  static const double _pupilExpandXBound = 0.55;
  static const double _pupilExpandYUpBound = 0.10;
  static const double _pupilExpandYLowBound = -0.5;

  bool isOutOfBounds(Gaze gaze) {
    double maxDistanceX = math.max(gaze.left.x.abs(), gaze.right.x.abs());
    double maxDistanceY = math.max(gaze.left.y, gaze.right.y);
    double minDistanceY = math.min(gaze.left.y, gaze.right.y);
    if (maxDistanceX > _pupilExpandXBound ||
        maxDistanceY > _pupilExpandYUpBound ||
        minDistanceY < _pupilExpandYLowBound) {
      return true;
    } else {
      return false;
    }
  }

  // Adjusted measurements for display purposes
  double get adjusted => (right + left) / 2;

  /// The coordinates of the right pupil in millimeters
  final double right;

  /// The coordinates of the left pupil in millimeters
  final double left;

  /// Returns true if it is a valid position
  bool isValid() => [right, left].every((element) => element.isFinite);

  @override
  toString() {
    return 'PupilDiameter [R: $right, L: $left]';
  }
}

/// The IMU data from the glasses in unit-norm quaternions
///
/// See https://en.wikipedia.org/wiki/Quaternions_and_spatial_rotation
class IMUQuaternion {
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
  toString() {
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
  toString() {
    return '$gaze $perEyeGaze $eyeCenter $pupilPosition $pupilDiameter $imuQuaternion';
  }
}

/// Discrete events that were detected by the glasses
sealed class EventData {}

/// Blink events detected by the glasses
///
/// Combined-eye blink event when the user's blink is detected on both eyes.
/// More specifically, the blink event indicates the time window where both
/// left and right blink events overlap in time.
/// This event is triggered as soon as any of the closed eyes is opened.
class BlinkEvent extends EventData with UnixTimestamp {
  BlinkEvent({required this.timestamp, required this.duration});

  /// Microcontroller timestamp since system start
  final double timestamp;

  /// Duration of the blink in milliseconds
  final double duration;

  @override
  toString() {
    return 'Blink: $timestamp $duration ms';
  }
}

/// Eye closed event indicating that a specific eye is closed.
class EyeClosedEvent extends EventData {
  EyeClosedEvent({required this.eye});
  final Eye eye;
}

/// Eye open event indicating that a specific eye is opened.
class EyeOpenedEvent extends EventData {
  EyeOpenedEvent({required this.eye});
  final Eye eye;
}

/// Gaze depth
class GazeDepth with UnixTimestamp {
  GazeDepth({required this.timestamp, required this.z});

  /// MCU timestamp
  final double timestamp;

  /// z coordinates of the gaze vector indicating depth
  final double z;

  @override
  toString() {
    return 'Gaze Depth: $timestamp $z m';
  }
}
