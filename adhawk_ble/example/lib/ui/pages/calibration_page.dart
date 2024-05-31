import 'package:adhawk_ble/adhawkapi/service/tracker_bloc.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

/// The [CalibrationInstructionsPage] guides the user through a user calibration
class CalibrationInstructionsPage extends StatelessWidget {
  const CalibrationInstructionsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calibrate',
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            NextButton(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(50),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    InstructionTopText(),
                    InstructionImage(),
                    InstructionBottomText(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstructionTopText extends StatelessWidget {
  const InstructionTopText({super.key});
  @override
  Widget build(BuildContext context) {
    return AutoSizeText(
      'Hold the phone straight out in front of you, level with your face.',
      style: Theme.of(context).textTheme.titleLarge,
      maxLines: 3,
    );
  }
}

class InstructionImage extends StatelessWidget {
  const InstructionImage({super.key});
  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/calibration_instructions.png');
  }
}

class InstructionBottomText extends StatelessWidget {
  const InstructionBottomText({super.key});
  @override
  Widget build(BuildContext context) {
    return AutoSizeText(
      "After clicking 'Next', focus on the spinning icon.",
      style: Theme.of(context).textTheme.titleLarge,
      maxLines: 2,
    );
  }
}

class NextButton extends StatelessWidget {
  const NextButton({super.key});
  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        context.read<TrackerBloc>().add(UserCalibration());
        context.goNamed(NamedRoutes.calibrate.value);
      },
      child: const Text('Next'),
    );
  }
}

class CalibrationPage extends StatelessWidget {
  const CalibrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Disables the back button
        title: const Text(
          'Calibrating...',
        ),
      ),
      body: BlocBuilder<TrackerBloc, TrackerState>(
        builder: (context, state) {
          switch (state.status) {
            case TrackerStatus.tuning:
              return const Align(
                child: CircularProgressIndicator(color: Colors.red),
              );
            case TrackerStatus.calibrating:
              return const Align(
                child: CircularProgressIndicator(color: Colors.yellow),
              );
            case TrackerStatus.active:
              return AlertDialog(
                title: const Text('Calibration successful'),
                content: const Text(
                    'You may need to calibrate again if eye tracking quality'
                    " isn't great or someone new is wearing the glasses."),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            case TrackerStatus.personalizing:
            // We should never be in the personalizing state on this page
            case TrackerStatus.faulted:
              return AlertDialog(
                title: const Text('Calibration failed'),
                content: const Text("Make sure you're using the right nosepiece"
                    ' and that the glasses fit properly. '
                    'During calibration, look straight ahead.'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            case TrackerStatus.unavailable:
              return AlertDialog(
                title: const Text('Calibration failed'),
                content: const Text('Glasses connection lost'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      //Navigator.of(context).pop();
                    },
                  ),
                ],
              );
          }
        },
      ),
    );
  }
}
