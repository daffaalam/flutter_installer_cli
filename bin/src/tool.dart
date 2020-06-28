import 'dart:io';

import 'package:archive/archive.dart';
import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/shell_run.dart' as shell_run;
import 'package:pub_semver/pub_semver.dart';
import 'package:sentry/sentry.dart';
import 'package:yaml/yaml.dart';

import '../model/flutter_releases.dart';
import 'config.dart';
import 'exception.dart';

void parseArgs(List<String> args) {
  var parse = ArgParser();
  parse.addOption(
    'path',
    valueHelp: 'custom-path',
    defaultsTo: defaultInstallationPath(),
    callback: initInstallationPath,
  );
  parse.addOption(
    'channel',
    valueHelp: 'flutter-channel',
    help: 'If the version and channel do not find a match, '
        'it will retrieve the latest this channel version.',
    allowed: <String>['stable', 'beta', 'dev'],
    defaultsTo: 'stable',
    callback: (String value) {
      value ??= '';
      flutterChannel = value;
    },
  );
  parse.addOption(
    'version',
    help: 'Use version naming format from Flutter SDK Releases '
        '(https://flutter.dev/docs/development/tools/sdk/releases). '
        'Example: --version v1.9.1+hotfix.6\n'
        '(defaults to check the latest version)',
    valueHelp: 'flutter-version',
    callback: (String value) {
      value ??= '';
      flutterVersion = value;
    },
  );
  parse.addFlag(
    'verbose',
    abbr: 'v',
    defaultsTo: false,
    negatable: false,
    callback: (bool value) {
      verboseShow = value;
    },
  );
  parse.addFlag(
    'debug',
    abbr: 'd',
    defaultsTo: false,
    negatable: false,
    callback: (bool value) {
      verboseShow = value;
      isDebug = value;
    },
    hide: true,
  );
  try {
    parse.parse(args);
  } on ArgParserException {
    stdout.writeln('${parse.usage}');
    exit(1);
  }
}

String defaultInstallationPath() {
  var path = Platform.isWindows ? userHomePath.split('\\')[0] : userHomePath;
  path += '/Development';
  return fixPathPlatform(path, Directory);
}

Future<void> initInstallationPath(String path) async {
  path ??= '';
  if (path.isEmpty) {
    installationPath = defaultInstallationPath();
  } else {
    path = path.replaceFirst('~', userHomePath);
    installationPath = fixPathPlatform(path, Directory);
  }
}

Future<void> logNewRun() async {
  environment.addAll(Platform.environment);
  var cont = await promptConfirm(
    '\nBefore continuing this, double-check the tools needed to run the Flutter.\n'
    'https://flutter.dev/docs/get-started/install/${Platform.operatingSystem}#system-requirements',
  );
  if (!cont) exit(0);
  try {
    if (isDebug) return;
    await sentryClient.capture(
      event: Event(
        loggerName: 'New Run',
        release: '$version',
        message: 'New Run',
        level: SeverityLevel.info,
        culprit: 'New Run',
        contexts: Contexts(
          operatingSystem: OperatingSystem(
            name: Platform.operatingSystem,
            version: Platform.operatingSystemVersion,
          ),
        ),
      ),
    );
  } catch (e) {}
}

Future<bool> checkPowerShell() async {
  try {
    var result = await run(
      'powershell \$Host.Version.Major',
      [],
      verbose: verboseShow,
      stdin: shell_run.sharedStdIn,
    );
    var version = fixVerbose(result.stdout, result.stderr);
    return (int.tryParse(version) ?? 0) >= 5;
  } catch (e) {
    return false;
  }
}

