
# AdHawk Flutter SDK for BLE devices

A flutter package for connecting to AdHawk BLE devices and collecting eyetracking data

## Features

* Scan for and connect to AdHawk BLE devices
* Collect the following data from the glasses
  * Eyetracking
    * Gaze
    * Eye center
    * Pupil Diameter
    * Blink Events
  * Sensor
    * IMU Quaternion

## Support

|             | Android | iOS   |
|-------------|---------|-------|
| **Support** | SDK 21+ |  ??   |


## Getting started

This package uses:
* [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) for BLE communication
* [flutter_bloc](https://pub.dev/packages/flutter_bloc) for state management

## Usage

To use this package add `adhawk_ble` as a dependency in your pubspec.yaml file

```yaml
adhawk_ble:
  git:
    url: git@github.com:adhawkmicrosystems/flutter_sdk.git
    ref: master
    path: adhawk_ble
```

### Example

The [example app](example) provides a starting point for connecting to AdHawk BLE devices and using the eyetracking data. 

It handles scanning, connecting and setting up communicaton with the glasses and you can skip right to [using the eye tracking data](#monitor-eyetracking-data)!

You can enhance or modify the application.

### API

Create the following:
* `BluetoothRepository` - Perform BLE communication
* `AdHawkApi` - Use the AdHawk protocol to encode commands and decode reponses and streams from the device

```dart
MultiRepositoryProvider(
  providers: [
    RepositoryProvider(
      create: (context) => BluetoothRepository(),
    ),
    RepositoryProvider(
      create: (context) => AdHawkApi(
        deviceRepo: context.read<BluetoothRepository>(),
      ),
    ),
  ],
  child: ...
)
```

#### Scan for AdHawk devices

Use the `ScanBloc` to trigger scan events and monitor the `ScanState`.

See [scan_bloc.dart](lib/bluetooth/service/scan_bloc.dart)

```dart
// Create a scan bloc
BlocProvider<ScanBloc>(
  create: (context) => ScanBloc(deviceRepo: BluetoothRepository()),
  child: ...
)

// Start the scan
context.read<ScanBloc>().add(ScanStarted());

// Stop the scan
context.read<ScanBloc>().add(ScanStopped());

// List the devices found in the scan
BlocBuilder<ScanBloc, ScanState>(
  builder: (context, state) {
    return ListView.separated(
      itemCount: state.devices.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) => Text(
        state.devices[index].name,
      ),
    );
  },
)
```

#### Connect

Use the `DeviceBloc` to connect to a device in the scan results and monitor the `DeviceState`.

See [device_bloc.dart](lib/bluetooth/service/device_bloc.dart)

```dart
// Create a device bloc
BlocProvider(
  create: (context) => DeviceBloc(
    deviceRepo: context.read<BluetoothRepository>(),
  )..add(DeviceCheckTriggered()),
),

// connect/disconnect to a device found in the scan
context.read<DeviceBloc>().add(DeviceConnectDisconnect(device));

// Monitor connection status of the device
BlocListener<DeviceBloc, DeviceState>(
  listener: (context, state) {
    if (state.status == ConnectionStatus.connected) {
      print('${state.device?.name} connected');
    } else if (state.status == ConnectionStatus.disconnected) {
      print('${state.device?.name} disconnected');
    }
  }
)
```

#### Communicate with the glasses

Use the `TrackerBloc` to communicate with the glasses and monitor the `TrackerState`

See [tracker_bloc.dart](lib/adhawkapi/service/tracker_bloc.dart)


```dart
// Create a tracker bloc
BlocProvider(
  create: (context) => TrackerBloc(
    api: context.read<AdHawkApi>(),
  ),
),

// Start communicating with the glasses
context.read<CommsBloc>().add(StartComms());

```

The `TrackerState` provides the `EyetrackingData`
and `BlinkEvent` streams from the glasses

##### Monitor Eyetracking Data

See `EyeTrackingData` in [api.dart](lib/adhawkapi/models/api.dart)

```dart
BlocListener<TrackerBloc, TrackerState>(
  listener: (context, state) {
    if (state.etData == null) {
      return;
    }
    print(state.etData?.gaze);
    print(state.etData?.eyeCenter);
    print(state.etData?.pupilDiameter);
    print(state.etData?.imuQuaternion);
  }
)
```
##### Monitor Blink Events

See `BlinkEvent` in [api.dart](lib/adhawkapi/models/api.dart)

```dart
BlocListener<TrackerBloc, TrackerState>(
  listener: (context, state) {
    if (state.eventData == null) {
      return;
    }
    print('Blink duration: ${state.eventData!.duration}');
  }
)
```
