import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:archive/archive.dart';
import 'package:args/args.dart';
import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/shell_run.dart' as shell_run;
import 'package:pub_semver/pub_semver.dart';
import 'package:sentry/sentry.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

import '../model/android_studio.dart';
import '../model/flutter_releases.dart';
import '../model/java_releases.dart';

bool isDebug = false;
String installationPath = '';
String flutterChannel = '';
String flutterVersion = '';
Map<String, String> environment = <String, String>{};
String githubRepos = 'https://github.com/daffaalam/flutter_installer_cli';
SentryClient sentryClient = SentryClient(
  dsn: '',
); // TODO : remove value before upload to public

void parseArgs(List<String> args) {
  var parse = ArgParser();
  parse.addOption(
    'channel',
    valueHelp: 'flutter channel',
    help: 'If the version and channel do not find a match, '
        'it will retrieve the latest this channel version.',
    allowed: <String>['stable', 'beta', 'dev'],
    defaultsTo: 'stable',
    callback: (value) {
      value ??= '';
      flutterChannel = value;
    },
  );
  parse.addFlag(
    'verbose',
    abbr: 'v',
    defaultsTo: false,
    negatable: false,
    callback: (bool value) {
      isDebug = value;
    },
  );
  parse.addOption(
    'version',
    help: 'Use version naming format from Flutter SDK Releases '
        '(https://flutter.dev/docs/development/tools/sdk/releases). '
        'Example: --version v1.9.1+hotfix.6\n'
        '(defaults to check the latest version)',
    valueHelp: 'flutter version',
    callback: (value) {
      value ??= '';
      flutterVersion = value;
    },
  );
  try {
    parse.parse(args);
  } on ArgParserException {
    stdout.writeln('${parse.usage}');
    exit(1);
  }
}

Future<bool> checkPowerShell() async {
  try {
    var result = await run(
      'powershell \$Host.Version.Major',
      [],
      verbose: isDebug,
      stdin: shell_run.sharedStdIn,
    );
    var version = fixVerbose(result.stdout, result.stderr);
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
  var _response = await Dio().get(
    'https://storage.googleapis.com/flutter_infra/releases/releases_$operatingSystem.json',
  );
  return FlutterReleases.fromMap(_response.data);
}

Future<JavaReleases> getJavaLatestInfo({
  @required String operatingSystem,
}) async {
  stdout.writeln('[JAVA] Getting latest version info...');
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
}

Future<Response> downloadFile({
  String title = 'unknown',
  String content = '',
  Map<String, String> queryParam = const <String, String>{},
  @required String urlPath,
  @required String savePath,
}) async {
  stdout.writeln('[$title] Downloading $content [START]');
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
  String content = '',
  @required String filePath,
  @required String savePath,
}) async {
  stdout.writeln('[$title] Extracting $content [START]');
  var archive = ZipDecoder().decodeBytes(
    File(filePath).readAsBytesSync(),
  );
  var oldName = archive[0].name.replaceAll('/', '') + '.old';
  var existsOld = await Directory(oldName).exists();
  if (existsOld) await Directory(oldName).delete(recursive: true);
  var existsNew = await Directory(archive[0].name).exists();
  if (existsNew) await Directory(archive[0].name).rename(oldName);
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
}

Future<AndroidStudio> checkAndroidStudio() async {
  try {
    var studioPath = '';
    var setDir = await Directory('$userHomePath').list().toSet();
    for (var dir in setDir) {
      if (dir.path.contains('.AndroidStudio')) studioPath = dir.path;
    }
    var version = studioPath.replaceAll('$userHomePath\\.AndroidStudio', '');
    var home = await File('$studioPath\\system\\.home').readAsString();
    stdout.writeln(
      '[STUDIO] Android Studio $version already installed on ${home.trim()}',
    );
    return AndroidStudio(
      home: home.trim(),
      config: '$studioPath\\config',
    );
  } catch (e) {
    return null;
  }
}

