import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as image;

import 'image_param.dart';
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

  /// 长截图，边滚动边截图，最后拼接压缩，成png格式的二进制数据，
  Future<Uint8List?> screenshotPng({
    ScrollController? scrollController,
    List<ImageParam> extraImage = const [],
    int? maxHeight,
    double pixelRatio = 1.0,
    Color? backgroundColor,
  }) async {
    var resultImage = await screenshot(
      scrollController: scrollController,
      extraImage: extraImage,
      maxHeight: maxHeight,
      pixelRatio: pixelRatio,
      backgroundColor: backgroundColor,
    );
    // level是压缩率，level越大文件越小速度越慢，不影响图像质量，0是不压缩，
    // 参考 [deflate](https://github.com/brendan-duncan/archive/blob/main/lib/src/zlib/deflate.dart)
    return image.encodePng(resultImage, level: 1);
  }

  /// 长截图，边滚动边截图，最后拼接压缩，成jpg格式的二进制数据，
  /// [quality] jpg图片质量，1-100，
  Future<Uint8List?> screenshotJpg({
    ScrollController? scrollController,
    List<ImageParam> extraImage = const [],
    int? maxHeight,
    double pixelRatio = 1.0,
    Color? backgroundColor,
    int quality = 90,
  }) async {
    var resultImage = await screenshot(
      scrollController: scrollController,
      extraImage: extraImage,
      maxHeight: maxHeight,
      pixelRatio: pixelRatio,
      backgroundColor: backgroundColor,
    );
    return image.encodeJpg(resultImage, quality: quality);
  }

  /// 长截图，边滚动边截图，最后拼接压缩，
  ///
  /// [scrollController] 属于滚动控件的控制器，
  /// [maxHeight] 粗略的限高，不完全靠谱，
  /// [backgroundColor] 背景色，
  Future<image.Image> screenshot({
    ScrollController? scrollController,
    List<ImageParam> extraImage = const [],
    int? maxHeight,
    double pixelRatio = 1.0,
    Color? backgroundColor,
  }) async {
    int sHeight =
        (scrollController?.position.viewportDimension ?? size.height).toInt();

    int rWidth = (size.width * pixelRatio).toInt();
    int rHeight = (sHeight * pixelRatio).toInt();

    int imageHeight = 0;

    List<ImageParam> imageParams = [];

    extraImage
        .where((e) => e.dx == -1 && e.dy == -1)
        .toList(growable: false)
        .forEach((e) {
      imageParams.add(ImageParam(
        image: e.image,
        dx: 0,
        dy: imageHeight,
      ));
      imageHeight += e.image.height;
    });

    bool canScroll = scrollController != null &&
        (scrollController.position.maxScrollExtent) > 0;

    if (canScroll) {
      await scrollTo(scrollController, 0);
    }

    var firstImage = await _screenshot(pixelRatio);

    imageParams.add(ImageParam(
      image: firstImage,
      dx: 0,
      dy: imageHeight,
    ));

    imageHeight += rHeight;

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
          int scrollHeight = scrollController.offset.toInt() + sHeight;

          if (scrollHeight > sHeight * i) {
            await scrollTo(scrollController, (sHeight * i).toDouble());
            i++;

            var image = await _screenshot(pixelRatio);

            imageParams.add(ImageParam(
              image: image,
              dx: 0,
              dy: imageHeight,
            ));
            imageHeight += rHeight;
          } else if (scrollHeight > scrollController.position.maxScrollExtent) {
            lastImageHeight = scrollController.position.maxScrollExtent +
                sHeight -
                sHeight * i;

            await scrollTo(
                scrollController, scrollController.position.maxScrollExtent);

            var lastImage = await _screenshot(pixelRatio);

            imageParams.add(ImageParam(
              image: lastImage,
              dx: 0,
              dy: (imageHeight - ((size.height - lastImageHeight) * pixelRatio))
                  .toInt(),
            ));
            imageHeight += (lastImageHeight * pixelRatio).toInt();
          } else {
            await scrollTo(scrollController, scrollHeight.toDouble());
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
        .where((e) => e.dx == -2 && e.dy == -2)
        .toList(growable: false)
        .forEach((e) {
      imageParams.add(ImageParam(
        image: e.image,
        dx: 0,
        dy: imageHeight,
      ));
      imageHeight += e.image.height;
    });

    extraImage
        .where(
            (e) => !(e.dx == -2 && e.dy == -2) && !(e.dx == -2 && e.dy == -2))
        .toList(growable: false)
        .forEach((element) {
      imageParams.add(element);
    });

    final mergeParam = MergeParam(
        color: backgroundColor,
        width: rWidth,
        height: imageHeight,
        imageParams: imageParams);

    return _merge(canScroll, mergeParam);
  }

  Future<void> scrollTo(
      ScrollController scrollController, double offset) async {
    scrollController.jumpTo(offset);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<image.Image> _merge(bool canScroll, MergeParam mergeParam) async {
    var width = mergeParam.width;
    var resultImage =
        image.Image(width: width, height: mergeParam.height, numChannels: 4);
    image.Color? backgroundColor;
    if (mergeParam.color != null) {
      var c = mergeParam.color!;
      backgroundColor = image.ColorRgba8(c.red, c.green, c.blue, c.alpha);
    }
    for (var param in mergeParam.imageParams) {
      var currentImage = await uiToImage(param.image);
      var currentHeight = param.image.height;
      var offsetY = param.dy;
      for (var y = 0; y < currentHeight; y++) {
        var realY = offsetY + y;
        if (realY >= resultImage.height) {
          // 以防万一，web端比较卡的时候有出现，
          break;
        }
        for (var i = 0; i < width; i++) {
          resultImage.setPixel(i, realY,
              blendColors(backgroundColor, currentImage.getPixel(i, y)));
        }
      }
    }
    return resultImage;
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

  Future<ui.Image> _screenshot(double pixelRatio) async {
    var uiImage = await toImage(pixelRatio: pixelRatio);
    return uiImage;
  }

  Future<image.Image> uiToImage(ui.Image uiImage) async {
    var width = uiImage.width;
    var height = uiImage.height;
    var numChannels = 4;
    var result =
        image.Image(width: width, height: height, numChannels: numChannels);
    var rgbaList =
        (await uiImage.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!
            .buffer
            .asUint8List();
    var offsetY = 0;
    for (var y = 0; y < height; y++) {
      var realY = offsetY + y;
      for (var i = 0; i < width; i++) {
        var offsetByte = numChannels * (y * width + i);
        result.setPixel(
          i,
          realY,
          image.ColorUint8.fromList(
            rgbaList.sublist(offsetByte, offsetByte + numChannels),
          ),
        );
      }
    }
    return result;
  }
}
