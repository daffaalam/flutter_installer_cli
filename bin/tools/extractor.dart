import 'dart:io';

import 'package:meta/meta.dart';
import 'package:archive/archive.dart';

class Extractor {
  static Future<void> extractZip({
    @required String filePath,
    @required String savePath,
  }) async {
    var archive = ZipDecoder().decodeBytes(
      File(filePath).readAsBytesSync(),
    );
    for (var files in archive) {
      var filename = files.name;
      if (files.isFile) {
        var data = files.content as List<int>;
        var file = File(savePath + filename);
        file.createSync(recursive: true);
        file.writeAsBytesSync(data);
      } else {
        var dir = Directory(savePath + filename);
        await dir.create(recursive: true);
      }
    }
  }
}
