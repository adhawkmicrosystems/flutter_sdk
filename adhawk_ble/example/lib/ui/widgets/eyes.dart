import 'dart:async';
import 'dart:math' as math;

import 'package:adhawk_ble/adhawkapi/models/api.dart';
import 'package:adhawk_ble/adhawkapi/service/tracker_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double xyBound = 1; // Used for tweaking things

class AppColors {
  static const Color irisColor = Color(0XFFD9D9D9);
  static const Color pupilColor = Color(0XFF000000);
  static const Color eyeballColor = Colors.white;
}

class EyeView extends StatelessWidget {
  const EyeView({
    super.key,
    required this.allowLocking,
  });

  final bool allowLocking;

  @override
  Widget build(BuildContext context) {
    bool isMirrored = false;
    bool isGlassesLocked = false;

    return IntrinsicWidth(
      // Use the IntrinsicWidth to determine how wide the Eyes container
      // should be, based on how wide the glasses image gets
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(
          alignment: AlignmentDirectional.center,
          children: [
            Eyes(isMirrored: isMirrored),
            Glasses(
              isMirrored: isMirrored,
              glassesLocked: isGlassesLocked,
            ),
          ],
        ),
      ),
    );
  }
}

class Glasses extends StatelessWidget {
  const Glasses({
    super.key,
    required this.isMirrored,
    required this.glassesLocked,
  });

  final bool isMirrored;
  final bool glassesLocked;
  static const Coordinates _nominalEyeOffsets = Coordinates(
      x: 32.00000000000005, y: 11.069903854965, z: 27.1456855969812);

  // These are used for tweaking the glasses movement
  static const double _rotateScaleFactor = 3;
  static const double _verticalOffsetScaleFactor = -2.5;
  static const double _xLeftCenter = 114;
  static const double _xRightCenter = 225;
  static const double _iconScaleFactor = 0.05;
  static const double _iconScaleMin = 0.8;
  static const double _iconScaleMax = 1.2;
  static const double _rotateLimit = 0.17453; // In Rad
  static const double _snapPercent = 0.8;
  static const double _goodMinBoundY = -3;
  static const double _goodMinBoundZ = -2;
  static const double _goodMaxBoundY = 5;
  static const double _goodMaxBoundZ = 4;

  Coordinates _getOffsets(Coordinates eyeCenter) {
    if (eyeCenter == const Coordinates(z: -1)) {
      return const Coordinates(x: -1);
    } else {
      return Coordinates(
          y: _nominalEyeOffsets.y - eyeCenter.y,
          z: eyeCenter.z - _nominalEyeOffsets.z);
    }
  }

  double _getRotation(double offsetLY, offsetRY) {
    final rotatedAngle = math.atan(_rotateScaleFactor *
        (offsetLY - offsetRY) /
        (_xRightCenter - _xLeftCenter));
    return rotatedAngle.clamp(-_rotateLimit, _rotateLimit);
  }

  double _getScale(double offsetsLZ, double offsetsRZ) {
    var glassesScale = 1 + _iconScaleFactor * (offsetsLZ + offsetsRZ);
    if (glassesScale > 1) {
      glassesScale = glassesScale * 0.5 + 0.5;
    }
    return glassesScale.clamp(_iconScaleMin, _iconScaleMax);
  }

