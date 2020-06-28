import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:xml/xml.dart';

import '../config.dart';
import '../tool.dart';

Future<void> installAndroid() async {
  // please stay this version for this issue
  // https://github.com/flutter/flutter/issues/51712
  // https://stackoverflow.com/questions/60460429/android-studio-installs-without-sdkmanager
  var os = Platform.isMacOS ? 'darwin' : Platform.operatingSystem;
  var androidZipName = 'sdk-tools-$os-4333796.zip';
  var androidZipPath = fixPathPlatform(downloadDir + androidZipName, File);
  var exists = await File(androidZipPath).exists();
  if (!exists) {
    await downloadFile(
      title: 'ANDROID',
      content: 'Android Tools 26.1.1',
      urlPath: 'https://dl.google.com/android/repository/$androidZipName',
      savePath: androidZipPath,
    );
  }
  await extractZip(
    title: 'ANDROID',
    content: 'Android Tools 26.1.1',
    filePath: androidZipPath,
    savePath: installationPath,
  );
  await setVariableEnvironment(
    title: 'ANDROID',
    variable: 'ANDROID_HOME',
    value: '$installationPath',
  );
  await setVariableEnvironment(
    title: 'ANDROID',
    variable: 'ANDROID_SDK_ROOT',
    value: '$installationPath/tools',
  );
  await setPathEnvironment(
    title: 'ANDROID',
    newPath: '$installationPath/tools/bin',
  );
  await setPathEnvironment(
    title: 'ANDROID',
    newPath: '$installationPath/platform-tools',
  );
  await updateAndroid(
    toolsPath: '$installationPath/tools/bin',
  );
}

Future<void> updateAndroid({
  @required String toolsPath,
}) async {
  stdout.writeln('[ANDROID] Installing and Updating [START]');
  var repoConfig = fixPathPlatform(
    '$userHomePath/.android/repositories.cfg',
    File,
  );
  var exists = await File(repoConfig).exists();
  if (!exists) await File(repoConfig).create(recursive: true);
  await runSdkManager(
    content: 'Installing platform-tools',
    arg: 'platform-tools',
    verbose: verboseShow,
    toolsPath: toolsPath,
  );
  var platformAndroid = await checkLatestAndroidSdk(
    androidTool: 'platforms;android-',
  );
  await runSdkManager(
    content: 'Installing $platformAndroid',
    arg: platformAndroid,
    verbose: verboseShow,
    toolsPath: toolsPath,
  );
  var buildTool = await checkLatestAndroidSdk(
    androidTool: 'build-tools;',
  );
  await runSdkManager(
    content: 'Installing $buildTool',
    arg: buildTool,
    verbose: verboseShow,
    toolsPath: toolsPath,
  );
  await runSdkManager(
    content: 'Checking for update',
    arg: '--update',
    verbose: verboseShow,
    toolsPath: toolsPath,
  );
  await runSdkManager(
    content: 'Checking for licenses',
    arg: '--licenses',
    verbose: verboseShow,
    toolsPath: toolsPath,
  );
  stdout.writeln('[ANDROID] Installed and Updated [FINISH]');
}

Future<String> checkLatestAndroidSdk({
  String androidTool,
}) async {
  var dio = Dio(BaseOptions(responseType: ResponseType.plain));
  var response = await dio.get(
    'https://dl.google.com/android/repository/repository2-1.xml',
  );
  var xml = XmlDocument.parse(response.data);
  var remotePackage = xml.findAllElements('remotePackage');
  var tools = [];
  for (var package in remotePackage) {
    if (package.getAttribute('obsolete') != 'true') {
      var path = package.getAttribute('path');
      if (path.contains(androidTool)) {
        path = path.replaceAll(androidTool, '');
        var version = androidTool.contains('android-')
            ? int.tryParse(path)
            : Version.parse(path);
        tools.add(version);
      }
    }
  }
  tools.sort();
  return '$androidTool${tools.last}';
}

Future<bool> checkAndroidTools({
  @required String toolsPath,
}) async {
  try {
    var result = await run(
      fixPathPlatform('./sdkmanager', File),
      ['--version'],
      workingDirectory: toolsPath,
      environment: environment,
    );
    var verbose = fixVerbose(result.stdout, result.stderr);
    var version = Version.parse(verbose);
    var constraint = VersionConstraint.parse('>=25.3.1 <=26.1.1');
    return !version.allowsAny(constraint);
  } catch (e) {
    return false;
  }
}
