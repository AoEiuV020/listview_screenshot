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
    final data = await image.toByteData(format: ImageByteFormat.png);
    return {
      'dx': dx,
      'dy': dy,
      'color': color?.value,
      'png': data!.buffer.asUint8List(),
    };
  }
}