  bool _inSnapRange(Coordinates offsetsL, Coordinates offsetsR,
      List snapMinRange, List snapMaxRange) {
    if (offsetsL.y <= snapMaxRange[0] &&
        offsetsL.y >= snapMinRange[0] &&
        offsetsL.z <= snapMaxRange[1] &&
        offsetsL.z >= snapMinRange[1] &&
        offsetsR.y <= snapMaxRange[0] &&
        offsetsR.y >= snapMinRange[0] &&
        offsetsR.z <= snapMaxRange[1] &&
        offsetsR.z >= snapMinRange[1]) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final snapMinRange = [
      _goodMinBoundY +
          0.5 * (_goodMaxBoundY - _goodMinBoundY) * (1 - _snapPercent),
      _goodMinBoundZ +
          0.5 * (_goodMaxBoundZ - _goodMinBoundZ) * (1 - _snapPercent)
    ];

    final snapMaxRange = [
      _goodMaxBoundY -
          0.5 * (_goodMaxBoundY - _goodMinBoundY) * (1 - _snapPercent),
      _goodMaxBoundZ -
          0.5 * (_goodMaxBoundZ - _goodMinBoundZ) * (1 - _snapPercent)
    ];

    return BlocSelector<TrackerBloc, TrackerState, EyeTrackingData>(
        selector: (state) => state.etData ?? EyeTrackingData(),
        builder: (context, etData) {
          var showGlasses = true;
          var offsetsL = _getOffsets(
              isMirrored ? etData.eyeCenter.left : etData.eyeCenter.right);
          var offsetsR = _getOffsets(
              isMirrored ? etData.eyeCenter.right : etData.eyeCenter.left);
          if (offsetsL.x == -1 || offsetsR.x == -1) {
            showGlasses = false;
          }

          if (glassesLocked ||
              _inSnapRange(offsetsL, offsetsR, snapMinRange, snapMaxRange)) {
            offsetsL = const Coordinates();
            offsetsR = const Coordinates();
          }
          final rotatedAngle = _getRotation(offsetsL.y, offsetsR.y);

          final glassesScale = _getScale(offsetsL.z, offsetsR.z);

          return Stack(
            children: [
              GlassesImage(color: Theme.of(context).colorScheme.surfaceVariant),
              showGlasses
                  ? Transform.translate(
                      offset: Offset(
                          0,
                          ((offsetsR.y + offsetsL.y) / 2) *
                              _verticalOffsetScaleFactor),
                      child: Transform.rotate(
                        angle: rotatedAngle,
                        child: Transform.scale(
                          scale: glassesScale,
                          child: GlassesImage(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    )
                  : Container()
            ],
          );
        });
  }
}

class GlassesImage extends StatelessWidget {
  const GlassesImage({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Image.asset(
        'assets/images/mindlink.png',
        color: color,
      ),
    );
  }
}

class Eyes extends StatelessWidget {
  const Eyes({super.key, required this.isMirrored});

  final bool isMirrored;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: SingleEye(isLeft: isMirrored, isMirrored: isMirrored)),
        Expanded(child: SingleEye(isLeft: !isMirrored, isMirrored: isMirrored)),
      ],
    );
  }
}

