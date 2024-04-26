import 'package:isolate_transformer/worker_transformer.dart';
import 'package:listview_screenshot/function.dart';

/// dart compile js imageMergeTransform.dart -o imageMergeTransform.js -O4
main() {
  workerMain(imageMergeTransform);
}
