import 'dart:io';

import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/which.dart';

import 'tools/function.dart';

void main() async {
  try {
    isDebug = false; // TODO : for testing only (show all verbose)
    environment.addAll(Platform.environment);

    var powerShell = await checkPowerShell();
    if (!powerShell) {
      stdout.writeln(
        'Can not find PowerShell 5.0 or newer. Please install first to continue.\n'
        'https://www.microsoft.com/en-us/download/confirmation.aspx?id=54616',
      );
      stdin.readLineSync();
      exit(0);
    }

    showText(' START ');

    var operatingSystem = Platform.operatingSystem;
    var flutterPath = await which('flutter');
    var dartPath = await which('dart');
    var javaPath = await which('java');
    var androidPath = await which('sdkmanager');
    var gitPath = await which('git');

    if (flutterPath == null) {
      var winDisk = userHomePath.split('\\')[0];
      installationPath = (Platform.isWindows ? '$winDisk\\' : '~/');
      installationPath += 'Development';
      stdout.writeln('\nFlutter will be installed in $installationPath\n');
      var exists = await Directory(installationPath).exists();
      if (!exists) await Directory(installationPath).create(recursive: true);
      var studio = await checkAndroidStudio();
      var later = '';
      if (!studio) {
        later = await prompt(
          'Android Studio is not installed. Do you want to install the full package (Flutter without Android Studio)? (Y/N)',
        );
        stdout.write('\n');
      }
      later = later.toLowerCase();
      if (later == 'y' || later == 'yes') {
        stdout.writeln('This process might require downloading ~1.5 GB\n');
        await withOutAndroidStudio(
          javaPath: javaPath,
          androidPath: androidPath,
          operatingSystem: operatingSystem,
        );
      } else {
        stdout.writeln('This process might require downloading ~900 MB\n');
      }
      await installFlutter(
        operatingSystem: operatingSystem,
      );
      if (gitPath == null) {
        await stdout.writeln(
          '[GIT] (Optional) You might need git for versioning, install from https://git-scm.com/downloads.',
        );
      }
      stdout.write(
        '\nPlease exit this window and open new Terminal or Command Prompt and run `flutter doctor -v`.\n',
      );
    } else {
      if (dartPath == null) {
        var path = Directory(flutterPath).parent.path;
        await setPathEnvironment(
          title: 'DART',
          newPath: '$path\\cache\\dart-sdk\\bin',
        );
      }
      await run(
        'flutter',
        ['upgrade'],
        verbose: true,
      );
    }
    showText(' FINISH ');
    stdin.readLineSync();
    exit(0);
  } catch (e) {
    await errorLog(e);
  }
}
