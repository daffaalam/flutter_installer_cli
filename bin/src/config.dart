import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:sentry/sentry.dart';

import '../../.env';
import 'tool.dart';

bool verboseShow = false;
bool isDebug = false;
String installationPath = '';
String flutterChannel = '';
String flutterVersion = '';
Map<String, String> environment = <String, String>{};

final Version version = Version.parse('0.3.2');
final String githubRepos = 'https://github.com/daffaalam/flutter_installer_cli';
final SentryClient sentryClient = SentryClient(dsn: DSN);
final String runDir = Directory(Platform.script.toFilePath()).parent.path;
final String downloadDir = fixPathPlatform(
  runDir + '/flutter_installer/',
  Directory,
);
