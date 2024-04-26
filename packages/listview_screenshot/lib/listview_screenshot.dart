import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as image;
import 'package:isolate_transformer/isolate_transformer.dart';
import 'package:listview_screenshot/function.dart';

import 'image_param.dart';

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
    String workerName = '',
  }) async {
    var resultImage = await screenshot(
      scrollController: scrollController,
      extraImage: extraImage,
      maxHeight: maxHeight,
      pixelRatio: pixelRatio,
      backgroundColor: backgroundColor,
      workerName: workerName,
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
    String workerName = '',
    int quality = 90,
  }) async {
    var resultImage = await screenshot(
      scrollController: scrollController,
      extraImage: extraImage,
      maxHeight: maxHeight,
      pixelRatio: pixelRatio,
      backgroundColor: backgroundColor,
      workerName: workerName,
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
    String workerName = '',
  }) async {
    final isolateTransformer = IsolateTransformer();
    final completer = Completer<image.Image>();
    final streamController = StreamController<ImageParam>();
    isolateTransformer
        .transform(streamController.stream.asyncMap((event) => event.toMap()),
            imageMergeTransform, workerName: workerName)
        .listen((event) {
      completer.complete(ImageExtension.fromMap(event));
    });
    int sHeight =
        (scrollController?.position.viewportDimension ?? size.height).toInt();

    // ignore: unused_local_variable
    int rWidth = (size.width * pixelRatio).toInt();
    int rHeight = (sHeight * pixelRatio).toInt();

    int imageHeight = 0;

    extraImage
        .where((e) => e.dx == -1 && e.dy == -1)
        .toList(growable: false)
        .forEach((e) {
      streamController.add(ImageParam(
        image: e.image,
        dx: 0,
        dy: imageHeight,
        color: backgroundColor,
      ));
      imageHeight += e.image.height;
    });

    bool canScroll = scrollController != null &&
        (scrollController.position.maxScrollExtent) > 0;

    if (canScroll) {
      await scrollTo(scrollController, 0);
    }

    var firstImage = await _screenshot(pixelRatio);

    streamController.add(ImageParam(
      image: firstImage,
      dx: 0,
      dy: imageHeight,
      color: backgroundColor,
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

            streamController.add(ImageParam(
              image: image,
              dx: 0,
              dy: imageHeight,
              color: backgroundColor,
            ));
            imageHeight += rHeight;
          } else if (scrollHeight > scrollController.position.maxScrollExtent) {
            lastImageHeight = scrollController.position.maxScrollExtent +
                sHeight -
                sHeight * i;

            await scrollTo(
                scrollController, scrollController.position.maxScrollExtent);

            var lastImage = await _screenshot(pixelRatio);

            streamController.add(ImageParam(
              image: lastImage,
              dx: 0,
              dy: (imageHeight - ((size.height - lastImageHeight) * pixelRatio))
                  .toInt(),
              color: backgroundColor,
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
      streamController.add(ImageParam(
        image: e.image,
        dx: 0,
        dy: imageHeight,
        color: backgroundColor,
      ));
      imageHeight += e.image.height;
    });

    extraImage
        .where(
            (e) => !(e.dx == -2 && e.dy == -2) && !(e.dx == -2 && e.dy == -2))
        .toList(growable: false)
        .forEach((element) {
      streamController.add(element);
    });
    streamController.close();
    return await completer.future;
  }

  Future<void> scrollTo(
      ScrollController scrollController, double offset) async {
    scrollController.jumpTo(offset);
    await Future.delayed(const Duration(milliseconds: 100));
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
}
