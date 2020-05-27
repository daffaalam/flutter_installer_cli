import 'dart:io';

import 'package:process_run/process_run.dart';
import 'package:process_run/which.dart';

import 'model/flutter_releases.dart';
import 'model/java_releases.dart';
import 'tools/api_client.dart';
import 'tools/extractor.dart';

String installationPath;
String operatingSystem;
Binary javaBinary;

void main() async {
  operatingSystem = Platform.operatingSystem;

  // find tools
  var _flutterPath = await which('flutter');
  var _dartPath = await which('dart');
  var _javaPath = await which('java');
  var _androidPath = await which('sdkmanager');
  var _gitPath = await which('git');

  if (_flutterPath == null) {
    var root = Directory.current.path.split('\\')[0];
    installationPath = (Platform.isWindows ? '$root\\' : '~/') + 'Development';
    await Directory(installationPath).exists().then(
      (bool exists) {
        if (!exists) Directory(installationPath).create();
      },
    );
    if (_javaPath == null) {
      await installJava();
    }
    await installFlutter();
  } else {
    installationPath = _flutterPath.replaceFirst(
        Platform.isWindows
            ? 'flutter\\bin\\flutter.bat'
            : 'flutter/bin/flutter',
        '');
    await run(
      'flutter',
      ['upgrade'],
      verbose: true,
    );
    if (_dartPath == null) {}
  }

  if (_androidPath == null) {
    await installAndroid();
  } else {
    await updateAndroid(
      haveSdkManager: true,
      haveJava: _javaPath != null,
    );
  }

  // TODO : change language
  if (_gitPath == null) {
    await print(
      '(Optional) You can install git versioning from https://git-scm.com/downloads',
    );
  }

  await stdout.write(
    '\nFINISH...\nPlease exit this window and open new Terminal or Command Prompt and run `flutter doctor -v`...\n',
  );
  await stdin.readLineSync();
}

Future<void> installJava() async {
  // check latest version from API
  print('Checking latest version...');
  var _javaReleases = await ApiClient.getJavaLatestInfo(
    operatingSystem: operatingSystem,
  );
  // get latest release version
  var binary = _javaReleases.binaries[0];
  var javaZipPath = '${Directory.current.path}\\${binary.binaryName}';
  await File(javaZipPath).exists().then(
    (bool exists) async {
      if (!exists) {
        // download openjdk as .msi or .dmg
        print('Downloading OpenJDK...');
        await ApiClient.downloadFile(
          urlPath: binary.binaryLink,
          savePath: javaZipPath,
        );
      }
    },
  );
  javaBinary = binary;
  // print('Installing OpenJDK...');
  // await run(
  //   'msiexec',
  //   [
  //     '/i',
  //     javaMsiPath,
  //     'INSTALLLEVEL=3',
  //   ],
  //   verbose: true,
  //   runInShell: true,
  // );
  // extract flutter sdk

  print('Extracting OpenJDK...');
  await Extractor.extractZip(
    filePath: javaZipPath,
    savePath: '${installationPath}/',
  );
  print('Set Java SDK to Environment...');
  var javaPackage = '${javaBinary.binaryType}'
      '${javaBinary.versionData.openjdkVersion}';
  await run(
    'setx',
    [
      'JAVA_HOME',
      '$installationPath\\$javaPackage',
    ],
    verbose: true,
    runInShell: true,
  );
  await setPathEnvironment();
}

