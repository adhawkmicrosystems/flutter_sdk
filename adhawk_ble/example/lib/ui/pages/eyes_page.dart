import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:adhawk_ble/adhawkapi/service/tracker_bloc.dart';
import 'package:adhawk_ble/adhawkapi/models/api.dart';
import 'package:adhawk_ble/adhawkapi/models/defaults.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

const double xyBound = 1; // Used for tweaking things
const bool _isMirrored = false;

class AppColors {
  static const Color blinkBoxColor = Color.fromARGB(255, 250, 250, 250);
  static const Color debugColor = Color.fromARGB(255, 0, 255, 255);
  static const Color irisColor = Color(0XFFD9D9D9);
  static const Color pupilColor = Color(0XFF000000);
  static const Color eyeballColor = Colors.white;
}

/*
--------------------------Eye Holder Architectural Info:-----------------------------------
- This assumes that the Gazes will be given independently for each eye with an X, Y, and Z vector.

- CURRENT BOUNDS BASED ON WAYS THAT DATA IS GIVEN:
- Pupil Diameter 2-8mm, this is the max and min for adults in general
- Z-gaze is given in a range of 0 to -1 where -1 is gazing straight forward (we modify this to be a scale between 0.5 to 1)
- X and Y gaze need to be *-1 of what is given to us to correspond correctly in our UI
  Also divide by 'xyBound' since that seems to be the bounds on how far we are able to look to the side
*/

class EyesPage extends StatelessWidget {
  const EyesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                alignment: Alignment.topRight,
                padding: const EdgeInsets.all(15),
                child: const CalibrateButton(),
              ),
              const Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: EyeView(),
                ),
              ),
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Flexible(child: EyeView()),
              Container(
                alignment: Alignment.topRight,
                padding: const EdgeInsets.all(15),
                child: const CalibrateButton(),
              ),
            ],
          );
        }
      },
    );
  }
}

class CalibrateButton extends StatelessWidget {
  const CalibrateButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackerBloc, TrackerState>(
      builder: (context, state) => Visibility(
        visible: state.status != TrackerStatus.unavailable,
        child: FilledButton.tonal(
          onPressed: () =>
              context.goNamed(NamedRoutes.calibrationInstruction.value),
          child: const Text('Calibrate'),
        ),
      ),
    );
  }
}

class EyeView extends StatelessWidget {
  const EyeView({super.key});

  @override
  Widget build(BuildContext context) {
    return const IntrinsicWidth(
      // Use the IntrinsicWidth to determine how wide the Eyes container
      // should be, based on how wide the glasses image gets
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          Eyes(),
          Glasses(),
        ],
      ),
    );
  }
}

class Glasses extends StatelessWidget {
  const Glasses({super.key});

  final Coordinates _nominalEyeOffsets = const Coordinates(
      x: 32.00000000000005, y: 11.069903854965, z: 27.1456855969812);

  // These are used for tweaking the glasses movement
  final double _rotateScaleFactor = 3;
  final double _verticalOffsetScaleFactor = -2.5;
  final double _xLeftCenter = 114;
  final double _xRightCenter = 225;
  final double _iconScaleFactor = 0.05;
  final double _iconScaleMin = 0.8;
  final double _iconScaleMax = 1.2;
  final double _rotateLimit = 0.17453; // In Rad
  final double _snapPercent = 0.8;
  final double _goodMinBoundY = -3;
  final double _goodMinBoundZ = -2;
  final double _goodMaxBoundY = 5;
  final double _goodMaxBoundZ = 4;

  Coordinates _getOffsets(Coordinates eyeCenter) {
    if (eyeCenter == const Coordinates(z: -1)) {
      return const Coordinates(x: -1, y: 0, z: 0);
    } else {
      return Coordinates(
          x: 0,
          y: _nominalEyeOffsets.y - eyeCenter.y,
          z: eyeCenter.z - _nominalEyeOffsets.z);
    }
  }

  double _getRotation(double offsetLY, offsetRY) {
    double rotatedAngle = math.atan(_rotateScaleFactor *
        (offsetLY - offsetRY) /
        (_xRightCenter - _xLeftCenter));
    return rotatedAngle.clamp(-_rotateLimit, _rotateLimit);
  }

  double _getScale(double offsetsLZ, double offsetsRZ) {
    double glassesScale = 1 + _iconScaleFactor * (offsetsLZ + offsetsRZ);
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
    bool isMirrored = _isMirrored;

    final List snapMinRange = [
      _goodMinBoundY +
          0.5 * (_goodMaxBoundY - _goodMinBoundY) * (1 - _snapPercent),
      _goodMinBoundZ +
          0.5 * (_goodMaxBoundZ - _goodMinBoundZ) * (1 - _snapPercent)
    ];

    final List snapMaxRange = [
      _goodMaxBoundY -
          0.5 * (_goodMaxBoundY - _goodMinBoundY) * (1 - _snapPercent),
      _goodMaxBoundZ -
          0.5 * (_goodMaxBoundZ - _goodMinBoundZ) * (1 - _snapPercent)
    ];

    return BlocSelector<TrackerBloc, TrackerState, EyeTrackingData>(
        selector: (state) => state.etData ?? EyeTrackingData(),
        builder: (context, etData) {
          bool showGlasses = true;
          Coordinates offsetsL = _getOffsets(
              isMirrored ? etData.eyeCenter.left : etData.eyeCenter.right);
          Coordinates offsetsR = _getOffsets(
              isMirrored ? etData.eyeCenter.right : etData.eyeCenter.left);
          if (offsetsL.x == -1 || offsetsR.x == -1) {
            showGlasses = false;
          }

          if (_inSnapRange(offsetsL, offsetsR, snapMinRange, snapMaxRange)) {
            offsetsL = const Coordinates(x: 0, y: 0, z: 0);
            offsetsR = const Coordinates(x: 0, y: 0, z: 0);
          }
          double rotatedAngle = _getRotation(offsetsL.y, offsetsR.y);

          double glassesScale = _getScale(offsetsL.z, offsetsR.z);

          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/grey_mindlink.png"),
                  ),
                ),
              ),
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
                              child: Container(
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage(
                                        "assets/images/mindlink.png"),
                                  ),
                                ),
                              ))))
                  : Container()
            ],
          );
        });
  }
}

