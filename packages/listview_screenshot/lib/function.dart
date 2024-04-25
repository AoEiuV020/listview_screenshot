import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart';

@pragma('vm:entry-point')
Stream<Map<String, dynamic>> imageMergeTransform(
    Stream<Map<String, dynamic>> inputStream) async* {
  Image? image;
  await for (var map in inputStream) {
    final int dx = map['dx'];
    final int dy = map['dy'];
    final int? color = map['color'];
    final Color? backgroundColor;
    if (color != null) {
      final argb = (ByteData(4)..setUint32(0, color)).buffer.asUint8List();
      backgroundColor = ColorUint8.rgba(argb[1], argb[2], argb[3], argb[0]);
    } else {
      backgroundColor = null;
    }
    final png = map['png'];
    final currentImage = decodePng(png)!;
    assert(() {
      log('input: ${currentImage.width}, ${currentImage.height}');
      return true;
    }());
    if (image == null) {
      image = currentImage;
    } else {
      final right = dx + currentImage.width;
      final bottom = dy + currentImage.height;
      final oldImage = image;
      image = Image.fromResized(oldImage,
          width: math.max(right, oldImage.width),
          height: math.max(bottom, oldImage.height));
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (y >= dy && y < bottom && x >= dx && x < right) {
            image.setPixel(
                x,
                y,
                blendColors(
                    backgroundColor, currentImage.getPixel(x - dx, y - dy)));
          } else if (y < oldImage.height && x < oldImage.width) {
            image.setPixel(
                x, y, blendColors(backgroundColor, oldImage.getPixel(x, y)));
          }
        }
      }
    }
  }
  final result = image ?? Image.empty();
  assert(() {
    log('output: ${result.width}, ${result.height}');
    return true;
  }());
  yield result.toMap();
}

Color blendColors(Color? backgroundColor, Color foregroundColor) {
  if (backgroundColor == null) {
    return foregroundColor;
  }
  double alpha = foregroundColor.a / 255.0;
  double oneMinusAlpha = 1.0 - alpha;

  int resultRed =
      ((oneMinusAlpha * backgroundColor.r) + (alpha * foregroundColor.r))
          .round();
  int resultGreen =
      ((oneMinusAlpha * backgroundColor.g) + (alpha * foregroundColor.g))
          .round();
  int resultBlue =
      ((oneMinusAlpha * backgroundColor.b) + (alpha * foregroundColor.b))
          .round();

  return ColorRgba8(resultRed, resultGreen, resultBlue, 255);
}

extension ImageExtension on Image {
  static Image fromMap(Map<String, dynamic> map) {
    final width = map['width'];
    final height = map['height'];
    final buffer = map['buffer'];
    return Image.fromBytes(
        width: width, height: height, bytes: buffer, numChannels: 4);
  }

  Map<String, dynamic> toMap() => {
        'width': width,
        'height': height,
        'buffer': buffer,
      };
}
