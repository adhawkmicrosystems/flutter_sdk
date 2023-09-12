import 'dart:math';
import 'dart:typed_data';

import 'api_packet.dart';
import 'struct.dart';

bool usePrefixPackets = false;

/// The request, response and stream packets may be prefixed with the following:
/// <uint8_t SOP> <uint16_t header>
/// The prefix can be used to allow multiple packets per BLE transmission
/// It is controlled by [usePrefixPackets]. It can be enabled/disabled until
/// we understand performance implications
class PacketPrefix {
  PacketPrefix(this.payloadLength, this.isStream);

  factory PacketPrefix.fromBytes(Uint8List bytes) {
    var unpacked = _headerStruct.unpackFrom(bytes);
    var sop = unpacked[0] as int;
    var header = unpacked[1] as int;
    if (sop != _sop) {
      throw FormatException('Invalid packet received: incorrect SOP: $sop');
    }
    int length = header & _lengthMask;
    int isStream = header & (1 << _streamBitOffset);
    return PacketPrefix(
      length,
      isStream == 0 ? false : true,
    );
  }

  /// Total size of the prefix
  static int get size => _headerStruct.size;

  /// length of payload
  final int payloadLength;

  /// Whether the packet is a stream or a request/response packet
  final bool isStream;

  /// Wraps the payload and encodes the packet
  Uint8List encode() {
    int header = 0;
    header |= (isStream ? 1 : 0) << _streamBitOffset;
    header |= payloadLength;
    return _headerStruct.pack([_sop, header]);
  }

  /// Packet header format
  static final _headerStruct = Struct('<HB');

  /// Mask used to determine the value of the stream bit
  static const _streamBitOffset = 15;

  /// Mask used to read the payload length
  static const _lengthMask = 0x03FF;

  /// Expected start of packet (used to catch synchronization errors)
  static const _sop = 0xAA;
}

/// Request packet format:
/// | PrefixPacket | <uint16_t request id> <uint8_t packet type> | <optional payload> |
class RequestPacket {
  RequestPacket(this.packetType, [this.payloadFormat, this.payload])
      : requestId = Random().nextInt(0xffff);

  /// 16 bit Request Id
  final int requestId;

  /// 8 bit packet type
  final PacketType packetType;

  /// payload
  final List<Object>? payload;

  /// payload format
  final String? payloadFormat;

  /// Encode the request packet
  Uint8List encode() {
    var payloadStruct = payloadFormat != null ? Struct(payloadFormat!) : null;
    var packetLength = _headerStruct.size + (payloadStruct?.size ?? 0);

    var header = _headerStruct.pack([requestId, packetType.value]);

    var builder = BytesBuilder();
    if (usePrefixPackets) {
      builder.add(PacketPrefix(packetLength, false).encode());
    }

    builder.add(header);
    if (payloadStruct != null && payload != null) {
      var payloadBytes = payloadStruct.pack(payload!);
      builder.add(payloadBytes);
    }
    return builder.toBytes();
  }

  @override
  String toString() {
    return 'ReqID=$requestId $packetType ${payload ?? ""}';
  }

  /// Packet header format
  static final _headerStruct = Struct('<HB');
}

/// Response packet format:
/// | PrefixPacket | <uint16_t request id> <uint8_t packet type> <uint8_t response code> | <optional data> |
class ResponsePacket {
  ResponsePacket._(this.requestId, this.packetType, this.ackCode, this.payload);

  factory ResponsePacket.fromBytes(Uint8List bytes) {
    PacketPrefix? prefix;
    if (usePrefixPackets) {
      prefix = PacketPrefix.fromBytes(bytes);
      bytes = Uint8List.sublistView(
        bytes,
        PacketPrefix.size,
        prefix.payloadLength,
      );
    }
    var unpacked = _headerStruct.unpackFrom(bytes);
    var requestId = unpacked[0] as int;
    var packetType = PacketType.from(unpacked[1] as int);
    var ackCode = AckCode.from(unpacked[2] as int);
    return ResponsePacket._(
      requestId,
      packetType,
      ackCode,
      Uint8List.sublistView(
        bytes,
        _headerStruct.size,
        usePrefixPackets ? _headerStruct.size + prefix!.payloadLength : null,
      ),
    );
  }

  /// 16 bit Request Id
  final int requestId;

  /// Packet type
  final PacketType packetType;

  /// 8 bit response code
  final AckCode ackCode;

  /// payload as bytes for client to decode further
  final Uint8List payload;

  @override
  String toString() {
    return 'ReqID=$requestId $packetType ${Struct.toHexString(payload)}';
  }

  /// Header format
  static final _headerStruct = Struct('<HBB');
}

/// Stream packet format:
/// | PrefixPacket | <uint8_t packet type> | <data> |
class StreamPacket {
  StreamPacket._(this.packetType, this.payload, this.length);

  factory StreamPacket.fromBytes(Uint8List bytes) {
    PacketPrefix? prefix;
    if (usePrefixPackets) {
      prefix = PacketPrefix.fromBytes(bytes);
      bytes = Uint8List.sublistView(
        bytes,
        PacketPrefix.size,
        prefix.payloadLength,
      );
    }
    var unpacked = _headerStruct.unpackFrom(bytes);
    var packetType = PacketType.from(unpacked[0] as int);
    return StreamPacket._(
      packetType,
      Uint8List.sublistView(
        bytes,
        _headerStruct.size,
        usePrefixPackets ? _headerStruct.size + prefix!.payloadLength : null,
      ),
      usePrefixPackets
          ? PacketPrefix.size + prefix!.payloadLength
          : bytes.length,
    );
  }

  /// 8 bit packet type
  final PacketType packetType;

  /// payload
  final Uint8List payload;

  /// length of the packet
  final int length;

  @override
  String toString() {
    return '$packetType: ${Struct.toHexString(payload)}';
  }

  /// Header format
  static final _headerStruct = Struct('<B');
}
