import 'dart:typed_data';

import 'package:adhawk_ble/adhawkapi/repository/api_packet.dart';
import 'package:adhawk_ble/adhawkapi/repository/packet.dart';
import 'package:adhawk_ble/utilities/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Packet', () {
    test('Create a request packet with no payload', () {
      final packet = RequestPacket(PacketType.trackerState);
      final bytes = packet.encode();
      final hexString = bytes.toHexString();
      final re = RegExp('[a-z0-9]{4}(90)');
      expect(re.hasMatch(hexString), true);
    });

    test('Create a request packet with payload', () {
      final packet = RequestPacket(PacketType.trackerState, '<3B', [
        PacketType.systemControl.value,
        SystemControlTypes.tracking.value,
        1,
      ]);
      final bytes = packet.encode();
      final hexString = bytes.toHexString();
      final re = RegExp('[a-z0-9]{4}9c0101');
      expect(re.hasMatch(hexString), true);
    });

    test('Parse a response packet', () {
      final bytes = Uint8List.fromList([0x0d, 0x00, 0x90, 0x0d]);
      final packet = ResponsePacket.fromBytes(bytes);
      expect(packet.requestId, 0xd);
      expect(packet.packetType, PacketType.trackerState);
      expect(packet.ackCode, AckCode.hardwareFault);
    });

    test('Parse a stream packet', () {
      final bytes = Uint8List.fromList([
        1,
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
      final packet = StreamPacket.fromBytes(bytes);
      expect(packet.packetType, PacketType.eyetrackingStream);
      expect(packet.payload, bytes.sublist(1));
    });
  });
}