Future<void> installFlutter() async {
  // check latest version from API
  print('Checking latest version...');
  var _flutterReleases = await ApiClient.getFlutterLatestInfo(
    operatingSystem: operatingSystem,
  );

  // get latest stable version
  for (var releases in _flutterReleases?.releases) {
    if (_flutterReleases.currentRelease.stable == releases.hash) {
      var flutterZipPath = '${releases.archive}'.replaceFirst(
        '${channelValues.reverse[Channel.STABLE]}/${operatingSystem}',
        Directory.current.path,
      );
      await File(flutterZipPath).exists().then(
        (bool exists) async {
          if (!exists) {
            // download flutter sdk as .zip or .tar.xz
            print('Downloading Flutter SDK...');
            await ApiClient.downloadFile(
              urlPath: '${_flutterReleases.baseUrl}/${releases.archive}',
              savePath: flutterZipPath,
            );
          }
        },
      );
      // extract flutter sdk
      print('Extracting Flutter SDK...');
      await Extractor.extractZip(
        filePath: flutterZipPath,
        savePath: '${installationPath}/',
      );
      print('Set Flutter SDK to PATH...');
      await setPathEnvironment();
    }
  }
}

Future<void> installAndroid() async {
  // use this old sdk tools for fixing Android Licenses
  var androidZipName = 'sdk-tools-windows-4333796.zip';
  var androidZipPath = '${Directory.current.path}/$androidZipName';
  await File(androidZipPath).exists().then(
    (bool exists) async {
      if (!exists) {
        // download android tools as .zip
        print('Downloading Android Tools...');
        await ApiClient.downloadFile(
          urlPath: 'https://dl.google.com/android/repository/$androidZipName',
          savePath: androidZipPath,
        );
      }
    },
  );
  // extract android tools
  print('Extracting Android Tools...');
  await Extractor.extractZip(
    filePath: androidZipPath,
    savePath: '${installationPath}/',
  );
  print('Set Android Tools to Environment...');
  await run(
    'setx',
    [
      'ANDROID_HOME',
      '${installationPath}',
    ],
    verbose: true,
    runInShell: true,
  );
  await run(
    'setx',
    [
      'ANDROID_SDK_ROOT',
      '${installationPath}\\tools',
    ],
    verbose: true,
    runInShell: true,
  );
  await setPathEnvironment();
  print('Updating Android Tools...');
  await updateAndroid(
    toolsPath: '${installationPath}\\tools',
  );
}

Future<void> updateAndroid({
  bool haveSdkManager = false,
  bool haveJava = false,
  String toolsPath = '',
}) async {
  var userProfile = Directory.systemTemp.path.replaceFirst(
    '\\AppData\\Local\\Temp',
    '',
  );
  await File('$userProfile\\.android\\repositories.cfg').exists().then(
    (bool exists) {
      if (!exists) File('$userProfile\\.android\\repositories.cfg').create();
    },
  );
  var javaPackage = '${javaBinary.binaryType}'
      '${javaBinary.versionData.openjdkVersion}';
  var javaHome =
      Platform.environment['JAVA_HOME'] ?? '${installationPath}\\$javaPackage';
  var javaDir = '$javaHome\\bin';
  await run(
    haveSdkManager ? 'sdkmanager' : '$toolsPath\\bin\\sdkmanager',
    [
      'platform-tools',
      'platforms;android-29',
      'build-tools;29.0.3',
    ],
    verbose: true,
    runInShell: true,
    environment: <String, String>{
      'JAVA_HOME': javaHome,
      !haveJava ? 'PATH' : '': !haveJava ? javaDir : '',
    },
  );
  await run(
    haveSdkManager ? 'sdkmanager' : '$toolsPath\\bin\\sdkmanager',
    ['--update'],
    verbose: true,
    runInShell: true,
    environment: <String, String>{
      'JAVA_HOME': javaHome,
      !haveJava ? 'PATH' : '': !haveJava ? javaDir : '',
    },
  );
  await run(
    haveSdkManager ? 'sdkmanager' : '$toolsPath\\bin\\sdkmanager',
    ['--licenses'],
    verbose: true,
    runInShell: true,
    environment: <String, String>{
      'JAVA_HOME': javaHome,
      !haveJava ? 'PATH' : '': !haveJava ? javaDir : '',
    },
  );
}

Future<void> setPathEnvironment({String path}) async {
  // TODO : implement set PATH Environment
}
