import 'package:adhawk_ble/adhawkapi/repository/adhawkapi.dart';
import 'package:adhawk_ble/adhawkapi/service/tracker_bloc.dart';
import 'package:adhawk_ble/bluetooth/models/device.dart';
import 'package:adhawk_ble/bluetooth/repository/bluetooth_api_fbp.dart';
import 'package:adhawk_ble/bluetooth/repository/bluetooth_repository.dart';
import 'package:adhawk_ble/bluetooth/service/battery_bloc.dart';
import 'package:adhawk_ble/bluetooth/service/device_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ui/router/app_router.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

// This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (context) => BluetoothRepository(
            api: BluetoothApiFBP(),
            minReconnectDurationSecs: 10,
            maxReconnectDurationSecs: 180,
          ),
        ),
        RepositoryProvider(
          create: (context) => AdHawkApi(
            deviceRepo: context.read<BluetoothRepository>(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => DeviceBloc(
              deviceRepo: context.read<BluetoothRepository>(),
            )..add(DeviceMonitor()),
          ),
          BlocProvider(
            create: (context) => BatteryBloc(
              deviceRepo: context.read<BluetoothRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => TrackerBloc(
              api: context.read<AdHawkApi>(),
            ),
          ),
        ],
        child: MultiBlocListener(
          listeners: [
            // When we have a device, start communcation with the tracker
            // and start monitoring the battery
            BlocListener<DeviceBloc, DeviceState>(
              listener: (context, state) {
                TrackerBloc comms = context.read<TrackerBloc>();
                BatteryBloc battery = context.read<BatteryBloc>();
                if (state.status == ConnectionStatus.connected) {
                  comms.add(StartComms());
                  comms.add(StreamStartStop(start: true));
                  battery.add(BatteryMonitorToggled(on: true));
                } else if (state.status == ConnectionStatus.disconnected) {
                  comms.add(StopComms());
                  battery.add(BatteryMonitorToggled(on: false));
                }
              },
            ),
          ],
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: true),
            routerConfig: routeBuilder(),
          ),
        ),
      ),
    );
  }
}
