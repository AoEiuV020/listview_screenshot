import 'dart:typed_data';

import 'package:image/image.dart';

enum ScreenshotFormat {
  png,
  jpg,
  rgba,
}

class ScreenshotEncoder {
  final ScreenshotFormat format;
  final int? quality;

  ScreenshotEncoder(this.format, {this.quality});

  Uint8List encode(Image image) {
    switch (format) {
      case ScreenshotFormat.png:
        return encodePng(image);
      case ScreenshotFormat.jpg:
        return encodeJpg(image, quality: quality ?? 90);
      case ScreenshotFormat.rgba:
        assert(image.numChannels == 4);
        // 这里没有深拷贝，
        return image.buffer.asUint8List();
    }
  }

  factory ScreenshotEncoder.fromMap(Map map) => ScreenshotEncoder(
        ScreenshotFormat.values[map['format']],
        quality: map['quality'],
      );

  Map toMap() => {
        'type': 'ScreenshotEncoder',
        'format': format.index,
        'quality': quality,
      };

  static bool isValidMap(Map map) => map['type'] == 'ScreenshotEncoder';
}
