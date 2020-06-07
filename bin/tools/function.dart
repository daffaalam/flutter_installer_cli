import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:archive/archive.dart';
import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/shell_run.dart' as s;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../model/flutter_releases.dart';
import '../model/java_releases.dart';

bool isDebug = false;
String installationPath = '';
Map<String, String> environment = <String, String>{};
String githubRepos = 'https://github.com/daffaalam/flutter_installer_cli';

Future<bool> checkPowerShell() async {
  try {
    var result = await run(
      'powershell \$Host.Version.Major',
      [],
      verbose: isDebug,
      stdin: s.sharedStdIn,
    );
    var version = '${result.stdout ?? result.stderr}';
    return (int.tryParse(version) ?? 0) >= 5;
  } catch (e) {
    return false;
  }
}

Future<void> withOutAndroidStudio({
  @required String javaPath,
  @required String androidPath,
  @required String operatingSystem,
}) async {
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
}

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
  String content = '',
  @required String urlPath,
  @required String savePath,
}) async {
  stdout.writeln('[$title] Downloading $content [START]');
  try {
    var _response = await Dio().download(
      '$urlPath',
      '$savePath',
      onReceiveProgress: (int count, int total) {
        var percent = (count / total * 100).toStringAsFixed(0);
        stdout.write('\r' '[$title] Receive $count Of $total ($percent%)');
        if (count == total) {
          stdout.write('\n[$title] Downloading $content [FINISH]\n');
        }
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
  String content = '',
  @required String filePath,
  @required String savePath,
}) async {
  stdout.writeln('[$title] Extracting $content [START]');
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
    stdout.write('\n[$title] Extracting $content [FINISH]\n');
  } catch (e) {
    await errorLog(e);
  }
}

Future<bool> checkAndroidStudio() async {
  try {
    var studioPath = '';
    var setDir = await Directory('$userHomePath').list().toSet();
    for (var dir in setDir) {
      if (dir.path.contains('.AndroidStudio')) studioPath = dir.path;
    }
    var studio = await Directory(studioPath).exists();
    var version = studioPath.replaceAll('$userHomePath\\.AndroidStudio', '');
    var home = await File('$studioPath\\system\\.home').readAsString();
    stdout.writeln(
      '[STUDIO] Android Studio $version already installed on ${home.trim()}',
    );
    return studio;
  } catch (e) {
    return false;
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
          content: 'Flutter ${releases.version}',
          urlPath: '${flutterReleases.baseUrl}/${releases.archive}',
          savePath: flutterZipPath,
        );
      }
      await extractZip(
        title: 'FLUTTER',
        content: 'Flutter ${releases.version}',
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
      content: 'Java ${binary.versionData.semver}',
      urlPath: binary.binaryLink,
      savePath: javaZipPath,
    );
  }
  await extractZip(
    title: 'JAVA',
    content: 'Java ${binary.versionData.semver}',
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
      content: 'Android Tools 26.1.1',
      urlPath: 'https://dl.google.com/android/repository/$androidZipName',
      savePath: androidZipPath,
    );
  }
  await extractZip(
    title: 'ANDROID',
    content: 'Android Tools 26.1.1',
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
  stdout.writeln('[ANDROID] Installing and Updating [START]');
  var repoConfig = '$userHomePath\\.android\\repositories.cfg';
  var exists = await File(repoConfig).exists();
  if (!exists) {
    await File(repoConfig).create(
      recursive: true,
    );
  }
  await runSdkManager(
    content: 'Installing Platform Tools',
    arg: 'platform-tools',
    verbose: isDebug,
    toolsPath: toolsPath,
  );
  await runSdkManager(
    content: 'Installing Platform Android 29',
    arg: 'platforms;android-29',
    verbose: isDebug,
    toolsPath: toolsPath,
  );
  await runSdkManager(
    content: 'Installing Build Tools 29.0.3',
    arg: 'build-tools;29.0.3',
    verbose: isDebug,
    toolsPath: toolsPath,
  );
  await runSdkManager(
    content: 'Checking for update',
    arg: '--update',
    verbose: isDebug,
    toolsPath: toolsPath,
  );
  await runSdkManager(
    content: 'Checking for licenses',
    arg: '--licenses',
    verbose: isDebug,
    toolsPath: toolsPath,
  );
  stdout.writeln('[ANDROID] Installed and Updated [FINISH]');
}