Future<void> installFlutter({
  @required String operatingSystem,
}) async {
  var flutterReleases = await getFlutterLatestInfo(
    operatingSystem: operatingSystem,
  );
  var release = fixFlutterVersion(flutterReleases);
  var flutterZipPath = '${release.archive}'.replaceFirst(
    '${channelValues.reverse[release.channel]}/${operatingSystem}',
    Directory.current.path + '\\flutter_installer',
  );
  var exists = await File(flutterZipPath).exists();
  if (!exists) {
    await downloadFile(
      title: 'FLUTTER',
      content: 'Flutter ${release.version}',
      urlPath: '${flutterReleases.baseUrl}/${release.archive}',
      savePath: flutterZipPath,
    );
  }
  await extractZip(
    title: 'FLUTTER',
    content: 'Flutter ${release.version}',
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

Future<int> checkJavaVersion() async {
  var result = await run('java', ['-fullversion']);
  var verbose = fixVerbose(result.stderr, result.stdout);
  var version = 0;
  for (var split in verbose.split('"')) {
    if (split.contains('.')) {
      var verA = int.tryParse(split.split('.')[0]);
      var verB = int.tryParse(split.split('.')[1]);
      if (verB == 0) {
        version = verA;
      } else {
        version = verB;
      }
    }
  }
  return version;
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
    content: 'Installing platform-tools',
    arg: 'platform-tools',
    verbose: isDebug,
    toolsPath: toolsPath,
  );
  var platformAndroid = await checkLatestAndroidSdk(
    androidTool: 'platforms;android-',
  );
  await runSdkManager(
    content: 'Installing $platformAndroid',
    arg: platformAndroid,
    verbose: isDebug,
    toolsPath: toolsPath,
  );
  var buildTool = await checkLatestAndroidSdk(
    androidTool: 'build-tools;',
  );
  await runSdkManager(
    content: 'Installing $buildTool',
    arg: buildTool,
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

Future<void> runSdkManager({
  String content = '',
  String arg = '',
  bool verbose = false,
  @required String toolsPath,
}) async {
  stdout.writeln('[ANDROID] $content');
  var accScript = 'for(\$i=0;\$i -lt 15;\$i++)'
      ' { \$response += "y`n" }; '
      '\$response | .\\sdkmanager $arg';
  await run(
    'powershell $accScript',
    [],
    workingDirectory: toolsPath,
    environment: environment,
    verbose: verbose,
  );
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
  var result = await run('setx', ['$variable', '$value'], verbose: isDebug);
  var verbose = fixVerbose(result.stdout, result.stderr);
  if (verbose.contains('SUCCESS')) {
    stdout.writeln('[$title] Updated $variable successfully');
  } else {
    stderr.writeln('[$title] Failed to update $variable');
  }
  var finalPath = fixPath('${environment[variable]};$value');
  environment.addAll(
    <String, String>{
      variable: '$finalPath',
    },
  );
}

Future<void> vscodeInstallExtensions() async {
  var result = await run('code', ['--list-extensions'], verbose: isDebug);
  var verbose = fixVerbose(result.stdout, result.stderr);
  if (!verbose.contains('Dart-Code.flutter')) {
    stdout.writeln('[VSCODE] Installing extensions [START]');
    var args = <String>[
      '--install-extension dart-code.flutter --force',
      '--install-extension dart-code.dart-code --force',
    ];
    var result = await run('code ${args.join(' ')}', [], verbose: isDebug);
    var verbose = fixVerbose(result.stdout, result.stderr).toLowerCase();
    if (verbose.contains('failed')) {
      stdout.writeln('[VSCODE] Failed installing extensions [FINISH]');
    } else {
      stdout.writeln(
        '[VSCODE] Extension was successfully installed [FINISH]',
      );
    }
  }
}

Future<void> androidStudioInstallExtensions({
  @required AndroidStudio studio,
}) async {
  var pluginsPath = Directory('${studio.config}\\plugins');
  var plugins = pluginsPath.listSync();
  var dartPlugin = false;
  var flutterPlugin = false;
  for (var dir in plugins) {
    if (dir.path.contains('Dart')) dartPlugin = true;
    if (dir.path.contains('flutter-intellij')) flutterPlugin = true;
  }
  var build = await File('${studio.home}\\build.txt').readAsString();
  if (!dartPlugin) {
    await installPluginAS(
      content: 'Dart plugin for Android Studio',
      savePath: 'DartPlugin.zip',
      id: 'Dart',
      build: build,
      pluginPath: pluginsPath.path,
    );
  }
  if (!flutterPlugin) {
    await installPluginAS(
      content: 'Flutter plugin for Android Studio',
      savePath: 'FlutterPlugin.zip',
      id: 'io.flutter',
      build: build,
      pluginPath: pluginsPath.path,
    );
  }
}

Future<void> installPluginAS({
  String content,
  @required String savePath,
  @required String id,
  @required String build,
  @required String pluginPath,
}) async {
  await downloadFile(
    content: content,
    title: 'ANDROID',
    urlPath: 'https://plugins.jetbrains.com/pluginManager',
    savePath: savePath,
    queryParam: <String, String>{
      'action': 'download',
      'id': id,
      'build': build,
    },
  );
  await extractZip(
    title: 'ANDROID',
    content: content,
    filePath: savePath,
    savePath: pluginPath,
  );
}

Future<void> checkLatestVersion() async {
  try {
    var dio = Dio(BaseOptions(responseType: ResponseType.plain));
    var response = await dio.get('$githubRepos/raw/master/pubspec.yaml');
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

Release fixFlutterVersion(FlutterReleases flutterReleases) {
  for (var release in flutterReleases.releases) {
    var isVersion = release.version == flutterVersion;
    var isChannel = release.channel == channelValues.map[flutterChannel];
    if (isVersion && isChannel) {
      return release;
    }
  }
  for (var release in flutterReleases.releases) {
    var isChannel = release.channel == channelValues.map[flutterChannel];
    if (isChannel) {
      return release;
    }
  }
  for (var release in flutterReleases.releases) {
    if (flutterReleases.currentRelease.stable == release.hash) {
      return release;
    }
  }
  return flutterReleases.releases.last;
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
  return path.trim();
}

String fixVerbose(String out, String err) {
  out ??= '';
  err ??= '';
  return '${out.isEmpty ? err : out}'.trim();
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

Future<Null> errorLog(e, s) async {
  s = s ?? StackTrace.current;
  if (!isDebug) {
    await sentryClient.captureException(
      exception: e,
      stackTrace: s,
    );
  }
  var logFile = File('flutter_installer_error.log');
  await logFile.writeAsString(
    '${DateTime.now()}\n$e\n$s\n'.trim(),
    mode: FileMode.writeOnlyAppend,
  );
  stderr.writeln(
    'Sorry. Failed to install.\n$e\n'
    'Please send an error log (${logFile.absolute.path}) to the github issue ($githubRepos/issues).\n'
    'Close this window or double `Enter`.',
  );
  stdin.readLineSync();
  exit(2);
}
