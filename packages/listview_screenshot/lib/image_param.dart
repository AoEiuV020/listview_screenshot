import 'dart:ui';

class ImageParam {
  final Image image;
  final int dx;
  final int dy;

  ImageParam({
    required this.image,
    required this.dx,
    required this.dy,
  });
  Map toMap() => {
        'dx': dx,
        'dy': dy,
        'image': image.toByteData(format: ImageByteFormat.png),
      };
}
