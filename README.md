# listview_screenshot
flutter针对ListView等滚动视图实现长截图，

[![img](https://img.shields.io/github/release/AoEiuV020/listview_screenshot.svg)](https://github.com/AoEiuV020/listview_screenshot/releases)
[![CI](https://github.com/AoEiuV020/listview_screenshot/workflows/CI/badge.svg)](https://github.com/AoEiuV020/listview_screenshot/actions)
[![Using melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)
[![Main version](https://img.shields.io/pub/v/listview_screenshot.svg)](https://pub.dev/packages/listview_screenshot)

## Getting started

```shell
dart pub add isolate_transformer
```

## Usage
[列表截图](./apps/example/lib/src/sample_feature/sample_item_list_view.dart)  

核心是 [WidgetShotRenderRepaintBoundary.screenshot](./packages/listview_screenshot/lib/listview_screenshot.dart)  
```dart
  final GlobalKey _shotKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
```
```dart
        child: WidgetShot(
          key: _shotKey,
          child: ListView.builder(
            controller: _scrollController,
            // ...
          ),
        ),
```
```dart
  void onScreenshot() async {
    var context = _shotKey.currentContext!;
    WidgetShotRenderRepaintBoundary repaintBoundary =
        context.findRenderObject() as WidgetShotRenderRepaintBoundary;
    Uint8List? pngBytes = await repaintBoundary.screenshotPng( // 或者调用screenshot得到image库的Image对象，
      scrollController: _scrollController,
      backgroundColor: Colors.white,
      workerName: 'imageMergeTransform', // web异步线程合并要生成对应js文件，否则不传，
    );
    if (pngBytes == null) {
      // ... error,
      return;
    }
    // ... save pngBytes to png file,
  }
```
web异步线程合并支持，  
[imageMergeTransform.dart](./packages/listview_screenshot/web/imageMergeTransform.dart)
下载到flutter项目web目录下，使用如下代码编译出js文件，  
生成的js文件名填写到screenshot方法参数workerName，  
```shell
dart compile js imageMergeTransform.dart -o imageMergeTransform.js -O4
```

## TODO
- [ ] mac HiDPI截不到高清图，
- [ ] web端一下一下的卡顿，
- [x] 合并过程异步，
- [x] 发布到pub.dev，
- [x] 全平台支持，
- [x] 提供未编码的图像或png/jpg已编码图像，
- [x] 整页翻页超长截图拼接，