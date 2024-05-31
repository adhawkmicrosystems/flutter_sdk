import 'package:adhawk_ble_example/ui/pages/personalization_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/calibration_page.dart';
import '../pages/connect_page.dart';
import '../pages/home_page.dart';

enum NamedRoutes {
  login('login'),
  home('home'),
  connect('connect'),
  personalization('personalization'),
  calibrationInstruction('calibrationInstruction'),
  calibrate('calibrate'),
  logs('logs'),
  ;

  const NamedRoutes(this.value);
  final String value;

  @override
  String toString() => value;
}

GoRouter routeBuilder() => GoRouter(
      initialLocation: '/home',
      routes: <GoRoute>[
        GoRoute(
          name: NamedRoutes.home.value,
          path: '/home',
          builder: (BuildContext context, GoRouterState state) =>
              const HomePage(title: 'AdHawk BLE'),
          routes: [
            GoRoute(
              name: NamedRoutes.connect.value,
              path: 'connect',
              builder: (BuildContext context, GoRouterState state) =>
                  const ConnectPage(),
            ),
            GoRoute(
              name: NamedRoutes.personalization.value,
              path: 'personalization',
              builder: (context, state) => const PersonalizationPage(),
            ),
            GoRoute(
              name: NamedRoutes.calibrationInstruction.value,
              path: 'calibrationInstruction',
              builder: (BuildContext context, GoRouterState state) =>
                  const CalibrationInstructionsPage(),
            ),
            GoRoute(
              name: NamedRoutes.calibrate.value,
              path: 'calibrate',
              builder: (BuildContext context, GoRouterState state) =>
                  const CalibrationPage(),
            ),
          ],
        ),
      ],
    );
