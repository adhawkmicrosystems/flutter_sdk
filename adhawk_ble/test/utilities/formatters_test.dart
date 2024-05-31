import 'package:flutter_test/flutter_test.dart';

import 'package:adhawk_ble/utilities/formatters.dart';

void main() {
  group('Utilities formatBytes', () {
    test('formatBytes B', () {
      expect(formatBytes(1200), '1.2 KB');
    });
    test('formatBytes MB', () {
      expect(formatBytes(1200000), '1.2 MB');
    });
    test('formatBytes GB', () {
      expect(formatBytes(1200000000), '1.2 GB');
    });
  });
}
