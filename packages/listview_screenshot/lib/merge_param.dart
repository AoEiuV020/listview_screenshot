import 'package:flutter/material.dart';

import 'image_param.dart';

class MergeParam {
  final Color? color;
  final int width;
  final int height;
  final List<ImageParam> imageParams;

  MergeParam(
      {required this.color,
      required this.width,
      required this.height,
      required this.imageParams});
}
