import 'dart:developer';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

class DocumentSaver {
  static Future<bool> save(
      Uint8List data, String filename, String ext, String mimetype) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        var saveAsResult = await FileSaver.instance.saveAs(
          name: filename,
          bytes: data,
          ext: ext,
          mimeType: MimeType.custom,
          customMimeType: mimetype,
        );
        return saveAsResult != null && saveAsResult.isNotEmpty;
      } catch (e, s) {
        log(e.toString(), stackTrace: s);
      }
    }
    try {
      var saveResult = await FileSaver.instance.saveFile(
        name: filename,
        bytes: data,
        ext: '.$ext', // FileSaver内部bug，拓展名加不加点一片混乱，
        mimeType: MimeType.custom,
        customMimeType: mimetype,
      );
      log('save: $saveResult');
      return saveResult.isNotEmpty;
    } catch (e, s) {
      log(e.toString(), stackTrace: s);
      return false;
    }
  }
}
