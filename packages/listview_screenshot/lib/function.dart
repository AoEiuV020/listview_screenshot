import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart';

@pragma('vm:entry-point')
Stream<dynamic> imageMergeTransform(Stream<Map> inputStream) async* {
  var index = 0;
  final List<(Image, int, int, Color?)> list = [];
  var maxWidth = 0;
  var maxHeight = 0;
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
    for (var y = 0; y < currentImage.height; y++) {
      for (var x = 0; x < currentImage.width; x++) {
        final newPixel =
            blendColors(backgroundColor, currentImage.getPixel(x, y));
        currentImage.setPixel(x, y, newPixel);
      }
    }
    list.add((currentImage, dx, dy, backgroundColor));
    final right = dx + currentImage.width;
    final bottom = dy + currentImage.height;
    if (right > maxWidth) {
      maxWidth = right;
    }
    if (bottom > maxHeight) {
      maxHeight = bottom;
    }
    yield index++;
    assert(() {
      log('input: ${currentImage.width}, ${currentImage.height}');
      return true;
    }());
  }
  Image? image;
  for (var param in list) {
    final (currentImage, dx, dy, backgroundColor) = param;
    image ??=
        Image.fromResized(currentImage, width: maxWidth, height: maxHeight);
    final right = dx + currentImage.width;
    final bottom = dy + currentImage.height;
    final oldImage = image;
    for (var y = dy; y < bottom; y++) {
      for (var x = dx; x < right; x++) {
        if (y >= dy && y < bottom && x >= dx && x < right) {
          image.setPixel(x, y, currentImage.getPixel(x - dx, y - dy));
        } else if (y < oldImage.height && x < oldImage.width) {
          image.setPixel(x, y, oldImage.getPixel(x, y));
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
  static Image fromMap(Map<dynamic, dynamic> map) {
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

/// 封装image库中的Image， 区别于flutter库中的Image,
class ImageImageParam {
  final Image image;
  final int dx;
  final int dy;
  final Color? color;

  ImageImageParam({
    required this.image,
    required this.dx,
    required this.dy,
    required this.color,
  });

  factory ImageImageParam.fromMap(Map map) {
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
    return ImageImageParam(
        image: currentImage, dx: dx, dy: dy, color: backgroundColor);
  }
}
