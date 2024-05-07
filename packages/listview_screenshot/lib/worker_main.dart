import 'package:isolate_transformer/worker_transformer.dart';

import 'src/function.dart';

@pragma('vm:entry-point')
void imageMergeTransformWorkerMain() {
  workerMain(imageMergeTransform);
}
