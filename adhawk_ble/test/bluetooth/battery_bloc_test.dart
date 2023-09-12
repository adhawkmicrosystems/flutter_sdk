import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhawk_ble/bluetooth/service/battery_bloc.dart';
import 'package:adhawk_ble/bluetooth/models/bluetooth_characteristics.dart';
import 'package:adhawk_ble/bluetooth/repository/bluetooth_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements BluetoothRepository {}

void main() {
  group('BatteryBloc', () {
    late MockRepository mockRepo;
    late BatteryBloc bloc;
    final Characteristic ch =
        BatteryCharacteristics.batteryLevel.characteristic;

    setUp(() {
      mockRepo = MockRepository();
      bloc = BatteryBloc(deviceRepo: mockRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test('Verify initial state', () {
      expect(bloc.state,
          const BatteryState(status: BatteryStatus.unknown, level: 0));
    });

    blocTest<BatteryBloc, BatteryState>(
      'Read initial levels on [BatteryMonitorToggled] on event',
      setUp: () {
        when(() => mockRepo.read(ch))
            .thenAnswer((_) => Future.value(Uint8List.fromList([80])));
        when(() => mockRepo.startStream(ch))
            .thenAnswer((_) => Future.value(Stream.fromIterable([])));
      },
      build: () => bloc,
      act: (bloc) => bloc.add(BatteryMonitorToggled(on: true)),
      verify: (_) {
        verify(() => mockRepo.read(ch)).called(1);
        verify(() => mockRepo.startStream(ch)).called(1);
      },
      expect: () => [
        const BatteryState(status: BatteryStatus.ok, level: 80),
      ],
    );

    blocTest<BatteryBloc, BatteryState>(
      'Monitor battery levels on [BatteryMonitorToggled] on event',
      setUp: () {
        when(() => mockRepo.read(ch))
            .thenAnswer((_) => Future.value(Uint8List.fromList([21])));
        when(() => mockRepo.startStream(ch))
            .thenAnswer((_) => Future.value(Stream.fromIterable([
                  Uint8List.fromList([20]),
                  Uint8List.fromList([19]),
                ])));
      },
      build: () => bloc,
      act: (bloc) => bloc.add(BatteryMonitorToggled(on: true)),
      verify: (_) {
        verify(() => mockRepo.read(ch)).called(1);
        verify(() => mockRepo.startStream(ch)).called(1);
      },
      expect: () => [
        const BatteryState(status: BatteryStatus.ok, level: 21),
        const BatteryState(status: BatteryStatus.ok, level: 20),
        const BatteryState(status: BatteryStatus.low, level: 19)
      ],
    );
    blocTest<BatteryBloc, BatteryState>(
      'Stop monitoring battery levels on [BatteryMonitorToggled] off event',
      build: () => bloc,
      seed: () => const BatteryState(status: BatteryStatus.ok, level: 80),
      act: (bloc) {
        bloc.add(BatteryMonitorToggled(on: false));
      },
      verify: (_) {
        verifyNever(() => mockRepo.read(ch));
        verifyNever(() => mockRepo.getStream(ch));
      },
      expect: () => [
        const BatteryState(status: BatteryStatus.unknown, level: 0),
      ],
    );
  });
}
