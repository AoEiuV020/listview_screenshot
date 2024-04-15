import 'dart:typed_data';

import 'package:flutter/material.dart';

class MergeParam {
  final Color? color;
  final Size size;
  final int quality;
  final List<ImageParam> imageParams;

  MergeParam(
      {this.color,
      required this.size,
      required this.quality,
      required this.imageParams});
}

class ImageParam {
  final Uint8List image;
  final Offset offset;
  final Size size;

  ImageParam({required this.image, required this.offset, required this.size});
}
