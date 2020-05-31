import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:archive/archive.dart';
import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/shell_run.dart' as s;

import '../model/flutter_releases.dart';
import '../model/java_releases.dart';

bool isDebug = false;
String installationPath = '';
Map<String, String> environment = <String, String>{};

Future<FlutterReleases> getFlutterLatestInfo({
  @required String operatingSystem,
}) async {
  stdout.writeln('[FLUTTER] Getting latest version info...');
  try {
    var _response = await Dio().get(
      'https://storage.googleapis.com/flutter_infra/releases/releases_$operatingSystem.json',
    );
    return FlutterReleases.fromMap(_response.data);
  } catch (e) {
    var log = await errorLog(e);
    return log;
  }
}

Future<JavaReleases> getJavaLatestInfo({
  @required String operatingSystem,
}) async {
  stdout.writeln('[JAVA] Getting latest version info...');
  try {
    var _response = await Dio().get(
      'https://api.adoptopenjdk.net/v2/info/releases/openjdk8',
      queryParameters: <String, String>{
        'openjdk_impl': 'hotspot',
        'os': operatingSystem,
        'arch': 'x64',
        'release': 'latest',
        'type': 'jdk',
        'heap_size': 'normal',
      },
    );
    return JavaReleases.fromMap(_response.data);
  } catch (e) {
    var log = await errorLog(e);
    return log;
  }
}

Future<Response> downloadFile({
  String title = 'unknown',
  @required String urlPath,
  @required String savePath,
}) async {
  stdout.writeln('[$title] Downloading...');
  try {
    var _response = await Dio().download(
      '$urlPath',
      '$savePath',
      onReceiveProgress: (int count, int total) {
        var percent = 100 ~/ (total / count);
        stdout.write('\r' '[$title] Receive $count Of $total ($percent%)');
        if (count == total) stdout.write('\n[$title] Download Finish\n');
      },
    );
    return _response;
  } catch (e) {
    var log = await errorLog(e);
    return log;
  }
}

