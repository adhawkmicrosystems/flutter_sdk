import 'dart:typed_data';
import 'package:collection/collection.dart';

/// Enum encapsulating the available struct formats
enum Formatter {
  sCharFmt(format: 'b', size: 1),
  uCharFmt(format: 'B', size: 1),
  boolFmt(format: '?', size: 1),
  shortFmt(format: 'h', size: 2),
  uShortFmt(format: 'H', size: 2),
  intFmt(format: 'i', size: 4),
  uintFmt(format: 'I', size: 4),
  longFmt(format: 'l', size: 4),
  uLongFmt(format: 'L', size: 4),
  longLongFmt(format: 'q', size: 8),
  uLongLongFmt(format: 'Q', size: 8),
  floatFmt(format: 'f', size: 4),
  doubleFmt(format: 'd', size: 8),
  ;

  const Formatter({required this.format, required this.size});

  factory Formatter.fromFormat(String format) {
    return values.firstWhere((element) => format == element.format);
  }

  void write(ByteData data, int byteOffset, Object value, Endian endian) {
    switch (this) {
      case sCharFmt:
        data.setInt8(byteOffset, value as int);
        break;
      case uCharFmt:
        data.setUint8(byteOffset, value as int);
        break;
      case boolFmt:
        data.setUint8(byteOffset, value as bool ? 1 : 0);
        break;
      case shortFmt:
        data.setInt16(byteOffset, value as int, endian);
        break;
      case uShortFmt:
        data.setUint16(byteOffset, value as int, endian);
        break;
      case intFmt:
      case longFmt:
        data.setInt32(byteOffset, value as int, endian);
        break;
      case uintFmt:
      case uLongFmt:
        data.setUint32(byteOffset, value as int, endian);
        break;
      case longLongFmt:
        data.setInt64(byteOffset, value as int, endian);
        break;
      case uLongLongFmt:
        data.setUint64(byteOffset, value as int, endian);
        break;
      case floatFmt:
        data.setFloat32(byteOffset, value as double, endian);
        break;
      case doubleFmt:
        data.setFloat64(byteOffset, value as double, endian);
        break;
    }
  }

  Object read(ByteData data, int byteOffset, Endian endian) {
    switch (this) {
      case sCharFmt:
        return data.getInt8(byteOffset);
      case uCharFmt:
        return data.getUint8(byteOffset);
      case boolFmt:
        return data.getUint8(byteOffset) == 0 ? false : true;
      case shortFmt:
        return data.getInt16(byteOffset, endian);
      case uShortFmt:
        return data.getUint16(byteOffset, endian);
      case intFmt:
      case longFmt:
        return data.getInt32(byteOffset, endian);
      case uintFmt:
      case uLongFmt:
        return data.getUint32(byteOffset, endian);
      case longLongFmt:
        return data.getInt64(byteOffset, endian);
      case uLongLongFmt:
        return data.getUint64(byteOffset, endian);
      case floatFmt:
        return data.getFloat32(byteOffset, endian);
      case doubleFmt:
        return data.getFloat64(byteOffset, endian);
    }
  }

  /// The standard size of the binary data
  final int size;

  /// The format string
  final String format;
}

class Struct {
  Struct._(this.format, this.endian, this.formatters, this.size);

  factory Struct(String format) {
    final endian = _parseEndian(format);
    final formatList = _parseFormat(format);
    final size =
        formatList.fold<int>(0, (size, element) => size + element.size);
    return Struct._(format, endian, formatList, size);
  }

  /// The format string provided to the constructor
  final String format;

  /// The endian specified by the format string
  final Endian endian;

  /// The formatter functions used to pack/unpack each value in the struct
  final List<Formatter> formatters;

  /// The standard size of the binary data
  final int size;

  /// The regexp used to capture the [format]
  static const formatRe = r'(?<count>\d*)?(?<format>[bB?hHiIlLqQfd])';

  /// Returns bytes as [Uint8List] containing the [values] packed according to the [format]
  /// The arguments must match the values required by the format exactly
  Uint8List pack(List<Object> values) {
    if (values.length != formatters.length) {
      throw FormatException(
          "Pack expects ${formatters.length} items. Got ${values.length}."
          " The format string is '$format'");
    }
    ByteData data = ByteData(size);
    IterableZip([formatters, values]).fold<int>(0, (byteOffset, element) {
      final formatter = element[0] as Formatter;
      final value = element[1];
      try {
        formatter.write(data, byteOffset, value, endian);
      } catch (e) {
        throw FormatException(
            "Unable to pack $value of type ${value.runtimeType}"
            " using '${formatter.format}'");
      }
      return byteOffset + formatter.size;
    });
    return data.buffer.asUint8List();
  }

  /// Unpacks the [Uint8List] bytes according to the [format]
  List<Object> unpack(Uint8List bytes) {
    var data = ByteData.sublistView(bytes);
    List<Object> values = [];
    int byteOffset = 0;
    if (size != data.lengthInBytes) {
      throw FormatException('Unpack expects a buffer of $size bytes.'
          ' Got ${data.lengthInBytes} bytes.');
    }
    for (final formatter in formatters) {
      values.add(formatter.read(data, byteOffset, endian));
      byteOffset += formatter.size;
    }
    return values;
  }

  /// Unpacks the [Uint8List] bytes according to the [format]
  List<Object> unpackFrom(Uint8List bytes, [int offset = 0]) {
    var data = ByteData.sublistView(bytes, offset);
    if (size > data.lengthInBytes) {
      throw FormatException('Unpack expects a buffer of at least $size bytes.'
          ' Got ${data.lengthInBytes} bytes.');
    }
    List<Object> values = [];
    int byteOffset = 0;
    for (final formatter in formatters) {
      values.add(formatter.read(data, byteOffset, endian));
      byteOffset += formatter.size;
    }
    return values;
  }

  /// Helper function to convert the [TypedData] to a hex string for readability
  static toHexString(TypedData data) {
    String value = data.buffer
        .asUint8List()
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();
    return '0x$value';
  }

  /// Parses the first element in the format string to determine the [Endian]
  static Endian _parseEndian(String format) {
    switch (format[0]) {
      case '<':
        return Endian.little;
      case '>':
      case '!':
        return Endian.big;
      case '@':
      case '=':
        return Endian.host;
      default:
        throw FormatException('$format is missing a valid endian format');
    }
  }

  /// Parses the [format] and returns an ordered list of [Formatter]s that can
  /// be used to pack or unpack values passed in
  /// Throws [FormatException] if [format] is invalid or unsupported
  static List<Formatter> _parseFormat(String format) {
    final matches = RegExp(formatRe).allMatches(format);
    if (matches.isEmpty) {
      throw FormatException('Unsupported struct format: $format');
    }
    List<Formatter> formatters = [];
    for (final match in matches) {
      final formatter = Formatter.fromFormat(match.namedGroup('format')!);
      final count = int.parse(match.namedGroup('count') ?? '1');
      for (int c = 0; c < count; c++) {
        formatters.add(formatter);
      }
    }
    return formatters;
  }
}
