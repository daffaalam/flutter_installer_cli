import 'dart:io';

import 'package:meta/meta.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/which.dart';

import '../internal/config.dart';
import 'install_android.dart';
import 'install_flutter.dart';
import 'install_ide.dart';
import 'install_java.dart';

Future<void> installFullPackage() async {
  stdout.writeln('\nFlutter will be installed in $installationPath\n');
  var exists = await Directory(installationPath).exists();
  if (!exists) await Directory(installationPath).create(recursive: true);
  var fullPackage = false;
  var studio = await checkAndroidStudio();
  if (studio == null) {
    fullPackage = await promptConfirm(
      'Android Studio is not installed. Do you want to install the full package (Flutter without Android Studio)?',
    );
  }
  if (fullPackage) {
    stdout.writeln(
      '\nThis process might require downloading ~1.7 GB for the first time.\n',
    );
    var javaPath = await which('java');
    var androidPath = await which('sdkmanager');
    if (androidPath != null) {
      var allowTools = await checkAndroidTools(
        toolsPath: Directory(androidPath).parent.path,
      );
      if (!allowTools) {
        stdout.writeln(
          '[ANDROID] Please install Android Tools 26.1.1 or earlier.',
        );
      }
    }
    await installWithOutAndroidStudio(
      javaPath: javaPath,
      androidPath: androidPath,
    );
  } else {
    stdout.writeln(
      '\nThis process might require downloading ~1 GB for the first time.\n',
    );
  }
  await installFlutter();
  if (studio != null) await androidStudioInstallExtensions(studio: studio);
  var vscodePath = await which('code');
  if (vscodePath != null) await vscodeInstallExtensions();
  var gitPath = await which('git');
  if (gitPath == null) {
    await stdout.writeln(
      '[GIT]${!Platform.isWindows ? ' (REQUIRED) ' : ' '}You might need git for versioning, install from https://git-scm.com/downloads.',
    );
  }
  stdout.write(
    '\nPlease exit this window and open new Terminal or Command Prompt and run `flutter doctor -v`.\n',
  );
}

Future<void> installWithOutAndroidStudio({
  @required String javaPath,
  @required String androidPath,
}) async {
  if (javaPath == null) {
    await installJava();
  } else {
    var javaVersion = await checkJavaVersion();
    if (javaVersion != 8) {
      stdout.writeln(
        '[JAVA] Java $javaVersion already installed, but this version is not recommended, '
        'please use version 8 or uninstall this java and use the default from Android Studio.',
      );
    }
  }
  if (androidPath == null) {
    await installAndroid();
  } else {
    await updateAndroid(toolsPath: Directory(androidPath).parent.path);
  }
}
