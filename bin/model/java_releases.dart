import 'dart:convert';

class JavaReleases {
    String releaseName;
    String releaseLink;
    DateTime timestamp;
    bool release;
    List<Binary> binaries;
    int downloadCount;

    JavaReleases({
        this.releaseName,
        this.releaseLink,
        this.timestamp,
        this.release,
        this.binaries,
        this.downloadCount,
    });

    factory JavaReleases.fromJson(String str) => JavaReleases.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory JavaReleases.fromMap(Map<String, dynamic> json) => JavaReleases(
        releaseName: json['release_name'],
        releaseLink: json['release_link'],
        timestamp: json['timestamp'] == null ? null : DateTime.parse(json['timestamp']),
        release: json['release'],
        binaries: json['binaries'] == null ? null : List<Binary>.from(json['binaries'].map((x) => Binary.fromMap(x))),
        downloadCount: json['download_count'],
    );

    Map<String, dynamic> toMap() => {
        'release_name': releaseName,
        'release_link': releaseLink,
        'timestamp': timestamp == null ? null : timestamp.toIso8601String(),
        'release': release,
        'binaries': binaries == null ? null : List<dynamic>.from(binaries.map((x) => x.toMap())),
        'download_count': downloadCount,
    };
}

class Binary {
    String os;
    String architecture;
    String binaryType;
    String openjdkImpl;
    String binaryName;
    String binaryLink;
    int binarySize;
    String checksumLink;
    String installerName;
    String installerLink;
    int installerSize;
    String installerChecksumLink;
    int installerDownloadCount;
    String version;
    VersionData versionData;
    String heapSize;
    int downloadCount;
    DateTime updatedAt;

    Binary({
        this.os,
        this.architecture,
        this.binaryType,
        this.openjdkImpl,
        this.binaryName,
        this.binaryLink,
        this.binarySize,
        this.checksumLink,
        this.installerName,
        this.installerLink,
        this.installerSize,
        this.installerChecksumLink,
        this.installerDownloadCount,
        this.version,
        this.versionData,
        this.heapSize,
        this.downloadCount,
        this.updatedAt,
    });

    factory Binary.fromJson(String str) => Binary.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory Binary.fromMap(Map<String, dynamic> json) => Binary(
        os: json['os'],
        architecture: json['architecture'],
        binaryType: json['binary_type'],
        openjdkImpl: json['openjdk_impl'],
        binaryName: json['binary_name'],
        binaryLink: json['binary_link'],
        binarySize: json['binary_size'],
        checksumLink: json['checksum_link'],
        installerName: json['installer_name'],
        installerLink: json['installer_link'],
        installerSize: json['installer_size'],
        installerChecksumLink: json['installer_checksum_link'],
        installerDownloadCount: json['installer_download_count'],
        version: json['version'],
        versionData: json['version_data'] == null ? null : VersionData.fromMap(json['version_data']),
        heapSize: json['heap_size'],
        downloadCount: json['download_count'],
        updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at']),
    );

    Map<String, dynamic> toMap() => {
        'os': os,
        'architecture': architecture,
        'binary_type': binaryType,
        'openjdk_impl': openjdkImpl,
        'binary_name': binaryName,
        'binary_link': binaryLink,
        'binary_size': binarySize,
        'checksum_link': checksumLink,
        'installer_name': installerName,
        'installer_link': installerLink,
        'installer_size': installerSize,
        'installer_checksum_link': installerChecksumLink,
        'installer_download_count': installerDownloadCount,
        'version': version,
        'version_data': versionData == null ? null : versionData.toMap(),
        'heap_size': heapSize,
        'download_count': downloadCount,
        'updated_at': updatedAt == null ? null : updatedAt.toIso8601String(),
    };
}

class VersionData {
    String openjdkVersion;
    String semver;

    VersionData({
        this.openjdkVersion,
        this.semver,
    });

    factory VersionData.fromJson(String str) => VersionData.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory VersionData.fromMap(Map<String, dynamic> json) => VersionData(
        openjdkVersion: json['openjdk_version'],
        semver: json['semver'],
    );

    Map<String, dynamic> toMap() => {
        'openjdk_version': openjdkVersion,
        'semver': semver,
    };
}
