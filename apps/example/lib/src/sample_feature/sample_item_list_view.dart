import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:listview_screenshot/listview_screenshot.dart';

import '../file/document_saver.dart';
import '../settings/settings_view.dart';
import 'sample_item_details_view.dart';

/// Displays a list of SampleItems.
class SampleItemListView extends StatefulWidget {
  const SampleItemListView({super.key});

  static const routeName = '/';

  @override
  State<SampleItemListView> createState() => _SampleItemListViewState();
}

class _SampleItemListViewState extends State<SampleItemListView> {
  final GlobalKey _shotKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  int _currentValue = 60;
  void onScreenshot() async {
    if (!WidgetShot.supported) {
      EasyLoading.showError('html渲染模式无法截图');
      return;
    }
    EasyLoading.show(status: '正在创建截图，请勿操作');
    var context = _shotKey.currentContext!;
    WidgetShotRenderRepaintBoundary repaintBoundary =
        context.findRenderObject() as WidgetShotRenderRepaintBoundary;
    Uint8List pngBytes;
    try {
      pngBytes = await repaintBoundary.screenshotPng(
        scrollController: _scrollController,
        backgroundColor: Colors.white,
        workerName: 'imageMergeTransform',
        onProcess: (p0, p1) {
          if (p0 == 0) {
            EasyLoading.show(status: '正在合并截图，请勿操作');
          } else {
            EasyLoading.showProgress(p0 / p1, status: '正在创建截图，请勿操作, $p0/$p1');
          }
        },
      );
    } catch (e, s) {
      log(e.toString(), stackTrace: s);
      EasyLoading.dismiss();
      EasyLoading.showError('生成截图失败: ${e.toString()}');
      return;
    }
    EasyLoading.show(status: '正在保存长截图...');
    var filename = '列表截图${DateTime.now().microsecondsSinceEpoch}';
    var ext = "png";
    var mimetype = "image/png";
    bool success = await DocumentSaver.save(
      pngBytes,
      filename,
      ext,
      mimetype,
    );
    EasyLoading.dismiss();
    if (success) {
      EasyLoading.showSuccess('保存成功');
    } else {
      EasyLoading.showError('保存失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('截图测试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to the settings page. If the user leaves and returns
              // to the app after it has been killed while running in the
              // background, the navigation stack is restored.
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              onScreenshot();
            },
          ),
        ],
      ),

      // To work with lists that may contain a large number of items, it’s best
      // to use the ListView.builder constructor.
      //
      // In contrast to the default ListView constructor, which requires
      // building all Widgets up front, the ListView.builder constructor lazily
      // builds Widgets as they’re scrolled into view.
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Slider(
              min: 0,
              max: 200,
              value: _currentValue.toDouble(),
              onChanged: (double newValue) {
                setState(() {
                  _currentValue = newValue.round();
                  EasyLoading.showToast('列表长度： $_currentValue');
                });
              },
            ),
            Expanded(
              child: WidgetShot(
                key: _shotKey,
                child: ListView.builder(
                  // Providing a restorationId allows the ListView to restore the
                  // scroll position when a user leaves and returns to the app after it
                  // has been killed while running in the background.
                  restorationId: 'sampleItemListView',
                  controller: _scrollController,
                  itemCount: _currentValue,
                  itemBuilder: (BuildContext context, int index) {
                    final text = List.generate(index, (i) => 'SampleItem $i')
                        .join(',  ');
                    return Stack(
                      children: [
                        // 使用FittedBox来包裹CustomPaint，确保其大小跟随Container
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: FittedBox(
                            fit: BoxFit.fill,
                            child: CustomPaint(
                              painter: CirclePainter(),
                              size: const Size(50, 50),
                            ),
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x22ff0000), Color(0x220000ff)],
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              // Navigate to the details page. If the user leaves and returns to
                              // the app after it has been killed while running in the
                              // background, the navigation stack is restored.
                              Navigator.restorablePushNamed(
                                context,
                                SampleItemDetailsView.routeName,
                              );
                            },
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircleAvatar(
                                    // Display the Flutter Logo image asset.
                                    foregroundImage: AssetImage(
                                        'assets/images/flutter_logo.png'),
                                  ),
                                ),
                                Expanded(child: Text(text)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.2) // 圆环的颜色
      ..strokeWidth = 1 // 圆环的宽度
      ..style = PaintingStyle.stroke; // 描边样式

    // 绘制一个椭圆形，使其上下左右都紧贴长方形的边缘
    final rect = Offset.zero & size; // 用`&`操作符创建一个Rect，其左上角在(0, 0)，大小为屏幕的尺寸
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
