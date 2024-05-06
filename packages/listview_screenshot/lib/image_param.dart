import 'dart:ui';

class ImageParam {
  final Image image;
  final int dx;
  final int dy;
  final Color? color;

  ImageParam({
    required this.image,
    required this.dx,
    required this.dy,
    required this.color,
  });
  Future<Map<String, dynamic>> toMap() async {
    final data = await image.toByteData(format: ImageByteFormat.rawStraightRgba);
    return {
      'dx': dx,
      'dy': dy,
      'width': image.width,
      'height': image.height,
      'color': color?.value,
      'bytes': data!.buffer.asUint8List(),
    };
  }
}
