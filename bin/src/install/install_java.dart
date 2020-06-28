import 'dart:io';

import 'package:dio/dio.dart';
import 'package:process_run/process_run.dart';

import '../../model/java_releases.dart';
import '../config.dart';
import '../tool.dart';

Future<JavaReleases> getJavaLatestInfo() async {
  stdout.writeln('[JAVA] Getting latest version info...');
  var os = Platform.operatingSystem.replaceAll('os', '');
  var _response = await Dio().get(
    'https://api.adoptopenjdk.net/v2/info/releases/openjdk8',
    queryParameters: <String, String>{
      'openjdk_impl': 'hotspot',
      'os': os,
      'arch': 'x64',
      'release': 'latest',
      'type': 'jdk',
      'heap_size': 'normal',
    },
  );
  return JavaReleases.fromMap(_response.data);
}

Future<int> checkJavaVersion() async {
  var result = await run('java', ['-fullversion']);
  var verbose = fixVerbose(result.stderr, result.stdout);
  for (var split in verbose.split('"')) {
    if (split.contains('.')) {
      var verA = int.tryParse(split.split('.')[0]);
      var verB = int.tryParse(split.split('.')[1]);
      return verB == 0 ? verA : verB;
    }
  }
  return 0;
}

Future<void> installJava() async {
  var javaReleases = await getJavaLatestInfo();
  var binary = javaReleases.binaries[0];
  var javaZipPath = fixPathPlatform(downloadDir + binary.binaryName, File);
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
    savePath: installationPath,
  );
  var javaPackage = '${binary.binaryType}'
      '${binary.versionData.openjdkVersion}';
  await setVariableEnvironment(
    title: 'JAVA',
    variable: 'JAVA_HOME',
    value: '$installationPath/$javaPackage',
  );
  await setPathEnvironment(
    title: 'JAVA',
    newPath: '${installationPath}/$javaPackage/bin',
  );
}
