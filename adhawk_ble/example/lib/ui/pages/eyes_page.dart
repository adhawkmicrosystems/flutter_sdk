import 'package:adhawk_ble/adhawkapi/service/tracker_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../widgets/eyes.dart';

class EyesPage extends StatelessWidget {
  const EyesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: EyeView(allowLocking: true),
            ),
          ),
        ],
      ),
      floatingActionButton: CalibrateButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }
}

class CalibrateButton extends StatelessWidget {
  const CalibrateButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackerBloc, TrackerState>(
      builder: (context, state) {
        final trackerBloc = context.read<TrackerBloc>();
        if (state.status != TrackerStatus.unavailable) {
          return FilledButton.tonal(
            onPressed: () {
              trackerBloc.add(PersonalizeTracker());
              context.goNamed(NamedRoutes.personalization.value);
            },
            child: const Text('Calibrate'),
          );
        } else {
          return Container();
        }
      },
    );
  }
}
