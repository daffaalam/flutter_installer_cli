import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../model/flutter_releases.dart';
import '../model/java_releases.dart';

class ApiClient {
  static final Dio _dio = Dio();

  static Future<FlutterReleases> getFlutterLatestInfo({
    @required String operatingSystem,
  }) async {
    try {
      var _response = await _dio.get(
        'https://storage.googleapis.com/flutter_infra/releases/releases_$operatingSystem.json',
      );
      return FlutterReleases.fromMap(_response.data);
    } catch (e) {
      throw Exception('$e');
    }
  }

  static Future<JavaReleases> getJavaLatestInfo({
    @required String operatingSystem,
  }) async {
    try {
      var _response = await _dio.get(
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
      throw Exception('$e');
    }
  }

  static Future<Response> downloadFile({
    @required String urlPath,
    @required String savePath,
  }) async {
    try {
      var _response = await _dio.download(
        '$urlPath',
        '$savePath',
      );
      return _response;
    } catch (e) {
      throw Exception('$e');
    }
  }
}
