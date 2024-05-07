import 'dart:developer';
import 'dart:typed_data';

import 'package:image/image.dart';
import 'package:listview_screenshot/screenshot_format.dart';

@pragma('vm:entry-point')
Stream<dynamic> imageMergeTransform(Stream<Map> inputStream) async* {
  var index = 0;
  final List<(Image, int, int)> list = [];
  var maxWidth = 0;
  var maxHeight = 0;
  ScreenshotEncoder? encoder;
  int startTime = DateTime.now().millisecondsSinceEpoch;
  await for (var map in inputStream) {
    if (ScreenshotEncoder.isValidMap(map)) {
      encoder = ScreenshotEncoder.fromMap(map);
      continue;
    }
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
    final currentImage = decodeRgba(map['width'], map['height'], map['bytes']);
    if (backgroundColor != null) {
      // 如果有设置背景色，在这里叠加上背景，
      // 这之后实际图片会变成3通道不透明，但还是占用4通道的内存，方便后面统一处理，
      for (var y = 0; y < currentImage.height; y++) {
        for (var x = 0; x < currentImage.width; x++) {
          final newPixel =
              blendColors(backgroundColor, currentImage.getPixel(x, y));
          currentImage.setPixel(x, y, newPixel);
        }
      }
    }
    list.add((currentImage, dx, dy));
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
  int inputTime = DateTime.now().millisecondsSinceEpoch;
  assert(() {
    log('inputTime: ${inputTime - startTime}');
    return true;
  }());
  Image? image;
  for (var param in list) {
    final (currentImage, dx, dy) = param;
    image ??=
        Image.fromResized(currentImage, width: maxWidth, height: maxHeight);
    final bottom = dy + currentImage.height;
    final imageBuffer = image.buffer.asUint32List();
    final currentImageBuffer = currentImage.buffer.asUint32List();
    if (dx == 0 && currentImage.width == image.width) {
      // 整个图片合并，
      final start = image.width * dy;
      final end = start + image.width * currentImage.height;
      imageBuffer.setRange(start, end, currentImageBuffer);
    } else {
      // 一行一行合并，
      for (var y = dy; y < bottom; y++) {
        final start = image.width * y + dx;
        final end = start + currentImage.width;
        imageBuffer.setRange(start, end,
            currentImageBuffer.sublist((y - dy) * currentImage.width));
      }
    }
  }
  int mergeTime = DateTime.now().millisecondsSinceEpoch;
  assert(() {
    log('mergeTime: ${mergeTime - inputTime}');
    return true;
  }());
  final result = image ?? Image.empty();
  assert(() {
    log('output: ${result.width}, ${result.height}');
    return true;
  }());
  if (encoder == null) {
    yield result.toMap();
    return;
  }
  yield encoder.encode(result);
  int encodeTime = DateTime.now().millisecondsSinceEpoch;
  assert(() {
    log('encodeTime: ${encodeTime - mergeTime}');
    return true;
  }());
}

Image decodeRgba(int width, int height, Uint8List bytes) {
  final image = Image.fromBytes(
    width: width,
    height: height,
    bytes: bytes.buffer,
    numChannels: 4,
  );
  return image;
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