class EyePainter extends CustomPainter {
  EyePainter({
    required this.gaze,
    required this.diameter,
    required this.isMirrored,
    required this.color,
  });
  // The eye painter for left and right eyes, for both the iris and the pupil
  final Coordinates gaze;
  final double diameter;
  final bool isMirrored;
  final Color color;
  Coordinates getCoordinates() {
    // This is where the gazeX and gazeZ are multiplied by -1 and put in a range of 1 to -1
    final double x =
        math.min(1, math.max(-1, (isMirrored ? 1 : -1) * gaze.x / xyBound));
    final double y = math.min(1, math.max(-1, -gaze.y / xyBound));
    // This is where the gazeZ is translated from a range of 0 to -1 to a range of 0.5 to 1
    final double z = math.min(math.max(((-gaze.z) * .5) + 0.5, 0.5), 1);
    return Coordinates(x: x, y: y, z: z);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pos = getCoordinates();
    final angle = math.atan2(pos.y, pos.x);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas
      ..save()
      ..translate(size.width, size.height)
      ..rotate(angle)
      ..drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: diameter * pos.z,
            height: diameter,
          ),
          paint)
      ..restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class SingleEye extends StatelessWidget {
  const SingleEye({super.key, required this.isLeft, required this.isMirrored});
  final bool isLeft;
  final bool isMirrored;

  /// Calculates the position of the iris & pupil using the gaze from the
  /// [EyeTrackingData for the current eye
  Coordinates getAlignment(EyeTrackingData etData) {
    final gaze = getGaze(etData);
    final x = (isMirrored ? 1 : -1) * gaze.x / xyBound;
    final y = -gaze.y;
    return Coordinates(x: x, y: y);
  }

  /// Returns the gaze from the [EyeTrackingData] for the current eye
  Coordinates getGaze(EyeTrackingData etData) {
    return isLeft ? etData.gaze.left : etData.gaze.right;
  }

  /// Translates the pupil diameter from the eyetracking data to
  /// a range in pixels
  double getPupilDiameter(PupilDiameter pupilDiameter, double minPupilMm,
      double maxPupilMm, double minPupilPx, double maxPupilPx) {
    final rangeMm = maxPupilMm - minPupilMm;
    final rangePx = maxPupilPx - minPupilPx;
    if (pupilDiameter.left == 0 && pupilDiameter.right == 0) {
      return minPupilPx + (rangePx / 2);
    }
    final pupilDiameterMm = pupilDiameter.adjusted(minPupilMm, maxPupilMm);

    return ((pupilDiameterMm - minPupilMm) * rangePx / rangeMm) + minPupilPx;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      // This AspectRatio makes the underlying container a square
      // This ensures that we have proper height and width size constraints
      // for the child widgets regardless of the size of the screen
      aspectRatio: 1,
      child: LayoutBuilder(
        // Use the layout builder to get the contraints from the parent
        builder: (context, constraints) {
          final eyeballDiameterPx = constraints.maxWidth * 0.5;
          final irisDiameterPx = eyeballDiameterPx * 0.5;
          final maxPupilPx = irisDiameterPx * 0.60;
          final minPupilPx = irisDiameterPx * 0.30;
          const maxPupilMm = 5.0;
          const minPupilMm = 2.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                // Eyeball
                alignment: Alignment.center,
                height: eyeballDiameterPx,
                width: eyeballDiameterPx,
                decoration: BoxDecoration(
                  color: AppColors.eyeballColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.irisColor),
                ),
                child: BlocSelector<TrackerBloc, TrackerState, EyeTrackingData>(
                  selector: (state) => state.etData ?? EyeTrackingData(),
                  builder: (context, etData) {
                    final alignment = getAlignment(etData);
                    final gaze = getGaze(etData);
                    final pupilDiameterPx = getPupilDiameter(
                      etData.pupilDiameter,
                      minPupilMm,
                      maxPupilMm,
                      minPupilPx,
                      maxPupilPx,
                    );
                    return Container(
                      alignment: Alignment(alignment.x, alignment.y),
                      width: irisDiameterPx,
                      height: irisDiameterPx,
                      child: CustomPaint(
                        // Iris
                        painter: EyePainter(
                          gaze: gaze,
                          diameter: irisDiameterPx,
                          isMirrored: isMirrored,
                          color: AppColors.irisColor,
                        ),
                        // Pupil
                        foregroundPainter: EyePainter(
                          gaze: gaze,
                          diameter: pupilDiameterPx,
                          isMirrored: isMirrored,
                          color: AppColors.pupilColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Eyelid(height: constraints.maxWidth),
            ],
          );
        },
      ),
    );
  }
}

class Eyelid extends StatefulWidget {
  const Eyelid({super.key, required this.height});

  final double height;

  @override
  State<Eyelid> createState() => _EyelidState();
}

/// [_EyelidState] is responsible for animating blink events
/// When a blink event is received, the "eyelid" height transitions from 0 to maxHeight
/// After half the blink duration, the eyelid height transitions back to 0
class _EyelidState extends State<Eyelid> {
  late double _maxHeight;
  late double _height;
  late int _duration;
  Timer? _timer;

  @override
  void initState() {
    _maxHeight = widget.height;
    _height = 0;
    _duration = 0;
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Convert the duration in the event to milliseconds
  /// and divide by 2 to split the animation time between opening and closing
  static int _getAnimationDuration(double blinkDuration) {
    return ((blinkDuration / 2) * 1000).round();
  }

  void closeEye(double blinkDuration) {
    setState(() {
      _height = _maxHeight;
      _duration = _getAnimationDuration(blinkDuration);
    });
  }

  void openEye(double blinkDuration) {
    setState(() {
      _height = 0;
      _duration = _getAnimationDuration(blinkDuration);
    });
  }

  @override
  Widget build(BuildContext context) {
    /// Use a BlocListener instead of a BlocBuilder to be able to set the
    /// height back to 0 (re-open the eye) after the blink duration.
    return BlocListener<TrackerBloc, TrackerState>(
      listener: (context, state) {
        if (state.eventData is! BlinkEvent) {
          return;
        }
        final blinkEvent = state.eventData! as BlinkEvent;
        closeEye(blinkEvent.duration);
        _timer = Timer(
            Duration(milliseconds: _getAnimationDuration(blinkEvent.duration)),
            () => openEye(blinkEvent.duration));
      },
      child: Align(
        // align to top center so the blink animation moves downwards
        alignment: Alignment.topCenter,
        child: AnimatedContainer(
          duration: Duration(milliseconds: _duration),
          height: _height,
          color: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }
}
