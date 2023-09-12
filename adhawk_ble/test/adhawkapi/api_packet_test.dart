import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:adhawk_ble/adhawkapi/repository/api_packet.dart';

void main() {
  group('Packet', () {
    test('Parse an eyetracking packet with pupil diameter', () {
      var bytes = Uint8List.fromList([
        244,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        36,
        2,
        143,
        194,
        245,
        60,
        123,
        20,
        174,
        190,
        215,
        163,
        112,
        191,
        184,
        30,
        5,
        62,
        92,
        143,
        194,
        190,
        195,
        245,
        104,
        191,
        5,
        215,
        163,
        96,
        64,
        51,
        51,
        99,
        64
      ]);
      var etData = EyeTrackingPacket.decode(bytes);
      expect(etData.pupilDiameter.left, closeTo(3.5, 0.5));
      expect(etData.pupilDiameter.right, closeTo(3.5, 0.5));
    });
  });
}
