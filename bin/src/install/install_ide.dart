import 'dart:io';

import 'package:meta/meta.dart';
import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart';

import '../../model/android_studio.dart';
import '../internal/config.dart';
import '../internal/tool.dart';

Future<AndroidStudio> checkAndroidStudio() async {
  try {
    var studioPath = '';
    var studioPrefix = '';
    var macDir = Platform.isMacOS ? '/Library/Preferences' : '';
    var listDir = await Directory('$userHomePath$macDir').list().toList();
    for (var dir in listDir) {
      if (dir.path.contains('.AndroidStudio')) {
        studioPath = dir.path;
        studioPrefix = '.AndroidStudio';
      }
      if (dir.path.contains('AndroidStudio')) {
        studioPath = dir.path;
        studioPrefix = 'AndroidStudio';
      }
    }
    var version = studioPath.replaceAll(
      fixPathPlatform('$userHomePath$macDir/$studioPrefix', File),
      '',
    );
    var home = await File(
      fixPathPlatform('$studioPath/system/.home', File),
    ).readAsString();
    var build = await File(
      fixPathPlatform('$home/build.txt', File),
    ).readAsString();
    stdout.writeln(
      '[ANDROID STUDIO] Android Studio $version already installed on ${home.trim()}',
    );
    return AndroidStudio(
      home: home.trim(),
      config: fixPathPlatform('$studioPath/config', File),
      build: build.trim(),
    );
  } catch (e) {
    return null;
  }
}

Future<void> vscodeInstallExtensions() async {
  var result = await run('code', ['--list-extensions'], verbose: verboseShow);
  var verbose = fixVerbose(result.stdout, result.stderr);
  if (!verbose.contains('Dart-Code.flutter')) {
    stdout.writeln('[VSCODE] Installing extensions [START]');
    var args = <String>[
      '--install-extension dart-code.flutter --force',
      '--install-extension dart-code.dart-code --force',
    ];
    var result = await run('code ${args.join(' ')}', [], verbose: verboseShow);
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
  var pluginsPath = Directory(
    fixPathPlatform('${studio.config}/plugins', Directory),
  );
  var plugins = await pluginsPath.list().toList();
  var dartPlugin = false;
  var flutterPlugin = false;
  for (var dir in plugins) {
    if (dir.path.contains('Dart')) dartPlugin = true;
    if (dir.path.contains('flutter-intellij')) flutterPlugin = true;
  }
  if (!dartPlugin) {
    await installPluginAS(
      content: 'Dart plugin for Android Studio',
      savePath: fixPathPlatform(
        downloadDir + '/DartPlugin-${studio.build}.zip',
        File,
      ),
      id: 'Dart',
      build: studio.build,
      pluginPath: pluginsPath.path,
    );
  }
  if (!flutterPlugin) {
    await installPluginAS(
      content: 'Flutter plugin for Android Studio',
      savePath: fixPathPlatform(
        downloadDir + '/FlutterPlugin-${studio.build}.zip',
        File,
      ),
      id: 'io.flutter',
      build: studio.build,
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
    title: 'ANDROID STUDIO',
    urlPath: 'https://plugins.jetbrains.com/pluginManager',
    savePath: savePath,
    queryParam: <String, String>{
      'action': 'download',
      'id': id,
      'build': build,
    },
  );
  await extractZip(
    title: 'ANDROID STUDIO',
    content: content,
    filePath: savePath,
    savePath: pluginPath,
  );
}
