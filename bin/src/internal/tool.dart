import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/shell_run.dart' as shell_run;
import 'package:pub_semver/pub_semver.dart';

import '../../model/flutter_releases.dart';
import '../../model/latest_release.dart';
import 'config.dart';
import 'debug.dart';

Future<bool> checkPowerShell() async {
  try {
    var result = await run(
      'powershell \$Host.Version.Major',
      [],
      verbose: verboseShow,
      stdin: shell_run.sharedStdIn,
    );
    var version = fixVerbose(result.stdout, result.stderr);
    await logCat('powershell version $version');
    return (int.tryParse(version) ?? 0) >= 5;
  } catch (e) {
    return false;
  }
}

Future<void> checkLatestVersion() async {
  try {
    var response = await Dio().get(
      'https://api.github.com/repos/daffaalam/flutter_installer_cli/releases/latest',
    );
    var tagName = LatestRelease.fromMap(response.data).tagName;
    var cloudVer = Version.parse(tagName.replaceAll(RegExp('[^0-9.]'), ''));
    if (cloudVer > version) {
      open('$githubRepos/releases/latest');
      stdout.writeln(
        '\nThe latest version found, please use the latest version for a better experience.\n'
        'Download it at $githubRepos/releases/latest.',
      );
      var ignore = await promptConfirm('Continue with the old version');
      if (!ignore) exit(0);
      stdout.write('\n');
    }
    await logCat('check latest version $cloudVer');
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
  var response = await Dio().download(
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
  await logCat('download $savePath from $urlPath');
  return response;
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
  await logCat('extract $filePath to $savePath');
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
  var success = false;
  if (Platform.isWindows) {
    var result = await run(
      'setx',
      ['$variable', fixPath(value)],
      verbose: verboseShow,
    );
    var verbose = fixVerbose(result.stdout, result.stderr);
    if (verbose.toUpperCase().contains('SUCCESS')) {
      stdout.writeln('[$title] Updated $variable successfully');
      success = true;
    } else {
      stderr.writeln('[$title] Failed to update $variable');
    }
  } else {
    var shell = 'bash';
    if (environment['SHELL'] != null) {
      shell = environment['SHELL'].split('/').last;
    }
    var fileRc = '.${shell}rc';
    try {
      var bashProfile = File('$userHomePath/$fileRc');
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
        var script = variable == 'PATH' ? '\$$variable:' : '';
        await bashProfile.writeAsString(
          '\nexport $variable=${script}$value',
          mode: FileMode.writeOnlyAppend,
        );
        stdout.writeln('[$title] Updated $variable on $fileRc successfully');
        success = true;
      }
    } catch (e) {
      stdout.writeln('[$title] Failed to update $variable on $fileRc');
    }
  }
  if (success) {
    value = fixPath('${environment[variable]};$value');
    environment.addAll(
      <String, String>{
        variable: value,
      },
    );
    await logCat('set $variable with $value');
  }
}

Future<void> runSdkManager({
  String content = '',
  @required String arg,
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
  await logCat('sdkmanager $arg');
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

void open(String url) async {
  String command;
  if (Platform.isWindows) command = 'start';
  if (Platform.isLinux) command = 'xdg-open';
  if (Platform.isMacOS) command = 'open';
  try {
    await run(command, [url]);
  } catch (e) {}
}
