import 'dart:io' show Platform;

import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:adhawk_ble/bluetooth/service/device_bloc.dart';
import 'package:adhawk_ble/bluetooth/service/scan_bloc.dart';
import 'package:adhawk_ble/bluetooth/models/device.dart';
import 'package:adhawk_ble/bluetooth/repository/bluetooth_repository.dart';
import '../widgets/guards.dart';

/// The [ConnectPage] creates and provides a [ScanBloc]
/// A scan is triggered as soon as the [ScanBloc] is created
class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider<ScanBloc>(
      create: (context) => ScanBloc(
        deviceRepo: context.read<BluetoothRepository>(),
      ),
      child: const ConnectGuards(),
    );
  }
}

/// Sets up checks to see if Bluetooth is enabled, Location is enabled
/// and the required permissions are granted before starting a scan
class ConnectGuards extends StatefulWidget {
  const ConnectGuards({super.key});

  @override
  State<ConnectGuards> createState() => _ConnectGuardsState();
}

class _ConnectGuardsState extends State<ConnectGuards> {
  Future<bool> _isLocationRequired() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt > 30) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scanBloc = BlocProvider.of<ScanBloc>(context);
    return GuardManager(
      guards: [
        PermissionGuard(
          permissions: [
            Platform.isAndroid ? Permission.bluetoothScan : Permission.bluetooth
          ],
          title: 'Allow Bluetooth?',
          rationale: 'We use Bluetooth to communicate with your glasses',
        ),
        ServiceGuard(
          check: () async =>
              (await Permission.bluetooth.serviceStatus.isEnabled),
          alertDialog: const SystemSettingsAlertDialog(
            title: 'Turn on Bluetooth?',
            rationale: 'We use Bluetooth to communicate with your glasses',
            appSettingsType: AppSettingsType.bluetooth,
          ),
        ),
        ServiceGuard(
          // Use the generic ServiceGuard here instead of the PermissionGuard
          // because we need to check if location
          // is required as well as check if the permission is granted
          check: () async => (!(await _isLocationRequired()) ||
              (await Permission.location.request().isGranted)),
          alertDialog: const SystemSettingsAlertDialog(
            title: 'Allow location?',
            rationale: 'We use location services to find nearby glasses',
            appSettingsType: AppSettingsType.settings,
          ),
        ),
        ServiceGuard(
          check: () async => (!(await _isLocationRequired()) ||
              (await Permission.location.serviceStatus.isEnabled)),
          alertDialog: const SystemSettingsAlertDialog(
            title: 'Turn on location?',
            rationale: 'We use location services to find nearby glasses',
            appSettingsType: AppSettingsType.location,
          ),
        ),
      ],
      child: const ConnectView(),
      onSuccess: () => scanBloc.add(ScanStarted()),
      onFailure: () => scanBloc.add(ScanStopped()),
    );
  }
}

/// The [ConnectView] displays a list of available devices
/// by listening to the [ScanState] emitted by the [ScanBloc]
class ConnectView extends StatelessWidget {
  const ConnectView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect'),
      ),
      body: BlocBuilder<ScanBloc, ScanState>(
        builder: (context, state) {
          return ListView.separated(
            itemCount: state.devices.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) => DeviceTile(
              device: state.devices[index],
            ),
          );
        },
      ),
    );
  }
}

class DeviceTile extends StatelessWidget {
  const DeviceTile({super.key, required this.device});
  final Device device;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceBloc, DeviceState>(
      builder: (context, state) {
        DeviceBloc deviceBloc = context.read<DeviceBloc>();
        return ListTile(
            title: Text(device.name),
            subtitle: Text(device.btInfo.description),
            trailing: state.device == device
                ? DeviceConnectivityIcon(state: state)
                : const Icon(null),
            onTap: () => (state.status == ConnectionStatus.disconnected ||
                    state.status == ConnectionStatus.connected)
                ? deviceBloc.add(DeviceConnectDisconnect(device))
                : null);
      },
    );
  }
}

class DeviceConnectivityIcon extends StatelessWidget {
  const DeviceConnectivityIcon({
    super.key,
    required this.state,
  });
  final DeviceState state;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ConnectionStatus.connected:
        return const Icon(Icons.check);
      case ConnectionStatus.connecting:
      case ConnectionStatus.disconnecting:
        return const CircularProgressIndicator();
      case ConnectionStatus.init:
      case ConnectionStatus.disconnected:
        return const Icon(null);
    }
  }
}
