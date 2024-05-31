import 'dart:convert';
import 'dart:typed_data';

import 'package:adhawk_ble/utilities/formatters.dart';
import 'package:adhawk_ble/utilities/struct.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Struct', () {
    void runner(String format, List<Object> values, String hexString) {
      final struct = Struct(format);
      final bytes = struct.pack(values);
      expect(bytes.toHexString(), hexString);
      expect(struct.unpack(bytes), values);
    }

    test('Test the signed char format', () {
      runner('<b', [127], '0x7f');
    });
    test('Test the unsigned char format', () {
      runner('<B', [255], '0xff');
    });
    test('Te(st the bool format', () {
      runner('<??', [true, false], '0x0100');
    });
    test('Test the short format', () {
      runner('<h', [-10], '0xf6ff');
    });
    test('Test the unsigned short format', () {
      runner('<H', [10], '0x0a00');
    });
    test('Test the int format', () {
      runner('<i', [-10], '0xf6ffffff');
    });
    test('Test the unsigned int format', () {
      runner('<I', [10], '0x0a000000');
    });
    test('Test the long format', () {
      runner('<l', [-10], '0xf6ffffff');
    });
    test('Test the unsigned long format', () {
      runner('<L', [10], '0x0a000000');
    });

    test('Test the string format', () {
      runner('<5s', [const Utf8Codec().encode('abc')], '0x6162630000');
    });

    test('Test string format - pad with null', () {
      const codec = Utf8Codec();
      final struct = Struct('<4s');
      final bytes = struct.pack([codec.encode('az')]);
      expect(bytes.length, 4);
      expect(bytes, [0x61, 0x7a, 0x00, 0x00]);
      expect(codec.decode(struct.unpack(bytes)[0] as Uint8List), 'az');
    });

    test('Test string format - truncate', () {
      const codec = Utf8Codec();
      final struct = Struct('<s');
      final bytes = struct.pack([codec.encode('az')]);
      expect(bytes.length, 1);
      expect(bytes, [0x61]);
      expect(codec.decode(struct.unpack(bytes)[0] as Uint8List), 'a');
    });

    test('Test the long long format', () {
      runner('<q', [-10], '0xf6ffffffffffffff');
    });
    test('Test the unsigned long long format', () {
      runner('<Q', [10], '0x0a00000000000000');
    });

    test('Test the float format', () {
      runner('<f', [1.5], '0x0000c03f');
    });

    test('Test the double format', () {
      runner('<d', [1.5], '0x000000000000f83f');
    });

    test('Test mixed formats', () {
      runner('<hfd3s', [0x90, 1.5, 134.3, const Utf8Codec().encode('abc')],
          '0x90000000c03f9a99999999c96040616263');
    });

    test('Test repeat counts', () {
      runner('<2h2d', [0x90, 0xa, 1.3, 1.2],
          '0x90000a00cdccccccccccf43f333333333333f33f');
    });

    test('Test double digit repeat counts', () {
      runner('<10B', [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], '0x0102030405060708090a');
    });

    test('Test invalid format strings (Missing endian)', () {
      expect(() => Struct('df'), throwsArgumentError);
    });

    test('Test invalid format strings (Invalid formatter)', () {
      expect(() => Struct('<3A'), throwsArgumentError);
    });

    test('Test mismatched type when packing', () {
      expect(() => Struct('<B').pack(['255']), throwsFormatException);
    });

    test('Test mismatched type when unpacking', () {
      final bytes = Struct('<d').pack([1.5]);
      expect(() => Struct('<B').unpack(bytes), throwsFormatException);
    });

    test('Test too many values when packing', () {
      expect(() => Struct('<f').pack([20, 300]), throwsFormatException);
    });

    test('Test too many values when unpacking', () {
      expect(() => Struct('<B').unpack(Uint8List.fromList([1, 2])),
          throwsFormatException);
    });

    test('Test too few values when packing', () {
      expect(() => Struct('<ff').pack([20]), throwsFormatException);
    });

    test('Test too few values when unpacking', () {
      expect(() => Struct('<ff').unpack(Uint8List.fromList([1])),
          throwsFormatException);
    });

    test('Test zero repeat count)', () {
      /// Mimic the behavior in python's struct
      expect(() => Struct('<0B').pack([1]), throwsFormatException);
    });
  });
}
