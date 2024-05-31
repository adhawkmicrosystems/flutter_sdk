// ignore_for_file: discarded_futures

import 'package:adhawk_ble/bluetooth/repository/bluetooth_repository.dart';
import 'package:adhawk_ble/bluetooth/service/scan_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements BluetoothRepository {}

void main() {
  group('ScanBlock', () {
    late MockRepository mockRepo;
    late ScanBloc scanBloc;

    setUp(() {
      mockRepo = MockRepository();
      scanBloc = ScanBloc(deviceRepo: mockRepo);
      when(() => mockRepo.stopScan()).thenAnswer((_) async {});
    });

    test('Verify initial ScanState', () {
      expect(scanBloc.state.status, ScanStatus.stopped);
      expect(scanBloc.state.devices, isEmpty);
    });

    blocTest(
      'Initiates a scan in reponse to [ScanStarted] event',
      build: () => scanBloc,
      setUp: () {
        when(() => mockRepo.startScan()).thenAnswer((_) => Stream.value([]));
      },
      act: (bloc) => bloc.add(ScanStarted()),
      verify: (_) {
        verify(() => mockRepo.startScan()).called(1);
      },
    );

    blocTest(
      'Stops a scan in reponse to [ScanStopped] event',
      build: () => scanBloc,
      seed: () => const ScanState(status: ScanStatus.scanning),
      act: (bloc) => bloc.add(ScanStopped()),
      verify: (_) {
        verify(() => mockRepo.stopScan()).called(1);
      },
    );

    blocTest(
      'Scan is stopped when the bloc is disposed',
      build: () => scanBloc,
      seed: () => const ScanState(status: ScanStatus.scanning),
      verify: (_) {
        verify(() => mockRepo.stopScan()).called(1);
      },
    );
  });
}
