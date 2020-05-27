import 'dart:convert';

class FlutterReleases {
    String baseUrl;
    CurrentRelease currentRelease;
    List<Release> releases;

    FlutterReleases({
        this.baseUrl,
        this.currentRelease,
        this.releases,
    });

    factory FlutterReleases.fromJson(String str) => FlutterReleases.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory FlutterReleases.fromMap(Map<String, dynamic> json) => FlutterReleases(
        baseUrl: json['base_url'],
        currentRelease: json['current_release'] == null ? null : CurrentRelease.fromMap(json['current_release']),
        releases: json['releases'] == null ? null : List<Release>.from(json['releases'].map((x) => Release.fromMap(x))),
    );

    Map<String, dynamic> toMap() => {
        'base_url': baseUrl,
        'current_release': currentRelease == null ? null : currentRelease.toMap(),
        'releases': releases == null ? null : List<dynamic>.from(releases.map((x) => x.toMap())),
    };
}

class CurrentRelease {
    String beta;
    String dev;
    String stable;

    CurrentRelease({
        this.beta,
        this.dev,
        this.stable,
    });

    factory CurrentRelease.fromJson(String str) => CurrentRelease.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory CurrentRelease.fromMap(Map<String, dynamic> json) => CurrentRelease(
        beta: json['beta'],
        dev: json['dev'],
        stable: json['stable'],
    );

    Map<String, dynamic> toMap() => {
        'beta': beta,
        'dev': dev,
        'stable': stable,
    };
}

class Release {
    String hash;
    Channel channel;
    String version;
    DateTime releaseDate;
    String archive;
    String sha256;

    Release({
        this.hash,
        this.channel,
        this.version,
        this.releaseDate,
        this.archive,
        this.sha256,
    });

    factory Release.fromJson(String str) => Release.fromMap(json.decode(str));

    String toJson() => json.encode(toMap());

    factory Release.fromMap(Map<String, dynamic> json) => Release(
        hash: json['hash'],
        channel: json['channel'] == null ? null : channelValues.map[json['channel']],
        version: json['version'],
        releaseDate: json['release_date'] == null ? null : DateTime.parse(json['release_date']),
        archive: json['archive'],
        sha256: json['sha256'],
    );

    Map<String, dynamic> toMap() => {
        'hash': hash,
        'channel': channel == null ? null : channelValues.reverse[channel],
        'version': version,
        'release_date': releaseDate == null ? null : releaseDate.toIso8601String(),
        'archive': archive,
        'sha256': sha256,
    };
}

enum Channel { BETA, STABLE, DEV }

final channelValues = EnumValues({
    'beta': Channel.BETA,
    'dev': Channel.DEV,
    'stable': Channel.STABLE
});

class EnumValues<T> {
    Map<String, T> map;
    Map<T, String> reverseMap;

    EnumValues(this.map);

    Map<T, String> get reverse {
        reverseMap ??= map.map((k, v) => MapEntry(v, k));
        return reverseMap;
    }
}
