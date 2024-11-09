import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import 'package:image/image.dart' as image;
import 'package:isolate_transformer/isolate_transformer.dart';

import 'function.dart';
import 'image_buffer.dart';
import 'image_param.dart';
import 'screenshot_format.dart';
import 'supported_check.dart' if (dart.library.js) 'supported_check_web.dart';

typedef OnProcess = void Function(int current, int total);

class WidgetShot extends SingleChildRenderObjectWidget {
  /// [controller] 属于滚动控件的控制器，
  const WidgetShot({super.key, this.controller, super.child});

  static final bool supported = isScreenshotSupported();
  final ScrollController? controller;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      WidgetShotRenderRepaintBoundary(context, controller);
}

class WidgetShotRenderRepaintBoundary extends RenderRepaintBoundary {
  final BuildContext context;
  final ScrollController? controller;

  WidgetShotRenderRepaintBoundary(
    this.context,
    this.controller,
  );

  /// 长截图，边滚动边截图，最后拼接压缩，成png格式的二进制数据，
  Future<Uint8List> screenshotPng({
    List<ImageParam> extraImage = const [],
    int? maxHeight,
    double? pixelRatio,
    Color? backgroundColor,
    String workerName = '',
    OnProcess? onProcess,
  }) async {
    final imageBuffer = await _screenshot(
      extraImage: extraImage,
      maxHeight: maxHeight,
      pixelRatio: pixelRatio,
      backgroundColor: backgroundColor,
      workerName: workerName,
      onProcess: onProcess,
      encoder: ScreenshotEncoder(ScreenshotFormat.png),
    );
    return imageBuffer.bytes;
  }

  /// 长截图，边滚动边截图，最后拼接压缩，成jpg格式的二进制数据，
  /// [quality] jpg图片质量，1-100，
  Future<Uint8List> screenshotJpg({
    List<ImageParam> extraImage = const [],
    int? maxHeight,
    double? pixelRatio,
    Color? backgroundColor,
    String workerName = '',
    OnProcess? onProcess,
    int quality = 90,
  }) async {
    final imageBuffer = await _screenshot(
      extraImage: extraImage,
      maxHeight: maxHeight,
      pixelRatio: pixelRatio,
      backgroundColor: backgroundColor,
      workerName: workerName,
      onProcess: onProcess,
      encoder: ScreenshotEncoder(ScreenshotFormat.jpg, quality: quality),
    );
    return imageBuffer.bytes;
  }

  Future<image.Image> screenshotImage({
    List<ImageParam> extraImage = const [],
    int? maxHeight,
    double? pixelRatio,
    Color? backgroundColor,
    String workerName = '',
    OnProcess? onProcess,
  }) async {
    final imageBuffer = await _screenshot(
      extraImage: extraImage,
      maxHeight: maxHeight,
      pixelRatio: pixelRatio,
      backgroundColor: backgroundColor,
      workerName: workerName,
      onProcess: onProcess,
      encoder: ScreenshotEncoder(ScreenshotFormat.rgba),
    );
    return imageBuffer.bufferToImage();
  }

