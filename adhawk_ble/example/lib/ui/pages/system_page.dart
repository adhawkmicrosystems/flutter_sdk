import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:adhawk_ble/adhawkapi/service/tracker_bloc.dart';
import 'package:adhawk_ble/bluetooth/service/battery_bloc.dart';
import 'package:adhawk_ble/bluetooth/service/device_bloc.dart';
import 'package:adhawk_ble/bluetooth/models/device.dart';
import '../router/app_router.dart';
import '../themes/theme.dart';
import '../widgets/justified_text.dart';

class SystemPage extends StatelessWidget {
  const SystemPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const DeviceInformation(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.goNamed(NamedRoutes.connect.value);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class DeviceInformation extends StatelessWidget {
  const DeviceInformation({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceBloc, DeviceState>(builder: (context, state) {
      if (state.status == ConnectionStatus.connected) {
        return Theme(
          data: Theme.of(context)
              .copyWith(cardTheme: deviceInformationTheme(context)),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      state.device!.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const BatteryLevel(),
                  const SerialNumber(),
                  const FirmwareVersion(),
                  JustifiedText(
                    left: 'Bluetooth FW version',
                    right: state.firmwareVersion ?? '',
                  ),
                  JustifiedText(
                    left: 'Hardware revision',
                    right: state.hardwareRev ?? '',
                  ),
                  JustifiedText(
                    left: 'Bluetooth ID',
                    right: state.device!.btInfo.id,
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        return Container();
      }
    });
  }
}

class BatteryLevel extends StatelessWidget {
  const BatteryLevel({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BatteryBloc, BatteryState>(builder: (context, state) {
      return JustifiedText(
        left: 'Battery',
        right: '${state.level}%',
      );
    });
  }
}

class SerialNumber extends StatelessWidget {
  const SerialNumber({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocSelector<TrackerBloc, TrackerState, String>(
      selector: (state) => state.serialNumber,
      builder: (context, serialNumber) => JustifiedText(
        left: 'Serial number',
        right: serialNumber,
      ),
    );
  }
}

class FirmwareVersion extends StatelessWidget {
  const FirmwareVersion({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocSelector<TrackerBloc, TrackerState, String>(
      selector: (state) => state.firmwareVersion,
      builder: (context, firmwareVersion) => JustifiedText(
        left: 'Firmware version',
        right: firmwareVersion,
      ),
    );
  }
}
