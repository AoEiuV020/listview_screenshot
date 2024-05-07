import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as image;
import 'package:isolate_transformer/isolate_transformer.dart';
import 'package:listview_screenshot/function.dart';
import 'package:listview_screenshot/screenshot_format.dart';

import 'image_param.dart';
import 'supported_check.dart' if (dart.library.js) 'supported_check_web.dart';

class WidgetShot extends SingleChildRenderObjectWidget {
  const WidgetShot({super.key, super.child});

  static final bool supported = isScreenshotSupported();

  @override
  RenderObject createRenderObject(BuildContext context) =>
      WidgetShotRenderRepaintBoundary(context);
}

class WidgetShotRenderRepaintBoundary extends RenderRepaintBoundary {
  BuildContext context;

  WidgetShotRenderRepaintBoundary(this.context);

  /// 长截图，边滚动边截图，最后拼接压缩，成png格式的二进制数据，
  Future<Uint8List> screenshotPng({
    ScrollController? scrollController,
    List<ImageParam> extraImage = const [],
    int? maxHeight,
    double pixelRatio = 1.0,
    Color? backgroundColor,
    String workerName = '',
    void Function(int, int)? onProcess,
  }) async {
    return await _screenshot(
      scrollController: scrollController,
      extraImage: extraImage,
      maxHeight: maxHeight,
      pixelRatio: pixelRatio,
      backgroundColor: backgroundColor,
      workerName: workerName,
      onProcess: onProcess,
      encoder: ScreenshotEncoder(ScreenshotFormat.png),
    );
  }

  /// 长截图，边滚动边截图，最后拼接压缩，成jpg格式的二进制数据，
  /// [quality] jpg图片质量，1-100，
  Future<Uint8List> screenshotJpg({
    ScrollController? scrollController,
    List<ImageParam> extraImage = const [],
    int? maxHeight,
    double pixelRatio = 1.0,
    Color? backgroundColor,
    String workerName = '',
    void Function(int, int)? onProcess,
    int quality = 90,
  }) async {
    return await _screenshot(
      scrollController: scrollController,
      extraImage: extraImage,
      maxHeight: maxHeight,
      pixelRatio: pixelRatio,
      backgroundColor: backgroundColor,
      workerName: workerName,
      onProcess: onProcess,
      encoder: ScreenshotEncoder(ScreenshotFormat.jpg, quality: quality),
    );
  }

  Future<image.Image> screenshotImage({
    ScrollController? scrollController,
    List<ImageParam> extraImage = const [],
    int? maxHeight,
    double pixelRatio = 1.0,
    Color? backgroundColor,
    String workerName = '',
    void Function(int, int)? onProcess,
  }) async {
    return await _screenshot(
      scrollController: scrollController,
      extraImage: extraImage,
      maxHeight: maxHeight,
      pixelRatio: pixelRatio,
      backgroundColor: backgroundColor,
      workerName: workerName,
      onProcess: onProcess,
    );
  }

  /// 长截图，边滚动边截图，最后拼接压缩，
  ///
  /// [scrollController] 属于滚动控件的控制器，
  /// [maxHeight] 粗略的限高，不完全靠谱，
  /// [backgroundColor] 背景色，
  /// [onProcess] 进度回调，参数两个int，第一个是是当前工作线程收到的图片数量（从1开始，全部收到为0），第二个是算出的总图片数量，item高度有变的话不准，
  /// [encoder] 截图后的编码方式，比如jpg, png, 默认为空就是不编码，返回原始Image,
  Future<dynamic> _screenshot({
    ScrollController? scrollController,
    List<ImageParam> extraImage = const [],
    int? maxHeight,
    double pixelRatio = 1.0,
    Color? backgroundColor,
    String workerName = '',
    void Function(int, int)? onProcess,
    ScreenshotEncoder? encoder,
  }) async {
    final isolateTransformer = IsolateTransformer();
    // 返回原始Image或者编码过的Uint8List,
    final completer = Completer<dynamic>();
    // 传编码格式和每个截图片段，
    final streamController = StreamController<dynamic>();
    int sHeight =
        (scrollController?.position.viewportDimension ?? size.height).toInt();
    isolateTransformer.transform(streamController.stream.asyncMap<Map>((event) {
      if (event is ImageParam) {
        return event.toMap();
      } else if (event is ScreenshotEncoder) {
        return event.toMap();
      } else {
        throw StateError('unknown input: ${event.runtimeType}');
      }
    }), imageMergeTransform, workerName: workerName).listen((event) {
      if (event is int) {
        int totalCount;
        if (scrollController == null) {
          totalCount = 1;
        } else {
          totalCount =
              (scrollController.position.maxScrollExtent / sHeight).ceil();
        }
        totalCount += extraImage.length;
        if (streamController.isClosed) {
          onProcess?.call(0, totalCount);
        } else {
          onProcess?.call(event + 1, totalCount);
        }
      } else if (event is Map) {
        completer.complete(ImageExtension.fromMap(event));
      } else if (event is Uint8List) {
        completer.complete(event);
      } else {
        throw StateError('unknown result: ${event.runtimeType}');
      }
    }, onError: completer.completeError);
    streamController.add(encoder);

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

    var firstImage = await _screenshotFlutterImage(pixelRatio);

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

            var image = await _screenshotFlutterImage(pixelRatio);

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

            var lastImage = await _screenshotFlutterImage(pixelRatio);

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

  Future<ui.Image> _screenshotFlutterImage(double pixelRatio) async {
    var uiImage = await toImage(pixelRatio: pixelRatio);
    return uiImage;
  }
}
