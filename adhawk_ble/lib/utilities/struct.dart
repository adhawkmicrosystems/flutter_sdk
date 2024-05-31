import 'dart:typed_data';
import 'package:collection/collection.dart';

/// Enum encapsulating the available struct formats
enum FormatType {
  sCharFmt(format: 'b', size: 1),
  uCharFmt(format: 'B', size: 1),
  stringFmt(format: 's', size: 1),
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

  const FormatType({required this.format, required this.size});

  factory FormatType.fromFormat(String format) {
    return values.firstWhere(
      (element) => format == element.format,
      orElse: () => throw ArgumentError('No matching struct format: $format'),
    );
  }

  /// The standard size of the binary data
  final int size;

  /// The format string
  final String format;
}

abstract class Formatter {
  /// The factory constructor creates specializations of the formatter
  factory Formatter(String format, int count, Endian endian) {
    final formatType = FormatType.fromFormat(format);
    switch (formatType) {
      case FormatType.stringFmt:
        return StringFormatter(
          formatType: formatType,
          count: count,
          endian: endian,
        );
      // ignore: no_default_cases
      default:
        return DefaultFormatter(
          formatType: formatType,
          endian: endian,
        );
    }
  }

  Formatter._({
    required this.formatType,
    required this.count,
    required this.endian,
  });

  /// The format type
  final FormatType formatType;

  /// The number of repetitions
  final int count;

  /// Endianness
  final Endian endian;

  /// The size of the binary data
  int get size => formatType.size * count;

  /// Write the data
  void write(ByteData data, int byteOffset, Object value);

  /// Read the data
  Object read(ByteData data, int byteOffset);
}

class DefaultFormatter extends Formatter {
  DefaultFormatter({
    required super.formatType,
    required super.endian,
  }) : super._(count: 1);

  @override
  void write(ByteData data, int byteOffset, Object value) {
    switch (formatType) {
      case FormatType.stringFmt:
        throw TypeError();
      case FormatType.sCharFmt:
        data.setInt8(byteOffset, value as int);
      case FormatType.uCharFmt:
        data.setUint8(byteOffset, value as int);
      case FormatType.boolFmt:
        data.setUint8(byteOffset, value as bool ? 1 : 0);
      case FormatType.shortFmt:
        data.setInt16(byteOffset, value as int, endian);
      case FormatType.uShortFmt:
        data.setUint16(byteOffset, value as int, endian);
      case FormatType.intFmt:
      case FormatType.longFmt:
        data.setInt32(byteOffset, value as int, endian);
      case FormatType.uintFmt:
      case FormatType.uLongFmt:
        data.setUint32(byteOffset, value as int, endian);
      case FormatType.longLongFmt:
        data.setInt64(byteOffset, value as int, endian);
      case FormatType.uLongLongFmt:
        data.setUint64(byteOffset, value as int, endian);
      case FormatType.floatFmt:
        data.setFloat32(byteOffset, value as double, endian);
      case FormatType.doubleFmt:
        data.setFloat64(byteOffset, value as double, endian);
    }
  }

  @override
  Object read(ByteData data, int byteOffset) {
    switch (formatType) {
      case FormatType.stringFmt:
        throw TypeError();
      case FormatType.sCharFmt:
        return data.getInt8(byteOffset);
      case FormatType.uCharFmt:
        return data.getUint8(byteOffset);
      case FormatType.boolFmt:
        return data.getUint8(byteOffset) != 0;
      case FormatType.shortFmt:
        return data.getInt16(byteOffset, endian);
      case FormatType.uShortFmt:
        return data.getUint16(byteOffset, endian);
      case FormatType.intFmt:
      case FormatType.longFmt:
        return data.getInt32(byteOffset, endian);
      case FormatType.uintFmt:
      case FormatType.uLongFmt:
        return data.getUint32(byteOffset, endian);
      case FormatType.longLongFmt:
        return data.getInt64(byteOffset, endian);
      case FormatType.uLongLongFmt:
        return data.getUint64(byteOffset, endian);
      case FormatType.floatFmt:
        return data.getFloat32(byteOffset, endian);
      case FormatType.doubleFmt:
        return data.getFloat64(byteOffset, endian);
    }
  }
}

