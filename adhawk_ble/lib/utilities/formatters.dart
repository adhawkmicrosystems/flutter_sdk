import 'dart:math';
import 'dart:typed_data';

String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes <= 0) {
    return '0 B';
  }
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
  final idx = (log(bytes) / log(1000)).floor();
  final value = bytes / pow(1000, idx).floor();
  return '${value.toStringAsFixed(decimals)} ${suffixes[idx]}';
}

extension TypedDataPrettyPrintExtension on TypedData {
  String toHexString() {
    final value = buffer
        .asUint8List()
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();
    return '0x$value';
  }
}