Future<void> checkLatestVersion() async {
  try {
    var dio = Dio(BaseOptions(responseType: ResponseType.plain));
    var response = await dio.get('$githubRepos/raw/master/pubspec.yaml');
    var cloudVer = Version.parse(loadYaml(response.data)['version']);
    if (cloudVer > version) {
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

Future<Response> downloadFile({
  String title = 'unknown',
  String content = 'unknown',
  Map<String, String> queryParam = const <String, String>{},
  @required String urlPath,
  @required String savePath,
}) async {
  stdout.writeln('[$title] Downloading $content [START]');
  var _response = await Dio().download(
    urlPath,
    savePath,
    onReceiveProgress: (int count, int total) {
      var percent = (count / total * 100).toStringAsFixed(0);
      stdout.write('\r' '[$title] Receive $count Of $total ($percent%)');
      if (count == total) {
        stdout.write('\n[$title] Downloading $content [FINISH]\n');
      }
    },
    queryParameters: queryParam,
  );
  return _response;
}

Future<void> extractZip({
  String title = 'unknown',
  String content = 'unknown',
  @required String filePath,
  @required String savePath,
}) async {
  stdout.writeln('[$title] Extracting $content [START]');
  savePath = fixPathPlatform(savePath, Directory);
  if (filePath.endsWith('.tar.xz')) {
    await run(
      'tar',
      ['-xf', filePath],
      workingDirectory: savePath,
      verbose: true,
    );
  } else {
    var bytes = await File(filePath).readAsBytes();
    var archive = Archive();
    if (filePath.endsWith('.zip')) {
      archive = ZipDecoder().decodeBytes(bytes);
    }
    if (filePath.endsWith('.tar.gz')) {
      archive = TarDecoder().decodeBytes(
        GZipDecoder().decodeBytes(bytes),
      );
    }
    var dirName = archive[0].name;
    var oldName = dirName.replaceRange(dirName.length - 1, null, '') + '.old';
    var existsOld = await Directory(oldName).exists();
    if (existsOld) await Directory(oldName).delete(recursive: true);
    var existsNew = await Directory(dirName).exists();
    if (existsNew) await Directory(dirName).rename(oldName);
    for (var i = 0; i < archive.length; i++) {
      stdout.write('\r' '[$title] Create ${i + 1} Of ${archive.length}');
      var files = archive[i];
      var filename = savePath + files.name;
      if (files.isFile) {
        var file = File(filename);
        await file.create(recursive: true);
        await file.writeAsBytes(files.content as List<int>);
      } else {
        await Directory(filename).create(recursive: true);
      }
    }
  }
  if (!Platform.isWindows) await run('chmod', ['-R', '+x', savePath]);
  stdout.write('\n[$title] Extracting $content [FINISH]\n');
}

Future<void> setPathEnvironment({
  String title = 'unknown',
  @required String newPath,
}) async {
  var path = '';
  if (Platform.isWindows) {
    path = fixPath('${environment['PATH']};$newPath');
  } else {
    path = newPath;
  }
  await setVariableEnvironment(
    title: title,
    variable: 'PATH',
    value: path,
  );
}

Future<void> setVariableEnvironment({
  String title = 'unknown',
  @required String variable,
  @required String value,
}) async {
  value = fixPathPlatform(value, File);
  if (Platform.isWindows) {
    var result = await run(
      'setx',
      ['$variable', '$value'],
      verbose: verboseShow,
    );
    var verbose = fixVerbose(result.stdout, result.stderr);
    if (verbose.toUpperCase().contains('SUCCESS')) {
      stdout.writeln('[$title] Updated $variable successfully');
    } else {
      stderr.writeln('[$title] Failed to update $variable');
    }
  } else {
    var bashProfile = File('$userHomePath/.bashrc');
    var exists = await bashProfile.exists();
    if (!exists) await bashProfile.create(recursive: true);
    var lines = await bashProfile.readAsLines();
    var contains = false;
    for (var line in lines) {
      line = line.toUpperCase();
      var v1 = variable.toUpperCase();
      var v2 = value.toUpperCase();
      if (line.contains(v1) && line.contains(v2)) contains = true;
    }
    if (!contains) {
      var script = variable == 'PATH' ? '$variable=\$$variable:' : '$variable=';
      await bashProfile.writeAsString(
        '\nexport $script$value',
        mode: FileMode.writeOnlyAppend,
      );
      stdout.writeln('[$title] Updated $variable successfully');
    }
  }
  value = fixPath('${environment[variable]};$value');
  environment.addAll(
    <String, String>{
      variable: fixPath(value),
    },
  );
}

Future<void> runSdkManager({
  String content = '',
  String arg = '',
  bool verbose = false,
  @required String toolsPath,
}) async {
  stdout.writeln('[ANDROID] $content');
  var script = '';
  if (Platform.isWindows) {
    var accScript = 'for(\$i=0;\$i -lt 15;\$i++)'
        ' { \$response += "y`n" }; '
        '\$response | .\\sdkmanager $arg';
    script = 'powershell $accScript';
  } else {
    script = './sdkmanager';
  }
  await run(
    script,
    !Platform.isWindows ? [arg] : [],
    workingDirectory: fixPathPlatform(toolsPath, Directory),
    environment: environment,
    stdin: !Platform.isWindows ? shell_run.sharedStdIn : null,
    verbose: !Platform.isWindows ? true : verbose,
  );
}

Release fixFlutterVersion(FlutterReleases flutterReleases) {
  for (var release in flutterReleases.releases) {
    var isVersion = release.version == flutterVersion;
    var isChannel = release.channel == channelValues.map[flutterChannel];
    if (isVersion && isChannel) return release;
  }
  for (var release in flutterReleases.releases) {
    var isChannel = release.channel == channelValues.map[flutterChannel];
    if (isChannel) return release;
  }
  for (var release in flutterReleases.releases) {
    if (flutterReleases.currentRelease.stable == release.hash) return release;
  }
  return flutterReleases.releases.last;
}

String fixPath(String oldPath) {
  if (!Platform.isWindows) oldPath = oldPath.replaceAll(';', ':');
  oldPath = fixPathPlatform(oldPath, File);
  var path = '';
  var pattern = Platform.isWindows ? ';' : ':';
  var splitOld = oldPath?.split(pattern)?.toSet() ?? <String>{};
  for (var i = 0; i < splitOld.length; i++) {
    var pathNew = splitOld?.toList()[i] ?? '';
    if (pathNew.isNotEmpty && pathNew != 'null') {
      path += '${fixPathPlatform(splitOld.toList()[i], File)}$pattern';
    }
  }
  if (path.endsWith(pattern)) {
    path = path.replaceRange(path.length - 1, null, '');
  }
  return path.trim();
}

String fixPathPlatform(String path, Type isDirectory) {
  path = Platform.isWindows
      ? path.replaceAll('/', '\\')
      : path.replaceAll('\\', '/');
  path = path.replaceAll('//', '/');
  path = path.replaceAll('\\\\', '\\');
  if (path.endsWith(Platform.pathSeparator)) {
    path = path.replaceRange(path.length - 1, null, '');
  }
  return isDirectory == Directory ? path + Platform.pathSeparator : path;
}

String fixVerbose(String out, String err) {
  out ??= '';
  err ??= '';
  return '${out.isEmpty ? err : out}'.trim();
}

void showText(String text) {
  var length = 0;
  try {
    length = (stdout.terminalColumns - text.length) ~/ 2;
  } catch (e) {
    length = 10;
  }
  var border = String.fromCharCodes(
    List<int>.generate(length, (index) => 61),
  );
  stdout.write(
    '\n' + border + text + border + '\n',
  );
}

Future<Null> errorLog(dynamic e, StackTrace s) async {
  var tempLog = fixPathPlatform(runDir + '/flutter_installer_error.log', File);
  var logFile = File(tempLog);
  var exception = exceptionLog(e);
  s ??= StackTrace.current;
  await logFile.writeAsString(
    '${DateTime.now()}\n$e\n$s\n',
    mode: FileMode.writeOnlyAppend,
  );
  stderr.writeln(
    '\n'
    'Sorry. Failed to install.\n$exception\n'
    'Please send an error log to the github issue ($githubRepos/issues).\n'
    'File: ${logFile.absolute.path}.\n'
    'Close this window or double `Enter`.',
  );
  var context = Contexts(
    operatingSystem: OperatingSystem(
      name: Platform.operatingSystem,
      version: Platform.operatingSystemVersion,
    ),
  );
  try {
    if (isDebug) return;
    await sentryClient.capture(
      event: Event(
        release: '$version',
        exception: e,
        stackTrace: s,
        contexts: context,
      ),
    );
  } catch (e) {}
}
