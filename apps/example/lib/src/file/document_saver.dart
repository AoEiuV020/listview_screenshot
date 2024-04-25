import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

class DocumentSaver {
  static Future<bool> save(
      Uint8List data, String filename, String ext, String mimetype) async {
    if (!kIsWeb && !Platform.isMacOS) {
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
        ext: '.$ext',
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

  static void test() async {
    var result = await save(
      utf8.encode('hello'),
      'test',
      'txt',
      'text/plain',
    );
    log("$result");
  }
}
