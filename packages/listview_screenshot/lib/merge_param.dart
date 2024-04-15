import 'package:flutter/material.dart' as ui;
import 'package:image/image.dart' as img;

class MergeParam {
  final ui.Color? color;
  final int width;
  final int height;
  final List<ImageParam> imageParams;

  MergeParam(
      {required this.color,
      required this.width,
      required this.height,
      required this.imageParams});
}

class ImageParam {
  final img.Image image;
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
