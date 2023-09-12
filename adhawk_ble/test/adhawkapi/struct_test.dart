import 'package:flutter_test/flutter_test.dart';

import 'package:adhawk_ble/adhawkapi/repository/struct.dart';

void main() {
  group('Struct', () {
    runner(String format, List<Object> values, String hexString) {
      var struct = Struct(format);
      var bytes = struct.pack(values);
      expect(Struct.toHexString(bytes), hexString);
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
      runner('<hfd', [0x90, 1.5, 134.3], r'0x90000000c03f9a99999999c96040');
    });

    test('Test repeat counts', () {
      runner('<2h2d', [0x90, 0xa, 1.3, 1.2],
          r'0x90000a00cdccccccccccf43f333333333333f33f');
    });

    test('Test double digit repeat counts', () {
      runner(
          '<10B', [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], r'0x0102030405060708090a');
    });

    test('Test invalid format strings (Missing endian)', () {
      expect(() => Struct('df'), throwsFormatException);
    });

    test('Test invalid format strings (Invalid formatter)', () {
      expect(() => Struct('<3A'), throwsFormatException);
    });

    test('Test mismatched type when packing', () {
      expect(() => Struct('<B').pack(['255']), throwsFormatException);
    });

    test('Test mismatched type when unpacking', () {
      var bytes = Struct('<d').pack([1.5]);
      expect(() => Struct('<B').unpack(bytes), throwsFormatException);
    });

    test('Test zero repeat count)', () {
      /// Mimic the behavior in python's struct
      expect(() => Struct('<0B').pack([1]), throwsFormatException);
    });
  });
}