Future<void> runSdkManager({
  String content = '',
  String arg = '',
  bool verbose = false,
  @required String toolsPath,
}) async {
  stdout.writeln('[ANDROID] $content');
  try {
    var accScript = 'for(\$i=0;\$i -lt 15;\$i++)'
        ' { \$response += "y`n" }; '
        '\$response'
        ' | '
        '.\\sdkmanager $arg';
    await run(
      'powershell $accScript',
      [],
      workingDirectory: toolsPath,
      environment: environment,
      verbose: verbose,
    );
  } catch (e) {
    await errorLog(e);
  }
}

Future<void> setPathEnvironment({
  String title = 'unknown',
  @required String newPath,
}) async {
  var finalPath = fixPath('${environment['PATH']};$newPath');
  await setVariableEnvironment(
    title: title,
    variable: 'PATH',
    value: '$finalPath',
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
    stdout.writeln('[$title] Updated $variable successfully');
  } else {
    stderr.writeln('[$title] Failed to update $variable');
    await errorLog(verbose);
  }
  var finalPath = fixPath('${environment[variable]};$value');
  environment.addAll(
    <String, String>{
      variable: '$finalPath',
    },
  );
}

String fixPath(String oldPath) {
  var path = '';
  var oldSplit = oldPath?.split(';')?.toSet() ?? <String>{};
  for (var i = 0; i < oldSplit.length; i++) {
    var newPath = oldSplit?.toList()[i] ?? '';
    if (newPath.isNotEmpty && newPath != 'null') {
      path += '${oldSplit.toList()[i]};';
    }
  }
  if (path.endsWith(';')) {
    path = path.replaceRange(path.length - 1, null, '');
  }
  return path;
}

void showText(String text) {
  var border = String.fromCharCodes(
    List<int>.generate(
      (stdout.terminalColumns - text.length) ~/ 2,
      (index) => 61,
    ),
  );
  stdout.write(
    '\n' + border + text + border + '\n',
  );
}

Future<void> vscodeInstallExtension() async {
  try {
    stdout.writeln('[VSCODE] Installing extensions [START]');
    var args = <String>[
      '--install-extension dart-code.flutter --force',
      '--install-extension dart-code.dart-code --force',
    ];
    var result = await run(
      'code ${args.join(' ')}',
      [],
      verbose: isDebug,
    );
    var verbose = '${result.stdout ?? result.stderr}'.toLowerCase();
    if (verbose.contains('failed')) {
      stdout.writeln('[VSCODE] Failed installing extensions [FINISH]');
    } else {
      stdout.writeln('[VSCODE] Extension was successfully installed [FINISH]');
    }
  } catch (e) {
    await errorLog(e);
  }
}

Future<void> checkLatestVersion() async {
  try {
    var response = await Dio(
      BaseOptions(
        responseType: ResponseType.plain,
      ),
    ).get(
      'https://raw.githubusercontent.com/daffaalam/flutter_installer_cli/master/pubspec.yaml',
    );
    var cloudVer = Version.parse(loadYaml(response.data)['version']);
    var localVer = Version.parse('0.2.2');
    if (cloudVer > localVer) {
      stdout.writeln(
        '\nThe latest version found, please use the latest version for a better experience.\n'
        'Download it at $githubRepos/releases/latest.',
      );
      var ignore = await promptConfirm('Continue with the old version');
      if (!ignore) exit(0);
      stdout.write('\n');
    }
  } catch (e) {
    stdout.writeln('\nCan not find the latest version.\n');
  }
}

Future<Null> errorLog(e) async {
  var logFile = File('flutter_installer_error.log');
  await logFile.writeAsString(
    '${DateTime.now()}\t: $e\n${StackTrace.current}\n',
    mode: FileMode.append,
  );
  stderr.writeln(
    'Sorry. Failed to install.\n$e\n'
    'Please send an error log (${logFile.absolute.path}) to the github issue ($githubRepos/issues).\n'
    'Close this window or double `Enter`.',
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
