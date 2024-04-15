import 'package:example/src/file/document_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:listview_screenshot/listview_screenshot.dart';

import '../settings/settings_view.dart';
import 'sample_item.dart';
import 'sample_item_details_view.dart';

/// Displays a list of SampleItems.
class SampleItemListView extends StatelessWidget {
  SampleItemListView({
    super.key,
    this.items = const [SampleItem(1), SampleItem(2), SampleItem(3)],
  });

  static const routeName = '/';

  final List<SampleItem> items;
  final GlobalKey _shotKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  void onScreenshot() async {
    EasyLoading.show(status: '正在创建截图，请勿操作');
    var context = _shotKey.currentContext!;
    WidgetShotRenderRepaintBoundary repaintBoundary =
        context.findRenderObject() as WidgetShotRenderRepaintBoundary;
    var pngBytes = await repaintBoundary.screenshot(
      scrollController: _scrollController,
      pixelRatio: 1,
      quality: 90,
      backgroundColor:
          Theme.of(context).colorScheme.brightness == Brightness.light
              ? Colors.white
              : Theme.of(context).colorScheme.background,
    );
    if (pngBytes == null) {
      EasyLoading.dismiss();
      EasyLoading.showError('生成截图失败');
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
      body: WidgetShot(
        key: _shotKey,
        child: ListView.builder(
          // Providing a restorationId allows the ListView to restore the
          // scroll position when a user leaves and returns to the app after it
          // has been killed while running in the background.
          restorationId: 'sampleItemListView',
          controller: _scrollController,
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            final item = items[index];

            return ListTile(
                title: Text('SampleItem ${item.id}'),
                leading: const CircleAvatar(
                  // Display the Flutter Logo image asset.
                  foregroundImage: AssetImage('assets/images/flutter_logo.png'),
                ),
                onTap: () {
                  // Navigate to the details page. If the user leaves and returns to
                  // the app after it has been killed while running in the
                  // background, the navigation stack is restored.
                  Navigator.restorablePushNamed(
                    context,
                    SampleItemDetailsView.routeName,
                  );
                });
          },
        ),
      ),
    );
  }
}
