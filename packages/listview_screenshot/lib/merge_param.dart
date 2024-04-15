import 'dart:typed_data';

import 'package:flutter/material.dart';

class MergeParam {
  final Color? color;
  final int width;
  final int height;
  final int quality;
  final List<ImageParam> imageParams;

  MergeParam(
      {required this.color,
      required this.width,
      required this.height,
      required this.quality,
      required this.imageParams});
}

class ImageParam {
  final Uint8List image;
  final int dx;
  final int dy;
  final int width;
  final int height;

  ImageParam(
      {required this.image,
      required this.dx,
      required this.dy,
      required this.width,
      required this.height});
}
