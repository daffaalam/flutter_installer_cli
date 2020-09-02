import 'dart:io';

import 'package:args/args.dart';
import 'package:process_run/shell.dart';
import 'package:sentry/sentry.dart';

import 'config.dart';
import 'exception.dart';
import 'tool.dart';

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

Future<void> logNewRun() async {
  environment.addAll(Platform.environment);
  await open('https://flutter.dev/docs/get-started/install/'
      '${Platform.operatingSystem}#system-requirements');
  var cont = await promptConfirm(
    '\nBefore continuing this, double-check the tools needed to run the Flutter.\n'
    'https://flutter.dev/docs/get-started/install/'
    '${Platform.operatingSystem}#system-requirements',
  );
  if (!cont) exit(0);
  await logCat(
    '[$version] install flutter version ${flutterVersion ?? 'latest'} '
    '(${flutterChannel ?? 'stable'}) in $installationPath',
  );
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

Future<File> logCat(String message) async {
  var tempLog = fixPathPlatform(runDir + '/flutter_installer.log', File);
  var file = await File(tempLog).writeAsString(
    '${DateTime.now()}\t$message\n',
    mode: FileMode.writeOnlyAppend,
  );
  return file;
}

Future<Null> errorLog(dynamic e, StackTrace s) async {
  var exception = exceptionLog(e);
  s ??= StackTrace.current;
  var logFile = await logCat('[ERROR]\n$e\n$s');
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
