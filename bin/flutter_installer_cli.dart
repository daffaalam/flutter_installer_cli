import 'dart:io';

import 'package:process_run/process_run.dart';
import 'package:process_run/which.dart';

import 'src/install/install.dart';
import 'src/internal/config.dart';
import 'src/internal/debug.dart';
import 'src/internal/tool.dart';

void main(List<String> args) async {
  try {
    parseArgs(args);
    showText(' START ${isDebug ? '(DEBUG MODE) ' : ''}');
    await logNewRun();
    if (Platform.isWindows) {
      await run('chcp 437 > nul', []);
      await run(
        'title',
        ['Flutter Installer $version by Abiyyu Daffa Alam ($githubRepos)'],
      );
      var powerShell = await checkPowerShell();
      if (!powerShell) {
        await open('https://www.microsoft.com/en-us/download/details.aspx?id=54616');
        stdout.writeln(
          'Can not find PowerShell 5.0 or newer. Please install first to continue.\n'
          'https://www.microsoft.com/en-us/download/details.aspx?id=54616',
        );
        stdin.readLineSync();
        exit(0);
      }
    }
    await checkLatestVersion();
    var flutterPath = await which('flutter');
    if (flutterPath == null) {
      await installFullPackage();
    } else {
      var dartPath = await which('dart');
      if (dartPath == null) {
        var path = Directory(flutterPath).parent.path;
        await setPathEnvironment(
          title: 'DART',
          newPath: '$path/cache/dart-sdk/bin',
        );
      }
      await run('flutter', ['upgrade'], runInShell: true, verbose: true);
    }
    showText(' FINISH ');
    await open('https://daffaalam.com');
    stdout.write('\n');
    stdout.writeln(
      'please report to $githubRepos if it fails or something wrong',
    );
    stdin.readLineSync();
    exit(0);
  } catch (e, s) {
    await open('https://daffaalam.com');
    await errorLog(e, s);
    stdin.readLineSync();
    exit(2);
  }
}
