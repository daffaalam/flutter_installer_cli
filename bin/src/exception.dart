import 'dart:io';

import 'package:archive/archive.dart';

String exceptionLog(e) {
  switch (e.runtimeType) {
    case ArchiveException:
      var message = (e as ArchiveException).message;
      if (message == 'Could not find End of Central Directory Record')
        return 'file is corrupt, please delete and re-download';
      break;
    case FileSystemException:
      var fileException = e as FileSystemException;
      return '${fileException.message} ${fileException.path.trim()}\n'
          '${fileException.osError.message.trim()}';
      break;
  }
  return '$e';
}