class Eyes extends StatelessWidget {
  const Eyes({super.key});

  @override
  Widget build(BuildContext context) {
    bool isMirrored = _isMirrored;
    return Row(
      children: [
        Expanded(child: SingleEye(isLeft: isMirrored, isMirrored: isMirrored)),
        Expanded(child: SingleEye(isLeft: !isMirrored, isMirrored: isMirrored)),
      ],
    );
  }
}

class EyePainter extends CustomPainter {
  // The eye painter for left and right eyes, for both the iris and the pupil
  final Coordinates gaze;
  final double diameter;
  final bool isMirrored;
  final Color color;

  EyePainter({
    required this.gaze,
    required this.diameter,
    required this.isMirrored,
    required this.color,
  });
  Coordinates getCoordinates() {
    // This is where the gazeX and gazeZ are multiplied by -1 and put in a range of 1 to -1
    double x =
        math.min(1, math.max(-1, (isMirrored ? 1 : -1) * gaze.x / xyBound));
    double y = math.min(1, math.max(-1, -gaze.y / xyBound));
    // This is where the gazeZ is translated from a range of 0 to -1 to a range of 0.5 to 1
    double z = math.min(math.max(((-gaze.z) * .5) + 0.5, 0.5), 1);
    return Coordinates(x: x, y: y, z: z);
  }

  @override
  void paint(Canvas canvas, Size size) {
    var pos = getCoordinates();
    double angle = math.atan2(pos.y, pos.x);
    var paint = Paint();
    paint.color = color;
    paint.style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(size.width, size.height);
    canvas.rotate(angle);
    canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: diameter * pos.z,
          height: diameter,
        ),
        paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class SingleEye extends StatelessWidget {
  final bool isLeft;
  final bool isMirrored;

  const SingleEye({super.key, required this.isLeft, required this.isMirrored});

  /// Calculates the position of the iris & pupil using the gaze from the
  /// [EyetrackingData] for the current eye
  Coordinates getAlignment(EyeTrackingData etData) {
    Coordinates gaze = getGaze(etData);
    double x = (isMirrored ? 1 : -1) * gaze.x / xyBound;
    double y = -gaze.y;
    return Coordinates(x: x, y: y, z: 0);
  }

  /// Returns the gaze from the [EyetrackingData] for the current eye
  Coordinates getGaze(EyeTrackingData etData) {
    return isLeft ? etData.gaze.left : etData.gaze.right;
  }

  /// Translates the pupil diameter from the eyetracking data to
  /// a range in pixels, returns the current pupil diameter if the pupil is
  /// out of the bounds that we allow dilation
  double getPupilDiameter(EyeTrackingData etData, double minPupil,
      double maxPupil, double curPupilDiameter) {
    if (curPupilDiameter != 0 &&
        etData.pupilDiameter.isOutOfBounds(etData.gaze)) {
      return curPupilDiameter;
    }

    var pupilDiameter = etData.pupilDiameter.adjusted;

    pupilDiameter =
        ((pupilDiameter - Defaults.minPupilSize) / Defaults.maxPupilSize);
    curPupilDiameter = ((maxPupil - minPupil) * pupilDiameter) + minPupil;
    return curPupilDiameter;
  }

  @override
  Widget build(BuildContext context) {
    double curPupilDiameter = 0;

    return AspectRatio(
      // This AspectRatio makes the underlying container a square
      // This ensures that we have proper height and width size constraints
      // for the child widgets regardless of the size of the screen
      aspectRatio: 1,
      child: LayoutBuilder(
        // Use the layout builder to get the contraints from the parent
        builder: (context, constraints) {
          double eyeballDiameter = constraints.maxWidth * 0.5;
          double irisDiameter = eyeballDiameter * 0.5;
          double maxPupil = irisDiameter * 0.8;
          double minPupil = irisDiameter * 0.25;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                // Eyeball
                alignment: Alignment.center,
                height: eyeballDiameter,
                width: eyeballDiameter,
                decoration: BoxDecoration(
                  color: AppColors.eyeballColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.irisColor),
                ),
                child: BlocSelector<TrackerBloc, TrackerState, EyeTrackingData>(
                  selector: (state) => state.etData ?? EyeTrackingData(),
                  builder: (context, etData) {
                    Coordinates alignment = getAlignment(etData);
                    Coordinates gaze = getGaze(etData);
                    curPupilDiameter = getPupilDiameter(
                        etData, minPupil, maxPupil, curPupilDiameter);
                    return Container(
                      alignment: Alignment(alignment.x, alignment.y),
                      width: irisDiameter,
                      height: irisDiameter,
                      child: CustomPaint(
                        // Iris
                        painter: EyePainter(
                          gaze: gaze,
                          diameter: irisDiameter,
                          isMirrored: isMirrored,
                          color: AppColors.irisColor,
                        ),
                        // Pupil
                        foregroundPainter: EyePainter(
                          gaze: gaze,
                          diameter: curPupilDiameter,
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
            color: AppColors.blinkBoxColor,
          )),
    );
  }
}
