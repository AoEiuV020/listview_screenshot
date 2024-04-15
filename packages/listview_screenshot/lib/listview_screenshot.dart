import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as image;

import 'merge_param.dart';

class WidgetShot extends SingleChildRenderObjectWidget {
  const WidgetShot({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      WidgetShotRenderRepaintBoundary(context);
}

class WidgetShotRenderRepaintBoundary extends RenderRepaintBoundary {
  BuildContext context;

  WidgetShotRenderRepaintBoundary(this.context);

  /// 长截图，边滚动边截图，最后拼接压缩，
  /// 
  /// [scrollController] 属于滚动控件的控制器，
  /// [maxHeight] 粗略的限高，不完全靠谱，
  /// [backgroundColor] 背景色，
  /// [quality] 0-100, 0和100是无损，
  Future<Uint8List?> screenshot({
    ScrollController? scrollController,
    List<ImageParam> extraImage = const [],
    int? maxHeight,
    double pixelRatio = 1.0,
    Color? backgroundColor,
    int quality = 100,
  }) async {
    if (quality > 100) {
      quality = 100;
    }
    if (quality < 0) {
      quality = 0;
    }
    Uint8List? resultImage;

    double sHeight =
        scrollController?.position.viewportDimension ?? size.height;

    double imageHeight = 0;

    List<ImageParam> imageParams = [];

    extraImage
        .where((element) => element.offset == const Offset(-1, -1))
        .toList(growable: false)
        .forEach((element) {
      imageParams.add(ImageParam(
        image: element.image,
        offset: Offset(0, imageHeight),
        size: element.size,
      ));
      imageHeight += element.size.height;
    });

    bool canScroll = scrollController != null &&
        (scrollController.position.maxScrollExtent) > 0;

    if (canScroll) {
      await scrollTo(scrollController, 0);
    }

    var firstImage = await _screenshot(pixelRatio);

    imageParams.add(ImageParam(
      image: firstImage,
      offset: Offset(0, imageHeight),
      size: size * pixelRatio,
    ));

    imageHeight += sHeight * pixelRatio;

    if (canScroll) {
      logger() {
        debugPrint(
            "WidgetShot scrollController.offser = ${scrollController.offset} , scrollController.position.maxScrollExtent = ${scrollController.position.maxScrollExtent}");
      }

      assert(() {
        scrollController.addListener(logger);
        return true;
      }());

      int i = 1;

      while (true) {
        if (maxHeight != null && imageHeight >= maxHeight * pixelRatio) {
          break;
        }
        double lastImageHeight = 0;

        if (_canScroll(scrollController)) {
          double scrollHeight = scrollController.offset + sHeight / 10;

          if (scrollHeight > sHeight * i) {
            await scrollTo(scrollController, sHeight * i);
            i++;

            Uint8List image = await _screenshot(pixelRatio);

            imageParams.add(ImageParam(
              image: image,
              offset: Offset(0, imageHeight),
              size: size * pixelRatio,
            ));
            imageHeight += sHeight * pixelRatio;
          } else if (scrollHeight > scrollController.position.maxScrollExtent) {
            lastImageHeight = scrollController.position.maxScrollExtent +
                sHeight -
                sHeight * i;

            await scrollTo(
                scrollController, scrollController.position.maxScrollExtent);

            Uint8List lastImage = await _screenshot(pixelRatio);

            imageParams.add(ImageParam(
              image: lastImage,
              offset: Offset(0,
                  imageHeight - ((size.height - lastImageHeight) * pixelRatio)),
              size: size * pixelRatio,
            ));

            imageHeight += lastImageHeight * pixelRatio;
          } else {
            await scrollTo(scrollController, scrollHeight);
          }
        } else {
          break;
        }
      }
      assert(() {
        scrollController.removeListener(logger);
        return true;
      }());
    }

    extraImage
        .where((element) => element.offset == const Offset(-2, -2))
        .toList(growable: false)
        .forEach((element) {
      imageParams.add(ImageParam(
        image: element.image,
        offset: Offset(0, imageHeight),
        size: element.size,
      ));
      imageHeight += element.size.height;
    });

    extraImage
        .where((element) => (element.offset != const Offset(-1, -1) &&
            element.offset != const Offset(-2, -2)))
        .toList(growable: false)
        .forEach((element) {
      imageParams.add(ImageParam(
        image: element.image,
        offset: element.offset,
        size: element.size,
      ));
    });

    final mergeParam = MergeParam(
        color: backgroundColor,
        size: Size(size.width * pixelRatio, imageHeight),
        quality: quality,
        imageParams: imageParams);

    resultImage = await _merge(canScroll, mergeParam);

    return resultImage;
  }

  Future<void> scrollTo(
      ScrollController scrollController, double offset) async {
    scrollController.jumpTo(offset);
    await Future.delayed(const Duration(milliseconds: 35));
  }

  Future<Uint8List?> _merge(bool canScroll, MergeParam mergeParam) async {
    var width = mergeParam.size.width.toInt();
    var resultImage = image.Image(
        width: width, height: mergeParam.size.height.toInt(), numChannels: 4);
    image.Color? backgroundColor;
    if (mergeParam.color != null) {
      var c = mergeParam.color!;
      backgroundColor = image.ColorRgba8(c.red, c.green, c.blue, c.alpha);
    }
    for (var param in mergeParam.imageParams) {
      var currentImage = image.decodePng(param.image)!;
      var currentHeight = param.size.height;
      var offsetY = param.offset.dy.toInt();
      for (var y = 0; y < currentHeight; y++) {
        var realY = offsetY + y;
        for (var i = 0; i < width; i++) {
          resultImage.setPixel(i, realY,
              blendColors(backgroundColor, currentImage.getPixel(i, y)));
        }
      }
    }
    int level;
    if (mergeParam.quality == 100) {
      level = 0;
    } else {
      level = mergeParam.quality ~/ 10;
    }
    return image.encodePng(resultImage, level: level);
  }

  image.Color blendColors(
      image.Color? backgroundColor, image.Color foregroundColor) {
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

    return image.ColorRgba8(resultRed, resultGreen, resultBlue, 255);
  }

  bool _canScroll(ScrollController? scrollController) {
    if (scrollController == null) {
      return false;
    }
    double maxScrollExtent = scrollController.position.maxScrollExtent;
    double offset = scrollController.offset;
    return !nearEqual(maxScrollExtent, offset,
        scrollController.position.physics.tolerance.distance);
  }

  Future<Uint8List> _screenshot(double pixelRatio) async {
    ui.Image image = await toImage(pixelRatio: pixelRatio);

    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List uint8list = byteData!.buffer.asUint8List();
    return Future.value(uint8list);
  }
}