  /// 长截图，边滚动边截图，最后拼接压缩，
  ///
  /// [maxHeight] 粗略的限高，不完全靠谱，
  /// [pixelRatio] 真实像素与逻辑像素的比例，默认按设备设置来，系统显示器设置200%就是2.0，两倍宽高更清晰，可以改成1.0意味着按逻辑像素输出截图尺寸，
  /// [backgroundColor] 背景色，
  /// [onProcess] 进度回调，参数两个int，第一个是是当前工作线程收到的图片数量（从1开始，全部收到为0），第二个是算出的总图片数量，item高度有变的话不准，
  /// [encoder] 截图后的编码方式，比如jpg, png, 默认为空就是不编码，返回原始Image,
  Future<ImageBuffer> _screenshot({
    List<ImageParam> extraImage = const [],
    int? maxHeight,
    double? pixelRatio,
    Color? backgroundColor,
    String workerName = '',
    OnProcess? onProcess,
    required ScreenshotEncoder encoder,
  }) async {
    pixelRatio ??= MediaQuery.of(context).devicePixelRatio;
    final scrollController = controller;
    final isolateTransformer = IsolateTransformer();
    // 返回返回合并结果，包含Uint8List,
    final completer = Completer<ImageBuffer>();
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
        } else if (scrollController.position.maxScrollExtent <=
            scrollController.offset) {
          // max可能小于offset, 就是翻过头了在回弹，
          // 等于的情况说明刚好最后一页整整的，也是翻完了，总数就是页索引加1，
          totalCount = event + 1;
        } else {
          // 因为最后一页可能是多次截图拼出来的，所以可能event超过理论上的页数，所以total改成event加上剩下的理论页数，
          totalCount = event +
              ((scrollController.position.maxScrollExtent -
                          scrollController.offset) /
                      sHeight)
                  .ceil();
        }
        totalCount += extraImage.length;
        if (streamController.isClosed) {
          onProcess?.call(0, totalCount);
        } else {
          assert(event + 1 <= totalCount);
          onProcess?.call(event + 1, totalCount);
        }
      } else if (event is Map) {
        completer.complete(ImageBuffer.fromMap(event));
      } else {
        throw StateError('unknown result: ${event.runtimeType}');
      }
    }, onError: completer.completeError);
    streamController.add(encoder);

    // 每一页的宽高，
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
        assert(() {
          debugPrint(
              "WidgetShot scrolling: offset = ${scrollController.offset} , max = ${scrollController.position.maxScrollExtent}");
          return true;
        }());
      }

      logger();

      assert(() {
        scrollController.addListener(logger);
        return true;
      }());

      while (true) {
        if (maxHeight != null && imageHeight >= maxHeight * pixelRatio) {
          break;
        }

        if (_canScroll(scrollController)) {
          final offsetBeforeScroll = scrollController.offset;
          final nextOffset = scrollController.offset.toInt() + sHeight;
          // max各种靠不住，所以这里干脆不判断是不是最后一页，直接翻页，然后等回弹等max和offset正确，
          await scrollTo(scrollController, nextOffset.toDouble());
          // 滚动后max可能变化， 重新计算偏移量，也就是需要截图的高度，
          final realMoveOffset =
              ((scrollController.offset - offsetBeforeScroll) * pixelRatio)
                  .toInt();
          var image = await _screenshotFlutterImage(pixelRatio);

          streamController.add(ImageParam(
            image: image,
            dx: 0,
            dy: imageHeight - (rHeight - realMoveOffset),
            color: backgroundColor,
          ));
          imageHeight += realMoveOffset;
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
    assert(() {
      debugPrint(
          "WidgetShot scroll start: from = ${scrollController.offset} , to = $offset , max = ${scrollController.position.maxScrollExtent}");
      return true;
    }());
    scrollController.jumpTo(offset);
    do {
      await Future.delayed(const Duration(milliseconds: 100));
      // 滚动过头会回弹，要等回弹结束，offset和max稳定下来，
    } while (
        scrollController.offset > scrollController.position.maxScrollExtent);
    assert(() {
      debugPrint(
          "WidgetShot scroll end: offset = ${scrollController.offset} , max = ${scrollController.position.maxScrollExtent}");
      return true;
    }());
  }

  bool _canScroll(ScrollController? scrollController) {
    if (scrollController == null) {
      return false;
    }
    double maxScrollExtent = scrollController.position.maxScrollExtent;
    double offset = scrollController.offset;
    return !nearEqual(
      maxScrollExtent,
      offset,
      // ignore: deprecated_member_use
      scrollController.position.physics.tolerance.distance,
    );
  }

  Future<ui.Image> _screenshotFlutterImage(double pixelRatio) async {
    var uiImage = await toImage(pixelRatio: pixelRatio);
    return uiImage;
  }
}
