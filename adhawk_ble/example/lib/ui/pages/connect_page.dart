import 'dart:io' show Platform;

import 'package:adhawk_ble/bluetooth/repository/bluetooth_repository.dart';
import 'package:adhawk_ble/bluetooth/service/scan_bloc.dart';
import 'package:adhawk_ble_example/ui/widgets/device_list.dart';
import 'package:adhawk_ble_example/ui/widgets/guards.dart';
import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

/// The [ConnectPage] creates and provides a [ScanBloc]
/// A scan is triggered as soon as the [ScanBloc] is created
class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider<ScanBloc>(
      create: (context) => ScanBloc(
        deviceRepo: context.read<BluetoothRepository>(),
      )..add(ScanStarted()),
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
          check: () async => Permission.bluetooth.serviceStatus.isEnabled,
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
          check: () async =>
              !(await _isLocationRequired()) ||
              (await Permission.location.request().isGranted),
          alertDialog: const SystemSettingsAlertDialog(
            title: 'Allow location?',
            rationale: 'We use location services to find nearby glasses',
            appSettingsType: AppSettingsType.settings,
          ),
        ),
        ServiceGuard(
          check: () async =>
              !(await _isLocationRequired()) ||
              (await Permission.location.serviceStatus.isEnabled),
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
      body: const DeviceList(),
    );
  }
}
