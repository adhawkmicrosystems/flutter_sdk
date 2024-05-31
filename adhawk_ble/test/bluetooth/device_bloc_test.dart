// ignore_for_file: discarded_futures

import 'dart:async';
import 'dart:typed_data';
import 'package:adhawk_ble/bluetooth/models/bluetooth_characteristics.dart';
import 'package:adhawk_ble/bluetooth/models/device.dart';
import 'package:adhawk_ble/bluetooth/repository/bluetooth_api.dart';
import 'package:adhawk_ble/bluetooth/repository/bluetooth_repository.dart';
import 'package:adhawk_ble/bluetooth/service/device_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements BluetoothRepository {}

void main() {
  group('DeviceBloc', () {
    const device1 = Device(
      name: 'MINDLINK-1',
      btInfo: BluetoothInformation(
        id: 'AA:AA:AA:AA:AA',
        description: '',
      ),
    );
    const device2 = Device(
      name: 'MINDLINK-2',
      btInfo: BluetoothInformation(
        id: 'BB:BB:BB:BB:BB',
        description: '',
      ),
    );
    final device1FWVersion = Uint8List.fromList([65]);
    final device2FWVersion = Uint8List.fromList([66]);
    final device1HWRev = Uint8List.fromList([118, 50]);
    final device2HWRev = Uint8List.fromList([118, 51]);

    late MockRepository mockRepo;
    late DeviceBloc bloc;
    late StreamController<ConnectionStatusEvent> mockStream;

    setUpAll(() {
      registerFallbackValue(Uint8List(0));
    });
    setUp(() {
      mockRepo = MockRepository();
      bloc = DeviceBloc(deviceRepo: mockRepo);
      mockStream = StreamController<ConnectionStatusEvent>.broadcast();
    });

    tearDown(() async {
      await mockStream.close();
      await bloc.close();
    });

    test('Verify initial state', () {
      expect(
        bloc.state,
        const DeviceState(
          status: ConnectionStatus.disconnected,
          device: null,
          hardwareRev: null,
          firmwareVersion: null,
          // ignore: avoid_redundant_argument_values, ensure correct default value
          connectFailed: false,
        ),
      );
    });

    blocTest<DeviceBloc, DeviceState>(
      'Verify connect to a device',
      setUp: () {
        when(() => mockRepo.connect(device1)).thenAnswer((_) async {
          mockStream.add(ConnectionStatusEvent(
            device: device1,
            status: ConnectionStatus.connected,
          ));
        });
        when(() => mockRepo.connectionStatus)
            .thenAnswer((_) => mockStream.stream);
        when(() => mockRepo.read(DeviceInformationCharacteristics
            .hardwareRevision
            .characteristic)).thenAnswer((_) async => device1HWRev);
        when(() => mockRepo.read(DeviceInformationCharacteristics
            .firmwareRevision
            .characteristic)).thenAnswer((_) async => device1FWVersion);
        when(() => mockRepo.write(
            TimeCharacteristics.setTime.characteristic, any(),
            withoutResponse: false)).thenAnswer((_) async {});
      },
      build: () => bloc,
      act: (bloc) {
        bloc
          ..add(DeviceMonitor())
          ..add(DeviceActionTriggered(device1, DeviceAction.connect));
      },
      verify: (_) {
        verify(() => mockRepo.connect(device1)).called(1);
      },
      expect: () => [
        const DeviceState(
            status: ConnectionStatus.connecting,
            device: device1,
            hardwareRev: null,
            firmwareVersion: null),
        const DeviceState(
            status: ConnectionStatus.connected,
            device: device1,
            hardwareRev: 'v2',
            firmwareVersion: 'A'),
      ],
    );

    blocTest<DeviceBloc, DeviceState>(
      'Verify connect to a device failed',
      setUp: () {
        when(() => mockRepo.connect(device1))
            .thenThrow(BluetoothConnectException('Failed'));
        when(() => mockRepo.connectionStatus)
            .thenAnswer((_) => mockStream.stream);
      },
      build: () => bloc,
      act: (bloc) {
        bloc
          ..add(DeviceMonitor())
          ..add(DeviceActionTriggered(device1, DeviceAction.connect));
      },
      verify: (_) {
        verify(() => mockRepo.connect(device1)).called(1);
      },
      expect: () => [
        const DeviceState(
            status: ConnectionStatus.connecting,
            device: device1,
            hardwareRev: null,
            firmwareVersion: null),
        const DeviceState(
            status: ConnectionStatus.disconnected,
            device: device1,
            hardwareRev: null,
            firmwareVersion: null,
            connectFailed: true),
      ],
    );

    blocTest<DeviceBloc, DeviceState>(
      'Verify behavior when reconnect attempt succeeds',
      setUp: () {
        when(() => mockRepo.connect(device1)).thenAnswer((_) async {
          mockStream.add(ConnectionStatusEvent(
            device: device1,
            status: ConnectionStatus.connected,
          ));
        });
        when(() => mockRepo.connectionStatus).thenAnswer(
          (_) => mockStream.stream,
        );
        when(() => mockRepo.read(DeviceInformationCharacteristics
            .hardwareRevision
            .characteristic)).thenAnswer((_) async => device1HWRev);
        when(() => mockRepo.read(DeviceInformationCharacteristics
            .firmwareRevision
            .characteristic)).thenAnswer((_) async => device1FWVersion);
        when(() => mockRepo.write(
            TimeCharacteristics.setTime.characteristic, any(),
            withoutResponse: false)).thenAnswer((_) async {});
      },
      build: () => bloc,
      seed: () => const DeviceState(
          status: ConnectionStatus.disconnected,
          device: device1,
          hardwareRev: null,
          firmwareVersion: null,
          connectFailed: true),
      act: (bloc) {
        bloc
          ..add(DeviceMonitor())
          ..add(DeviceActionTriggered(device1, DeviceAction.connect));
      },
      verify: (_) {
        verify(() => mockRepo.connect(device1)).called(1);
      },
      expect: () => [
        const DeviceState(
            status: ConnectionStatus.connecting,
            device: device1,
            hardwareRev: null,
            firmwareVersion: null),
        const DeviceState(
            status: ConnectionStatus.connected,
            device: device1,
            hardwareRev: 'v2',
            firmwareVersion: 'A'),
      ],
    );

    blocTest<DeviceBloc, DeviceState>(
      'Verify behavior when reconnect attempt fails',
      setUp: () {
        when(() => mockRepo.connect(device1))
            .thenThrow(BluetoothConnectException('Failed'));
        when(() => mockRepo.connectionStatus).thenAnswer(
          (_) => mockStream.stream,
        );
      },
      build: () => bloc,
      seed: () => const DeviceState(
          status: ConnectionStatus.disconnected,
          device: device1,
          hardwareRev: null,
          firmwareVersion: null,
          connectFailed: true),
      act: (bloc) {
        bloc
          ..add(DeviceMonitor())
          ..add(DeviceActionTriggered(device1, DeviceAction.connect));
      },
      verify: (_) {
        verify(() => mockRepo.connect(device1)).called(1);
      },
      expect: () => [
        const DeviceState(
            status: ConnectionStatus.connecting,
            device: device1,
            hardwareRev: null,
            firmwareVersion: null),
        const DeviceState(
            status: ConnectionStatus.disconnected,
            device: device1,
            hardwareRev: null,
            firmwareVersion: null,
            connectFailed: true),
      ],
    );

    blocTest<DeviceBloc, DeviceState>(
      'Verify disconnect from current device',
      setUp: () {
        when(() => mockRepo.disconnect(device1)).thenAnswer((_) async {
          mockStream.add(ConnectionStatusEvent(
            device: device1,
            status: ConnectionStatus.disconnected,
          ));
        });
        when(() => mockRepo.connectionStatus).thenAnswer(
          (_) => mockStream.stream,
        );
      },
      build: () => bloc,
      seed: () => const DeviceState(
          status: ConnectionStatus.connected,
          device: device1,
          hardwareRev: 'v2',
          firmwareVersion: 'A'),
      act: (bloc) {
        bloc
          ..add(DeviceMonitor())
          ..add(DeviceActionTriggered(device1, DeviceAction.disconnect));
      },
      verify: (_) {
        verify(() => mockRepo.disconnect(device1)).called(1);
      },
      expect: () => [
        const DeviceState(
            status: ConnectionStatus.disconnecting,
            device: device1,
            hardwareRev: 'v2',
            firmwareVersion: 'A'),
        const DeviceState(
            status: ConnectionStatus.disconnected,
            device: device1,
            hardwareRev: 'v2',
            firmwareVersion: 'A'),
      ],
    );

    blocTest<DeviceBloc, DeviceState>(
      'Verify disconnect from current device failed',
      setUp: () {
        when(() => mockRepo.disconnect(device1))
            .thenThrow(BluetoothDisconnectException('Failed'));
        when(() => mockRepo.connectionStatus)
            .thenAnswer((_) => mockStream.stream);
      },
      build: () => bloc,
      seed: () => const DeviceState(
          status: ConnectionStatus.connected,
          device: device1,
          hardwareRev: 'v2',
          firmwareVersion: 'A'),
      act: (bloc) {
        bloc
          ..add(DeviceMonitor())
          ..add(DeviceActionTriggered(device1, DeviceAction.disconnect));
      },
      verify: (_) {
        verify(() => mockRepo.disconnect(device1)).called(1);
      },
      expect: () => [
        const DeviceState(
            status: ConnectionStatus.disconnecting,
            device: device1,
            hardwareRev: 'v2',
            firmwareVersion: 'A'),
        const DeviceState(
            status: ConnectionStatus.disconnected,
            device: device1,
            hardwareRev: 'v2',
            firmwareVersion: 'A'),
      ],
    );

    blocTest<DeviceBloc, DeviceState>(
      'Verify connect to a new device',
      setUp: () {
        when(() => mockRepo.disconnect(device1)).thenAnswer((_) async {
          mockStream.add(ConnectionStatusEvent(
            device: device1,
            status: ConnectionStatus.disconnected,
          ));
        });
        when(() => mockRepo.connect(device2)).thenAnswer((_) async {
          mockStream.add(ConnectionStatusEvent(
            device: device2,
            status: ConnectionStatus.connected,
          ));
        });
        when(() => mockRepo.connectionStatus)
            .thenAnswer((_) => mockStream.stream);
        when(() => mockRepo.read(DeviceInformationCharacteristics
            .hardwareRevision
            .characteristic)).thenAnswer((_) async => device2HWRev);
        when(() => mockRepo.read(DeviceInformationCharacteristics
            .firmwareRevision
            .characteristic)).thenAnswer((_) async => device2FWVersion);
        when(() => mockRepo.write(
            TimeCharacteristics.setTime.characteristic, any(),
            withoutResponse: false)).thenAnswer((_) async {});
      },
      build: () => bloc,
      seed: () => const DeviceState(
          status: ConnectionStatus.connected,
          device: device1,
          hardwareRev: 'v2',
          firmwareVersion: 'A'),
      act: (bloc) async {
        bloc
          ..add(DeviceMonitor())
          ..add(DeviceActionTriggered(device2, DeviceAction.connect));
      },
      verify: (_) {
        verify(() => mockRepo.disconnect(device1)).called(1);
        verify(() => mockRepo.connect(device2)).called(1);
        verify(() => mockRepo.read(DeviceInformationCharacteristics
            .hardwareRevision.characteristic)).called(1);
        verify(() => mockRepo.read(DeviceInformationCharacteristics
            .firmwareRevision.characteristic)).called(1);
      },
      expect: () => [
        const DeviceState(
            status: ConnectionStatus.disconnecting,
            device: device1,
            hardwareRev: 'v2',
            firmwareVersion: 'A'),
        const DeviceState(
            status: ConnectionStatus.disconnected,
            device: device1,
            hardwareRev: 'v2',
            firmwareVersion: 'A'),
        const DeviceState(
            status: ConnectionStatus.connecting,
            device: device2,
            hardwareRev: null,
            firmwareVersion: null),
        const DeviceState(
            status: ConnectionStatus.connected,
            device: device2,
            hardwareRev: 'v3',
            firmwareVersion: 'B'),
      ],
    );
  });
}
