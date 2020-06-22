# Flutter Installer

[![GitHub issues](https://img.shields.io/github/issues/daffaalam/flutter_installer_cli)](https://github.com/daffaalam/flutter_installer_cli/issues) [![GitHub forks](https://img.shields.io/github/forks/daffaalam/flutter_installer_cli)](https://github.com/daffaalam/flutter_installer_cli/network) [![GitHub stars](https://img.shields.io/github/stars/daffaalam/flutter_installer_cli)](https://github.com/daffaalam/flutter_installer_cli/stargazers) [![GitHub license](https://img.shields.io/github/license/daffaalam/flutter_installer_cli)](https://github.com/daffaalam/flutter_installer_cli/blob/master/LICENSE)

Installer for Flutter SDK, including Android SDK and Java SDK if not installed (automatic detection). Currently only for Windows. MacOS and Linux are under development.

## How to run

Please remember the [system requirements](https://flutter.dev/docs/get-started/install/windows#system-requirements) needed before running this application.

Download **[here](https://github.com/daffaalam/flutter_installer_cli/releases/latest)** and run right away.

By default it will take the latest flutter version from the stable channel. If you want to use another version, use the `channel` and `version` flags. Use the version name from https://flutter.dev/docs/development/tools/sdk/releases.

For example to get the latest beta channel:
```
flutter_installer_cli --channel beta
```
You can also choose the version:
```
flutter_installer_cli --version v1.12.13+hotfix.9
```
You can also combine two flags:
```
flutter_installer_cli --channel beta --version v1.14.6
```

If the version and channel do not find a match, it will retrieve the latest this channel version (by default it is a stable channel).

## Screenshots

![screenshot](screenshots/screenshot.png)

## Features

- [x] Detects whether Android Studio and or Visual Studio Code is already installed.
- [x] Detects whether Android SDK, Java SDK and Flutter SDK are installed.
- [x] Check the latest versions of Android SDK, Java SDK, and Flutter SDK.
- [x] Install Android SDK, Java SDK, and Flutter SDK.
- [x] Install Flutter and Dart plugin for Visual Studio Code and Android Studio.
- [x] Choose the previous flutter version.

## TODO

- [ ] low - Language improvement (I'm very bad at English).
- [ ] high - Implementation to Linux and MacOS.
- [ ] low - Pretty and simple code.
- [ ] high - Implementation to the GUI (flutter) version.
- [ ] high - Can choose a custom installation path.

## Running the tests

1. Create a new virtual machine (Windows 7, 8, 10) with VirtualBox or everything.
2. Run it from Command Prompt or PowerShell, don't run it from double click, so you can see the crash message before the program exits.

## Deployment

1. Clone or download this [repository](https://github.com/daffaalam/flutter_installer_cli).
2. Install `Dart` from https://dart.dev/get-dart or https://gekorm.com/dart-windows/.
3. Run on project: `dart2native bin/flutter_installer_cli.dart`.

## Other

(Obsolete) Batch file (.bat) version [here](https://github.com/daffaalam/flutter-installer).

## Contributing

When contributing to this repository, please first discuss the change you wish to make via [issue](https://github.com/daffaalam/flutter_installer_cli/issues), [email](mailto:daffaalam@gmail.com), or [any other method](https://s.id/bio-daffa) with the owners of this repository before making a change.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
