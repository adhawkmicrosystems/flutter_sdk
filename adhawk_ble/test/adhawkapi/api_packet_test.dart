import 'dart:typed_data';

import 'package:adhawk_ble/adhawkapi/repository/api_packet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Packet', () {
    test('Parse an eyetracking packet with pupil diameter', () {
      final bytes = Uint8List.fromList([
        16,
        49,
        42,
        184,
        129,
        0,
        0,
        0,
        3,
        1,
        132,
        229,
        177,
        186,
        250,
        201,
        108,
        189,
        127,
        45,
        166,
        191,
        252,
        249,
        49,
        61,
        3,
        12,
        204,
        239,
        65,
        105,
        79,
        46,
        65,
        13,
        245,
        246,
        65,
        60,
        105,
        222,
        193,
        237,
        148,
        69,
        65,
        69,
        38,
        223,
        65,
        5,
        157,
        114,
        11,
        64,
        186,
        13,
        12,
        64,
        8,
        100,
        75,
        76,
        62,
        48,
        249,
        37,
        63,
        185,
        25,
        98,
        62,
        99,
        114,
        51,
        191
      ]);
      final etData = EyeTrackingPacket.decode(bytes);
      expect(etData.pupilDiameter.left, inInclusiveRange(2, 6));
      expect(etData.pupilDiameter.right, inInclusiveRange(2, 6));
    });

    test('Handle monocular eye tracking packets', () {
      final bytes = Uint8List.fromList([
        48,
        50,
        78,
        202,
        91,
        1,
        0,
        0,
        1,
        1,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        0,
        0,
        192,
        127,
        3,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        5,
        255,
        255,
        255,
        255,
        8,
        177,
        252,
        168,
        189,
        146,
        212,
        33,
        63,
        62,
        131,
        11,
        62,
        84,
        42,
        66,
        63
      ]);
      expect(() => EyeTrackingPacket.decode(bytes), throwsFormatException);
    });
  });
}
