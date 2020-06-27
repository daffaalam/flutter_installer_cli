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

void parseArgs(List<String> args) {
  var parse = ArgParser();
  parse.addOption(
    'channel',
    valueHelp: 'flutter channel',
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
    valueHelp: 'flutter version',
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

Future<void> logNewRun() async {
  if (isDebug) return;
  var cont = await promptConfirm(
    '\nBefore continuing this, double-check the tools needed to run the Flutter.\n'
    'https://flutter.dev/docs/get-started/install/${Platform.operatingSystem}#system-requirements',
  );
  if (!cont) exit(0);
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
  environment.addAll(Platform.environment);
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
  savePath = Directory(fixPathPlatform(savePath)).absolute.path;
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
  filePath = fixPathPlatform(filePath);
  savePath = Directory(fixPathPlatform(savePath)).absolute.path;
  if (filePath.endsWith('.tar.xz')) {
    filePath = File(filePath).absolute.path;
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
    var existsNew = await Directory(archive[0].name).exists();
    if (existsNew) await Directory(archive[0].name).rename(oldName);
    for (var i = 0; i < archive.length; i++) {
      var files = archive[i];
      var filename = files.name;
      stdout.write('\r' '[$title] Create ${i + 1} Of ${archive.length}');
      if (files.isFile) {
        var file = File(savePath + filename);
        await file.create(recursive: true);
        await file.writeAsBytes(files.content as List<int>);
      } else {
        await Directory(savePath + filename).create(recursive: true);
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
    value: '$path',
  );
}

Future<void> setVariableEnvironment({
  String title = 'unknown',
  @required String variable,
  @required String value,
}) async {
  value = fixPathPlatform(value);
  if (Platform.isWindows) {
    var result = await run(
      'setx',
      ['$variable', '$value'],
      verbose: verboseShow,
    );
    var verbose = fixVerbose(result.stdout, result.stderr);
    if (verbose.contains('SUCCESS')) {
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
  environment.addAll(
    <String, String>{
      variable: fixPath('${environment[variable]};$value'),
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
  toolsPath = Directory(toolsPath).absolute.path;
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
    workingDirectory: toolsPath,
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
  oldPath = fixPathPlatform(oldPath);
  var path = '';
  var pattern = Platform.isWindows ? ';' : ':';
  var oldSplit = oldPath?.split(pattern)?.toSet() ?? <String>{};
  for (var i = 0; i < oldSplit.length; i++) {
    var newPath = oldSplit?.toList()[i] ?? '';
    if (newPath.isNotEmpty && newPath != 'null') {
      path += '${oldSplit.toList()[i]}$pattern';
    }
  }
  if (path.endsWith(pattern)) {
    path = path.replaceRange(path.length - 1, null, '');
  }
  return path.trim();
}

String fixPathPlatform(String path) {
  path = Platform.isWindows
      ? path.replaceAll('/', '\\')
      : path.replaceAll('\\', '/');
  path = Platform.isWindows
      ? path.replaceAll(':', ';')
      : path.replaceAll(';', ':');
  return path;
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

Future<Null> errorLog(e, s) async {
  var logFile = File('flutter_installer_error.log');
  await logFile.writeAsString(
    '${DateTime.now()}\n$e\n$s\n'.trim(),
    mode: FileMode.writeOnlyAppend,
  );
  stderr.writeln(
    '\n'
    'Sorry. Failed to install.\n$e\n'
    'Please send an error log to the github issue ($githubRepos/issues).\n'
    'File: ${logFile.absolute.path}.\n'
    'Close this window or double `Enter`.',
  );
  if (isDebug) return;
  s ??= StackTrace.current;
  var context = Contexts(
    operatingSystem: OperatingSystem(
      version: Platform.operatingSystemVersion,
    ),
  );
  await sentryClient.capture(
    event: Event(
      release: '$version',
      exception: e,
      stackTrace: s,
      contexts: context,
    ),
  );
}
