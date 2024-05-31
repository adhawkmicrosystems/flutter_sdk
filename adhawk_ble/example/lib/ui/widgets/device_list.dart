import 'package:adhawk_ble/bluetooth/models/device.dart';
import 'package:adhawk_ble/bluetooth/service/device_bloc.dart';
import 'package:adhawk_ble/bluetooth/service/scan_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeviceList extends StatelessWidget {
  const DeviceList({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScanBloc, ScanState>(
      builder: (context, state) {
        if (state.status == ScanStatus.success && state.devices.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No glasses found. Check that your glasses are charged, nearby, and turned on.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return ListView.separated(
          itemCount: state.devices.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) => DeviceTile(
            device: state.devices[index],
          ),
        );
      },
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
        final deviceBloc = context.read<DeviceBloc>();
        return ListTile(
          title: Text(device.name),
          subtitle: Text(device.btInfo.description),
          trailing: state.device == device
              ? DeviceConnectivityIcon(state: state)
              : const Icon(null),
          onTap: () async {
            if (state.status == ConnectionStatus.disconnected) {
              if (device == state.device && state.connectFailed) {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      ConnectFailureAlertDialog(device: state.device!),
                );
              }
              deviceBloc.add(DeviceActionTriggered(
                device,
                DeviceAction.connect,
              ));
            } else if (state.status == ConnectionStatus.connected) {
              // display a dialog to ensure the user wanted to disconnect
              final disconnect = await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    DisconnectAlertDialog(device: state.device!),
              );
              if (disconnect) {
                deviceBloc.add(DeviceActionTriggered(
                  device,
                  DeviceAction.disconnect,
                ));
              }
            }
          },
        );
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
    if (state.connectFailed) {
      return const Icon(Icons.error);
    }
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

class DisconnectAlertDialog extends StatelessWidget {
  const DisconnectAlertDialog({required this.device, super.key});

  final Device device;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Disconnect?'),
      content: Text('Are you sure you want to disconnect from ${device.name}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Disconnect'),
        )
      ],
    );
  }
}

class ConnectFailureAlertDialog extends StatelessWidget {
  const ConnectFailureAlertDialog({required this.device, super.key});

  final Device device;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connection failed'),
      content:
          Text('Make sure ${device.name} is in range and properly paired.\n'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
