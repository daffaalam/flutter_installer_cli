import 'dart:io';

import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/which.dart';

import 'tools/function.dart';

void main() async {
  isDebug = false; // TODO : test only (show verbose)
  environment.addAll(Platform.environment);

  var text = ' START ';
  var border = String.fromCharCodes(
    List<int>.generate(
      (stdout.terminalColumns - text.length) ~/ 2,
      (index) => 61,
    ),
  );
  stdout.writeln('\n' + border + text + border + '\n');

  var operatingSystem = Platform.operatingSystem;
  var flutterPath = await which('flutter');
  var dartPath = await which('dart');
  var javaPath = await which('java');
  var androidPath = await which('sdkmanager');
  var gitPath = await which('git');

  if (flutterPath == null) {
    var system = userHomePath.split('\\')[0];
    installationPath = (Platform.isWindows ? '$system\\' : '~/');
    installationPath += 'Development';
    var exists = await Directory(installationPath).exists();
    if (!exists) await Directory(installationPath).create();
    if (javaPath == null) {
      await installJava(
        operatingSystem: operatingSystem,
      );
    }
    if (androidPath == null) {
      await installAndroid(
        operatingSystem: operatingSystem,
      );
    } else {
      await updateAndroid(
        toolsPath: Directory(androidPath).parent.path,
      );
    }
    await installFlutter(
      operatingSystem: operatingSystem,
    );
    if (gitPath == null) {
      await stdout.writeln(
        '[GIT] You can install git versioning from https://git-scm.com/downloads.',
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
  await finish();
}
