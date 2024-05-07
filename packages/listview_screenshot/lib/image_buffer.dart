import 'dart:typed_data';

/// 简单封装图片的数据和宽高，
/// 不含格式信息，这里的bytes可能是png之类也可能是rgba原始数据，
class ImageBuffer {
  final int width;
  final int height;
  final Uint8List bytes;

  ImageBuffer(this.width, this.height, this.bytes);
  factory ImageBuffer.fromMap(Map map) {
    final width = map['width'];
    final height = map['height'];
    final bytes = map['bytes'];
    return ImageBuffer(width, height, bytes);
  }

  Map<String, dynamic> toMap() => {
        'width': width,
        'height': height,
        'bytes': bytes,
      };
}
