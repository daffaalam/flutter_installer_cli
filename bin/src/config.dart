import 'package:pub_semver/pub_semver.dart';
import 'package:sentry/sentry.dart';

Version version = Version.parse('0.3.0');
bool verboseShow = false;
bool isDebug = false;
String installationPath = '';
String flutterChannel = '';
String flutterVersion = '';
Map<String, String> environment = <String, String>{};
String githubRepos = 'https://github.com/daffaalam/flutter_installer_cli';
SentryClient sentryClient = SentryClient(
  dsn: '' // TODO : remove value before upload to public
      '',
);
