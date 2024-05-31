import 'package:adhawk_ble/adhawkapi/service/tracker_bloc.dart';
import 'package:adhawk_ble_example/ui/router/app_router.dart';
import 'package:adhawk_ble_example/ui/widgets/eyes.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PersonalizationPage extends StatelessWidget {
  const PersonalizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitting'),
      ),
      body: BlocListener<TrackerBloc, TrackerState>(
        listenWhen: (previous, current) =>
            previous.status == TrackerStatus.personalizing &&
            current.status == TrackerStatus.faulted,
        listener: (context, state) async {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Personalization failed'),
              content: const Text("Make sure you're using the right nosepiece"
                  ' and that the glasses fit properly. '),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                )
              ],
            ),
          );
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: const Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: InstructionTopText()),
                  NextButton(),
                ],
              ),
              Expanded(child: EyeView(allowLocking: false)),
            ],
          ),
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
      'Move your glasses around a bit.\n'
      "Press 'Next' after the moving frame aligns with the fixed frame as much as possible",
      style: Theme.of(context).textTheme.titleMedium,
      maxLines: 3,
    );
  }
}

class NextButton extends StatelessWidget {
  const NextButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackerBloc, TrackerState>(
      builder: (context, state) {
        var enable = true;
        switch (state.status) {
          case TrackerStatus.active:
            enable = true;
          case TrackerStatus.personalizing:
          case TrackerStatus.tuning:
          case TrackerStatus.calibrating:
          case TrackerStatus.faulted:
          case TrackerStatus.unavailable:
            enable = false;
        }
        return FilledButton(
          onPressed: enable
              ? () {
                  context.goNamed(NamedRoutes.calibrationInstruction.value);
                }
              : null,
          child: const Text('Next'),
        );
      },
    );
  }
}
