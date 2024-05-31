// ignore_for_file: discarded_futures

import 'dart:typed_data';
import 'package:adhawk_ble/bluetooth/models/bluetooth_characteristics.dart';
import 'package:adhawk_ble/bluetooth/repository/bluetooth_repository.dart';
import 'package:adhawk_ble/bluetooth/service/battery_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements BluetoothRepository {}

void main() {
  group('BatteryBloc', () {
    late MockRepository mockRepo;
    late BatteryBloc bloc;
    final ch = BatteryCharacteristics.batteryLevel.characteristic;

    setUp(() {
      mockRepo = MockRepository();
      bloc = BatteryBloc(deviceRepo: mockRepo);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('Verify initial state', () {
      expect(bloc.state, BatteryState(status: BatteryStatus.unknown, level: 0));
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
        const TypeMatcher<BatteryState>()
            .having((state) => state.status, 'status', equals(BatteryStatus.ok))
            .having((state) => state.level, 'level', equals(80)),
      ],
    );

    blocTest<BatteryBloc, BatteryState>(
      'Monitor battery levels on [BatteryMonitorToggled] on event',
      setUp: () {
        when(() => mockRepo.read(ch))
            .thenAnswer((_) => Future.value(Uint8List.fromList([31])));
        when(() => mockRepo.startStream(ch))
            .thenAnswer((_) => Future.value(Stream.fromIterable([
                  Uint8List.fromList([30]),
                  Uint8List.fromList([29]),
                ])));
      },
      build: () => bloc,
      act: (bloc) => bloc.add(BatteryMonitorToggled(on: true)),
      verify: (_) {
        verify(() => mockRepo.read(ch)).called(1);
        verify(() => mockRepo.startStream(ch)).called(1);
      },
      expect: () => [
        const TypeMatcher<BatteryState>()
            .having((state) => state.status, 'status', equals(BatteryStatus.ok))
            .having((state) => state.level, 'level', equals(31)),
        const TypeMatcher<BatteryState>()
            .having((state) => state.status, 'status', equals(BatteryStatus.ok))
            .having((state) => state.level, 'level', equals(30)),
        const TypeMatcher<BatteryState>()
            .having(
                (state) => state.status, 'status', equals(BatteryStatus.low))
            .having((state) => state.level, 'level', equals(29)),
      ],
    );
    blocTest<BatteryBloc, BatteryState>(
      'Stop monitoring battery levels on [BatteryMonitorToggled] off event',
      build: () => bloc,
      seed: () => BatteryState(status: BatteryStatus.ok, level: 80),
      act: (bloc) {
        bloc.add(BatteryMonitorToggled(on: false));
      },
      verify: (_) {
        verifyNever(() => mockRepo.read(ch));
        verifyNever(() => mockRepo.startStream(ch));
      },
      expect: () => [
        BatteryState(status: BatteryStatus.unknown, level: 0),
      ],
    );
  });
}