Future<void> extractZip({
  String title = 'unknown',
  @required String filePath,
  @required String savePath,
}) async {
  stdout.writeln('[$title] Extracting...');
  try {
    var archive = ZipDecoder().decodeBytes(
      File(filePath).readAsBytesSync(),
    );
    for (var i = 0; i < archive.length; i++) {
      var files = archive[i];
      var filename = files.name;
      stdout.write('\r' '[$title] Create ${i + 1} Of ${archive.length}');
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
    stdout.write('\n[$title] Extract Finish\n');
  } catch (e) {
    await errorLog(e);
  }
}

Future<void> installFlutter({
  @required String operatingSystem,
}) async {
  var flutterReleases = await getFlutterLatestInfo(
    operatingSystem: operatingSystem,
  );
  for (var releases in flutterReleases?.releases) {
    if (flutterReleases.currentRelease.stable == releases.hash) {
      var flutterZipPath = '${releases.archive}'.replaceFirst(
        '${channelValues.reverse[Channel.STABLE]}/${operatingSystem}',
        Directory.current.path + '\\flutter_installer',
      );
      var exists = await File(flutterZipPath).exists();
      if (!exists) {
        await downloadFile(
          title: 'FLUTTER',
          urlPath: '${flutterReleases.baseUrl}/${releases.archive}',
          savePath: flutterZipPath,
        );
      }
      await extractZip(
        title: 'FLUTTER',
        filePath: flutterZipPath,
        savePath: '${installationPath}\\',
      );
      await setPathEnvironment(
        title: 'FLUTTER',
        newPath: '${installationPath}\\flutter\\bin',
      );
      await setPathEnvironment(
        title: 'FLUTTER',
        newPath: '${installationPath}\\flutter\\bin\\cache\\dart-sdk\\bin',
      );
    }
  }
}

Future<void> installJava({
  @required String operatingSystem,
}) async {
  var javaReleases = await getJavaLatestInfo(
    operatingSystem: operatingSystem,
  );
  var binary = javaReleases.binaries[0];
  var javaZipPath = '${Directory.current.path}'
      '\\flutter_installer\\${binary.binaryName}';
  var exists = await File(javaZipPath).exists();
  if (!exists) {
    await downloadFile(
      title: 'JAVA',
      urlPath: binary.binaryLink,
      savePath: javaZipPath,
    );
  }
  await extractZip(
    title: 'JAVA',
    filePath: javaZipPath,
    savePath: '${installationPath}\\',
  );
  var javaPackage = '${binary.binaryType}'
      '${binary.versionData.openjdkVersion}';
  await setVariableEnvironment(
    title: 'JAVA',
    variable: 'JAVA_HOME',
    value: '$installationPath\\$javaPackage',
  );
  await setPathEnvironment(
    title: 'JAVA',
    newPath: '${installationPath}\\$javaPackage\\bin',
  );
}

Future<void> installAndroid({
  @required String operatingSystem,
}) async {
  var androidZipName = 'sdk-tools-$operatingSystem-4333796.zip';
  var androidZipPath = '${Directory.current.path}'
      '\\flutter_installer\\$androidZipName';
  var exists = await File(androidZipPath).exists();
  if (!exists) {
    await downloadFile(
      title: 'ANDROID',
      urlPath: 'https://dl.google.com/android/repository/$androidZipName',
      savePath: androidZipPath,
    );
  }
  await extractZip(
    title: 'ANDROID',
    filePath: androidZipPath,
    savePath: '$installationPath\\',
  );
  await setVariableEnvironment(
    title: 'ANDROID',
    variable: 'ANDROID_HOME',
    value: '$installationPath',
  );
  await setVariableEnvironment(
    title: 'ANDROID',
    variable: 'ANDROID_SDK_ROOT',
    value: '$installationPath\\tools',
  );
  await setPathEnvironment(
    title: 'ANDROID',
    newPath: '$installationPath\\tools\\bin',
  );
  await setPathEnvironment(
    title: 'ANDROID',
    newPath: '$installationPath\\platform-tools',
  );
  await updateAndroid(
    toolsPath: '$installationPath\\tools\\bin',
  );
}

Future<void> updateAndroid({
  @required String toolsPath,
}) async {
  stdout.writeln('[ANDROID] Updating...');
  var repoConfig = '$userHomePath\\.android\\repositories.cfg';
  var exists = await File(repoConfig).exists();
  if (!exists) await File(repoConfig).create();
  await runSdkManager(
    args: [
      'platform-tools',
      'platforms;android-29',
      'build-tools;29.0.3',
    ],
    verbose: true,
    toolsPath: toolsPath,
  );
  await runSdkManager(
    args: ['--update'],
    verbose: true,
    toolsPath: toolsPath,
  );
  await runSdkManager(
    args: ['--licenses'],
    verbose: true,
    toolsPath: toolsPath,
  );
  stdout.writeln('[ANDROID] Updated');
}

Future<void> runSdkManager({
  List<String> args,
  bool verbose = false,
  @required String toolsPath,
}) async {
  try {
    await run(
      '.\\sdkmanager',
      args,
      workingDirectory: toolsPath,
      environment: environment,
      verbose: verbose,
      stdin: s.sharedStdIn,
    );
  } catch (e) {
    await errorLog(e);
  }
}

Future<void> setPathEnvironment({
  String title = 'unknown',
  @required String newPath,
}) async {
  var oldPath = fixPath(environment['PATH']);
  await setVariableEnvironment(
    title: title,
    variable: 'PATH',
    value: '$oldPath$newPath',
  );
}

Future<void> setVariableEnvironment({
  String title = 'unknown',
  @required String variable,
  @required String value,
}) async {
  var result = await run(
    'setx',
    [
      '$variable',
      '$value',
    ],
    verbose: isDebug,
  );
  var verbose = '${result.stdout ?? result.stderr}';
  if (verbose.contains('SUCCESS')) {
    stdout.writeln('[$title] Success update $variable');
  } else {
    stderr.writeln(verbose);
    await errorLog(verbose);
  }
  var fixValue = fixPath(environment[variable]);
  environment.addAll(
    <String, String>{
      variable: '$fixValue$value',
    },
  );
}

String fixPath(String oldPath) {
  var path = '';
  var oldSplit = oldPath?.split(';')?.toSet() ?? <String>{};
  for (var i = 0; i < oldSplit.length; i++) {
    if (oldSplit.toList()[i].isNotEmpty) path += '${oldSplit.toList()[i]};';
  }
  return path;
}

Future<void> finish() async {
  var text = ' FINISH ';
  var border = String.fromCharCodes(
    List<int>.generate(
      (stdout.terminalColumns - text.length) ~/ 2,
      (index) => 61,
    ),
  );
  stdout.write(
    '\n' + border + text + border + '\n',
  );
  stdin.readLineSync();
  exit(0);
}

Future<Null> errorLog(e) async {
  var logFile = File('flutter_installer_error.log');
  await logFile.writeAsString(
    '${DateTime.now()}\t: $e\n${StackTrace.current}\n',
    mode: FileMode.append,
  );
  stderr.write(
    'Sorry. Failed to install.\n$e\nPlease send log file (${logFile.absolute.path})',
  );
  stdin.readLineSync();
  exit(2);
}

/* uncomment for debugging only
Future<Null> debugLog(e) async {
  var logFile = File('flutter_installer_debug.log');
  await logFile.writeAsString(
    '${DateTime.now()}\t: $e\n',
    mode: FileMode.append,
  );
}
*/