/// For the 's' format character, the count is interpreted as the length of the bytes,
/// not a repeat count like for the other format characters;
/// Example, '10s' means a single 10-byte string mapping to or from a single dart string
class StringFormatter extends Formatter {
  StringFormatter({
    required super.formatType,
    required super.count,
    required super.endian,
  }) : super._();

  @override
  void write(ByteData data, int byteOffset, Object value) {
    assert(formatType == FormatType.stringFmt, 'Invalid formatType');
    final encoded = value as Uint8List;
    var offset = byteOffset;
    // pad with null
    for (var i = 0; i < count; ++i) {
      final e = i < encoded.length ? encoded[i] : 0;
      data.setUint8(offset, e);
      offset += formatType.size;
    }
  }

  @override
  Object read(ByteData data, int byteOffset) {
    assert(formatType == FormatType.stringFmt, 'Invalid formatType');
    return Uint8List.fromList(data.buffer
        .asUint8List(byteOffset, size)
        .takeWhile((value) => value != 0)
        .toList());
  }
}

class Struct {
  factory Struct(String format) {
    final formatList = _parseFormat(format);
    final size =
        formatList.fold<int>(0, (size, element) => size + element.size);
    return Struct._(format, formatList, size);
  }
  Struct._(this.format, this.formatters, this.size);

  /// The format string provided to the constructor
  final String format;

  /// The formatter functions used to pack/unpack each value in the struct
  final List<Formatter> formatters;

  /// The standard size of the binary data
  final int size;

  /// The regexp used to capture the [format]
  static const formatRe = r'(?<count>\d*)?(?<format>[bBs?hHiIlLqQfd])';

  /// Returns bytes as [Uint8List] containing the [values] packed according to the [format]
  /// The arguments must match the values required by the format exactly
  Uint8List pack(List<Object> values) {
    if (values.length != formatters.length) {
      throw FormatException(
          'Pack expects ${formatters.length} items. Got ${values.length}.'
          " The format string is '$format'");
    }
    final data = ByteData(size);
    IterableZip([formatters, values]).fold<int>(0, (byteOffset, element) {
      final formatter = element[0] as Formatter;
      final value = element[1];
      try {
        formatter.write(data, byteOffset, value);
        // ignore: avoid_catching_errors
      } on TypeError {
        throw FormatException(
            'Unable to pack $value of type ${value.runtimeType}'
            " using '${formatter.formatType.format}'");
      }
      return byteOffset + formatter.size;
    });
    return data.buffer.asUint8List();
  }

  /// Unpacks the [Uint8List] bytes according to the [format]
  List<Object> unpack(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final values = <Object>[];
    var byteOffset = 0;
    if (size != data.lengthInBytes) {
      throw FormatException('Unpack expects a buffer of $size bytes.'
          ' Got ${data.lengthInBytes} bytes.');
    }
    for (final formatter in formatters) {
      values.add(formatter.read(data, byteOffset));
      byteOffset += formatter.size;
    }
    return values;
  }

  /// Unpacks the [Uint8List] bytes according to the [format]
  List<Object> unpackFrom(Uint8List bytes, [int offset = 0]) {
    final data = ByteData.sublistView(bytes, offset);
    if (size > data.lengthInBytes) {
      throw FormatException('Unpack expects a buffer of at least $size bytes.'
          ' Got ${data.lengthInBytes} bytes.');
    }
    final values = <Object>[];
    var byteOffset = 0;
    for (final formatter in formatters) {
      values.add(formatter.read(data, byteOffset));
      byteOffset += formatter.size;
    }
    return values;
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
        throw ArgumentError('$format is missing a valid endian format');
    }
  }

  /// Parses the [format] and returns an ordered list of [Formatter]s that can
  /// be used to pack or unpack values passed in
  /// Throws [FormatException] if [format] is invalid or unsupported
  static List<Formatter> _parseFormat(String format) {
    final endian = _parseEndian(format);
    final matches = RegExp(formatRe).allMatches(format);
    if (matches.isEmpty) {
      throw ArgumentError('Unsupported struct format: $format');
    }
    final formatters = <Formatter>[];
    for (final match in matches) {
      final formatStr = match.namedGroup('format')!;
      final count = int.parse(match.namedGroup('count') ?? '1');
      final formatter = Formatter(formatStr, count, endian);
      for (var c = formatter.count; c <= count; c++) {
        formatters.add(formatter);
      }
    }
    return formatters;
  }
}
