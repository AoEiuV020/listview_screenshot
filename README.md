# listview_screenshot
flutter全平台针对ListView等滚动视图实现长截图，

[![img](https://img.shields.io/github/release/AoEiuV020/listview_screenshot.svg)](https://github.com/AoEiuV020/listview_screenshot/releases)
[![CI](https://github.com/AoEiuV020/listview_screenshot/workflows/CI/badge.svg)](https://github.com/AoEiuV020/listview_screenshot/actions)
[![Using melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)
[![Main version](https://img.shields.io/pub/v/listview_screenshot.svg)](https://pub.dev/packages/listview_screenshot)

## Getting started

```shell
dart pub add listview_screenshot
```

## Usage
[列表截图示例](./apps/example/lib/src/sample_feature/sample_item_list_view.dart)  

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
    EasyLoading.show(status: '正在创建截图，请勿操作');
    var context = _shotKey.currentContext!;
    WidgetShotRenderRepaintBoundary repaintBoundary =
        context.findRenderObject() as WidgetShotRenderRepaintBoundary;
    Uint8List pngBytes;
    try {
      pngBytes = await repaintBoundary.screenshotPng( // 或者调用screenshotImage得到image库的Image对象，
        scrollController: _scrollController,
        backgroundColor: Colors.white,
        workerName: 'imageMergeTransform', // web异步线程合并要生成对应js文件，否则不传，
        onProcess: (p0, p1) {
          if (p0 == 0) {
            EasyLoading.show(status: '正在合并截图，请勿操作');
          } else {
            EasyLoading.showProgress(p0 / p1, status: '正在创建截图，请勿操作, $p0/$p1');
          }
        },
      );
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('生成截图失败: ${e.toString()}');
      return;
    }
    EasyLoading.show(status: '正在保存长截图...');
    // ... save pngBytes to png file,
  }
```
web异步线程合并支持，  
[imageMergeTransform.dart](./packages/listview_screenshot/web/imageMergeTransform.dart)
下载到flutter项目web目录下，使用如下代码编译出js文件，  
生成的js文件名填写到screenshot方法参数workerName，  
同时生成的js.deps和js.map文件仅调试使用，不必须，  
```shell
dart compile js imageMergeTransform.dart -o imageMergeTransform.js -O4
```
不过web有个硬伤，html渲染模式无法截图，所以只能使用前加个判断，  
否则截图方法会抛异常，
toImage is not supported on the Web    
```dart
    if (!WidgetShot.supported) {
      EasyLoading.showError('html渲染模式无法截图');
      return;
    }
```
默认手机浏览器访问就是html渲染模式，所以可以在index.html设置指定强制使用canvaskit模式，  
[index.html](../../apps/example/web/index.html)  
```js
        onEntrypointLoaded: function(engineInitializer) {
          engineInitializer.initializeEngine({
            renderer: "canvaskit",
          }).then(function(appRunner) {
            appRunner.runApp();
          });
        }
```

## TODO
- mac HiDPI截不到高清图，